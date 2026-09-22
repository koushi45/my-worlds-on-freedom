"""Personal family identity, independent of 1546 employer and gameplay placement."""
import collections,hashlib,json,re,urllib.parse
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
MASTER=ROOT/'data/master/officers'
CACHE=ROOT/'data/sources/officers/affiliations_1546'
def read(p):return json.loads(p.read_text(encoding='utf-8'))
def write(p,d):p.parent.mkdir(parents=True,exist_ok=True);p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
def digest(d):return hashlib.sha256(json.dumps(d,ensure_ascii=False,sort_keys=True).encode()).hexdigest()
def clean(s):
    s=re.sub(r'<!--.*?-->|<ref\b.*?(?:</ref>|/>)','',s,flags=re.S)
    s=re.sub(r'\{\{.*?\}\}','',s)
    s=re.sub(r'\[\[([^]|]+)\|([^]]+)\]\]',r'\2',s)
    return re.sub(r'<[^>]+>|\[\[|\]\]','',s).strip()
ANCESTORS={'源氏','源姓','清和源氏','宇多源氏','村上源氏','河内源氏','甲斐源氏','平氏','平姓','桓武平氏','藤原氏','藤原北家','藤原南家','大江氏','多々良氏','橘氏','神氏','神党','諏訪神党'}
AMBIGUOUS={'北条','上杉','武田','毛利','酒井','石川','伊東','伊藤','有馬','長野','村上','斎藤','小笠原','細川','内藤','松井','高橋','秋山','鈴木','佐々木','吉田','山田','山本','加藤','前田','池田','太田','大島','本多','松平','佐藤','小川','渡辺','渡邊','中村','原','安藤','安東','土屋','山口','服部','田中','遠藤','遠山','佐野','三浦','結城','児玉','児嶋'}
TARGETS={'六角氏':'rokkaku','肥前有馬氏':'arima_hizen','摂津有馬氏':'arima_settsu','上野長野氏':'nagano_kozuke','長野工藤氏':'nagano_ise','豊前長野氏':'nagano_buzen','信濃村上氏':'murakami_shinano','石川氏 (伊予国)':'ishikawa_iyo','石川氏#三河石川氏':'ishikawa_mikawa','小笠原氏#石見小笠原氏':'ogasawara_iwami','小笠原氏#京都小笠原氏':'ogasawara_kyoto','武田氏#若狭武田氏':'takeda_wakasa','若狭武田氏':'takeda_wakasa','武田氏#安芸武田氏':'takeda_aki','越後北条氏':'kitajo_echigo','扇谷上杉氏':'uesugi_ogigayatsu','越後上杉氏':'uesugi_echigo_shugo'}
ALIASES={'前野家':'前野氏','能登畠山氏':'畠山氏#能登畠山氏','備中清水氏':'清水氏#備中清水氏'}
TARGETS.update({'武田氏#甲斐武田氏':'takeda_kai','本多氏#平八郎家 （忠勝の家系）':'honda_tadakatsu','本多氏#作左衛門家 （重次の家系）':'honda_shigetsugu'})
AMBIGUOUS.add('山内')
def clan_links(raw):
    raw=re.sub(r'<ref\b.*?(?:</ref>|/>)','',raw,flags=re.S)
    result=[]
    for target,alias in re.findall(r'\[\[([^]|]+)(?:\|([^]]+))?\]\]',raw):
        label=alias or target.split('#')[-1]
        if ('氏' in label or '家' in label or '氏' in target) and target.split('#')[0] not in ANCESTORS:
            result.append({'target':target,'label':label})
    return result
def main():
    roster=read(ROOT/'data/derived/officers/officers_1546.json')['officers']
    cache={p.stem:read(p) for p in CACHE.glob('Q*.json')}
    name_ids=collections.defaultdict(list)
    for r in roster:name_ids[r['display_name']].append(r['external_id'])
    groups=read(Path(__file__).with_name('lineage_groups.json'))
    overrides={};catalog={}
    for key,label,names,note in groups:
        catalog[key]={'id':key,'display_name':label,'description':note,'classification':'editorial_family_branch'}
        for name in names.split(','):
            assert len(name_ids[name])<=1,('Ambiguous name requires ID',name)
            for q in name_ids[name]:overrides[q]=(key,note)
    # The two Sakai Tadakatsus have identical display names: identify by record ID.
    overrides['Q5367620']=('sakai_saemon','庄内の酒井忠勝。左衛門尉家。小浜の同名人物とは別ID。')
    overrides['Q7402768']=('sakai_utanokami','小浜の酒井忠勝。雅楽頭家。庄内の同名人物とは別ID。')
    baseline_path=MASTER/'lineages_baseline.json'
    baseline={'roster_ids':sorted(r['external_id'] for r in roster),'assessments_sha256':digest(read(MASTER/'assessments.json')),'affiliations_sha256':digest(read(MASTER/'affiliations_1546.json'))}
    if baseline_path.exists():assert read(baseline_path)==baseline,'Existing scores, affiliations, or roster changed: review baseline explicitly'
    else:write(baseline_path,baseline)
    results={}
    for r in roster:
        q=r['external_id'];name=r['display_name'];source=cache.get(q,{})
        raw=source.get('params',{}).get('氏族','');cs=clan_links(raw)
        record={'family_id':None,'display_name':'家系未確認','status':'unresolved','basis':'未確認','note':'本人の家系・分家を特定する資料の照合待ち。同姓だけで他人物の家系に統合しない。',
            'scope':'lifetime_family_not_1546_employer','source_urls':[source['url']] if source else [],'source_locator':'人物紹介の氏族欄・家族関係・家名の記載',
            'source_clan_text':clean(raw),'documented_family_sequence':[c['label'] for c in cs],
            'has_transition_notation':'→' in raw,'transition_note':'氏族欄の移動・改姓・養子等の表記を保持。各矢印の種類・年次は本文の確認が必要。' if '→' in raw else '',
            'birth_family_display':None,'family_at_1546_display':None}
        multi=source.get('text','').count('凡例')>1 or len(re.findall(r'\{\{\s*基礎情報[ _]武士',source.get('text','')))>1
        if q in overrides:
            key,note=overrides[q];record.update(family_id=key,display_name=catalog[key]['display_name'],status='editorial_review',basis='個別の系統整理',note=note)
        elif not multi:
            candidates=[]
            for i,c in enumerate(cs):
                score=max([n for n in range(1,7) if len(name)>n and name[:n] in c['label']+c['target']]+[0])
                candidates.append((score,i,c))
            chosen=max(candidates,key=lambda x:(x[0],x[1]))[2] if candidates else None
            # A plain, explicit family name is usable even without a wiki link.
            if raw:
                plain=clean(raw)
                tokens=[name[:n] for n in range(1,7) if len(name)>n and name[:n]+'氏' in plain and name[:n]+'氏' not in ANCESTORS]
                if tokens:
                    token=max(tokens,key=len)
                    if not chosen or token not in chosen['label']+chosen['target']:chosen={'target':token+'氏','label':token+'氏'}
            # Missing infoboxes: use an explicit family category / kinship phrase,
            # rather than guessing the surname from the personal name.
            if not chosen:
                text=source.get('text','')
                cats=re.findall(r'\[\[Category:([^]|]+)',text)
                for cat in cats:
                    if re.fullmatch(r'[一-龥々ヶ]{2,10}氏',cat) and cat not in ANCESTORS and name.startswith(cat[:-1]):chosen={'target':cat,'label':cat}
                if chosen:record['basis']='人物記事の家系分類（要照合）'
            if chosen:
                target=ALIASES.get(chosen['target'],chosen['target']);label=chosen['label'];root=target.split('#')[0].split(' (')[0].removesuffix('氏')
                if target in TARGETS:
                    key=TARGETS[target];record.update(family_id=key,display_name=catalog[key]['display_name'],status='source_catalog',basis='氏族欄の系統指定',note=catalog[key]['description'])
                elif root in AMBIGUOUS and '#' not in target and label==root+'氏':
                    record.update(display_name=root+'家（系統未確認）',note='氏族の記載はあるが同姓諸家のどの系統か未確認。共通の家系IDは付与しない。')
                else:
                    # A link can point to a broad clan page while its caption
                    # identifies a particular branch. Never merge those captions
                    # solely because they share the same Wikipedia destination.
                    if any(mark in label for mark in ('→','/','／')):
                        label=target.split('#')[-1]
                    if label.endswith(('流','姓')):label=target.split('#')[0]
                    label=label.replace('氏（','家（').replace('氏 (','家 (')
                    if label.endswith('氏'):label=label[:-1]+'家'
                    if not label.endswith('家') and '家' not in label:label+='家'
                    if '#' in target:
                        branch=target.split('#',1)[1].replace(root+'氏','')
                        branch=re.sub(r'[（(]','・',branch);branch=re.sub(r'[）)]','',branch)
                        label=root+'家（'+branch.strip('・ ')+'）'
                    elif ' (' in target:label=root+'家（'+target.split(' (',1)[1].rstrip(')')+'）'
                    if target=='薩州家':label='島津家（薩州）'
                    if target=='豊州家':label='島津家（豊州）'
                    if target=='将軍家':label='足利家（将軍家）'
                    if target=='水戸徳川家':label='徳川家（水戸）'
                    if target=='土佐山内氏':label='山内家（土佐）'
                    key='family_'+hashlib.sha256((target+'|'+label).encode()).hexdigest()[:16]
                    catalog.setdefault(key,{'id':key,'display_name':label,'description':'氏族の明記に基づく家名分類。近親・嫡流の確定ではない。','classification':'source_catalog','source_family_target':target})
                    record.update(family_id=key,display_name=label,status='source_catalog',basis=record['basis'] if record['basis']!='未確認' else '氏族欄の明記',note='紹介資料の家名・系統に基づく分類。伝承・自称・異説を含む場合があり、血縁の確定や1546年の所属を意味しない。')
        if multi and q not in overrides:record['note']='同名複数人物の略歴を含むページのため家系特定を保留。氏族欄を無条件には採用しない。'
        if q=='Q311080':record.update(birth_family_display='長尾家（越後・府内）',family_at_1546_display='長尾家（越後・府内）',transition_note='1561年に上杉憲政の家と名跡を継承。表示家系は後年の上杉家、1546年は長尾家。')
        if q=='Q171977':record.update(birth_family_display='松平家（安祥）',family_at_1546_display='松平家（安祥）',transition_note='松平氏から徳川氏へ改姓。1546年の家名は松平。')
        if q=='Q1190934':record['birth_family_display']='北条家（相模・後北条）'
        if q=='Q1376605':record['birth_family_display']='長尾家（越後・上田）'
        if q=='Q6379490':record.update(birth_family_display='戸次家',family_at_1546_display='戸次家',transition_note='1571年に立花の名跡を継承。所属先の大友家とは別。')
        if q=='Q120403158':record['note']+=' ユーザーの「六角貞治」は現行名簿の六角定治として対応。別人物を新設しない。'
        primary={'Q467417':'https://crd.ndl.go.jp/reference/entry/index.php?id=1000328828&page=ref_view','Q311080':'https://www.city.nagaoka.niigata.jp/kankou/rekishi/ijin/oitati.html'}
        if q in primary:record['source_urls'].insert(0,primary[q])
        if record['family_id'] and not record['source_urls']:
            record.update(family_id=None, display_name='家系未確認', status='unresolved',
                          basis='個別整理の参照資料不足', note='家名候補はあるが、当人の系統を裏付ける参照資料が未収録のため保留。')
        results[q]=record
    # A linked father is evidence beyond a shared surname. Only inherit a known
    # branch when the child's recorded name agrees and its own branch is unknown.
    entities={r['external_id']:read(ROOT/'data/sources/officers/entities'/(r['external_id']+'.json'))['entity'] for r in roster}
    byid={r['external_id']:r for r in roster}
    for _ in range(4):
        changed=False
        for q,a in results.items():
            if a['family_id'] or '同名複数' in a['note']:continue
            parents=[c.get('mainsnak',{}).get('datavalue',{}).get('value',{}).get('id') for c in entities[q].get('claims',{}).get('P22',[]) if c.get('rank')!='deprecated']
            candidates={p for p in parents if p in results and results[p]['family_id']}
            if len(candidates)!=1:continue
            p=next(iter(candidates));family=results[p];root=family['display_name'].split('家')[0]
            if not byid[q]['display_name'].startswith(root):continue
            a.update(family_id=family['family_id'],display_name=family['display_name'],status='family_relation_provisional',basis='父の人物IDとの関係から推定',note='原台帳の父子リンクと同じ家名を使った系統推定。血縁・養子の実証済みを意味しない。父：'+byid[p]['display_name'],parent_reference_id=p)
            a['source_urls']+=['https://www.wikidata.org/wiki/'+q]+family['source_urls'];changed=True
        if not changed:break
    # Normalize catalogue records shared by explicit branch references and reviews.
    # No fallback from an employer / county / surname is permitted here.
    stats=dict(collections.Counter(x['status'] for x in results.values()));stats.update(total=len(results),assigned=sum(x['family_id'] is not None for x in results.values()),families=len({x['family_id'] for x in results.values() if x['family_id']}))
    write(MASTER/'lineages.json',{'schema_version':1,'basis':'生涯の通用名に対応する本人の家系。1546年の所属先とは別。','stats':stats,'officers':results})
    write(MASTER/'lineage_families.json',{'schema_version':1,'families':[v for k,v in sorted(catalog.items()) if any(r['family_id']==k for r in results.values())]})
    lines=['# 武将の家系','',f'全{len(results)}人／家系分類{stats["assigned"]}人／未確認{stats.get("unresolved",0)}人。','', '家系は本人の家・分家の分類。1546年の仕官先・配置郡とは独立。出生家・養家・改姓を同一視せず、同姓未確定は共通IDに統合しない。','','|人物|家系|根拠区分|出生家（確認分）|','|---|---|---|---|']
    for r in roster:
        a=results[r['external_id']];lines.append('|'+ '|'.join([r['display_name'],a['display_name'],a['basis'],a['birth_family_display'] or '未確認'])+'|')
    (ROOT/'docs/officers/LINEAGES.md').write_text('\n'.join(lines)+'\n',encoding='utf-8')
    print(json.dumps(stats,ensure_ascii=False))
if __name__=='__main__':main()
