"""Stage A/B research inventory. Never creates runtime districts or changes map inputs.

python -X utf8 tools/prepare_district_ledgers.py fetch
python -X utf8 tools/prepare_district_ledgers.py initialize
python -X utf8 tools/prepare_district_ledgers.py check
python -X utf8 tools/prepare_district_ledgers.py report

Only fetch accesses the network. initialize refuses to overwrite editorial work.
Requires the project's existing Shapely and pyproj for read-only spatial inventory.
"""
import argparse
import hashlib
import html
import json
import re
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone
from pathlib import Path
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'data/editorial/districts'
CACHE = ROOT / 'data/sources/districts'
DOC = ROOT / 'docs/districts'
REGISTRY = 'data/derived/political/approved_western/political_registry.json'
BASE = 'https://geoshape.ex.nii.ac.jp/kg/'
EDITION = 'district-survey-ab-2026-09-12-v1'

# Explicit editorial crosswalk, keyed by EXISTING IDs, never a name join.
# K IDs are comparison-dataset partitions, not 1582 identities or geometry matches.
LINKS = '''chikuzen:63 buzen:65 hizen:67 chikugo:64 bungo:66 higo:68 hyuga:69
satsuma:71 osumi:70 iyo:61 sanuki:60 tosa:62 awa_shikoku:59 nagato:56 suo:55
iwami:47 aki:54 bingo:53 bitchu:52 izumo:46 hoki:45 inaba:44 mimasaka:50 bizen:51
honshu-area-01:31 honshu-area-03:33 honshu-area-04:30 honshu-area-05:29
honshu-area-06:32 echigo:39 honshu-area-08:27 honshu-area-09:28 noto:37 shimotsuke:26
etchu:38 hitachi:20 kaga:36 shinano:24 hida:23 musashi:16 echizen:35 kai:13 tango:42
mino:22 tajima:43 kazusa:18 sagami:15 omi:21 tanba:41 suruga:12 owari:09
honshu-area-30:17 yamashiro:01 harima:49 mikawa:10 totomi:11 izu:14 iga:06 ise:07
kawachi:03 yamato:02 kii:57 kozuke:25 shimosa:19 settsu:05 izumi:04'''
CROSSWALK = {k: f'K{int(v):02}' for k, v in (x.split(':') for x in LINKS.split())}
PILOT = ['izumi', 'settsu', 'kawachi', 'yamato']
ADDITIONAL_FETCH = [
    ('nai-genroku-izumi','https://www.digital.archives.go.jp/gallery/0000000226'),
    ('kai-four','https://www.pref.yamanashi.jp/shigaku-kgk/10_035.html'),
    ('shinano-ten','https://adeac.jp/nagano-city/texthtml/d100150/ct00000011/ht000710'),
    ('hinenosho','https://www.city.izumisano.lg.jp/kakuka/seikatsu/bunkazai/menu/hinenosyo/hinenoshoiseki.html'),
    ('kagawa-shiwaku','https://k-archives.pref.kagawa.lg.jp/detail/komonjo_bunshogun/9188'),
]

SUPPLEMENTS = [
    dict(source_id='codh-province', url='https://codh.rois.ac.jp/province/',
         title='国・地域ID データセット', publisher='ROIS-DS CODH',
         period='江戸〜明治。P002=分割前陸奥、P003=出羽。P111–P117=明治の分割後区分。',
         locator='国・地域ID表 P002/P003/P111–P117、各P行',
         use='外部IDの区分体系・分割前後の関係の確認。1582年境界の証拠ではない。'),
    dict(source_id='rekihaku-kyudaka', url='https://www.rekihaku.ac.jp/doc/gaiyou/kyuudaka.html',
         title='旧高旧領取調帳データベース概要', publisher='国立歴史民俗博物館',
         period='郡名・区画は明治2年頃。公開1990年4月。',
         locator='項目説明「旧郡名」「旧村名」「旧領名」',
         use='後世の村所属調査の入口。今回、個別村レコードは未取得。'),
    dict(source_id='rekihaku-shoen', url='https://www.rekihaku.ac.jp/help/getdoc_syoen.html',
         title='日本荘園データベース 項目説明', publisher='国立歴史民俗博物館',
         period='郡欄は原則和名類聚抄。中世の所属と異なる場合あり。',
         locator='「国名」「郡名」「出典」「遺文番号」「記録類」',
         use='対象年代の個別文書へ遡る入口。今回、荘園レコードは未取得。'),
    dict(source_id='osaka-archives38',
         url='https://archives.pref.osaka.lg.jp/search/information.do?id=58&method=initPage',
         title='大阪あーかいぶず第38号「近代大阪府の郡役所」矢切努', publisher='大阪府公文書館',
         period='刊行2006年9月。主に1878〜1926年。',
         locator='p.1「三新法体制下と郡長・郡役所」、図1への本文参照、「大阪府における郡制の施行」',
         use='畿内候補の表記・明治期再編を照合。図1そのものは未取得・未判読。'),
    dict(source_id='uda-history', url='https://www.city.uda.lg.jp/soshiki/41/1068.html',
         title='宇陀市の歴史', publisher='宇陀市文化財課',
         period='中世〜近世の回顧説明。郡名を伴う1585年の記述あり。',
         locator='「近世」冒頭・天正13年（1585年）の宇陀郡の記述',
         use='宇陀の表記と対象年に近い郡名の回顧的根拠。1582年の直接確認・境界証拠ではない。'),
    dict(source_id='nai-genroku',
         url='https://www.digital.archives.go.jp/DAS/pickup/view/category/categoryArchives/0300000000/0301000000/01',
         title='元禄国絵図', publisher='国立公文書館',
         period='元禄期。1582年より後世。', locator='元禄国絵図案内。各国の請求番号・図版は未確認。',
         use='国別図版を探す入口。取得不能の場合は所在候補に留め、閲覧済みとしない。'),
]


def read(path):
    return json.loads((ROOT / path).read_text(encoding='utf-8'))


def write(path, data):
    path = ROOT / path
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def clean(value):
    return ' '.join(html.unescape(re.sub('<[^>]*>', '', value)).split())


def table_rows(text, pattern):
    result = []
    for row in re.findall(r'<tr\b[^>]*>(.*?)</tr>', text, re.S | re.I):
        cells = re.findall(r'<td\b[^>]*>(.*?)</td>', row, re.S | re.I)
        values = [clean(c) for c in cells]
        if len(values) > 1 and re.fullmatch(pattern, values[1]):
            result.append(values)
    return result


def fetch_one(item):
    source_id, url = item
    p = CACHE / 'pages' / f'{source_id}.html'
    meta = p.with_suffix('.json')
    if p.exists() and meta.exists():
        old = json.loads(meta.read_text(encoding='utf-8'))
        assert old['url'] == url and old['sha256'] == digest(p), source_id
        return old
    try:
        with urlopen(Request(url, headers={'User-Agent': 'DistrictResearchInventory/1.0'}), timeout=30) as r:
            data = r.read()
            final_url = r.url
            headers = {k: r.headers.get(k) for k in ['Content-Type', 'ETag', 'Last-Modified']}
        text = data.decode('utf-8')
        assert '<html' in text.lower() or '<head' in text.lower(), source_id
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_bytes(data)
        record = dict(source_id=source_id, url=url, final_url=final_url,
                      fetched_at_utc=datetime.now(timezone.utc).isoformat(),
                      path=p.relative_to(ROOT).as_posix(), sha256=digest(p), headers=headers,
                      operation='research_html_cache; no images, map tiles or polygon downloads',
                      status='retrieved')
        write(meta, record)
        return record
    except Exception as e:
        return dict(source_id=source_id, url=url, status='fetch_failed', error=str(e))


def fetch():
    tasks = [('kg-index', BASE + 'resource/'), ('kg-about', BASE + 'index.html.ja')]
    # 73 includes the seven missing historical parents; northern modern countries
    # and Ryukyu are inventoried in the country index only, outside current scope.
    tasks += [(f'kg-K{i:02}', BASE + f'resource/K{i:02}.html') for i in range(1, 74)]
    tasks += [(s['source_id'], s['url']) for s in SUPPLEMENTS]
    tasks += ADDITIONAL_FETCH
    with ThreadPoolExecutor(max_workers=3) as pool:
        records = list(pool.map(fetch_one, tasks))
    write(CACHE / 'retrieval_log.json', dict(records=records, export_allowed=False))
    failed = [x for x in records if x['status'] != 'retrieved']
    print(json.dumps(dict(retrieved=len(records)-len(failed), failures=failed), ensure_ascii=False))
    assert not any(x['source_id'].startswith('kg-') or x['source_id']=='codh-province' for x in failed)


def page(source_id):
    return (CACHE / 'pages' / f'{source_id}.html').read_text(encoding='utf-8')


def reference(source_id, locator, **kwargs):
    return dict(source_ref=source_id, locator=locator, **kwargs)


def initialize():
    if (OUT / 'scope.json').exists():
        raise SystemExit('Editorial ledger already exists. Edit it explicitly; initialize will not overwrite research.')
    from shapely.geometry import Polygon, Point, shape
    from shapely.ops import unary_union, transform
    from pyproj import Transformer

    registry = read(REGISTRY)
    regions = registry['regions']
    assert set(CROSSWALK) == {r['region_id'] for r in regions}
    kg_rows = table_rows(page('kg-index'), r'K\d{2}')
    kg = {v[1]: dict(id=v[1], name=v[2], reading=v[3], count=int(v[4]),
                        prefectures=v[5], province_external_id=v[6]) for v in kg_rows}
    assert len(kg) == 85 and sum(k['count'] for k in kg.values()) == 806
    records = {r['source_id']: r for r in read(CACHE / 'retrieval_log.json')['records']}
    sources = []
    credit = '『旧国・旧郡境界データセット』（CODH作成）「幕末明治地勢地図境界データ」（人間文化研究機構作成）を加工 doi:10.20676/00000454'
    for sid, rec in records.items():
        if sid.startswith('kg-'):
            sources.append(dict(source_id=sid, title=('旧国・旧郡境界データセット ' + (kg[sid[3:]]['name'] if sid[3:] in kg else sid[3:])),
                publisher='ROIS-DS CODH / 原データ:人間文化研究機構', url=rec['url'],
                publication_date='2025-05-01（データセット公開。個別ページ更新日は不明）',
                represented_period='提供者説明:江戸時代末期。ただし国IDには明治分割後区分を含む。郡別の時点は要検証。',
                temporal_basis='later_comparison', retrieval=rec,
                rights=dict(status='CC-BY-NC-4.0', url=BASE+'index.html.ja#license',
                    locator='本文「ライセンス」', credit=credit,
                    note='HTMLメタのCC BY 4.0と本文CC BY-NCが不一致。より制限のある本文条件を台帳に記録。商用配布の許諾は取得していない。',
                    use_performed=['HTMLの調査用保存', '国・郡の一覧項目と出典IDの抽出'],
                    geometry_downloaded=False, images_downloaded=False, export_allowed=False),
                limitations=['1582年の郡の存在・境界を直接立証しない', '一覧掲載がない中世の郡を排除する根拠にはならない']))
    for spec in SUPPLEMENTS:
        rec = records[spec['source_id']]
        sources.append(dict(source_id=spec['source_id'], title=spec['title'], publisher=spec['publisher'],
            url=spec['url'], publication_date='本文・台帳のperiodを参照。不明日は補わない',
            represented_period=spec['period'], temporal_basis='retrospective' if spec['source_id']=='uda-history' else 'later_comparison',
            retrieval=rec, locator=spec['locator'], use=spec['use'],
            rights=dict(status='individual_reuse_terms_unverified', url=spec['url'], locator='個別転載・画像再利用条件は未確認',
                use_performed=['ウェブ本文参照・調査用HTML保存'] if rec['status']=='retrieved' else ['所在URL記録のみ'],
                geometry_downloaded=False, images_downloaded=False, export_allowed=False)))

    m = read('data/base/japan_land_manifest.json')['game_transform']
    forward = Transformer.from_crs('EPSG:4326', m['projection'], always_xy=True)
    inv = Transformer.from_crs(m['projection'], 'EPSG:4326', always_xy=True)
    bx, by, _, _ = m['projected_scope_bounds_m']
    scale = m['uniform_scale_px_per_m']
    def xy(lon, lat, z=None):
        x, y = forward.transform(lon, lat)
        return m['offset_x_px']+(x-bx)*scale, m['offset_y_px']+m['content_height_px']-(y-by)*scale
    def lonlat(x, y):
        return list(inv.transform(bx+(x-m['offset_x_px'])/scale, by+(m['content_height_px']-y+m['offset_y_px'])/scale))
    geometries = {r['region_id']: unary_union([Polygon(p) for p in r['polygons']]) for r in regions}
    assert all(g.is_valid for g in geometries.values())
    sites = read('data/derived/settlements/settlements_1582.json')['sites']
    parents, mappings, districts, reviews = [], [], [], []
    for r in regions:
        rid = r['region_id']
        k = CROSSWALK[rid]
        ext = kg[k]
        number = int(k[1:])
        north_mutsu = 27 <= number <= 31
        north_dewa = 32 <= number <= 33
        pcode = 'P002' if north_mutsu else 'P003' if north_dewa else ext['province_external_id']
        historical_id = 'province-' + pcode.lower()
        historical_name = '陸奥' if north_mutsu else '出羽' if north_dewa else ext['name']
        g = geometries[rid]
        rp = g.representative_point()
        witnesses = [s for s in sites if g.covers(Point(s['point']))]
        adjacency = sorted({b['region_b'] if b['region_a']==rid else b['region_a'] for b in registry['boundaries'] if rid in [b['region_a'], b['region_b']]})
        evidence = [reference('local-registry', f'regions[region_id={rid}]', input_sha256=digest(ROOT/REGISTRY)),
                    reference('kg-'+k, '基本情報:旧国・旧郡ID、現在の都道府県、国・地域ID'),
                    reference('codh-province', pcode + '行' + ('、'+ext['province_external_id']+'行' if north_mutsu or north_dewa else ''))]
        # Location witnesses corroborate broad identification; do not assert an
        # external boundary equality without registration / comparison geometry.
        spatial = dict(representative_point_world=list(rp.coords[0]), representative_point_lonlat=lonlat(rp.x,rp.y),
            bounds_world=list(g.bounds), neighbor_parent_ids=adjacency,
            contained_site_witnesses=[dict(site_id=s['id'], display_name=s['display_name'], recorded_province_id=s['province_id'],
                point=s['point'], source_refs=s.get('source_refs',[])) for s in witnesses],
            external_prefecture_hint=ext['prefectures'],
            status='local_geometry_and_existing_site_context_recorded; external_geometry_not_compared')
        mappings.append(dict(mapping_id='mapping-'+rid, parent_region_id=rid, current_display_name=r['name_ja'],
            historical_province_id=historical_id, historical_province_name=historical_name+'国',
            external_comparison=dict(namespace='geoshape-kg', country_id=k, country_name=ext['name'],
                codh_province_id=ext['province_external_id'], historical_codh_province_id=pcode),
            relation='current_partition_of_historical_province' if north_mutsu or north_dewa else 'candidate_correspondence',
            mapping_status='provisional_context_supported', geometry_equivalence='not_asserted',
            method='既存IDを明示した編集対応表。現行面の座標・隣接・内包拠点と外部の府県欄・国ID関係を併記。名前一致による自動結合は不使用。',
            evidence=evidence, spatial_context=spatial,
            remaining='史料の村郷・島・国境を比較して領域対応を検証。東北の郡を現在の親だけへ自動帰属させない。' if north_mutsu or north_dewa else '同名でも形状が一致するとは限らない。外部形状との国境・島の差分は工程C以降で確認。'))
        rows = table_rows(page('kg-'+k), r'G\d{5}')
        assert len(rows) == ext['count'], (k, len(rows), ext['count'])
        candidate_ids = []
        for v in rows:
            _, gid, name, reading, country, prefectures = v
            did = 'district-candidate-' + gid.lower()
            candidate_ids.append(did)
            locator = f'#gun-list 旧郡一覧 / 旧郡ID={gid} / 掲載名={name} / 国={country}'
            existence = reference('kg-'+k, locator, supports='後世比較データに当該名称・国所属が掲載されること', target_year_supported=False)
            districts.append(dict(district_entity_id=did, identity_status='provisional_candidate_not_a_confirmed_1582_entity',
                source_name=name, candidate_display_name=name+'郡', aliases=[], reading=reading,
                historical_province_id=historical_id, candidate_parent_region_ids=[rid],
                parent_assignment_status='research_bucket_only_not_geometric_membership',
                external_ids=dict(namespace='geoshape-kg', district_id=gid, country_id=k),
                external_record_url=BASE+'resource/'+gid+'.html', external_record_reviewed=False,
                target_period=dict(year=1582, label='本能寺の変の直前'),
                attested_period='後世比較データの記載。郡別の成立・廃止・分割年は未検証。',
                existence_status='unconfirmed', name_in_reference_status='supported',
                geometry_status='unlocated', geometry=None, adoption_status='held', temporal_basis='later_comparison',
                evidence=dict(name_existence=[existence], location=[], target_period=[]),
                location_leads=[reference('kg-'+k, locator, prefectures=prefectures, map_url=BASE+'resource/'+gid+'.html#map',
                    reviewed=False, note='府県欄は後世の広域手掛かり。地図・図版は未判読。座標・境界の証拠には数えない。')],
                temporal_difference='1582年への遡及は未確認。後世の分郡・統合・改称・国所属変更を点検する。',
                decision_reason='全親領域の初回候補台帳に登録。採用は保留し、名称の存在と位置の証拠を分離。',
                source_refs=['kg-'+k], reuse_status='research_only_not_cleared_for_distribution',
                unresolved=['1582年時点の存在・表記', '成立・分割・統合・国所属の変遷', '対象年の村郷所属と位置', '境界の典拠・区間別精度']))
        parents.append(dict(parent_region_id=rid, display_name=r['name_ja'], input_version=registry['version'],
            input_sha256=digest(ROOT/REGISTRY), mapping_ref='mapping-'+rid, historical_province_id=historical_id,
            historical_province_name=historical_name+'国', scope_status='in_scope_current_parent_only',
            research_status='調査中', initial_candidate_sweep='complete', target_period_research='unresolved',
            candidate_count=len(rows), candidate_ids=candidate_ids,
            priority=PILOT.index(rid)+1 if rid in PILOT else 5,
            polygon_count=len(r['polygons']), local_geometry_sha256=hashlib.sha256(json.dumps(r['polygons'],separators=(',',':')).encode()).hexdigest()))
        reviews.append(dict(parent_region_id=rid, comparison_source_ref='kg-'+k, locator='#gun-list 旧郡一覧（全行）',
            expected_rows=ext['count'], observed_rows=len(rows), candidate_ids=candidate_ids,
            sweep_status='complete', evidence_coverage='later_comparison_only',
            target_year_status='unresolved', geometry_status='not_started',
            followups=['rekihaku-shoen', 'rekihaku-kyudaka', 'nai-genroku'],
            next_action=f'{historical_name}国の中世・天正期の郡名と村郷所属を調査し、後世候補との分合を記録する。'))

    sources += [dict(source_id='local-registry', title='現行採用済み親領域レジストリ', local_path=REGISTRY,
                    version=registry['version'], sha256=digest(ROOT/REGISTRY), represented_period='ゲームの現行採用区分。東北は後世名を含む。',
                    rights=dict(status='existing_project_input', export_allowed=False)),
                dict(source_id='local-settlements', title='現行254拠点', local_path='data/derived/settlements/settlements_1582.json',
                    sha256=digest(ROOT/'data/derived/settlements/settlements_1582.json'),
                    represented_period='1582年シナリオ。個別採用例外あり。郡の証拠とはしない。', rights=dict(status='existing_project_input',export_allowed=False))]
    missing = []
    for k, ext in kg.items():
        if k in CROSSWALK.values():
            continue
        missing.append(dict(issue_id='scope-missing-'+k.lower(), external_country_id=k, name=ext['name'],
            historical_province_id=('province-'+ext['province_external_id'].lower()) if int(k[1:])<74 else None,
            status='unrepresented_parent_backlog' if int(k[1:])<74 else 'out_of_scope_later_partition_or_ryukyu',
            source_ref='kg-index', locator=k+'行', parent_region_id=None,
            reason='現行親IDとの明示対応がない。国の未収録と、面が他国に含まれるかの確認は別。郡を先行作成しない。' if int(k[1:])<74 else '本工程の現行親領域がない。蝦夷地の明治分割区分・琉球は1582年の郡として取り込まない。'))
    # Inventory canonical land components that lie outside all current parents.
    union = unary_union(list(geometries.values()))
    land = read('data/base/japan_land.geojson')
    uncovered = []
    for fi, f in enumerate(land['features']):
        raw = shape(f['geometry'])
        parts = list(raw.geoms) if raw.geom_type=='MultiPolygon' else [raw]
        for pi, part in enumerate(parts):
            g = transform(xy, part)
            rest = g.difference(union)
            if rest.area <= 1e-4:
                continue
            rp = rest.representative_point()
            uncovered.append(dict(issue_id=f'land-outside-parent-{fi:03}-{pi:03}',
                canonical_feature_index=fi, canonical_part_index=pi,
                component_sha256=hashlib.sha256(part.wkb).hexdigest(),
                outside_area_world2=rest.area, canonical_component_area_world2=g.area,
                outside_fraction=rest.area/g.area, representative_point_lonlat=lonlat(rp.x,rp.y),
                status='unassigned_land_component_or_coastal_residual', name=None,
                action='島名・親国未収録・国面差分を区別して確認。郡で自動補完しない。'))
    # Freeze actual files, not just a version label. Future edits invalidate this snapshot.
    paths = {ROOT/REGISTRY, ROOT/'data/base/japan_land_manifest.json', ROOT/'data/base/japan_land.gpkg', ROOT/'data/base/japan_land.geojson'}
    for directory in ['data/derived/settlements','data/derived/road_connections','data/derived/elevation',
                      'data/derived/hydrography','data/derived/detail_map','assets/map/elevation','assets/map/detail','scripts/map']:
        paths.update(p for p in (ROOT/directory).rglob('*') if p.is_file() and p.suffix not in ['.import','.uid'])
    paths.update([ROOT/'scripts/main/main_map.gd', ROOT/'export_presets.cfg'])
    assert all(p.exists() for p in paths)
    lock = dict(edition=EDITION, created_at_utc=datetime.now(timezone.utc).isoformat(),
        files=[dict(path=p.relative_to(ROOT).as_posix(), bytes=p.stat().st_size, sha256=digest(p)) for p in sorted(paths)],
        policy='Do not silently refresh hashes. Changed inputs require a new reviewed survey edition.')
    write(OUT/'input_lock.json', lock)
    write(OUT/'scope.json', dict(schema_version=1, edition=EDITION, target_year=1582, temporal_scope='本能寺の変の直前',
        world_size=[8192,8192], active_registry=REGISTRY, registry_version=registry['version'], registry_scope=registry['scope'],
        input_lock='data/editorial/districts/input_lock.json', parent_count=len(parents),
        stage_a_status='inventory_frozen_with_explicit_mapping_uncertainties', stage_b_status='first_pass_inventory_complete_not_historical_confirmation',
        historical_province_count=len({p['historical_province_id'] for p in parents}),
        pilot_order=PILOT, parents=parents, export_allowed=False))
    write(OUT/'province_mapping.json', dict(schema_version=1, edition=EDITION, mappings=mappings))
    write(OUT/'sources.json', dict(schema_version=1, edition=EDITION, sources=sources))
    write(OUT/'districts.json', dict(schema_version=1, edition=EDITION, districts=districts))
    write(OUT/'country_reviews.json', dict(schema_version=1, edition=EDITION, reviews=reviews))
    write(OUT/'backlog.json', dict(schema_version=1, edition=EDITION, missing_parents=missing, uncovered_land=uncovered,
        note='台帳の全行調査完了と1582年史料調査完了は別。親外陸地の面は生成せず、面積・原本参照のみを保存。'))
    print(json.dumps(dict(parents=len(parents), candidates=len(districts), sources=len(sources), outside_components=len(uncovered)),ensure_ascii=False))


def check():
    scope = read(OUT/'scope.json')
    registry = read(REGISTRY)
    ds = read(OUT/'districts.json')['districts']
    ss = read(OUT/'sources.json')['sources']
    ms = read(OUT/'province_mapping.json')['mappings']
    reviews = read(OUT/'country_reviews.json')['reviews']
    issues = []
    def require(condition, msg):
        if not condition: issues.append(msg)
    for collection, key in [(scope['parents'],'parent_region_id'),(ds,'district_entity_id'),(ss,'source_id'),(ms,'mapping_id')]:
        require(len({r[key] for r in collection})==len(collection), 'duplicate '+key)
    parents = {r['parent_region_id']:r for r in scope['parents']}
    source_ids = {s['source_id'] for s in ss}
    district_ids = {d['district_entity_id'] for d in ds}
    require(set(parents)=={r['region_id'] for r in registry['regions']}, 'parent registry drift')
    require({m['parent_region_id'] for m in ms}==set(parents), 'incomplete mapping coverage')
    require({r['parent_region_id'] for r in reviews}==set(parents), 'incomplete country review coverage')
    for p in parents.values():
        require(set(p['candidate_ids'])<=district_ids, 'unknown district '+p['parent_region_id'])
        require(len(p['candidate_ids'])==p['candidate_count'], 'candidate count '+p['parent_region_id'])
        actual={d['district_entity_id'] for d in ds if p['parent_region_id'] in d['candidate_parent_region_ids']}
        require(set(p['candidate_ids'])==actual, 'parent/candidate reverse-reference mismatch')
        if 'upstream_master' in p:
            master=read(p['upstream_master']['file'])
            upstream=next((r for r in master['regions'] if r['region_id']==p['parent_region_id']),None)
            active=next(r for r in registry['regions'] if r['region_id']==p['parent_region_id'])
            require(upstream is not None and upstream['polygons']==active['polygons'] and upstream['name_ja']==active['name_ja'],'upstream provenance changed')
    by_did={d['district_entity_id']:d for d in ds}
    for review in reviews:
        cached=table_rows(page(review['comparison_source_ref']),r'G\d{5}')
        original=review.get('comparison_candidate_ids',review.get('candidate_ids',[]))
        require(len(cached)==review['expected_rows']==review['observed_rows']==len(original),'incomplete source sweep')
        require({v[1] for v in cached}=={by_did[x]['external_ids']['district_id'] for x in original},'source rows omitted')
        for v in cached:
            row=by_did.get('district-candidate-'+v[1].lower(),{})
            require(row.get('source_name')==v[2], 'raw source name was lost: '+v[1])
    for d in ds:
        require(set(d['candidate_parent_region_ids'])<=set(parents), 'unknown parent '+d['district_entity_id'])
        require(set(d['source_refs'])<=source_ids, 'unknown source '+d['district_entity_id'])
        require(d['geometry'] is None and d['adoption_status'] in ['held','excluded'], 'unexpected runtime adoption')
        require(bool(d['evidence']['name_existence']), 'missing name evidence')
        require('location' in d['evidence'] and 'target_period' in d['evidence'], 'undifferentiated evidence')
        for refs in d['evidence'].values():
            for ref in refs:
                require(ref['source_ref'] in source_ids and bool(ref['locator']), 'invalid claim reference')
        for ref in d['location_leads']:
            require(ref['source_ref'] in source_ids and bool(ref['locator']), 'invalid location lead')
        if d.get('unit_type')=='source_region_entry_district_type_unconfirmed':
            require(not d['candidate_display_name'].endswith('郡'),'invented district suffix')
    for m in ms:
        require(bool(m['spatial_context']['representative_point_lonlat']), 'missing spatial context')
        for ref in m['evidence']:
            require(ref['source_ref'] in source_ids and bool(ref['locator']), 'invalid mapping evidence')
    lock = read(OUT/'input_lock.json')
    for item in lock['files']:
        p = ROOT/item['path']
        require(p.exists() and digest(p)==item['sha256'], 'input changed: '+item['path'])
    for source in ss:
        rec = source.get('retrieval', {})
        if rec.get('status')=='retrieved':
            p = ROOT/rec['path']
            require(p.exists() and digest(p)==rec['sha256'], 'source cache changed: '+source['source_id'])
    decisions_path=OUT/'review_decisions.json'
    if decisions_path.exists():
        for decision in read(decisions_path)['decisions']:
            require(set(decision['district_entity_ids'])<=district_ids,'unknown reviewed candidate')
            for ref in decision['evidence']:
                require(ref['source_ref'] in source_ids and bool(ref['locator']),'invalid review evidence')
    summary = dict(status='passed' if not issues else 'failed', errors=issues,
        parent_count=len(parents), candidate_count=len(ds), source_count=len(ss),
        historical_province_count=len({p['historical_province_id'] for p in parents.values()}),
        accepted_1582_districts=sum(d['adoption_status']=='accepted' for d in ds),
        comparison_rows=sum(bool(d['external_ids']) for d in ds),
        supplemental_candidates=sum(not bool(d['external_ids']) for d in ds),
        excluded_at_target=sum(d['adoption_status']=='excluded' for d in ds),
        location_supported_candidates=sum(bool(d['evidence']['location']) for d in ds),
        frozen_input_files=len(lock['files']), all_country_first_pass=len(reviews))
    write(OUT/'qa.json', summary)
    print(json.dumps(summary, ensure_ascii=False))
    if issues: raise SystemExit(1)


def report():
    scope = read(OUT/'scope.json')
    ds = read(OUT/'districts.json')['districts']
    ss = read(OUT/'sources.json')['sources']
    sources_by_id={s['source_id']:s for s in ss}
    reviews = {r['parent_region_id']:r for r in read(OUT/'country_reviews.json')['reviews']}
    backlog = read(OUT/'backlog.json')
    DOC.mkdir(parents=True,exist_ok=True)
    text = ['# 郡台帳：工程A・B 初回調査', '', '版：'+EDITION, '',
        f'現行の全{scope["parent_count"]}親領域を固定し、全親領域の郡候補一覧を一巡した。比較一覧{sum(bool(x["external_ids"]) for x in ds)}件＋別資料の追加候補{sum(not bool(x["external_ids"]) for x in ds)}件、計{len(ds)}項目。対応先は史料調査用の{scope["historical_province_count"]}国。', '',
        '**工程Aの入力・対象一覧と工程Bの初回候補台帳は作成済み。1582年の郡の確定・位置合わせ・郡境作成は未実施。**', '',
        '後世比較一覧を入口にしており、中世に存在し後世に消えた郡は今後追加が必要。一覧の件数を1582年の全国郡数とはしない。', '',
        '## 台帳', '',
        '- [対象・進捗](../../data/editorial/districts/scope.json)',
        '- [入力版とSHA-256](../../data/editorial/districts/input_lock.json)',
        '- [現行親領域と史料上の国の対応](../../data/editorial/districts/province_mapping.json)',
        '- [郡候補と判断根拠](../../data/editorial/districts/districts.json)',
        '- [資料・参照箇所・利用条件](../../data/editorial/districts/sources.json)',
        '- [読みやすい資料一覧](SOURCES.md)',
        '- [個別の照合・判断記録](../../data/editorial/districts/review_decisions.json)',
        '- [全親領域の調査記録](../../data/editorial/districts/country_reviews.json)',
        '- [未収録国・親領域外の陸地](../../data/editorial/districts/backlog.json)',
        '- [整合検査](../../data/editorial/districts/qa.json)', '',
        '## 対応の読み方', '',
        '国IDの結合は既存IDごとの明示対応表。各面の座標・隣接領域・内包拠点と、比較資料の府県・国ID関係を併記した。名称一致だけの結合ではない。対応は暫定であり、外部と現行の境界一致を意味しない。', '',
        '東北7親領域は、分割前陸奥・出羽の調査IDへ対応させた。郡候補の親IDは調査の振り分け先であり、郡の全域がその親に収まると決めたものではない。同名郡・表示断片は史料照合まで統合しない。', '',
        '## 国別一覧', '', '|現行名・詳細|親ID|史料上の国（暫定）|候補数|初回の根拠|', '|---|---|---|---:|---|']
    for p in scope['parents']:
        rid = p['parent_region_id']
        selected = [d for d in ds if rid in d['candidate_parent_region_ids']]
        coverage='後世資料のみ' if reviews[rid]['evidence_coverage']=='later_comparison_only' else '比較資料＋個別照合（1582年未確定）'
        text.append(f'|[{p["display_name"]}](countries/{rid}.md)|`{rid}`|{p["historical_province_name"]}|{len(selected)}|{coverage}|')
        lines = ['# '+p['display_name']+'：郡候補初回台帳', '', '[全体報告へ](../SURVEY_AB.md)', '',
            f'親ID：`{rid}` ／ 史料上の国（暫定）：{p["historical_province_name"]} ／ 入力版：{p["input_version"]}', '',
            '地域別正本：'+p.get('upstream_master',{}).get('area','未記録')+' '+p.get('upstream_master',{}).get('version','')+'（現行の名称・面との完全一致を検証）', '',
            '現在の状態：調査中。候補一覧の初回確認済み。1582年の存在と境界は未確定。', '',
            '全候補の位置・境界は未作成。各「典拠」は閲覧済みの国別一覧の行を示す。郡詳細ページや地図の閲覧済み扱いにはしない。', '',
            '|候補名|原表記／読み|候補ID|名称典拠|時代差・残件|', '|---|---|---|---|---|']
        for d in selected:
            citations=[]
            for ref in d['evidence']['name_existence']:
                source=sources_by_id[ref['source_ref']]
                citations.append(f'[{ref["source_ref"]}]({source["url"]})（{ref["locator"]}）')
            lines.append(f'|{d["candidate_display_name"]}|{d["source_name"]}／{d["reading"] or "未確認"}|`{d["district_entity_id"]}`|{" / ".join(citations)}|{d["temporal_difference"]}|')
        lines += ['', '次の調査：'+reviews[rid]['next_action'], '',
            '利用条件：国別比較一覧はCODH/人間文化研究機構のCC BY-NC。別資料は各資料の条件を記録。調査用台帳であり、ゲーム配布への取込は未許諾。詳細は資料台帳を参照。', '']
        (DOC/'countries').mkdir(exist_ok=True)
        (DOC/'countries'/f'{rid}.md').write_text('\n'.join(lines),encoding='utf-8')
    missing = [x['name'] for x in backlog['missing_parents'] if x['status']=='unrepresented_parent_backlog']
    text += ['', '## 初回照合で反映した事項', '',
        '- 甲斐：近代の9分郡は1582年の採用から除外し、分割前の山梨・八代・巨摩・都留を別候補に追加。[山梨県の解説](https://www.pref.yamanashi.jp/shigaku-kgk/10_035.html)',
        '- 信濃：古い区分から伊那・筑摩・安曇・水内・高井・佐久の候補を追加。対象年までの継続は未確認。[長野市誌](https://adeac.jp/nagano-city/texthtml/d100150/ct00000011/ht000710)',
        '- 大和：比較一覧の「宇蛇」を原表記として保持し、「宇陀郡」を編集上の優先候補にした。1585年の回顧記述と1582年の確認を区別。[宇陀市の歴史](https://www.city.uda.lg.jp/soshiki/41/1068.html)',
        '- 讃岐：直島・塩飽島は区画種別未確認の地域項目として扱い、「郡」を自動付加しない。[旧郡一覧](https://geoshape.ex.nii.ac.jp/kg/resource/K60.html#gun-list)',
        '- 和泉・河内・大和と摂津の大阪側：計42項目の名称を別の後世資料で照合。郡境の確定には使っていない。[大阪府公文書館](https://archives.pref.osaka.lg.jp/search/information.do?id=58&method=initPage)', '',
        '国立公文書館の旧案内URLは取得失敗を記録した。和泉の元禄図は[個別ギャラリー](https://www.digital.archives.go.jp/gallery/0000000226)の本文と図版識別子を確認できたが、画像は未判読。日根荘の紹介も原文書への調査入口として扱い、荘園の範囲を郡境に転用していない。', '',
        '## 残件', '',
        '現行親IDとの対応がない国：'+ '・'.join(missing)+'。未収録として別管理し、隣国へ郡を押し込まない。', '',
        f'親領域の外に面積が残る正本陸地成分：{len(backlog["uncovered_land"])}件。島の丸ごと未収録、北海道、本土沿岸の差分等を含み、件数を「島数」とは呼ばない。原本のfeature/part番号、座標、面積比から追跡できる。', '',
        '全候補の成立・改称・分郡・合併・村郷所属は今後の年代補正対象。資料台帳に所在のみの史料を含む場合、取得失敗・個別文書未調査を明記した。', '',
        '## 利用条件と保存範囲', '',
        'HTMLと一覧項目を調査用に保存した。ポリゴン・地図タイル・史料画像は取得していない。CODH旧国旧郡ページの本文はCC BY-NCで、HTMLメタのCC BY表記と一致しないため本文側の制限を記録した。各出典の条件を相互に流用しない。', '',
        'この調査台帳は既存export除外対象のdata/editorial、data/sources、docs以下に保存。実行時郡レジストリや配布版は作らない。', '',
        '## 再確認', '', '```powershell',
        'python -X utf8 tools/prepare_district_ledgers.py check',
        'python -X utf8 tools/prepare_district_ledgers.py report', '```', '',
        '`fetch`は取得済みHTMLのハッシュを確認して再利用する。`initialize`は編集台帳の存在時に停止し、追加の研究を上書きしない。入力が変わった場合は旧ハッシュを黙って更新せず、調査版を分ける。', '']
    (DOC/'SURVEY_AB.md').write_text('\n'.join(text),encoding='utf-8')
    source_lines = ['# 資料台帳（閲覧状態・時代・利用条件）', '', '[全体報告へ](SURVEY_AB.md)', '',
        '|ID・資料|対象年代|閲覧状態|利用条件|', '|---|---|---|---|']
    for s in ss:
        url=s.get('url', '../../'+s.get('local_path',''))
        source_lines.append(f'|[{s["source_id"]}: {s["title"]}]({url})|{s["represented_period"]}|{s.get("retrieval",{}).get("status","local_input")}|{s["rights"]["status"]}|')
    source_lines += ['', '個々の名称・位置の判断はdistricts.jsonのevidenceから、資料IDとlocatorで遡る。HTML原本の取得日時・SHA-256はsources.jsonとdata/sources/districts/pages/*.jsonに保存。', '']
    (DOC/'SOURCES.md').write_text('\n'.join(source_lines),encoding='utf-8')
    print('Wrote survey report, country reports and source index.')


if __name__ == '__main__':
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('action', choices=['fetch','initialize','check','report'])
    args = ap.parse_args()
    globals()[args.action]()
