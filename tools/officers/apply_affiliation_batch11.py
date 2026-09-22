"""Remaining 65-person overlay, including explicitly authorized future reservations."""
import collections
import copy
import hashlib
import html
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MASTER = ROOT / 'data/master/officers'
HERE = Path(__file__).parent
BATCH = 'affiliation_batch11_65'
ROLES = {'大名', '大名家一門', '武将', '浪人', '元服前'}


def read(path):
    return json.loads(path.read_text(encoding='utf-8'))


def write(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')


def apply(data, houses, districts, by_name):
    baseline = read(MASTER / 'affiliation_batch11_baseline.json')
    selected = read(HERE / 'affiliation_batch11_selection.json')
    runtime_by_id = {r['external_id']: r for r in read(ROOT / 'data/derived/officers/officers_1546.json')['officers']}
    # Display labels disambiguate namesakes without changing their runtime names.
    by_name = {**by_name, **{s['name']: runtime_by_id[s['id']] for s in selected}}
    ids = {s['id'] for s in selected}
    assert len(ids) == len(selected) == 65 and ids == set(baseline['selected_ids'])
    profiles = data['officers']
    assert profiles == baseline['officers'], 'The preceding scenario changed; review before regenerating batch 11'
    before = copy.deepcopy(profiles)
    decisions = {}
    for line in (HERE / 'affiliation_batch11_decisions.txt').read_text(encoding='utf-8').splitlines():
        if not line or line.startswith('#'):
            continue
        name, house, role, region, father, note = line.split('|', 5)
        assert name not in decisions and role in ROLES, name
        decisions[name] = dict(house=None if house == '-' else house, role=role, region=region,
                               father=None if father == '-' else father, note=note)
    assert {s['name'] for s in selected} == set(decisions)
    by_key = {d['key']: d for d in districts}

    def location(country, name):
        matches = [d['key'] for d in districts if d['country'] == country and d['name'] == name]
        assert len(matches) == 1, (country, name)
        return matches[0]

    # Resolve independently reviewed adult affiliations first. A child may refer to
    # a father in this same batch, regardless of the presentation order.
    for s in selected:
        qid, name = s['id'], s['name']
        assert by_name[name]['external_id'] == qid
        a, decision = profiles[qid], decisions[name]
        assert a['district_key'] is None and not a.get('scenario_batch')
        if a['availability'] == 'not_born':
            assert decision['role'] == '元服前'
        a['house_id'] = decision['house']
        a['role'] = decision['role']

    relationships = read(MASTER / 'relationships.json')['officers']
    father_checks = {}
    selected_by_id = {s['id']: s for s in selected}

    def resolve_father(qid, visiting):
        if qid not in selected_by_id or profiles[qid]['role'] != '元服前':
            return profiles[qid]['house_id']
        if qid in visiting:
            raise AssertionError('Father cycle: ' + qid)
        if qid in father_checks:
            return profiles[qid]['house_id']
        decision = decisions[selected_by_id[qid]['name']]
        father_name = decision['father']
        if father_name:
            father_id = father_name[1:] if father_name.startswith('@Q') else by_name.get(father_name, {}).get('external_id')
            basis = '人物紹介の実父表記を個別照合（養父・諸説は区別）'
        else:
            fathers = relationships[qid]['father']
            father_id = fathers[0]['external_id'] if len(fathers) == 1 and not fathers[0].get('qualifier_labels') else None
            basis = '既存の父子関係台帳を照合'
        if father_id not in profiles:
            father_id = None
        fid = resolve_father(father_id, visiting | {qid}) if father_id else None
        check = dict(father_name=father_name, father_id=father_id, basis=basis,
                     status='inherited' if fid else 'father_house_unknown' if father_id else 'father_unregistered_or_unresolved')
        if fid:
            profiles[qid]['house_id'] = fid
            check['house_id'] = fid
        father_checks[qid] = check
        return fid

    for s in selected:
        if profiles[s['id']]['role'] == '元服前':
            resolve_father(s['id'], set())

    rows = []
    for s in selected:
        qid, name = s['id'], s['name']
        a, decision = profiles[qid], decisions[name]
        fid = a['house_id']
        source_path = ROOT / 'data/sources/officers/affiliations_1546' / (qid + '.json')
        if not source_path.exists():
            source_path = ROOT / 'data/sources/officers/affiliation_batch11_summaries' / (qid + '.json')
        source = read(source_path)
        sources = [dict(title=source.get('title') or source['name'] + '（人物紹介・保存版）', url=source['url'],
                        locator=source.get('locator', '生涯・略歴・経歴・父母・地縁の該当箇所。採用範囲は個別判断欄に記載。'),
                        accessed=source.get('accessed'), snapshot_path=source_path.relative_to(ROOT).as_posix(),
                        snapshot_sha256=hashlib.sha256(source_path.read_bytes()).hexdigest(), source_kind=source.get('source_kind', 'secondary_biography'))]
        supplements = {
            '武田元光': ('小浜市・発心寺 木造武田元光坐像', 'https://www1.city.obama.fukui.jp/obm/rekisi/sekai_isan/japanese/data/318.htm', '出家隠居と信豊への家督譲渡'),
            '宗晴康': ('対馬市広報2021年6月・宗氏の歴史', 'https://www.city.tsushima.nagasaki.jp/material/files/group/70/kouhou202106-4.pdf', '1539年晴康家督・1546年の宗姓使用制限'),
            '竹田右衛門': ('Commons・静岡県史料第4輯 連署状画像の書誌', 'https://commons.wikimedia.org/wiki/File:Kuze_Hironobu_Hoka_3_mei_Renshojo_cropped_Shizuoka_ken_Shiryo_Part_4_Frame_242.jpg', '書誌・御前崎本間文書および1607年の分類。原文の署名同定完了ではない'),
        }
        if name in supplements:
            title, url, locator = supplements[name]
            sources.append(dict(title=title, url=url, locator=locator, accessed='2026-09-13', source_kind='municipal_or_temple_publication'))
        note = decision['note']
        check = father_checks.get(qid)
        if check and check['status'] == 'inherited':
            note += ' 登録された父の所属家を引き継ぐゲーム設定を適用。史料上の父の奉公年・本人の出仕年を変更する判断ではない。'
        proxy = bool(fid and not houses[fid]['pool']) or any(w in decision['note'] for w in ('未収録',))
        if fid and not proxy:
            pool = houses[fid]['pool']
            assert pool, (name, fid)
            counts = collections.Counter(v['district_key'] for other, v in profiles.items()
                                         if other != qid and v['house_id'] == fid and v['district_key'])
            least = min(counts[k] for k in pool)
            choices = [k for k in pool if counts[k] == least]
            placement_note = '所属家の登録本拠圏内で人数を分散したゲーム配置。本人の居住郡や領地全体の史実認定ではない。'
        else:
            country, district = decision['region'].split('/', 1)
            if district == '*':
                regional = [d for d in districts if d['country'] == country]
                choices = [d['key'] for d in regional if '（仮' not in d['name']] or [d['key'] for d in regional]
            else:
                choices = [location(country, district)]
            placement_note = '所属不明のまま地縁から推定配置。後年の地域を代用する場合も1546年の実居住を証明するものではない。'
        assert choices, name
        key = min(choices, key=lambda k: hashlib.sha256((BATCH + ':' + qid + ':' + k).encode()).hexdigest())
        district = by_key[key]
        reserved = qid in baseline['future_reserved_ids']
        uncertain = by_name[name]['temporal_status'] != 'alive'
        reference = not reserved
        if reference:
            a['reference_placement_only'] = True
            note += ' 参照用配置（開始時配属なし）。故人・年代保留の浪人は必須5分類の便宜値であり、1546年に浪人として生存したという認定ではない。'
        if proxy:
            a['geographic_proxy'] = True
            placement_note = '現行地図に本来の地域がないための代替郡。所属家の領地ではなく、領有・陸路接続・開始時配属には使わない。'
        if reserved:
            note += ' 未誕生の将来用仮配置。1546年には登場・出仕・開始時所属への組み込みを行わない。'
            a['future_placement_reserved'] = True
            a['future_chronology_basis'] = 'biography_or_family_inference_raw_dates_preserved'
            assert by_name[name]['temporal_status'] in ('unborn', 'unresolved')
        a.update(house_display=houses[fid]['display_name'] if fid else '不明', status='scenario', reason=note,
                 district_key=key, district_display=district['country'] + '・' + district['name'],
                 district_geometry_status=district['adoption'], assignment_kind='gameplay_distributed_not_historical_residence',
                 placement_house_id=None if proxy else fid, placement_policy='user_scenario_location', placement_reason=note + ' ' + placement_note,
                 scenario_override=True, scenario_batch=BATCH, scenario_confidence='暫定・ゲーム設定',
                 scenario_sources=sources, historical_review_note=decision['note'],
                 availability='not_born' if reserved else 'deceased' if before[qid]['availability'] == 'deceased' else 'uncertain' if uncertain else 'available',
                 can_serve_at_start=False)
        if check:
            a['father_assignment_check'] = check
        a['source_urls'] = list(dict.fromkeys(a.get('source_urls', []) + [src['url'] for src in sources]))
        a['previous_historical_role'] = a.get('historical_role')
        a['historical_role'] = '1546年の史料上の身分は個別判断欄を参照（ゲーム立場と区別）'
        rows.append(dict(id=qid, name=name, before=before[qid], after=copy.deepcopy(a), sources=sources))
    assert all(a == before[q] for q, a in profiles.items() if q not in ids), 'Unrelated officer changed'
    for file, digest in baseline['protected_sha256'].items():
        assert hashlib.sha256((MASTER / file).read_bytes()).hexdigest() == digest, file
    report = dict(schema_version=1, batch=BATCH, year=1546, officers=rows,
                  policy='保存済み人物紹介62件と既存調査の出典付き要約3件を参照。一部の自治体資料・画像書誌を再確認。故人・年代保留・同定保留は参照用、未誕生は将来用に分離。現行地図の郡名には後世区画と仮区画があり、史実の1546年郡所属や居所の確定ではない。',
                  selection_exclusions=baseline['selection_exclusions'],
                  stats=dict(total=65, placed=65, reference_only=sum(bool(r['after'].get('reference_placement_only')) for r in rows), geographic_proxies=sum(bool(r['after'].get('geographic_proxy')) for r in rows), future_reserved=sum(bool(r['after'].get('future_placement_reserved')) for r in rows), with_house=sum(bool(r['after']['house_id']) for r in rows),
                             unknown_house=sum(not r['after']['house_id'] for r in rows),
                             inherited_from_father=sum(c['status'] == 'inherited' for c in father_checks.values()),
                             roles=dict(collections.Counter(r['after']['role'] for r in rows))))
    write(MASTER / 'affiliation_batch11_research.json', report)
    render_report(report)


def render_report(report):
    e = html.escape
    rows = []
    for i, row in enumerate(report['officers'], 1):
        a = row['after']
        refs = '<br>'.join(f'<a href="{e(s["url"], quote=True)}" target="_blank" rel="noopener">{e(s["title"])}</a>：{e(s["locator"])}' for s in row['sources'])
        check = a.get('father_assignment_check')
        family = ''
        if check:
            status = {'inherited': '登録父と同じ所属家を設定', 'father_house_unknown': '登録父の所属が不明のため維持',
                      'father_unregistered_or_unresolved': '父未登録・同定未確定のため不明を維持'}[check['status']]
            family = '<p class="muted">父の照合：' + e(check.get('father_name') or check.get('father_id') or '未特定') + ' ／ ' + status + '</p>'
        rows.append(f'<tr id="{row["id"]}"><td>{i}</td><td>{e(row["name"])}</td><td>{e(a["house_display"])}</td><td>{e(a["role"])}</td><td>{e(a["district_display"])}</td><td>{e(a["placement_reason"])}{family}<p class="muted">出仕：{"可" if a["can_serve_at_start"] else "無効／保留"} ／ 年代：{"未誕生・将来用仮配置" if a.get("future_placement_reserved") else "参照用・開始時配属なし"}</p></td><td>{refs}</td></tr>')
    stats = report['stats']
    page = '''<!doctype html><html lang="ja"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>所属・立場・配置郡の残り65人 第11組 · 1546年</title><style>
:root{color-scheme:dark;font-family:system-ui,"Yu Gothic UI",sans-serif;background:#10191d;color:#e6ece8}body{margin:24px}h1{font-size:26px}p{line-height:1.7;max-width:1250px}a{color:#a5d1e3}input{padding:10px;width:min(90%,450px);background:#23353b;color:white;border:1px solid #60767b}table{border-collapse:collapse;width:100%;font-size:14px}th,td{padding:12px;border-bottom:1px solid #344449;vertical-align:top;text-align:left}th{background:#25373d;position:sticky;top:0}td:nth-child(2),td:nth-child(3),td:nth-child(4){white-space:nowrap}td:nth-child(6){min-width:320px}td:nth-child(7){min-width:220px}.tablewrap{overflow:auto}.muted{color:#a5b5b4;font-size:12px}.note{border-left:3px solid #d4b574;padding:12px;background:#25312d}
</style><h1>所属・立場・配置郡の残り65人 · 第11組</h1><p><a href="officers_1546.html">全武将一覧</a> ／ <a href="affiliation_research_100.html">第1組</a> ／ <a href="affiliation_research_next_100.html">第2組</a> ／ <a href="affiliation_research_third_100.html">第3組</a> ／ <a href="affiliation_research_fourth_100.html">第4組</a> ／ <a href="affiliation_research_fifth_100.html">第5組</a> ／ <a href="affiliation_research_sixth_100.html">第6組</a> ／ <a href="affiliation_research_seventh_100.html">第7組</a> ／ <a href="affiliation_research_eighth_100.html">第8組</a> ／ <a href="affiliation_research_ninth_100.html">第9組</a></p>'''
    page += f'<p class="note">未配置だった残り65人全員に、立場と配置郡を設定。うち{stats["reference_only"]}人は参照用配置（開始時配属なし）、{stats["future_reserved"]}人は未誕生の将来用仮配置で、1546年には登場・出仕させません。所属家あり：{stats["with_house"]}人、所属不明：{stats["unknown_house"]}人。父の登録所属を引き継いだ元服前の人物：{stats["inherited_from_father"]}人。</p>'
    page += '<p>立場は大名・大名家一門・武将・浪人・元服前の5種類。所属が分からなくても郡は推定で設定します。元服前の人物は、登録父の所属が決まっていれば同じ家へ配置。本人の1546年の身分を判断できる記事がある場合は、その判断も個別に示します。</p>'
    page += '<p>' + e(report['policy']) + ' 具体的な地縁が弱い人物は代替地域と明記し、年代・同定の保留を解消した扱いにはしません。未誕生の仮配置と故人・保留人物の参照配置は開始時配置と分けて保存します。未配置の残り65人を対象に、既存1533人の設定と能力・家系・父母子情報を保持しています。</p>'
    page += '<p><label>人物・家・郡・根拠を検索 <input id="search" type="search" placeholder="武田、元服前、父 など"></label> <span id="count">65人</span></p><div class="tablewrap"><table><thead><tr><th>No.</th><th>人物</th><th>所属家</th><th>立場</th><th>配置郡</th><th>判断・留保</th><th>資料・参照箇所</th></tr></thead><tbody>' + ''.join(rows) + '</tbody></table></div>'
    page += '''<script>const rows=[...document.querySelectorAll('tbody tr')];document.querySelector('#search').addEventListener('input',ev=>{const q=ev.target.value.trim();let n=0;for(const r of rows){r.hidden=!r.textContent.includes(q);if(!r.hidden)n++;}document.querySelector('#count').textContent=n+'人';});</script></html>'''
    (ROOT / 'docs/officers/affiliation_research_remaining_65.html').write_text(page, encoding='utf-8')
