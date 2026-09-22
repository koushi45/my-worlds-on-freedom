"""Seventeenth cohort: 100 provisional editorial lifetime assessments."""
import json, hashlib
from pathlib import Path
from seed_next_assessments import TYPES, KEYS
ROOT=Path(__file__).resolve().parents[2]
SOURCES={}
ROWS = (Path(__file__).with_name('seventeenth_assessment_rows.txt')).read_text(encoding='utf-8')


def main():
    master=ROOT/'data/master/officers'
    assessments=json.loads((master/'assessments.json').read_text(encoding='utf-8'))
    roster={r['external_id']:r for r in json.loads((ROOT/'data/derived/officers/officers_1546.json').read_text(encoding='utf-8'))['officers']}
    candidates=json.loads((master/'seventeenth_100_candidates.json').read_text(encoding='utf-8'))
    before={q:a for q,a in assessments.items() if a.get('cohort') in ('major_60','next_60','third_60','fourth_100','fifth_100','sixth_100','seventh_100','eighth_100','ninth_100','tenth_100','eleventh_100','twelfth_100','thirteenth_100','fourteenth_100','fifteenth_100','sixteenth_100')}
    assert len(before)==1480
    digest=hashlib.sha256(json.dumps(before,ensure_ascii=False,sort_keys=True).encode()).hexdigest()
    selection_path=master/'seventeenth_100_selection.json'
    if selection_path.exists():
        assert json.loads(selection_path.read_text(encoding='utf-8'))['previous_1480_sha256']==digest,'Earlier assessments changed'
    sources={s['id']:s for s in json.loads((master/'sources.json').read_text(encoding='utf-8'))}
    for key,(title,url) in SOURCES.items():
        sid='b17_'+key
        sources[sid]={'id':sid,'title':title,'url':url,'accessed':'2026-09-13','use':'人物の参照事項とリンク。数値は編集評価。原文・画像の転載なし。'}
    bibliography={r['name']:r for r in json.loads((master/'seventeenth_100_bibliography.json').read_text(encoding='utf-8'))}
    selected=[]
    lines=ROWS.strip().splitlines()
    assert len(lines)==len(candidates)==100
    for rank,(line,candidate) in enumerate(zip(lines,candidates,strict=True),1):
        name,extras,evidence,items=line.split('|');q=candidate['external_id']
        assert name==candidate['research_name'] and candidate['display_name']==roster[q]['display_name'],(rank,name)
        display_name=candidate['display_name']
        assert q not in assessments or assessments[q].get('cohort')=='seventeenth_100',name
        refs=['b17_'+key if key in SOURCES else key for key in extras.split(',') if key]
        if display_name in bibliography:
            source=bibliography[display_name];sid='b17_bio_'+q.lower()
            sources[sid]={'id':sid,'title':source['title'],'url':source['url'],'accessed':'2026-09-13','use':'人物伝・自治体資料等を参照。原文や図版は転載せず独自要約とリンクを保存。点数は編集判断。'}
            refs.append(sid)
        assert refs and all(ref in sources for ref in refs),(name,refs)
        scores={};reasons={};basis={};confidence={}
        for key,item in zip(KEYS,items.split(';'),strict=True):
            kind,value,reason=item.split(':',2);value=int(value)
            low,high={'N':(11,13),'F':(4,6),'P':(14,24)}.get(kind,(1,30))
            assert low<=value<=high and reason,(name,key,value)
            scores[key]=value;reasons[key]=reason;basis[key]=TYPES[kind]
            confidence[key]='limited_evidence' if kind in 'PNF' else 'editorial_estimate'
        assessments[q]={'status':'editorial_draft','cohort':'seventeenth_100','selection_rank':rank,'basis':'lifetime','scores':scores,'source_refs':refs,'evidence':evidence,'score_reasons':reasons,'score_basis':basis,'score_confidence':confidence,'confidence':'provisional','score_policy':'participation_standard_v2','caveat':'生涯の業績からのゲーム用比較値。参加が確認でき目立つ失策がない任務は標準遂行と解釈。成否材料なし・失敗のみは今回の参照範囲の判断であり、史料の完全な網羅を意味しない。評価済みは史料確認済み・実在確定・開始時の出仕可能を意味しない。人物同定保留時の12点はゲーム用の仮置き。','score_method':'1〜30点・1点刻み。成否材料なし12前後、失敗のみ5前後。参加のみは規模・戦域・責任を評価。掲載順は今回100人内の編集上の知名度目安であり統計順位ではない。'}
        selected.append({**candidate,'selection_rank':rank})
    assert len({r['external_id'] for r in selected})==100
    baseline=json.loads((master/'seventeenth_100_baseline.json').read_text(encoding='utf-8'))
    later_review=master/'remaining_40_review.json'
    archived_later={r['external_id'] for r in json.loads(later_review.read_text(encoding='utf-8')) if r['outcome']!='rated'} if later_review.exists() else set()
    assert sorted(set(roster)|archived_later)==baseline['roster_ids']
    assert len(baseline['unrated_ids'])==140
    assert set(r['external_id'] for r in selected)<=set(baseline['unrated_ids'])
    selection={'selection':'既存名簿1620人の未評価140人から100人を知名度を目安に編集選定。新規登録なし。評価済み1580人、未評価40人。','identity_notes':['知名度は今回候補内の編集判断であり統計順位ではない。富樫泰高、中野一安、国富貞次、稲葉通則などを先に掲載。','明らかな古代・鎌倉期人物や重複疑義が強い候補を選定から外した。残件を解消する目的で架空の事績を追加しない。','採用者にも人物同定・系譜・軍記の史実性に留保がある。本人に帰属する活動を確認できない項目は12点の暫定値とし、資料不足を低能力としない。','1546年以前の死去・以後の出生を伝える人物は評価本文に記載。開始時の存命判定の原台帳再照合は別の残件。今回の評価は出仕許可ではない。','蔵田五郎左衛門と萱場元時は世代の混同を避ける。国富貞次の諱、細川政清の同定、落合道久と道次の関係も留保。','旧1480人の全評価はSHA-256で保持を確認し、既存未評価IDからの選定と名簿ID不変を検証。'],'previous_1480_sha256':digest,'officers':selected}
    for filename,value in [('assessments.json',assessments),('sources.json',list(sources.values())),('seventeenth_100_selection.json',selection)]:
        (master/filename).write_text(json.dumps(value,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    # Assessment research uncovered contradictions in the original start-year data.
    # Retain the requested existing roster entries, but never make a known doubtful
    # identity/date eligible merely because its five scores are now populated.
    decisions=json.loads((master/'decisions.json').read_text(encoding='utf-8'))
    reviews={
        'Q11457027': {'temporal_status':'unresolved','suppress_start_age':True,'reason':'人物伝では1504年以前に死去。元の没年台帳との照合を残して名簿は保持するが、1546年存命とは扱わず開始時年齢も表示しない。','source_urls':['https://ja.wikipedia.org/wiki/富樫泰高']},
        'Q7677166': {'temporal_status':'unresolved','suppress_start_age':True,'reason':'人物伝では1523年没とされ、元台帳の開始時存命判定と矛盾するため保留へ修正。1546年の出仕対象にしない。','source_urls':['https://ja.wikipedia.org/wiki/高梨澄頼']},
        'Q11606011': {'temporal_status':'unresolved','suppress_start_age':True,'reason':'野州家系譜の年代に疑義があり架空人物説もあるため、元台帳の存命扱いを保留へ修正。能力の暫定値は実在確認や出仕許可を意味しない。','source_urls':['https://ja.wikipedia.org/wiki/細川通政']},
        'Q108781100': {'temporal_status':'unborn','birth_range':[1615,1615],'reason':'柳生利厳の子で1615年生。生涯評価用の既存名簿を保持し、1546年は未誕生として出仕対象から分離。','source_urls':['https://ja.wikipedia.org/wiki/柳生清厳']},
    }
    for q,review in reviews.items():
        decisions[q]={**decisions.get(q,{}),**review}
    (master/'decisions.json').write_text(json.dumps(decisions,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    (master/'seventeenth_temporal_reviews.json').write_text(json.dumps(reviews,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print('Assessed',len(selected),'existing unrated officers; total',len(assessments))

if __name__=='__main__':main()
