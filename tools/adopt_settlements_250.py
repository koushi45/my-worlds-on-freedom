"""One-time reviewed expansion. Live edits belong in the master after adoption."""
import copy,json
from pathlib import Path
from collections import Counter
from urllib.parse import urlparse
ROOT=Path(__file__).resolve().parents[1]
def read(p):return json.loads((ROOT/p).read_text(encoding='utf-8'))
def write(p,v):(ROOT/p).write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
TARGETS=dict(tohoku=31,kanto=37,koshin=13,hokuriku=25,tokai=29,kinki=30,chugoku=35,shikoku=15,kyushu=34,hokkaido=1)
MERGES={
 'uchi_castle':['kanmachi_town','kagoshima_port'], 'shibushi_castle':['shibushi_port'],
 'otomo_yakata':['funai_town'], 'usuki_castle':['usuki_port'], 'katsunoo_castle':['katsunoo_town'],
 'sakai_town':['sakai_port'], 'kyoto_kamigyo':['kyoto_shimogyo'], 'odawara_castle':['odawara_town']}
NAMES={'uchi_castle':'鹿児島・内城','shibushi_castle':'志布志','otomo_yakata':'府内・大友館','usuki_castle':'臼杵','katsunoo_castle':'勝尾','sakai_town':'堺','kyoto_kamigyo':'京都','odawara_castle':'小田原'}
LEGACY={0:'oura',2:'kunohe',6:'shiroishi',9:'sukagawa',10:'shirakawa',12:'nihonmatsu',15:'yamagata',21:'yokote',22:'hiyama',23:'tsuchizaki',25:'odate',28:'edo',41:'kamakura',51:'koga',59:'utsunomiya',61:'minowa',66:'wakamiko',68:'fukashi',69:'suwa',70:'iida',76:'kitanosho',77:'fuchu_echizen',78:'oyama',80:'komatsu',82:'toyama',83:'uozu',98:'tsuruga',99:'obama',100:'kiyosu',103:'kuwana',106:'tsu',112:'ogaki',119:'okazaki',122:'yoshida',124:'kakegawa',126:'atsuta',132:'himeji',135:'izushi',137:'kameyama',138:'fukuchiyama',144:'nara',151:'gassan',155:'hatsukaichi',158:'mihara',162:'kannabe',165:'okayama',170:'tottori',173:'kurayoshi',176:'yunotsu',178:'ginzan',181:'yamaguchi',182:'akaseki',185:'yuzuki',186:'ozu',189:'kawanoe',191:'shozui',192:'hakuchi',195:'hiketa',197:'nakamura',198:'saga',199:'kumamoto'}
SPECIAL={
1:'中世城館の前身を含む地域代表表示。現存縄張りの大改修は1594年で、1582年の形状を表さない。',
4:'稗貫氏の鳥谷ヶ崎城。1591年以後の花巻という城名を対象年の名と混同しない。',
7:'相馬・伊達勢力間の丸森の城。1584年以後の城主配置は対象時点に遡及しない。',
25:'比内の16世紀城館として採用するが、大館城の造営・1582年時点の直接記録は未確定。',
26:'酒田の湊町。16世紀の河川北岸への移転を含むため、当年の町域は未確定。',
33:'北条氏の滝山城域。八王子城への移転時期と当年の利用状態は精査が残る。',
43:'赤井氏以後の中世館林城の継続を推定。1590年以後の榊原氏城下整備は反映しない。',
64:'1533年の宿泊記事と中世集落・交通の沿革から継続を推定。江戸期の中山道宿場制度を設定しない。',
69:'観光協会年表に1582年3月の茶臼山城への代官配置がある。1592年着工の湖畔高島城とは区別。',
75:'木曽氏が居住した中世福島集落を採用。近世の福島関所の規模・制度は設定しない。',
83:'1582年の魚津城攻囲期の拠点。落城前の本能寺の変直前を基準とする。',
93:'直江氏の山城としての与板城。北方の本与板城への利用集中・移転の時期には諸説があるため地域代表として採用し、両城を別計数しない。',
96:'新発田氏の中世城域を採用。溝口氏による近世城郭整備とは区別し、古丸周辺の詳細比定は未完了。',
97:'越後本庄（後の村上）の城域。武蔵本庄や徳川期の村上城の整備を遡及しない。',
98:'中世敦賀湊を採用。若狭ではなく越前に集計する。',
99:'中世小浜湊を採用。1601年築城の近世小浜城は配置しない。',
108:'戦国期の鳥羽湊を代表表示。後代の九鬼氏近世城郭の存在を意味しない。',
109:'興国寺城の沿革・年表を参照。対象年の継続を推定し、築城年の伝承と区別する。',
111:'戦国期に御師の活動が盛んになった内外宮の門前町を宇治山田として一体表示。近世御師制度の規模は設定しない。',
118:'1585年の天正地震以前の帰雲城を採用。埋没前の位置には異説があり、地域代表点に限る。',
133:'中世鶏籠山の龍野城を採用。山麓の近世城郭・御殿とは区別する。',
141:'一色氏最後の拠点として、1582年の本能寺の変後の落城以前を表示する。',
143:'納所の淀古城。江戸期に別の場所で築かれた淀城とは区別する。',
146:'1581～1582年の包囲を受けた寺院・山内集落。寺院ごとに分割して計数しない。',
148:'堀内氏領の熊野新宮の門前集落を表示。近世新宮城を対象年の城として追加しない。',
160:'1568年の出船と16世紀後半の下市形成を紹介する二次解説から港町の継続を推定。市史原典の照合と岸線復元は未完了。',
164:'1582年の高松城攻囲中、本能寺の変直前の拠点。水攻めの湛水域は今回の湖レイヤーとは別で未復元。',
169:'美作の草苅氏の山城を採用。石見銀山近くの同名城と区別する。',
175:'1565年落城後にも16世紀末～17世紀初の遺物がある。対象年の機能継続は推定。',
178:'1526年以後の石見銀山開発に伴う仙ノ山・石銀地区の集落を代表表示。近世大森代官所は採用しない。',
179:'益田氏の石見七尾城。廃城時期が異なる能登七尾城を混同しない。',
184:'1545年頃～1591年の吉川氏の本拠・日山城。隠居館は別拠点として追加しない。',
188:'板島丸串城の中世段階を採用。藤堂高虎以後の宇和島城の縄張りを遡及しない。',
197:'中村の町場を採用。一条氏滅亡後の御所が現役であるとは扱わない。',
198:'龍造寺氏の村中城を代表表示。水ヶ江城など隣接する一体の城下は別計数しない。',
199:'隈本の古城を表示。加藤氏の後代の新城を1582年に遡及しない。'}

def adopt():
    master=read('data/editorial/settlements/settlements_1582.json')
    assert not master.get('allocation_policy'),'Expansion already adopted; edit the master instead.'
    sources=read('data/editorial/settlements/sources.json');lookup={s['id']:s for s in master['sites']}
    for primary,children in MERGES.items():
        s=lookup[primary];members=[copy.deepcopy(s)]+[copy.deepcopy(lookup[c]) for c in children]
        s['components']=[{k:m.get(k) for k in ['id','display_name','roles','lonlat','temporal_note','location_note','source_refs']} for m in members]
        s['display_name']=NAMES[primary]
        s['aliases']=sorted({v for m in members for v in m['aliases']+[m['display_name'],m['id']]})
        s['roles']=list(dict.fromkeys(v for m in members for v in m['roles']))
        s['source_refs']=list(dict.fromkeys(v for m in members for v in m['source_refs']))
        for key in s['claims']:s['claims'][key]=[v for m in members for v in m['claims'].get(key,[])]
        s['validity_evidence']=[v for m in members for v in m['validity_evidence']]
        s['temporal_note']='\n'.join(m['display_name']+'：'+m['temporal_note'] for m in members)
        s['selection_reason']+=' 同一都市・城下の機能を一つに統合し、拠点数は1とする。'
        s['location_note']+=' 統合拠点の代表座標を使用。城・町・港の個別位置は構成要素に保存。'
        s['adoption_reason']='同一都市・城下を一拠点として採用。複数機能による水増しをしない。'
        for c in children:
            lookup[c]['adoption_status']='excluded';lookup[c]['merged_into']=primary
            lookup[c]['adoption_reason']='年代除外ではなく、'+NAMES[primary]+'の構成要素へ統合。単独表示・計数をしない。'
    sources.append(dict(id='nrct_poi_20250515',title='日本歴史地名大系 施設・地点項目データセット（CODH作成）',url='https://geoshape.ex.nii.ac.jp/nrct-poi/',publisher='人文学オープンデータ共同利用センター（CODH）',publication_year=2025,accessed='2026-09-11',locator='nrct-poi-20250515.csv / 個別IDは各拠点のlocation_poi_id',observation='城跡等の名称・現代住所・座標の照合に使用。1582年の活動や精密城域を立証するデータではない。',read_status='csv_records',scope='名称・住所・緯度経度の対象レコードを確認。地名大系の原本文全体は未読。',redistribute_original=True,license='CC BY 4.0',attribution='『日本歴史地名大系』施設・地点項目データセット（CODH作成） doi:10.20676/00000456'))
    for r in read('data/editorial/settlements/expansion_250/adopted_additions.json'):
        i=r['index'];ref=f'expansion_250_{i:03}';id=f'site_1582_{r["province"]}_{i:03}';h=r['history_source']
        note=SPECIAL.get(i,h['editorial_note'])
        sources.append(dict(id=ref,title=h['title'],url=h['url'],publisher=urlparse(h['url']).netloc,publication_year=None,accessed='2026-09-11',locator='対象拠点の沿革・中世／戦国期の記述（検索抜粋中心。ページ単位の原典精査は未完了）',observation=h['editorial_note'],read_status=h['read_status'],scope='ウェブ本文又は検索提供抜粋。史料全文や全挿図を精査したという意味ではない。',redistribute_original=False))
        claim=dict(source_ref=ref,locator='沿革・対象拠点の項',assessment='reference_or_inference')
        refs=[ref]+(['nrct_poi_20250515'] if r['poi_id'] else [])
        locationclaim=dict(source_ref='nrct_poi_20250515',locator=r['poi_id'],assessment='modern_reference_location') if r['poi_id'] else dict(source_ref=ref,locator=r['location_note'],assessment='manual_area_estimate')
        roles=[r['role']]
        if r['role']=='port':roles.append('settlement')
        s=dict(id=id,name_1582=None,display_name=r['name'],aliases=[r['name']],roles=roles,site_group_id=id,province_id=r['province'],region_id=r['region'],temporal_status='unresolved' if i in [25,33,93,118,175] else 'inferred',temporal_note=note,name_status='reference_name',name_note='参照資料に使われる地名で表示。1582年当年の呼称・表記の原文照合は未完了。',validity_evidence=[dict(source_ref=ref,locator='沿革・対象拠点の項',note=note)],lonlat=r['lonlat'],location_status='area_estimate',location_note=r['location_note'],location_poi_id=r['poi_id'],uncertainty_m=None,display_anchor=None,importance=1 if i in [0,2,15,28,43,59,68,71,76,78,82,98,99,100,111,119,132,137,144,146,151,163,165,170,181,185,198,199,200] else 2,selection_reason='地方別配分を保つ独立拠点として追加。'+note,adoption_status='accepted',adoption_reason='1582年を想定するゲーム用の地域代表拠点として採用。年代と位置の推定は詳細に明示。',source_refs=refs,claims=dict(name=[claim],temporal=[claim],location=[locationclaim],function=[claim]),connection_anchors=[],review_notes=['地方別250拠点版。原典精査・歴史的な城域や岸線の復元は継続課題。'],port_type='coastal_estimate' if r['role']=='port' else None)
        if i==184:s['aliases']+=['日山城','火野山城']
        if i==93:s['aliases']+=['本与板城']
        if i==69:s['aliases']+=['茶臼山城']
        master['sites'].append(s)
    policy=dict(total=250,reference_counts=dict(tohoku=26,kanto=31,koshin=11,hokuriku=21,tokai=24,kinki=25,chugoku=29,shikoku=12,kyushu=28),stated_reference_total=206,actual_reference_total=207,allocated_reference_regions=249,retained_hokkaido=1,method='largest_remainder',targets=TARGETS,unit='one_independent_place_regardless_of_roles',merged_component_count=9,new_place_count=204)
    master['allocation_policy']=policy
    master['coverage']='全国250拠点の地方配分版。城・主要集落・港の複合機能は同一場所につき1拠点。参考表の地方合計207を基に249を比例配分し、既存の北海道1拠点を加える。年代・位置は推定を含み、史料の網羅調査・精密復元ではない。'
    chosen=[s for s in master['sites'] if s['adoption_status']=='accepted']
    counts=Counter('kyushu' if s['region_id']=='south_kyushu' else s['region_id'] for s in chosen)
    assert dict(counts)==TARGETS,(counts,TARGETS)
    assert len({s['site_group_id'] for s in chosen})==250
    write('data/editorial/settlements/settlements_1582.json',master);write('data/editorial/settlements/sources.json',sources)
    print('Adopted:',counts)
if __name__=='__main__':adopt()
