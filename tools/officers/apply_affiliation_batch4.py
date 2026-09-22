"""Fourth 100-person placement overlay, after the three existing research batches."""
import collections
import copy
import hashlib
import html
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MASTER = ROOT / 'data/master/officers'
HERE = Path(__file__).parent
BATCH = 'affiliation_batch4_100'
ROLES = {'大名', '大名家一門', '武将', '浪人', '元服前'}


def read(path):
    return json.loads(path.read_text(encoding='utf-8'))


def write(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')


def apply(data, houses, districts, by_name):
    baseline = read(MASTER / 'affiliation_batch4_baseline.json')
    selected = read(HERE / 'affiliation_batch4_selection.json')
    ids = {s['id'] for s in selected}
    assert len(ids) == len(selected) == 100 and ids == set(baseline['selected_ids'])
    profiles = data['officers']
    assert profiles == baseline['officers'], 'The preceding scenario changed; review before regenerating batch 4'
    before = copy.deepcopy(profiles)
    decisions = {}
    for line in (HERE / 'affiliation_batch4_decisions.txt').read_text(encoding='utf-8').splitlines():
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
        assert a['district_key'] is None and not a.get('research_batch') and not a.get('scenario_batch')
        assert a['availability'] not in ('not_born', 'deceased')
        a['house_id'] = decision['house']
        a['role'] = decision['role']

    family_snapshot = copy.deepcopy(profiles)
    relationships = read(MASTER / 'relationships.json')['officers']
    father_checks = {}
    for s in selected:
        qid, name = s['id'], s['name']
        a, decision = profiles[qid], decisions[name]
        if a['role'] != '元服前' or a['house_id']:
            continue
        father_name = decision['father']
        if father_name:
            father_id = by_name.get(father_name, {}).get('external_id')
            parent_refs = [father_id] if father_id else []
            basis = '人物紹介の父表記を個別照合'
        else:
            fathers = relationships[qid]['father']
            parent_refs = [f['external_id'] for f in fathers if f['external_id'] in family_snapshot]
            # Do not silently choose between competing birth/adoptive fathers.
            if len(fathers) != 1 or fathers[0].get('qualifier_labels'):
                parent_refs = []
            father_id = parent_refs[0] if len(parent_refs) == 1 else None
            basis = '既存の父子関係台帳を照合'
        fid = family_snapshot.get(father_id, {}).get('house_id') if father_id else None
        check = dict(father_name=father_name, father_id=father_id, basis=basis,
                     status='inherited' if fid else 'father_house_unknown' if father_id else 'father_unregistered_or_unresolved')
        if fid:
            a['house_id'] = fid
            check['house_id'] = fid
        father_checks[qid] = check

    rows = []
    for s in selected:
        qid, name = s['id'], s['name']
        a, decision = profiles[qid], decisions[name]
        fid = a['house_id']
        source_path = ROOT / 'data/sources/officers/affiliations_1546' / (qid + '.json')
        source = read(source_path)
        sources = [dict(title=source['name'] + '（人物紹介・保存版）', url=source['url'],
                        locator='生涯・略歴・経歴・父母・地縁の該当箇所。採用範囲は個別判断欄に記載。',
                        accessed=source.get('accessed'), snapshot_path=source_path.relative_to(ROOT).as_posix(),
                        snapshot_sha256=hashlib.sha256(source_path.read_bytes()).hexdigest(), source_kind='secondary_biography')]
        supplements = {
            '佐野秀綱': ('佐野市「秀綱の家訓」', 'https://www.city.sano.lg.jp/kurashi_gyosei/kanko_bunka_sports/bunka_dento/karasawa/3/8769.html', '1527年頃の家督継承の説明'),
            '最上義光': ('最上義光歴史館・プロフィール', 'https://mogamiyoshiaki.jp/?l=12172&p=log', '1546年1月出生・父義守・1560年元服の説明'),
            '服部保長': ('三重県史Q&A「服部半蔵と家康」', 'https://www.bunka.pref.mie.lg.jp/rekishi/kenshi/asp/Q_A/detail124.html', '父保長の足利奉公と永禄初年再仕官。清康奉公説との相違を留保'),
            '服部正成': ('三重県史Q&A「服部半蔵と家康」', 'https://www.bunka.pref.mie.lg.jp/rekishi/kenshi/asp/Q_A/detail124.html', '保長の子・1542年出生の説明（和暦換算と長男表記には他説との差がある）'),
        }
        if name in supplements:
            title, url, locator = supplements[name]
            sources.append(dict(title=title, url=url, locator=locator, accessed='2026-09-13', source_kind='municipal_or_museum_publication'))
        note = decision['note']
        check = father_checks.get(qid)
        if check and check['status'] == 'inherited':
            note += ' 登録された父の所属家を引き継ぐゲーム設定を適用。史料上の父の奉公年・本人の出仕年を変更する判断ではない。'
        if fid:
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
        uncertain = by_name[name]['temporal_status'] != 'alive' or name in {'佐野秀綱', '中島可之助', '坪内昌家', '望月千代女'}
        a.update(house_display=houses[fid]['display_name'] if fid else '不明', status='scenario', reason=note,
                 district_key=key, district_display=district['country'] + '・' + district['name'],
                 district_geometry_status=district['adoption'], assignment_kind='gameplay_distributed_not_historical_residence',
                 placement_house_id=fid, placement_policy='user_scenario_location', placement_reason=note + ' ' + placement_note,
                 scenario_override=True, scenario_batch=BATCH, scenario_confidence='暫定・ゲーム設定',
                 scenario_sources=sources, historical_review_note=decision['note'],
                 availability='uncertain' if uncertain else 'available',
                 can_serve_at_start=bool(by_name[name]['start_present']) and not uncertain and a['role'] != '元服前')
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
                  policy='既存の保存済み人物紹介を個別確認し、不足する配置には出自・本拠・後年活動圏を用いた推定を設定。全件の一次史料による確定ではない。',
                  selection_exclusions=baseline['selection_exclusions'],
                  stats=dict(total=100, placed=100, with_house=sum(bool(r['after']['house_id']) for r in rows),
                             unknown_house=sum(not r['after']['house_id'] for r in rows),
                             inherited_from_father=sum(c['status'] == 'inherited' for c in father_checks.values()),
                             roles=dict(collections.Counter(r['after']['role'] for r in rows))))
    write(MASTER / 'affiliation_batch4_research.json', report)
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
        rows.append(f'<tr id="{row["id"]}"><td>{i}</td><td>{e(row["name"])}</td><td>{e(a["house_display"])}</td><td>{e(a["role"])}</td><td>{e(a["district_display"])}</td><td>{e(a["placement_reason"])}{family}<p class="muted">出仕：{"可" if a["can_serve_at_start"] else "無効／保留"} ／ 年代：{"未確定" if a["availability"] == "uncertain" else "配置対象"}</p></td><td>{refs}</td></tr>')
    stats = report['stats']
    page = '''<!doctype html><html lang="ja"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>所属・立場・配置郡の追加100人 第4組 · 1546年</title><style>
:root{color-scheme:dark;font-family:system-ui,"Yu Gothic UI",sans-serif;background:#10191d;color:#e6ece8}body{margin:24px}h1{font-size:26px}p{line-height:1.7;max-width:1250px}a{color:#a5d1e3}input{padding:10px;width:min(90%,450px);background:#23353b;color:white;border:1px solid #60767b}table{border-collapse:collapse;width:100%;font-size:14px}th,td{padding:12px;border-bottom:1px solid #344449;vertical-align:top;text-align:left}th{background:#25373d;position:sticky;top:0}td:nth-child(2),td:nth-child(3),td:nth-child(4){white-space:nowrap}td:nth-child(6){min-width:320px}td:nth-child(7){min-width:220px}.tablewrap{overflow:auto}.muted{color:#a5b5b4;font-size:12px}.note{border-left:3px solid #d4b574;padding:12px;background:#25312d}
</style><h1>所属・立場・配置郡の追加100人 · 第4組</h1><p><a href="officers_1546.html">全武将一覧</a> ／ <a href="affiliation_research_100.html">第1組</a> ／ <a href="affiliation_research_next_100.html">第2組</a> ／ <a href="affiliation_research_third_100.html">第3組</a></p>'''
    page += f'<p class="note">未配置だった別の100人全員に、立場と配置郡を設定。所属家あり：{stats["with_house"]}人、所属不明：{stats["unknown_house"]}人。父の登録所属を引き継いだ元服前の人物：{stats["inherited_from_father"]}人。</p>'
    page += '<p>立場は大名・大名家一門・武将・浪人・元服前の5種類。所属が分からなくても郡は推定で設定します。元服前の人物は、登録父の所属が決まっていれば同じ家へ配置。本人の1546年の身分を判断できる記事がある場合は、その判断も個別に示します。</p>'
    page += '<p>' + e(report['policy']) + ' 具体的な地縁が弱い人物は代替地域と明記し、年代・同定の保留を解消した扱いにはしません。現在の地図に配置できる人物を選び、既存1498人の設定と能力・家系・父母子情報を保持しています。</p>'
    page += '<p><label>人物・家・郡・根拠を検索 <input id="search" type="search" placeholder="最上、元服前、父 など"></label> <span id="count">100人</span></p><div class="tablewrap"><table><thead><tr><th>No.</th><th>人物</th><th>所属家</th><th>立場</th><th>配置郡</th><th>判断・留保</th><th>資料・参照箇所</th></tr></thead><tbody>' + ''.join(rows) + '</tbody></table></div>'
    page += '''<script>const rows=[...document.querySelectorAll('tbody tr')];document.querySelector('#search').addEventListener('input',ev=>{const q=ev.target.value.trim();let n=0;for(const r of rows){r.hidden=!r.textContent.includes(q);if(!r.hidden)n++;}document.querySelector('#count').textContent=n+'人';});</script></html>'''
    (ROOT / 'docs/officers/affiliation_research_fourth_100.html').write_text(page, encoding='utf-8')
