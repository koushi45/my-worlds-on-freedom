"""Explicit named main stems. Retain all source geometry; change visibility only."""
import networkx as nx

# Editorial major-river selection, not a guessed flow/width classification.
# Aliases describe the SAME main stem; tributaries such as Kinu/Edogawa are excluded.
MAIN_STEMS = [
    ('天塩川',['TESHIO G.']),('石狩川',['ISHIKARI G.']),('十勝川',['TOKACHI G.']),('釧路川',['KUSHIRO G.']),
    ('岩木川',['IWAKI G.']),('馬淵川',['MABECHI G.']),('北上川',['KITAKAMI G.']),
    ('雄物川',['OMONO G.']),('最上川',['MOGAMI G.']),('阿武隈川',['ABUKUMA G.']),
    ('利根川',['TONE G.']),('荒川',['ARA K.'],[138.5,35.5,140.1,36.5]),
    ('多摩川',['TAMA G.']),('相模川',['SAGAMI G.']),
    ('信濃川・千曲川',['SHINANO G.','CHIKUMA G.']),('阿賀野川',['AGANO G.']),
    ('富士川・釜無川',['FUJI K.','FUJI G.','KAMANASHI G.']),('天竜川',['TENRYU G.']),('大井川',['OI G.']),
    ('木曽川',['KISO G.']),('長良川',['NAGARA G.']),('揖斐川',['IBI G.']),
    ('神通川',['JINZU G.']),('庄川',['SHO K.']),('九頭竜川',['KUZURYU G.']),
    ('淀川・宇治川',['YODO G.','UJI G.']),
    ('紀の川',['KINO G.','YOSHINO G.'],[135.0,33.5,136.5,34.6]),
    ('高梁川',['TAKAHASHI G.']),('旭川',['ASAHI G.']),('江の川',['ENO K.','GONO G.']),('太田川',['OTA G.']),
    ('吉野川',['YOSHINO G.'],[132.5,33.0,134.9,34.5]),('四万十川',['SHIMANTO G.']),
    ('仁淀川',['NIYODO G.']),('肱川',['HIJI G.']),
    ('筑後川',['CHIKUGO G.']),('遠賀川',['ONGA G.']),('球磨川',['KUMA G.']),
    ('川内川',['SENDAI G.'],[129.5,31.4,131.2,32.5]),('大野川',['ONO G.']),('大淀川',['OYODO G.'])]

def matches(row, stem):
    if str(row['nam']).strip() not in stem[1]: return False
    if len(stem)<3: return True
    x,y=row.geometry.representative_point().coords[0]
    a,b,c,d=stem[2]
    return a<=x<=c and b<=y<=d

def select(rivers, waters):
    graph=nx.Graph()
    endpoints={}
    for index,row in rivers.iterrows():
        coords=list(row.geometry.coords)
        a=tuple(round(v,6) for v in coords[0]);b=tuple(round(v,6) for v in coords[-1])
        endpoints[index]=(a,b)
        # A graph is used only to bridge gaps in source NAM attributes.
        # Never add or move geometry; preserve source edge indices.
        if not graph.has_edge(a,b) or row.geometry.length<graph[a][b]['weight']:
            graph.add_edge(a,b,index=int(index),weight=row.geometry.length)
    chosen={}
    report=[]
    for stem in MAIN_STEMS:
        seeds={int(i) for i,r in rivers.iterrows() if matches(r,stem)}
        assert seeds,stem[0]
        selected=set(seeds)
        # Connect named portions only through unnamed parts of their original network.
        # Named tributaries and distributaries are never used as shortcuts.
        allowed=[i for i,r in rivers.iterrows() if i in seeds or str(r['nam']).strip()=='UNK']
        routing=nx.Graph()
        for i in allowed:
            a,b=endpoints[i]
            if graph.has_edge(a,b): routing.add_edge(a,b,**graph[a][b])
        for nodes in nx.connected_components(routing):
            targets=sorted({n for i in seeds for n in endpoints[i] if n in nodes})
            if len(targets)<2: continue
            _,paths=nx.single_source_dijkstra(routing,targets[0],weight='weight')
            for target in targets[1:]:
                for a,b in zip(paths[target],paths[target][1:]): selected.add(routing[a][b]['index'])
        for index in selected: chosen.setdefault(index,[]).append(stem[0])
        report.append({'name_ja':stem[0],'source_names':stem[1],'geographic_bounds':stem[2] if len(stem)>2 else None,
            'named_source_indices':sorted(seeds),'connecting_source_indices':sorted(selected-seeds),
            'selected_source_indices':sorted(selected)})
    # Area representations of rivers belong to the river toggle, not the lake toggle.
    surfaces={}
    for index,row in waters.iterrows():
        if int(row['hyt'])!=1: continue
        names=[s[0] for s in MAIN_STEMS if matches(row,s)]
        if not names and str(row['nam']).strip()=='UNK':
            for i in chosen:
                if row.geometry.intersection(rivers.loc[i].geometry).length>0.0001:
                    names=chosen[i];break
        if names: surfaces[int(index)]=names
    return chosen,surfaces,report
