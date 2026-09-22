"""Resolve the final 40 entries; preserve old scores and archive scope mistakes."""
import hashlib, json
from pathlib import Path
from seed_next_assessments import KEYS, TYPES
ROOT = Path(__file__).resolve().parents[2]
MASTER = ROOT/'data/master/officers'
def read(p): return json.loads(p.read_text(encoding='utf-8'))
def write(p, value): p.write_text(json.dumps(value, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
def main():
    assessments = read(MASTER/'assessments.json')
    previous = {q:a for q,a in assessments.items() if a.get('cohort') != 'remaining_40'}
    assert len(previous) == 1580
    digest = hashlib.sha256(json.dumps(previous, ensure_ascii=False, sort_keys=True).encode()).hexdigest()
    candidates = {r['external_id']:r for r in read(MASTER/'eighteenth_40_candidates.json')}
    rows = read(Path(__file__).with_name('remaining_assessment_rows.json'))
    assert len(rows) == 40 and {r[0] for r in rows} == set(candidates)
    baseline_path = MASTER/'remaining_40_baseline.json'
    if not baseline_path.exists():
        roster = read(ROOT/'data/derived/officers/officers_1546.json')['officers']
        assert {r['external_id'] for r in roster if r['assessment']['status']=='unrated'} == set(candidates)
        write(baseline_path, {'previous_1580_sha256':digest, 'roster_ids':sorted(r['external_id'] for r in roster), 'unrated_ids':sorted(candidates)})
    assert read(baseline_path)['previous_1580_sha256'] == digest
    sources = {s['id']:s for s in read(MASTER/'sources.json')}
    decisions = read(MASTER/'decisions.json')
    reviews = []
    lines = ['# 残る未評価40件の評価・対象整理', '', '既存1580人の評価を保持。対象名簿18人を評価し、時代の異なる16人は対象外台帳に参考評価を保存。誤収録6件は評価対象外とし、点数を付けない。新規人物の登録なし。', '', '能力は生涯実績に基づく編集値（各1〜30点、整数）。本人の確認できる参加は標準遂行と解釈。資料不足・同定保留の12点は実在や出仕資格の確定を意味しない。人望は忠義の強さから推定しない。', '', '|人物|処理|統率|武勇|知略|政治|人望|総合|', '|---|---|---:|---:|---:|---:|---:|---:|']
    details = []
    labels = {'rated':'名簿・評価','reference':'対象外・参考評価','not_applicable':'対象外・非該当'}
    for rank, row in enumerate(rows, 1):
        q, outcome, name, evidence = row[:4]
        candidate = candidates[q]
        url = row[5] if len(row)>5 else ''
        if not url:
            links = candidate['sitelinks']
            site = 'jawiki' if 'jawiki' in links else 'enwiki'
            url = ('https://ja.wikipedia.org/wiki/' if site=='jawiki' else 'https://en.wikipedia.org/wiki/') + links[site]['title'].replace(' ', '_')
        sid = 'b18_'+q.lower()
        sources[sid] = {'id':sid,'title':name+'：人物同定・活動記録（個別の留保は評価本文）','url':url,'accessed':'2026-09-13','use':'紹介・目録を参照した独自要約。一次史料の網羅的検証ではない。数値は編集判断。'}
        scores = dict.fromkeys(KEYS, None if outcome=='not_applicable' else 12)
        reasons = {k:'本人に帰属するこの項目の成否材料を確認できず12点で暫定評価。人望は忠誠や家柄から推定しない。' for k in KEYS}
        basis = dict.fromkeys(KEYS, TYPES['N'])
        for item in (row[4].split(';') if len(row)>4 and row[4] else []):
            key, kind, value, reason = item.split(':', 3)
            value = int(value)
            lo, hi = {'N':(11,13),'P':(14,24),'F':(4,6)}.get(kind,(1,30))
            assert lo <= value <= hi
            scores[key], reasons[key], basis[key] = value, reason, TYPES[kind]
        assessments[q] = {'status':'not_applicable' if outcome=='not_applicable' else 'editorial_draft','cohort':'remaining_40','selection_rank':rank,'basis':'lifetime','scores':scores,'source_refs':[sid],'evidence':evidence,'score_reasons':reasons if outcome!='not_applicable' else {},'score_basis':basis if outcome!='not_applicable' else {},'score_confidence':dict.fromkeys(KEYS,'limited_evidence') if outcome!='not_applicable' else {},'confidence':'provisional','score_policy':'participation_standard_v2','caveat':'資料不足と無能を区別する。人物同定保留の12点はゲーム用仮置き。対象外の参考値を実行時の出仕や所属に使用しない。','score_method':'1〜30点・1点刻み。成否材料なし12前後、失敗のみ5前後。参加は任務規模に応じた標準遂行。'}
        decision = dict(decisions.get(q, {}))
        if name != candidate['display_name']:
            decision.update(display_name=name, aliases=sorted(set(decision.get('aliases',[])+[candidate['display_name']])))
        if outcome != 'rated':
            decision.update(in_scope=False, temporal_status='excluded', suppress_start_age=True, reason=labels[outcome]+'。'+evidence, source_urls=[url])
        elif q in {'Q5507616','Q1191579','Q1077696'}:
            decision.update(temporal_status='unresolved', suppress_start_age=True, reason='人物・世代の同定保留。'+evidence, source_urls=[url])
        if decision: decisions[q] = decision
        reviews.append({'external_id':q,'display_name':name,'outcome':outcome,'reason':evidence,'source_refs':[sid]})
        total = sum(scores.values()) if outcome!='not_applicable' else '—'
        lines.append('|'+ '|'.join(map(str,[name,labels[outcome],*[v if v is not None else '—' for v in scores.values()],total]))+'|')
        details += ['', '## '+name+'（'+labels[outcome]+'）','',evidence,'','[参照資料]('+url+')']
        if outcome!='not_applicable': details += ['', *[f'- {k}: {scores[k]} — {reasons[k]}' for k in KEYS]]
    write(MASTER/'assessments.json', assessments)
    write(MASTER/'sources.json', list(sources.values()))
    write(MASTER/'decisions.json', decisions)
    write(MASTER/'remaining_40_review.json', reviews)
    (ROOT/'docs/officers/REMAINING_40.md').write_text('\n'.join(lines+details)+'\n', encoding='utf-8')
    print('Reviewed 40: 18 roster assessments, 16 excluded reference assessments, 6 not applicable.')
if __name__=='__main__': main()
