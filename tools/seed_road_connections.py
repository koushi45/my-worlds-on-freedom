"""Editorial relationships for the 250-site connection edition (not historical claims)."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'data/editorial/road_connections'

# Ordered regional relationships, selected for a coastal, basin or inland role.
# These are game-design connections; existence of the endpoint is not road evidence.
CHAINS = [
('南九州・日向の拠点間', 'sadowara_castle mukasa_castle kiyotake_castle obi_castle shibushi_castle'),
('南九州・盆地と湾奥', 'mukasa_castle miyakonojo_castle kajiki_port uchi_castle'),
('南九州・内陸盆地', 'miyakonojo_castle iino_castle kakuto_castle hitoyoshi_castle'),
('薩摩半島の港域と城', 'uchi_castle chiran_castle yamagawa_port'),
('薩摩西岸への連絡', 'chiran_castle bonotsu_port'),
('薩摩西岸と肥後', 'uchi_castle akune_port furufumoto_castle 199'),
('大隅半島の陸側連絡', 'kajiki_port takasu_port nejime_port uchinoura_port shibushi_castle'),
('肥後の内陸連絡', 'furufumoto_castle hitoyoshi_castle'),
('豊後と日向の連絡', 'sadowara_castle usuki_castle otomo_yakata'),
('豊後盆地と肥後', 'otomo_yakata 200 199'),
('筑後と筑前', '199 yanagawa_castle katsunoo_castle hakata_port tachibana_castle umagatake_castle'),
('筑前の内陸拠点', 'katsunoo_castle 202 201 umagatake_castle'),
('豊前から豊後', 'umagatake_castle otomo_yakata'),
('肥前の地域連絡', 'katsunoo_castle 198 nagasaki_port 203'),
('山陽の港域・城域', '182 181 155 157 160 159 158 162 164 165 133 132 130 129'),
('鞆の陸側出入口', '162 161'),
('中国山地の拠点間', '157 koriyama_castle 184 154 153 152 151 177 175 173 172 171 170'),
('石見の港と銀山', '181 180 179 176 178 154'),
('備中から美作', '164 163 167 166 168 169 174 170'),
('伯耆と美作の盆地', '175 167'),
('但馬への連絡', '174 135 136 134 133'),
('伊予の海岸側拠点', '188 187 186 185 190 189 196 194 195 193 191 ichinomiya_castle'),
('四国の盆地間', '189 192 ichinomiya_castle'),
('土佐の地域連絡', '188 197 okou_castle 192'),
('摂津・山城の連絡', '129 128 127 142 143 kyoto_kamigyo otsu_port sakamoto_castle'),
('近江の幹線接続', 'otsu_port azuchi_castle 149 098'),
('近江の内陸拠点', 'azuchi_castle 150 104'),
('丹波から丹後', 'kyoto_kamigyo 137 139 138 140 141'),
('丹波から但馬・播磨', '138 135'),
('播磨の内陸拠点', '130 131 139'),
('摂津と和泉', '129 ishiyama_honganji sakai_town'),
('和泉と河内・大和', 'sakai_town takaya_castle tsutsui_castle 145 144 143'),
('紀伊の城下・寺内', 'sakai_town kishiwada_castle saika_town 147 146 148'),
('尾張・三河・遠江の地域連絡', '103 126 120 119 122 hamamatsu_castle 124 110 109 125 odawara_castle'),
('伊勢・志摩の拠点', '103 105 104 106 107 111 108'),
('尾張の内陸拠点', '126 100 101 115 114 064'),
('美濃の拠点', '100 gifu_castle 112 102 103'),
('美濃と近江', '112 149'),
('三河の支線', '120 121 122 123 113 114'),
('飛騨への盆地連絡', '115 116 117 118 078'),
('木曽谷と信濃', '064 075 068 073 071 072 kasugayama_castle'),
('伊那・諏訪の盆地', '123 070 069 068'),
('甲斐の拠点と盆地', '069 066 kofu_town 065 040'),
('信濃東部の城域', '066 067 074 073'),
('甲斐から駿河', 'kofu_town 110'),
('相模の城下と港', 'odawara_castle 038 041 039'),
('相模から武蔵', '038 037 042 028 030 050 051 052 059'),
('武蔵の内陸拠点', '037 033 040'),
('武蔵北部の拠点', '028 029 034 032 035 031 036 030'),
('上野と下野の拠点', '035 061 062 063 043 060 059'),
('信濃から上野', '067 061'),
('下総・房総の連絡', '028 049 048 047 045 046 044'),
('常陸の地域連絡', '048 056 055 058 057 053 054'),
('下野と常陸', '052 058'),
('北陸の海岸側拠点', '099 098 077 076 079 080 081 078 087 085 082 083 kasugayama_castle 091 092 093 096 097'),
('越中の内陸城と港', '085 086 089 082 088'),
('松倉への出入り', '083 084'),
('能登の港域', '078 090'),
('越後の盆地間', '093 094 095 kasugayama_castle'),
('越後から会津', '096 kurokawa_castle'),
('奥羽の南北連絡', '059 010 009 014 012 006 027 005 004 003 002 sannohe_castle'),
('陸奥南部の支線', '054 011 010'),
('浜通りと阿武隈', '054 008 007 006'),
('小浜の出入り', '014 013 012'),
('会津と出羽', '009 kurokawa_castle yonezawa_castle 016 015 017 018 020 021 024 025 001 000'),
('出羽の海岸側拠点', '097 019 026 023 022 025'),
('横手盆地から沿岸', '021 023'),
('津軽と南部', '001 sannohe_castle'),
('米沢と陸奥', 'yonezawa_castle 006'),
]

def main():
    OUT.mkdir(parents=True, exist_ok=True)
    sites = json.loads((ROOT/'data/derived/settlements/settlements_1582.json').read_text(encoding='utf-8'))['sites']
    lookup = {s['id']: s for s in sites if s['adoption_status']=='accepted'}
    short = {s['id'].rsplit('_',1)[-1]: s['id'] for s in lookup.values() if s['id'].startswith('site_')}
    plans=[]; pairs=set()
    for name, chain in CHAINS:
        ids=[short.get(i,i) for i in chain.split()]
        assert all(i in lookup for i in ids), ids
        for a,b in zip(ids,ids[1:]):
            if tuple(sorted([a,b])) in pairs: continue
            pairs.add(tuple(sorted([a,b])))
            plans.append(dict(id=f'link_{len(plans)+1:03}', name=lookup[a]['display_name']+'―'+lookup[b]['display_name'],
                from_site=a,to_site=b,region=lookup[a]['region_id'],purpose=name,
                basis='game_inferred_connection',year_status='unconfirmed',geometry_status='terrain_estimate',
                adoption_status='proposed',source_refs=['method:editorial_relationships'],
                note='地域の城域・集落・港域の連絡をゲーム用に補完する。交通関係・1582年の利用・門・橋の位置を史実と断定しない。'))
    exemptions={
        'hirado_port':'平戸島内の対象拠点は1地点。対岸との接続には海上航路が必要。現代の平戸大橋は使用しない。',
        short['156']:'宮島内の対象拠点は1地点。対岸とは航路の別工程とする。',
        short['183']:'上関の代表点は長島側。対岸との海峡を陸路化せず航路の別工程とする。',
        'katsuyama_tate':'北海道内の対象拠点は1地点。本州との接続には海上航路が必要。館内・麓の道は微細地形の別調査を要する。'}
    used={x[k] for x in plans for k in ['from_site','to_site']}
    assert used | set(exemptions)==set(lookup), set(lookup)-used-set(exemptions)
    fixed=json.loads((ROOT/'data/editorial/road_connections/waypoints.json').read_text(encoding='utf-8'))
    controls={('sadowara_castle','mukasa_castle'):['honjo_hyuga','takaoka_hyuga'],
              ('mukasa_castle','miyakonojo_castle'):['sarukawa','takajo_hyuga'],
              ('miyakonojo_castle','kajiki_port'):['shikine']}
    for p in plans:
        p['via']=[dict(fixed[i]) for i in controls.get((p['from_site'],p['to_site']),[])]
        if p['via']:
            p['source_refs'].append('history:higashime')
            p['note']+=' 参考資料の通過順と固定通過点を用い、通過域間だけ地形探索する。'
    payload=dict(target_year=1582,target_sites=sorted(lookup),plans=plans,land_exemptions=exemptions,
        parameters=dict(grid_game_px=2,grid_metres=453.19,search_margin_m=18000,max_crossing_m=650,
                        river_centerline_buffer_m=15,entrance_search_m=1800,grade_review=0.22,
                        source_dem='assets/map/elevation/elevation_m.png',dem_note='再投影約453m、元タイルz8。細い谷・門・登城道は検証できない。'),
        source_refs=['method:editorial_relationships','dem:existing','water:existing'])
    (OUT/'plan.json').write_text(json.dumps(payload,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    sources=[dict(id='method:editorial_relationships',title='250拠点・地域内連絡の編集判断',url=None,
        locator='tools/seed_road_connections.py / CHAINS',access_scope='拠点の地域的位置・機能と既存回廊を比較した接続目的。歴史資料ではない。',claim='ゲーム用接続関係'),
        dict(id='dem:existing',title='既存Mapzen Terrarium z8標高',url='https://registry.opendata.aws/terrain-tiles/',locator='data/derived/elevation/elevation_manifest.json',access_scope='ローカル実標高ラスタを使用。表示用平滑化メッシュは経路評価に使用しない。',claim='現代地形の概形'),
        dict(id='water:existing',title='既存の全河川・水域',url=None,locator='data/derived/hydrography/water_registry.json',access_scope='非表示の支流を含む全形状',claim='現代水系との交差'),
        dict(id='history:higashime',title='都城市・薩摩街道東目筋',url='https://www.city.miyakonojo.miyazaki.jp/site/kanko/32148.html',locator='薩摩街道の歴史・冒頭の通過地説明',access_scope='2026-09-11本文閲覧',claim='江戸期の佐土原・本庄・高岡・去川・都城・鹿児島の接続順のみ。1582年の利用・線形を証明しない。')]
    (OUT/'sources.json').write_text(json.dumps(sources,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(f'{len(plans)} editorial relationships / {len(used)} land sites / {len(exemptions)} sea-separated sites')

if __name__=='__main__': main()
