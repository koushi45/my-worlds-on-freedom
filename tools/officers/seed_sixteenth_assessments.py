"""Sixteenth cohort: 100 provisional editorial lifetime assessments."""
import json, hashlib
from pathlib import Path
from seed_next_assessments import TYPES, KEYS
ROOT=Path(__file__).resolve().parents[2]
SOURCES={'mikawa': ('国立公文書館「旗本御家人・三河物語」', 'https://www.archives.go.jp/exhibition/digital/hatamotogokenin/contents/18.html'), 'hasekura': ('仙台市博物館「支倉常長と慶長遣欧使節」', 'https://www.city.sendai.jp/hakubutsu-shomu/hakubutsukan/kidscorner/kids-08/kidscorner-02/index.html')}
ROWS = (Path(__file__).with_name('sixteenth_assessment_rows.txt')).read_text(encoding='utf-8')


def main():
    master=ROOT/'data/master/officers'
    assessments=json.loads((master/'assessments.json').read_text(encoding='utf-8'))
    roster={r['external_id']:r for r in json.loads((ROOT/'data/derived/officers/officers_1546.json').read_text(encoding='utf-8'))['officers']}
    candidates=json.loads((master/'sixteenth_100_candidates.json').read_text(encoding='utf-8'))
    before={q:a for q,a in assessments.items() if a.get('cohort') in ('major_60','next_60','third_60','fourth_100','fifth_100','sixth_100','seventh_100','eighth_100','ninth_100','tenth_100','eleventh_100','twelfth_100','thirteenth_100','fourteenth_100','fifteenth_100')}
    assert len(before)==1380
    digest=hashlib.sha256(json.dumps(before,ensure_ascii=False,sort_keys=True).encode()).hexdigest()
    selection_path=master/'sixteenth_100_selection.json'
    if selection_path.exists():
        assert json.loads(selection_path.read_text(encoding='utf-8'))['previous_1380_sha256']==digest,'Earlier assessments changed'
    sources={s['id']:s for s in json.loads((master/'sources.json').read_text(encoding='utf-8'))}
    for key,(title,url) in SOURCES.items():
        sid='b16_'+key
        sources[sid]={'id':sid,'title':title,'url':url,'accessed':'2026-09-13','use':'人物の参照事項とリンク。数値は編集評価。原文・画像の転載なし。'}
    bibliography={r['name']:r for r in json.loads((master/'sixteenth_100_bibliography.json').read_text(encoding='utf-8'))}
    selected=[]
    lines=ROWS.strip().splitlines()
    assert len(lines)==len(candidates)==100
    for rank,(line,candidate) in enumerate(zip(lines,candidates,strict=True),1):
        name,extras,evidence,items=line.split('|');q=candidate['external_id']
        assert name==candidate['research_name'] and candidate['display_name']==roster[q]['display_name'],(rank,name)
        display_name=candidate['display_name']
        assert q not in assessments or assessments[q].get('cohort')=='sixteenth_100',name
        refs=['b16_'+key if key in SOURCES else key for key in extras.split(',') if key]
        if display_name in bibliography:
            source=bibliography[display_name];sid='b16_bio_'+q.lower()
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
        assessments[q]={'status':'editorial_draft','cohort':'sixteenth_100','selection_rank':rank,'basis':'lifetime','scores':scores,'source_refs':refs,'evidence':evidence,'score_reasons':reasons,'score_basis':basis,'score_confidence':confidence,'confidence':'provisional','score_policy':'participation_standard_v2','caveat':'生涯の業績からのゲーム用比較値。参加が確認でき目立つ失策がない任務は標準遂行と解釈。成否材料なし・失敗のみは今回の参照範囲の判断であり、史料の完全な網羅を意味しない。未誕生者の評価は開始時の出仕を意味しない。','score_method':'1〜30点・1点刻み。成否材料なし12前後、失敗のみ5前後。参加のみは規模・戦域・責任を評価。掲載順は今回100人内の編集上の知名度目安であり統計順位ではない。'}
        selected.append({**candidate,'selection_rank':rank})
    assert len({r['external_id'] for r in selected})==100
    selection={'selection':'未登録の人物100人を知名度を目安に編集選定。名簿1620人、評価済み1480人。','identity_notes':['大久保忠教・支倉常長・水野信元ほか100人を新規登録。軍事担当と政務担当を分けて生涯評価する。', '酒井忠勝は出羽庄内藩主。松平家忠は深溝家。伊達宗実は亘理家、宗清は吉岡家。留守宗利と宇和島の伊達宗利は別人。', '伊達政道の名乗り・死因や服部家の逸話には不確実性がある。後世の小説、主君への忠義、個人の刃傷を部隊戦果や配下定着へ換算しない。', '候補照合時に鎌倉期の伊達宗綱との取り違えを除外。江戸中期中心の本多忠英・重益も採用せず、青山忠門・渡辺治綱・松平清善を選定。', '既存未評価140人の時代外・架空・重複疑義などの原台帳整理は別の残件。旧1380人の全評価をSHA-256で保持確認。', '今回の100人内での知名度を目安にした編集順であり統計順位ではない。原史料の全件照合は未完で暫定評価。開始時の出仕・配属とは分離する。'],'previous_1380_sha256':digest,'officers':selected}
    for filename,value in [('assessments.json',assessments),('sources.json',list(sources.values())),('sixteenth_100_selection.json',selection)]:
        (master/filename).write_text(json.dumps(value,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print('Assessed',len(selected),'new officers; total',len(assessments))

if __name__=='__main__':main()
