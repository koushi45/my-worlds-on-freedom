"""1546 affiliation draft and deterministic placements within explicit house pools.

Life-long service lists are only leads; uncertain start-year service stays labelled.
No surname-only matching, no territory inferred from the 1582 map's ownership.
"""
import collections, hashlib, json, re
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
MASTER=ROOT/'data/master/officers'
CACHE=ROOT/'data/sources/officers/affiliations_1546'
def read(p):return json.loads(p.read_text(encoding='utf-8'))
def write(p,d):p.parent.mkdir(parents=True,exist_ok=True);p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
def links(s):return [x.split('#')[0] for x in re.findall(r'\[\[([^]|]+)',s)]
def plain(s):
    s=re.sub(r'<ref\b.*?(?:</ref>|/>)','',s,flags=re.S)
    s=re.sub(r'\{\{.*?\}\}','',s)
    s=re.sub(r'\[\[([^]|]+)\|([^]]+)\]\]',r'\2',s)
    return re.sub(r'<[^>]+>|\[\[|\]\]','',s).strip()
def bio_year(p,key,fallback):
    s=re.sub(r'<!--.*?-->','',p.get(key,''),flags=re.S).split('<ref')[0].split('{{')[0]
    years=[int(y) for y in re.findall(r'(?<!\d)(1[0-9]{3}|20[0-9]{2})年',s)]
    return [min(years),max(years)] if years else fallback
def main():
    # The reviewed batch uses a frozen pre-review input to prevent unrelated moves.
    if (MASTER/'affiliation_research_100_baseline.json').exists():
        from build_affiliation_research_100 import main as build_reviewed
        build_reviewed()
        return
    roster=read(ROOT/'data/derived/officers/officers_1546.json')['officers']
    byname={r['display_name']:r for r in roster}
    byid={r['external_id']:r for r in roster}
    candidates=read(ROOT/'docs/districts/areas/district_areas.json')['rows']
    review={r['external_id']:r for r in read(MASTER/'remaining_40_review.json')}
    caches={p.stem:read(p) for p in CACHE.glob('Q*.json')}
    rows=read(Path(__file__).with_name('affiliation_house_rows.json'))+read(Path(__file__).with_name('affiliation_house_supplement.json'))
    houses={};lordhouse={}
    for fid,label,head,spec,lords,note in rows:
        pool=[]
        for block in spec.split(';') if spec else []:
            parent,names=block.split(':');names=names.split(',')
            found=[d for d in candidates if d['parent']==parent and (names==['*'] or d['name'] in names)]
            assert found,(fid,block)
            pool+=found
        source=caches.get(byname.get(head,{}).get('external_id'),{})
        houses[fid]={'id':fid,'display_name':label,'head_reference':head,'pool':[d['key'] for d in pool],
            'district_names':[d['country']+'・'+d['name'] for d in pool],
            'basis':'1546年頃の本拠圏を使ったゲーム用配置候補。郡全域の排他的領有確定ではない。',
            'note':note,'source_urls':[source['url']] if source else [],'status':'editorial_core_area_draft'}
        for lord in lords.split(','):lordhouse[lord]=fid
    clan_house={'後北条氏':'hojo','大友氏':'otomo','今川氏':'imagawa','朝倉氏':'asakura','六角氏':'rokkaku','浅井氏':'azai',
        '尼子氏':'amago','毛利氏':'mori','三好氏':'miyoshi','長宗我部氏':'chosokabe','龍造寺氏':'ryuzoji',
        '島津氏':'shimazu','伊達氏':'date','蘆名氏':'ashina','佐竹氏':'satake','里見氏':'satomi',
        '宇都宮氏':'utsunomiya','最上氏':'mogami','南部氏':'nanbu','小野寺氏':'onodera','大崎氏':'osaki',
        '葛西氏':'kasai','田村氏':'tamura','岩城氏':'iwaki','相馬氏':'soma','北畠氏':'kitabatake',
        '赤松氏':'akamatsu','別所氏':'bessho','浦上氏':'uragami','三村氏':'mimura','筒井氏':'tsutsui',
        '波多野氏':'hatano','赤井氏':'akai','相良氏':'sagara','肝付氏':'kimotsuki','秋月氏':'akizuki'}
    # Clan-only links describe kinship, not service; use only a matching personal
    # clan name and the first recorded lineage, while retaining provisional status.
    # Accession dates prevent a later lord from becoming a 1546 employer.
    after={'織田信長':1551,'織田信行':1551,'織田信勝':1551,'上杉謙信':1548,'長尾景虎':1548,
        '大友宗麟':1550,'大友義鎮':1550,'大友義統':1576,'徳川家康':1555,'松平元康':1555,
        '今川氏真':1560,'武田勝頼':1573,'北条氏政':1559,'北条氏直':1580,'毛利輝元':1563,
        '尼子義久':1561,'斎藤義龍':1554,'斎藤龍興':1561,'浅井長政':1560,'朝倉義景':1548,
        '島津義久':1566,'島津義弘':1560,'島津忠恒':1590,'長宗我部元親':1560,'長宗我部盛親':1599,
        '龍造寺隆信':1548,'龍造寺政家':1584,'吉川元春':1547,'宇喜多直家':1550,
        '伊達輝宗':1564,'伊達政宗':1584,'大内義長':1551,'三好義継':1564,'三好長治':1562,
        '足利義昭':1568,'畠山高政':1550,'畠山義綱':1560,'結城晴朝':1559,'最上義光':1570,
        '南部信直':1582,'相良義陽':1555,'伊東祐兵':1570,'有馬晴信':1571,'大村純忠':1550,
        '松浦鎮信':1568,'秋月種実':1557,'宗像氏貞':1551,'蘆名盛隆':1575,'蘆名盛興':1561,
        '佐竹義重':1562,'佐竹義宣':1589,'里見義弘':1574,'里見義頼':1578,'最上義定':1500}
    own={}
    for fid,label,head,spec,lords,note in rows:
        for lord in lords.split(','):own[lord]=fid
    manual={name:(fid,role,note) for name,fid,role,note in read(Path(__file__).with_name('affiliation_person_overrides.json'))}
    group_reviews={name:(fid,note) for fid,names,note in read(Path(__file__).with_name('affiliation_group_reviews.json')) for name in names.split(',')}
    output={}
    for r in roster:
        q=r['external_id'];name=r['display_name'];cache=caches.get(q,{});params=cache.get('params',{})
        entity=read(ROOT/'data/sources/officers/entities'/(q+'.json'))['entity']
        birth=bio_year(params,'生誕',r['birth_year_range']);death=bio_year(params,'死没',r['death_year_range'])
        multi_bio=cache.get('text','').count('凡例')>1 or len(re.findall(r'\{\{\s*基礎情報[ _]武士',cache.get('text','')))>1
        identity_conflict=bool(birth and death and death[1]<birth[0]) or multi_bio
        role='立場不明';status='unresolved';fid=None;note='1546年の所属・立場を確定する材料が不足。';refs=[cache['url']] if cache else []
        served=links(params.get('主君',''));possible=list(dict.fromkeys(lordhouse[s] for s in served if s in lordhouse))
        record={'year':1546,'house_id':None,'house_display':'所属不明','role':role,'district_key':None,'district_display':'未配置',
            'status':status,'assignment_kind':'none','reason':note,'source_urls':refs,'reference_house_ids':possible,
            'reference_house_display':'・'.join(houses[h]['display_name'] for h in possible) or '未確認',
            'birth_reference':birth,'death_reference':death,'source_locator':'人物紹介の主君・氏族・生誕・死没欄と個別判断',
            'can_serve_at_start':False}
        if identity_conflict:
            role='人物・年代要確認';note='参照ページに複数同名人物の略歴、または生没年の矛盾があるため所属・配置を保留。既存の能力評価は保持。'
        elif r['temporal_status']=='unborn' or birth and birth[0]>1546:
            role='未誕生';status='unborn';note='1546年より後の出生。後年の所属候補は参考欄のみ。'
        elif death and death[1]<1546:
            role='故人';status='deceased';note='1546年以前の没年を参照。生涯評価を保持し、開始時の所属・配置はなし。'
        elif q in review and all(v==12 for v in r['assessment']['scores'].values()):
            role='人物・経歴要確認';note=review[q]['reason']
        elif name in manual:
            fid,role,note=manual[name];fid=fid or None;status='reviewed' if fid else 'unresolved'
        elif name in group_reviews:
            fid,note=group_reviews[name];status='provisional';role='武将（所属推定）'
            if birth and birth[0]>=1532:role='家臣・一門の子（幼少）'
        elif name in own:
            fid=own[name];role='一門・当主候補';status='provisional';note='当該家の人物。1546年の当主・一門の区別は継承年の確認を残す。'
            if name==houses[fid]['head_reference']:
                role='領主・当主';note='本拠圏台帳の1546年当主候補。継承年の年内前後は留保。'
            if birth and birth[0]>=1532:role='一門・幼少'
        elif any(c in clan_house and name.startswith(c.removesuffix('氏').removeprefix('後')) for c in links(params.get('氏族','').split('→')[0])):
            c=next(c for c in links(params['氏族'].split('→')[0]) if c in clan_house and name.startswith(c.removesuffix('氏').removeprefix('後')))
            fid=clan_house[c];role='一門（所属推定）';status='provisional'
            note='人物紹介の氏族欄と当人の家名を照合した一門の配置案。改姓・養子入り時期の追加確認を残す。'
            if birth and birth[0]>=1532:role='一門・幼少'
        else:
            # Only an attested service link can select an employer, never a surname.
            chosen=None
            for lord in served:
                if lord not in lordhouse:continue
                if after.get(lord,0)>1546:continue
                lr=byname.get(lord,{})
                ld=caches.get(lr.get('external_id'),{}).get('params',{})
                dead=bio_year(ld,'死没',lr.get('death_year_range'))
                if dead and dead[1]<1546:continue
                chosen=lord;break
            if chosen and (not birth or birth[1]<1532):
                fid=lordhouse[chosen];role='武将（所属推定）';status='provisional'
                note=f'人物紹介の奉公先「{chosen}」と1546年の活動可能年代を照合した所属案。個人の仕官年月は未確定。'
                # A dated first service after 1546 must not be backdated.
                text=cache.get('text','')
                joined=re.findall(r'(1[45]\d{2})年[^。\n]{0,80}(?:初めて仕え|初めて出仕|より仕え|から仕え)',text)
                if joined and min(map(int,joined))>1546:
                    fid=None;role='未出仕・所属不明';status='unresolved';note='参照紹介の出仕記録は1546年より後。後年の主君を前倒しして割り当てない。'
            elif birth and birth[0]>=1532:
                role='幼少・未出仕';note='幼少期。後年の奉公先を開始時所属とは扱わない。'
        if birth and birth[0]==birth[1]==1546 or death and death[0]==death[1]==1546:
            if status not in ('unborn','deceased'):
                status='same_year_ambiguous';note+=' 1546年の生没の前後が未固定のため郡配置は保留。'
        record.update(house_id=fid,house_display=houses[fid]['display_name'] if fid else ('該当なし' if status in ('unborn','deceased') else '所属不明'),role=role,status=status,reason=note)
        primary={
            '北条氏康':'https://www.city.odawara.kanagawa.jp/kanko/hojo/p09347.html',
            '織田信長':'https://www.city.nagoya.jp/_res/projects/default_project/_page_/001/010/543/shiryou.pdf',
            '織田信秀':'https://www.museum.city.nagoya.jp/exhibition/owari/theme_07/index.html',
            '大友宗麟':'https://www.city.oita.oita.jp/o157/bunkasports/citypromotion/1369370791117.html',
            '大友義鑑':'https://www.city.oita.oita.jp/o204/documents/dai3syou.pdf',
        }
        if name in primary:record['source_urls'].insert(0,primary[name])
        record['can_serve_at_start']=bool(fid and status in ('reviewed','provisional') and not any(s in role for s in ('幼少','未出仕','僧','後継者','若年','年内','候補')) and r['start_present'])
        output[q]=record
    # Children may share a documented parent's affiliation; this is family, not service.
    for q,record in output.items():
        if record['house_id'] or record['role']!='幼少・未出仕':continue
        entity=read(ROOT/'data/sources/officers/entities'/(q+'.json'))['entity']
        parents=[c.get('mainsnak',{}).get('datavalue',{}).get('value',{}).get('id') for c in entity.get('claims',{}).get('P22',[]) if c.get('rank')!='deprecated']
        choices=[p for p in parents if p in output and output[p]['house_id'] and output[p]['status'] in ('reviewed','provisional')]
        if len(choices)==1:
            parent=output[choices[0]];fid=parent['house_id']
            record.update(house_id=fid,house_display=houses[fid]['display_name'],role='家臣・一門の子（幼少）',status='provisional',reason='父の人物IDとの関係を使った家族所属の配置案。本人の出仕を意味しない。父：'+byid[choices[0]]['display_name'])
            record['source_urls']+=parent['source_urls']
    district_by_key={d['key']:d for d in candidates}
    # Round-robin after a stable hash sort balances each family's placement pool.
    for fid,house in houses.items():
        members=sorted((q for q,a in output.items() if a['house_id']==fid and a['status'] in ('reviewed','provisional')),key=lambda q:hashlib.sha256(('1546-v1:'+q).encode()).hexdigest())
        pool=sorted(house['pool'])
        for i,q in enumerate(members):
            if not pool:output[q]['reason']+=' 現行郡に対応領地がなく未配置。';continue
            key=pool[i%len(pool)];d=district_by_key[key]
            output[q].update(district_key=key,district_display=d['country']+'・'+d['name'],assignment_kind='gameplay_distributed_not_historical_residence',district_geometry_status=d['adoption'])
    old=read(MASTER/'assessments.json')
    digest=hashlib.sha256(json.dumps(old,ensure_ascii=False,sort_keys=True).encode()).hexdigest()
    stats=dict(collections.Counter(a['status'] for a in output.values()))
    stats.update(total=len(output),with_house=sum(bool(a['house_id']) for a in output.values()),placed=sum(bool(a['district_key']) for a in output.values()))
    write(MASTER/'affiliations_1546.json',{'schema_version':1,'year':1546,'assessment_sha256':digest,'policy':'郡はゲーム上の分散配置。家の本拠圏内の郡候補を使用し、史実の居所・知行地とは区別。所属推定を確定史実としない。','stats':stats,'officers':output})
    write(MASTER/'house_placement_pools_1546.json',{'schema_version':1,'year':1546,'houses':list(houses.values())})
    lines=['# 1546年の所属家・立場・配置郡','',str(stats),'','郡はユーザー指定によるゲーム用の分散配置で、史実の居所ではない。所属推定と未確定の区別を保持する。未誕生・故人・年内前後不明は配置しない。','','|人物|所属家|立場|配置郡|確度|後年を含む参考所属|','|---|---|---|---|---|---|']
    for r in roster:
        a=output[r['external_id']];lines.append('|'+ '|'.join([r['display_name'],a['house_display'],a['role'],a['district_display'],a['status'],a['reference_house_display']])+'|')
    (ROOT/'docs/officers/AFFILIATIONS_1546.md').write_text('\n'.join(lines)+'\n',encoding='utf-8')
    print(json.dumps(stats,ensure_ascii=False))
if __name__=='__main__':main()
