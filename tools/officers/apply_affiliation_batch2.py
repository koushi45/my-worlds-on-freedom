"""Second, independently reversible 100-person scenario overlay.

Inputs are editorial decisions and existing source snapshots, not surname matching.
No web requests occur during generation. Removing the call in apply_affiliation_scenario
restores the pre-batch scenario; the historical affiliation ledger is never overwritten here.
"""
import collections
import hashlib
import html
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MASTER = ROOT / 'data/master/officers'
HERE = Path(__file__).parent
BATCH = 'affiliation_batch2_100'


def read(path):
    return json.loads(path.read_text(encoding='utf-8'))


def write(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')


# One district is a conservative game home pool, not a full claim of territorial control.
NEW_HOUSES = [
    ('honjo_echigo', '本庄家（越後）', '本庄繁長', '越後国', '岩舩郡', '小泉荘の本庄氏。実権は小川長資が保持しており、繁長は幼少。'),
    ('oyamada_gunnai', '小山田家（郡内）', '小山田信茂', '甲斐国', '都留郡周辺（仮1）', '郡内小山田氏の本拠圏。現行マップの都留郡周辺の仮区画で表現。武田氏との主従関係とは別に家中の単位を記録。'),
    ('suwa_shrine', '諏訪家（大祝）', '諏訪頼忠', '信濃国', '諏訪郡', '諏訪大社大祝の祭祀家。諏訪頼重の旧領全体を保有する設定ではない。'),
    ('kunohe', '九戸家', '九戸政実', '陸奥国', '二戸郡', '九戸城付近を現行郡台帳の二戸郡で表す。九戸という氏名から九戸郡を機械選択しない。'),
    ('ashikaga_hirashima', '足利家（平島公方）', '足利義栄', '阿波国', '那賀郡', '足利義維の阿波平島の家中。義栄は1546年時点では幼少。'),
    ('kumabe', '隈部家', '隈部親永', '肥後国', '山鹿郡', '隈部氏の永野・山鹿の本拠圏。1546年の当主は父親家とする推定。'),
    ('nejime', '禰寝家', '禰寝重長', '大隅国', '南大隅郡', '禰寝氏の本拠圏。肝付・島津への後年の帰属を遡及しない。'),
    ('hachinohe', '八戸家', '八戸政栄', '陸奥国', '三戸郡', '八戸氏とその庶流の家族配置。三戸南部本家への一括所属はしない。'),
    ('shiokawa', '塩川家（摂津）', '塩川長満', '摂津国', '川辺郡', '山下・一庫を本拠とする塩川氏の圏域。1546年の三好家従属は未確定。'),
    ('kobayakawa_numata', '小早川家（沼田）', '小早川繁平', '安芸国', '豊田郡', '沼田荘・高山城の圏域。安芸沼田郡との同名混同を避ける。竹原家とは別家中。'),
    ('miki_aga', '三木家（英賀）', '三木通秋', '播磨国', '飾西郡', '英賀城の三木氏。飛騨三木氏と同姓だが別の家中。'),
    ('mita_musashi', '三田家（武蔵）', '三田綱秀', '武蔵国', '西多摩郡', '勝沼・辛垣の本拠圏。山内上杉から北条への転属年は未確定。'),
    ('misawa_izumo', '三沢家（出雲）', '三沢為清', '出雲国', '仁多郡', '出雲三沢氏の本拠圏。1543年以後は尼子方に復帰した家中として扱う。'),
]

SUPPLEMENTS = {
    '豊臣秀吉': [('名古屋市博物館「戦国武将の文書」', 'https://www.museum.city.nagoya.jp/collection/data/data_06/index.html', '豊臣秀吉・愛知郡中村出生の説明')],
    '豊臣秀長': [('名古屋市「豊臣秀吉・秀長兄弟生誕の地 名古屋中村」', 'https://www.city.nagoya.jp/kankobunkakoryu/cmsfiles/contents/0000189/189786/guideline3.pdf', 'ロゴマーク使用ガイドライン・生誕地の表示')],
    '明智光秀': [('可児市「歴史が息づくまち」', 'https://www.city.kani.lg.jp/21578.htm', '明智荘・明智城の居住伝承')],
    '堀尾吉晴': [('大口町「大口町出身の武将、松江開府の祖 堀尾吉晴公」', 'https://www.town.oguchi.lg.jp/item/7827.htm', '出生と元服後の父子の織田信安奉公')],
    '本庄繁長': [('村上市郷土資料館「歴代の藩主一覧」', 'https://www.iwafune.ne.jp/~osyagiri/rekisi/rekisi.html', '小川長資1539～1551年、本庄繁長1551年以後の在城期間')],
}

UNCERTAIN_NAMES = {'成田長親', '増田長盛', '上杉朝定', '小島弥太郎', '三戸景道', '上条政繁', '服部一忠', '赤座直保', '生駒家長', '梶原景宗', '溝尾茂朝'}
CHILD_HEADS = {'小早川繁平', '三沢為清'}
REVIEWED_HISTORICAL_ROLES = {
    '小早川繁平': '沼田小早川家の幼少当主（家臣団が政務を担当）',
    '三沢為清': '出雲三沢家の幼少当主',
    '三木通秋': '1544年元服・英賀三木家当主',
    '三田綱秀': '武蔵三田氏当主・国人領主',
    '大舘尚氏': '足利義晴の幕臣・申次・内談衆（出家名常興）',
    '妙印尼': '由良成繁の正室',
    '施薬院全宗': '僧侶（比叡山薬樹院、在任年の詳細は未確定）',
    '塚原卜伝': '鹿島系の神官家出身・兵法家',
    '諏訪頼忠': '諏訪大社大祝（幼少）',
    '隈部親永': '隈部親家の子・家督相続前の一門',
}


def apply(data, houses, districts, by_name):
    selection = read(HERE / 'affiliation_batch2_selection.json')
    baseline = read(MASTER / 'affiliation_batch2_baseline.json')
    decisions = {}
    for line in (HERE / 'affiliation_batch2_decisions.txt').read_text(encoding='utf-8').splitlines():
        if not line or line.startswith('#'):
            continue
        name, house, role, region, reason = line.split('|', 4)
        assert name not in decisions, name
        decisions[name] = (None if house == '-' else house, role, region, reason)
    assert len(selection) == len(decisions) == 100
    assert {s['name'] for s in selection} == set(decisions)
    assert {s['id'] for s in selection} == set(baseline['selected_ids'])
    profiles = data['officers']
    by_key = {d['key']: d for d in districts}

    def location(country, name):
        found = [d['key'] for d in districts if d['country'] == country and d['name'] == name]
        assert len(found) == 1, (country, name, found)
        return found[0]

    def choose(qid, pool):
        assert pool, qid
        return min(pool, key=lambda k: hashlib.sha256((BATCH + ':' + qid + ':' + k).encode()).hexdigest())

    for fid, display, reference, country, dname, note in NEW_HOUSES:
        qid = by_name[reference]['external_id']
        source = read(ROOT / 'data/sources/officers/affiliations_1546' / (qid + '.json'))
        assert fid not in houses, fid
        houses[fid] = dict(id=fid, display_name=display, head_reference=None,
                          family_reference=reference, pool=[location(country, dname)],
                          district_names=[country + '・' + dname], basis='個別の在地家中・家族配置の暫定本拠圏',
                          note=note, source_urls=[source['url']], status='scenario_provisional', scenario_batch=BATCH)

    rows = []
    for selected in selection:
        qid, name = selected['id'], selected['name']
        assert by_name[name]['external_id'] == qid
        a = profiles[qid]
        assert a == baseline['officers'][qid], name
        assert a['district_key'] is None and not a.get('research_batch'), name
        assert a['availability'] not in ('not_born', 'deceased'), name
        fid, role, region, reason = decisions[name]
        source_path = ROOT / 'data/sources/officers/affiliations_1546' / (qid + '.json')
        source = read(source_path)
        sources = [dict(title=source.get('name', name) + '（Wikipedia・保存済み紹介）', url=source['url'],
                        locator='生涯・経歴・出自・系譜の該当段落（個別判断は調査欄に記載）',
                        accessed=source.get('accessed'), snapshot_path=source_path.relative_to(ROOT).as_posix(),
                        snapshot_sha256=hashlib.sha256(source_path.read_bytes()).hexdigest(),
                        source_kind='cached_secondary_biography')]
        sources.extend(dict(title=t, url=u, locator=l, accessed='2026-09-13', source_kind='supplementary_institutional_page')
                       for t, u, l in SUPPLEMENTS.get(name, []))
        if fid:
            assert region == '-'
            pool = houses[fid]['pool']
            counts = collections.Counter(v['district_key'] for other, v in profiles.items()
                                         if other != qid and v['house_id'] == fid and v['district_key'])
            least = min(counts[k] for k in pool)
            key = choose(qid, [k for k in pool if counts[k] == least])
            placement_reason = reason + ' 配置郡はこの家の既存本拠圏（新規家は個別登録圏）内で人数を分散したゲーム設定で、本人の居住地の確定ではない。'
        else:
            country, dname = region.split('/', 1)
            pool = [d['key'] for d in districts if d['country'] == country and '（仮' not in d['name']] if dname == '*' else [location(country, dname)]
            key = choose(qid, pool)
            placement_reason = reason + ' 所属家は不明。地縁を用いたゲーム配置で、郡の所有や1546年の居住を新たに史実認定するものではない。'
        d = by_key[key]
        # The old affiliation status may be unresolved merely because the employer
        # was unknown. It must not override an independently recorded life date.
        uncertain = name in UNCERTAIN_NAMES or by_name[name]['temporal_status'] != 'alive'
        a.update(house_id=fid, house_display=houses[fid]['display_name'] if fid else '不明',
                 role=role, status='scenario', reason=reason, district_key=key,
                 district_display=d['country'] + '・' + d['name'], district_geometry_status=d['adoption'],
                 assignment_kind='gameplay_distributed_not_historical_residence', placement_house_id=fid,
                 placement_policy='user_scenario_location', placement_reason=placement_reason,
                 scenario_override=True, scenario_batch=BATCH, scenario_confidence='暫定・ゲーム設定',
                 scenario_sources=sources, historical_review_note=reason,
                 availability='uncertain' if uncertain else 'available',
                 can_serve_at_start=bool(by_name[name]['start_present']) and not uncertain and role != '元服前' and name not in CHILD_HEADS)
        a['source_urls'] = list(dict.fromkeys(a.get('source_urls', []) + [s['url'] for s in sources]))
        if name in REVIEWED_HISTORICAL_ROLES:
            a['previous_historical_role'] = a['historical_role']
            a['historical_role'] = REVIEWED_HISTORICAL_ROLES[name]
        rows.append(dict(id=qid, name=name, before=baseline['officers'][qid], after=a, sources=sources))
    selected_ids = set(baseline['selected_ids'])
    assert all(a == baseline['officers'][q] for q, a in profiles.items() if q not in selected_ids), 'Unrelated officer changed'
    for filename, expected in baseline['protected_sha256'].items():
        assert hashlib.sha256((MASTER / filename).read_bytes()).hexdigest() == expected, filename
    report = dict(schema_version=1, batch=BATCH, year=1546, selection='前回100人と重複しない未配置者。現行国郡で位置を表せる人物を100人選定。',
                  policy='人物ごとに保存済み紹介の前半生・系譜・就任年を再読。追加の自治体・博物館資料は出典欄に区別。全件を一次史料で確定したものではない。',
                  stats=dict(total=100, placed=len(rows), with_house=sum(bool(r['after']['house_id']) for r in rows),
                             unknown_house=sum(not r['after']['house_id'] for r in rows),
                             roles=dict(collections.Counter(r['after']['role'] for r in rows))),
                  excluded_unmapped=baseline['excluded_unmapped'], officers=rows)
    write(MASTER / 'affiliation_batch2_research.json', report)
    render_report(report)


def render_report(report):
    e = html.escape
    lines = []
    for index, row in enumerate(report['officers'], 1):
        a = row['after']
        refs = '<br>'.join(f'<a href="{e(s["url"], quote=True)}" target="_blank" rel="noopener">{e(s["title"])}</a>：{e(s["locator"])}' for s in row['sources'])
        lines.append(f'<tr id="{row["id"]}"><td>{index}</td><td>{e(row["name"])}</td><td>{e(a["house_display"])}</td><td>{e(a["role"])}</td><td>{e(a["district_display"])}</td><td>{e(a["placement_reason"])}<p class="muted">出仕：{"可" if a["can_serve_at_start"] else "無効／保留"} ／ 年代・同定：{e(a["availability"])}</p></td><td>{refs}</td></tr>')
    stats = report['stats']
    exclusions = '、'.join(e(r['name'] + '（' + r['region'] + '）') for r in report['excluded_unmapped'])
    page = '''<!doctype html><html lang="ja"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>所属・立場・配置郡の追加調査100人 · 1546年</title><style>
:root{color-scheme:dark;font-family:system-ui,"Yu Gothic UI",sans-serif;background:#10191d;color:#e6ece8}body{margin:24px}h1{font-size:26px}p{line-height:1.7;max-width:1200px}a{color:#a5d1e3}input{padding:10px;width:min(90%,450px);background:#23353b;color:white;border:1px solid #60767b}table{border-collapse:collapse;width:100%;font-size:14px}th,td{padding:12px;border-bottom:1px solid #344449;vertical-align:top;text-align:left}th{background:#25373d;position:sticky;top:0}td:nth-child(2),td:nth-child(3),td:nth-child(4){white-space:nowrap}td:nth-child(6){min-width:300px}td:nth-child(7){min-width:220px}.tablewrap{overflow:auto}.muted{color:#a5b5b4;font-size:12px}.note{border-left:3px solid #d4b574;padding:12px;background:#25312d}
</style><h1>所属・立場・配置郡の追加調査100人</h1><p><a href="officers_1546.html">全武将一覧へ</a> ／ <a href="affiliation_research_100.html">前回100人の調査へ</a></p>
'''
    page += f'<p class="note">今回100人の配置完了。所属家を設定：{stats["with_house"]}人 ／ 所属不明を維持：{stats["unknown_house"]}人。前回100人と重複せず、他1498人の設定を維持しています。</p>'
    page += '<p>立場は大名・大名家一門・武将・浪人・元服前の5種類。幼少で家督を継いだ当主は大名として表示し、本人の出仕は無効にします。所属不明でも地域の根拠から配置し、後年の仕官を1546年へ遡及しません。配置先はゲーム設定です。</p>'
    page += f'<p>{e(report["policy"])} 年代・同定の留保は配置で解消したことにせず、個別欄に残します。生年等の元台帳の訂正はこの所属調査とは分けています。</p><details><summary>今回は対象外にした地図未収録地域の6人</summary><p>{exclusions}。配置可能な国郡が現行マップにないため別人を選定しました。既存設定は変更していません。</p></details>'
    page += '<p><label>人物・家・郡・根拠を検索 <input id="search" type="search" placeholder="明智、元服前、尾張 など"></label> <span id="count">100人</span></p><div class="tablewrap"><table><thead><tr><th>No.</th><th>人物</th><th>所属家</th><th>立場</th><th>配置郡</th><th>判断・留保</th><th>資料・参照箇所</th></tr></thead><tbody>' + ''.join(lines) + '</tbody></table></div>'
    page += '''<script>const rows=[...document.querySelectorAll('tbody tr')];document.querySelector('#search').addEventListener('input',ev=>{const q=ev.target.value.trim();let n=0;for(const r of rows){r.hidden=!r.textContent.includes(q);if(!r.hidden)n++;}document.querySelector('#count').textContent=n+'人';});</script></html>'''
    (ROOT / 'docs/officers/affiliation_research_next_100.html').write_text(page, encoding='utf-8')
