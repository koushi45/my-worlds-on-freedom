"""Reproduce the first 100 individually reviewed affiliations without moving others.

The baseline is a versioned input, not a test expectation to overwrite on each run.
Later research batches should explicitly extend this overlay or migrate that input.
"""
import collections
import copy
import hashlib
import html
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MASTER = ROOT / 'data/master/officers'
DOCS = ROOT / 'docs/officers'
TOOLS = Path(__file__).parent
BATCH = 'affiliation_1546_research_100_v1'
DATE = '2026-09-13'


def read(path):
    return json.loads(path.read_text(encoding='utf-8'))


def write(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')


def digest(value):
    return hashlib.sha256(json.dumps(value, ensure_ascii=False, sort_keys=True).encode()).hexdigest()


def main():
    baseline = read(MASTER / 'affiliation_research_100_baseline.json')
    selection = read(DOCS / 'affiliation_research_100_selection.json')
    decisions = read(TOOLS / 'affiliation_research_100_decisions.json') + read(TOOLS / 'affiliation_research_100_late_decisions.json')
    assert len(selection) == len(decisions) == 100
    assert {s['external_id'] for s in selection} == set(baseline['selected_ids'])
    by_name = {r['display_name']: r for r in read(ROOT / 'data/derived/officers/officers_1546.json')['officers']}
    assert {d[0] for d in decisions} == {s['name'] for s in selection}
    districts = read(ROOT / 'docs/districts/areas/district_areas.json')['rows']
    profiles = copy.deepcopy(baseline['officers'])
    houses = {h['id']: copy.deepcopy(h) for h in baseline['houses']}
    selected_ids = set(baseline['selected_ids'])
    sources = collections.defaultdict(list)
    for names, publisher, title, url, locator, scope in read(TOOLS / 'affiliation_research_100_sources.json'):
        for name in names.split('|'):
            sources[name].append(dict(publisher=publisher, title=title, url=url, locator=locator, scope=scope, consulted=DATE))
    for fid, label, head, country, district, note in read(TOOLS / 'affiliation_research_100_houses.json'):
        matches = [d for d in districts if d['country'] == country and d['name'] == district]
        assert len(matches) == 1, (fid, country, district)
        members = [name for name, h, *_ in decisions if h == fid]
        refs = [s['url'] for n in members for s in sources[n]]
        refs += [read(ROOT / 'data/sources/officers/affiliations_1546' / (by_name[n]['external_id'] + '.json'))['url'] for n in members]
        houses[fid] = dict(id=fid, display_name=label, head_reference=head, pool=[matches[0]['key']],
                           district_names=[country + '・' + district], basis='史料・紹介資料の本拠を現行表示郡に対応させたゲーム配置候補。郡全域の排他的領有の証明ではない。',
                           note=note, source_urls=list(dict.fromkeys(refs)), status='editorial_core_area_draft', research_batch=BATCH)
    reviewed = set('本多重次 戸田康光 菅沼定村 久松俊勝 佐野豊綱 真里谷信隆 留守景宗 間宮康俊 樺山善久 村上通康 杉坊明算 荻野秋清 大井信広'.split())
    reviewed.add('島津忠広 (豊州家)')
    inactive = set('氏家直元 蜂須賀正勝 牧野成定 多功秀朝 多賀谷政経 真里谷信政 須田秀行 国分盛氏 一栗放牛 黒木家永 山内直通 細川元常 多羅尾光俊'.split())
    research_rows = []
    for name, fid, role, reason, locator in decisions:
        r = by_name[name]
        q = r['external_id']
        assert profiles[q]['status'] == 'unresolved', (name, profiles[q]['status'])
        a = profiles[q]
        status = ('reviewed' if name in reviewed else 'provisional') if fid else 'unresolved'
        if name in ('長野顕業', '村上隆勝'):
            status = 'deceased'
        if name == '島津忠親':
            status = 'same_year_ambiguous'
        cache = read(ROOT / 'data/sources/officers/affiliations_1546' / (q + '.json'))
        evidence = [dict(title=name + ' 人物紹介（取得版）', publisher='Wikipedia執筆者', url=cache['url'], locator=locator,
                         scope='人物紹介本文を個別に照合。記載された古文書・系図は原典を読了した意味ではない。',
                         cached_path='data/sources/officers/affiliations_1546/' + q + '.json',
                         consulted=DATE, cache_accessed=cache.get('accessed'), cache_sha256=cache.get('sha256'))] + sources[name]
        a.update(house_id=fid, house_display=houses[fid]['display_name'] if fid else ('該当なし' if status == 'deceased' else '所属不明'),
                 role=role, status=status, reason=reason, source_locator=locator, source_urls=list(dict.fromkeys(s['url'] for s in evidence)),
                 district_key=None, district_display='未配置', assignment_kind='none', research_batch=BATCH,
                 research_confidence='紹介資料と年代を個別照合' if status == 'reviewed' else '推定・異説あり' if status == 'provisional' else '保留／適用対象外')
        a.pop('district_geometry_status', None)
        a['can_serve_at_start'] = bool(fid and r['start_present'] and name not in inactive and not any(x in role for x in ('幼少', '若年', '未出仕', '候補', '隠居', '僧', '継承前')))
        if name == '福原貞俊':
            a.update(birth_reference=[1512, 1519], death_reference=[1593, 1593])
        if name == '村上隆勝':
            a['death_reference'] = [1527, 1532]
        if name == '長野顕業':
            a['death_reference'] = None
            a['death_before_or_at_year'] = 1506
        if name == '島津忠親':
            a['reference_house_ids'] = ['hongo', 'shimazu_hoshu']
            a['reference_house_display'] = '北郷家／島津家（豊州）：1546年養子入り前後'
        if name == '池田信正':
            a['allegiance_note'] = '細川晴元方→氏綱方（1546年中、開始時の前後未固定）'
        if name == '水野信近':
            a['reference_house_display'] = '水野家（緒川）／1550年以後の刈谷水野家'
        if name == '山中氏頼':
            a['reference_house_ids'] = ['hojo']
            a['reference_house_display'] = '北条家（氏綱への奉公、1546年生存は未確認）'
        research_rows.append(dict(external_id=q, name=name, before=copy.deepcopy(baseline['officers'][q]), sources=evidence))
    # Fill the least populated slot, leaving all pre-existing placements untouched.
    by_key = {d['key']: d for d in districts}
    for fid, h in houses.items():
        counts = collections.Counter(a['district_key'] for q, a in profiles.items() if q not in selected_ids and a['house_id'] == fid and a['district_key'])
        members = sorted(q for q in selected_ids if profiles[q]['house_id'] == fid)
        for q in members:
            if not h['pool']:
                continue
            key = min(h['pool'], key=lambda k: (counts[k], hashlib.sha256((q + k).encode()).hexdigest()))
            d = by_key[key]
            profiles[q].update(district_key=key, district_display=d['country'] + '・' + d['name'],
                               assignment_kind='gameplay_distributed_not_historical_residence', district_geometry_status=d['adoption'])
            counts[key] += 1
    for row in research_rows:
        row['after'] = profiles[row['external_id']]
        row['placement_note'] = houses[row['after']['house_id']]['note'] if row['after']['house_id'] else '未配置。候補や後年の所属を開始時配置へ自動転用しない。'
        row['remaining'] = (row['after']['reason'] if row['after']['status'] != 'reviewed' else '個別紹介に挙げられた原典本文との再照合。配置郡は史実居所ではない。')
    assert all(profiles[q] == old for q, old in baseline['officers'].items() if q not in selected_ids)
    master = read(MASTER / 'affiliations_1546.json')
    master['schema_version'] = 1
    master['policy'] = '郡はゲーム上の分散配置。家の本拠圏内の郡候補を使用し、史実の居所・知行地とは区別。所属推定を確定史実としない。'
    stats = dict(collections.Counter(a['status'] for a in profiles.values()))
    stats.update(total=len(profiles), with_house=sum(bool(a['house_id']) for a in profiles.values()), placed=sum(bool(a['district_key']) for a in profiles.values()))
    master.update(officers=profiles, stats=stats)
    write(MASTER / 'affiliations_1546.json', master)
    write(MASTER / 'house_placement_pools_1546.json', dict(schema_version=1, year=1546, houses=list(houses.values())))
    batch_stats = dict(collections.Counter(row['after']['status'] for row in research_rows))
    batch_stats.update(investigated=100, placed=sum(bool(row['after']['district_key']) for row in research_rows), unchanged_others=len(profiles)-100)
    report = dict(schema_version=1, id=BATCH, consulted=DATE, year=1546, stats=batch_stats, officers=research_rows)
    write(MASTER / 'affiliation_research_100.json', report)
    render_report(report)
    lines = ['# 1546年の所属家・立場・配置郡', '', '調査100人の詳細は [個別調査報告](AFFILIATION_RESEARCH_100.md) を参照。', '',
             '郡は史実居所ではなく本拠圏へのゲーム配置。推定・保留を区別。', '', '|人物|所属家|立場|配置郡|確度|', '|---|---|---|---|---|']
    for name, r in by_name.items():
        a = profiles[r['external_id']]
        lines.append('|' + '|'.join([name, a['house_display'], a['role'], a['district_display'], a['status']]) + '|')
    (DOCS / 'AFFILIATIONS_1546.md').write_text('\n'.join(lines)+'\n', encoding='utf-8')
    # Historical research remains reproducible; game rules are a separate overlay.
    from apply_affiliation_scenario import apply
    scenario, scenario_houses = apply(master, list(houses.values()), districts, list(by_name.values()))
    scenario_rows = []
    for row in report['officers']:
        a = scenario['officers'][row['external_id']]
        scenario_rows.append(dict(name=row['name'], external_id=row['external_id'], **a))
    write(MASTER/'affiliation_scenario_100.json', {'officers':scenario_rows})
    page_path = DOCS/'affiliation_research_100.html'
    page = page_path.read_text(encoding='utf-8')
    page = page.replace('<h1>', '<p class="result">現在のゲーム設定：立場は5種類。調査100人中、故人2人を除く98人に配置済み。下段の資料・残件は変更前の史料判断です。</p><h1>', 1)
    page = page.replace('変更前：', '初回調査前：').replace('全結果</option>', '全史料判断（現在の配置とは別）</option>')
    page = page.replace('100人を個別照合し、66人に所属家・立場・配置郡を設定。', '100人を個別照合した初回調査では、66人に所属家・立場・配置郡を設定。')
    for row in scenario_rows:
        marker = f'id="{row["external_id"]}">'
        current = '<p class="result">現在の設定：'+html.escape('／'.join([row['house_display'],row['role'],row['district_display']]))+'</p>'
        current += '<p>'+html.escape(row.get('placement_reason','従来の本拠圏内配置。出生前・故人は未配置。'))+'</p>'
        page = page.replace(marker,marker+current)
    page_path.write_text(page,encoding='utf-8')
    lines = ['# 1546年の所属家・立場・配置郡（ゲーム設定）','','所属と配置先を分離。史料判断は AFFILIATION_RESEARCH_100.md、現行設定は本表。','','|人物|所属家|立場|配置郡|史料上の立場|','|---|---|---|---|---|']
    for name, r in by_name.items():
        a=scenario['officers'][r['external_id']]
        lines.append('|'+ '|'.join([name,a['house_display'],a['role'],a['district_display'],a['historical_role']])+'|')
    (DOCS/'AFFILIATIONS_1546.md').write_text('\n'.join(lines)+'\n',encoding='utf-8')
    print(json.dumps({'historical_research':batch_stats, 'scenario_100_placed':sum(bool(r['district_key']) for r in scenario_rows), 'role_types':sorted({a['role'] for a in scenario['officers'].values()})}, ensure_ascii=False))


def render_report(report):
    esc = html.escape
    s = report['stats']
    intro = f"所属等が未確定だった100人を個別照合し、{s['placed']}人に所属家・立場・配置郡を設定。うち推定は{s.get('provisional',0)}人。故人{s.get('deceased',0)}人、年内前後保留{s.get('same_year_ambiguous',0)}人、その他未解決{s.get('unresolved',0)}人。対象外1498人の所属・配置と全員の能力・家系・親子情報は維持。"
    policy = '調査日：2026-09-13。対象は1546年、配置には現行1582年基準の表示郡を使用。資料紹介に記載された年月・人物世代・臣従と同盟の違いを照合した。原典を閲覧できないものは紹介資料に基づく判断であり、100人全員の所属が確定したわけではない。推定所属はゲーム用の案として表示する。幼少・若年・隠居と現役を分離。未確認を「存在しない」とは解釈しない。'
    md = ['# 1546年・未確定100人の所属調査', '', intro, '', policy, '', '## 調査方法と制約', '',
          '対象IDは調査前に固定。既存人物紹介の取得版を100件すべて読んで時系列を整理し、自治体・博物館・大学の公開資料を追加照合した。検索索引のみ確認できた資料、案内ページのみ閲覧した原典は各資料の欄で明示。書誌にある古文書を直接確認したとは扱わない。', '',
          '配置郡は本拠が含まれる現行区画への分散配置で、郡全域の領有や実際の住居ではない。能勢郡高山荘は現行マップでは合併後の川辺郡表示を使用。対立陣営の大崎義宣と義直、竹谷と岡崎の松平家は別所属。', '',
          '再生成：`python tools/officers/build_affiliations.py` → `python tools/officers/build_roster.py`。個別判断・追加資料・本拠圏は `tools/officers/affiliation_research_100_*.json`、変更前は `data/master/officers/affiliation_research_100_baseline.json` に保存。後続調査はこの固定入力を明示的に拡張する。無関係な再分散は行わない。', '',
          '## 個別結果', '']
    cards = []
    for i, row in enumerate(report['officers'], 1):
        a, before = row['after'], row['before']
        status = {'reviewed':'個別照合', 'provisional':'推定配置', 'unresolved':'未解決', 'deceased':'故人', 'same_year_ambiguous':'年内前後保留'}[a['status']]
        md += [f"### {i}. {row['name']}（{row['external_id']}）", '',
               f"変更前：{before['house_display']}／{before['role']}／{before['district_display']}", '',
               f"変更後：**{a['house_display']}／{a['role']}／{a['district_display']}** · {status}", '',
               a['reason'], '', '配置判断：'+row['placement_note'], '', '残件：'+row['remaining'], '']
        refs = []
        for ref in row['sources']:
            description = ref['publisher']+'「'+ref['title']+'」／'+ref['locator']+'。'+ref['scope']
            md += [f"- [{description}]({ref['url']})"]
            refs.append(f'<li><a href="{esc(ref["url"],quote=True)}" target="_blank" rel="noopener">{esc(ref["publisher"]+" · "+ref["title"])}</a><br>{esc(ref["locator"])}<br><span class="muted">{esc(ref["scope"])}</span></li>')
        md += ['']
        cards.append(f'<article data-status="{a["status"]}" id="{row["external_id"]}"><h2>{i}. {esc(row["name"])} <small>{status}</small></h2><p class="muted">変更前：{esc(before["house_display"]+"／"+before["role"]+"／"+before["district_display"])}</p><p class="result">{esc(a["house_display"])} · {esc(a["role"])} · {esc(a["district_display"])}</p><p>{esc(a["reason"])}</p><p><b>配置判断：</b>{esc(row["placement_note"])}</p><details><summary>資料・残件</summary><p>{esc(row["remaining"])}</p><ul>{"".join(refs)}</ul><p class="muted">{row["external_id"]} / 調査日 {DATE}</p></details></article>')
    (DOCS/'AFFILIATION_RESEARCH_100.md').write_text('\n'.join(md)+'\n', encoding='utf-8')
    page = '''<!doctype html><html lang="ja"><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>1546年 所属調査100人</title><style>body{font-family:system-ui,sans-serif;background:#102028;color:#e6eeee;margin:0;line-height:1.8}main{max-width:1050px;margin:auto;padding:28px}h1{font-size:28px}h2{font-size:21px}small,.muted{color:#a8bdc7;font-size:14px}a{color:#8fd7ff}article{background:#1b303a;border:1px solid #37525c;border-radius:10px;padding:18px 24px;margin:20px 0}article p{margin:12px 0}.result{color:#cbe9bd;font-weight:600}input,select{font:inherit;padding:9px;background:#fff;color:#132630;border-radius:6px;max-width:100%;box-sizing:border-box}nav{position:sticky;top:0;padding:12px;background:#102028;display:flex;gap:10px;flex-wrap:wrap}summary{cursor:pointer}li{margin-bottom:12px}[hidden]{display:none}</style><main><a href="officers_1546.html">武将一覧へ</a><h1>1546年の所属・立場・配置郡 — 100人の個別調査</h1>'''
    page += '<p>'+esc(intro)+'</p><p class="muted">'+esc(policy)+'</p><p><a href="AFFILIATION_RESEARCH_100.md">調査方法・全資料を含む報告書</a></p>'
    page += '<nav><input id="query" type="search" aria-label="人物・所属・理由で検索" placeholder="人物・所属・理由で検索"><select id="status" aria-label="調査結果"><option value="">全結果</option value="reviewed">個別照合</option><option value="provisional">推定配置</option><option value="unresolved">未解決</option><option value="deceased">故人</option><option value="same_year_ambiguous">年内前後保留</option></select><span id="count">100人</span></nav>'
    page += ''.join(cards) + '''</main><script>const query=document.getElementById('query'),status=document.getElementById('status');function filter(){let n=0;for(const a of document.querySelectorAll('article')){a.hidden=!(a.textContent.includes(query.value.trim())&&(!status.value||a.dataset.status===status.value));if(!a.hidden)n++}document.getElementById('count').textContent=n+'人'}query.addEventListener('input',filter);status.addEventListener('change',filter);</script></html>'''
    (DOCS/'affiliation_research_100.html').write_text(page, encoding='utf-8')


if __name__ == '__main__':
    main()
