"""Fifteenth cohort: 100 provisional editorial lifetime assessments."""
import json, hashlib
from pathlib import Path
from seed_next_assessments import TYPES, KEYS
ROOT=Path(__file__).resolve().parents[2]
SOURCES={'musashi': ('兵庫県立美術館・兵庫文学館「宮本武蔵館」', 'https://www.artm.pref.hyogo.jp/bungaku/kikaku/musashi/'), 'akashi': ('明石城「トリビア・武蔵の町割りの所伝」', 'https://www.akashijo.jp/trivia/index.html'), 'naridomi': ('農林水産省「佐賀の治水の神様 成富兵庫茂安」', 'https://www.maff.go.jp/j/nousin/sekkei/museum/m_izin/saga/')}
ROWS = (Path(__file__).with_name('fifteenth_assessment_rows.txt')).read_text(encoding='utf-8')


def main():
    master=ROOT/'data/master/officers'
    assessments=json.loads((master/'assessments.json').read_text(encoding='utf-8'))
    roster={r['external_id']:r for r in json.loads((ROOT/'data/derived/officers/officers_1546.json').read_text(encoding='utf-8'))['officers']}
    candidates=json.loads((master/'fifteenth_100_candidates.json').read_text(encoding='utf-8'))
    before={q:a for q,a in assessments.items() if a.get('cohort') in ('major_60','next_60','third_60','fourth_100','fifth_100','sixth_100','seventh_100','eighth_100','ninth_100','tenth_100','eleventh_100','twelfth_100','thirteenth_100','fourteenth_100')}
    assert len(before)==1280
    digest=hashlib.sha256(json.dumps(before,ensure_ascii=False,sort_keys=True).encode()).hexdigest()
    selection_path=master/'fifteenth_100_selection.json'
    if selection_path.exists():
        assert json.loads(selection_path.read_text(encoding='utf-8'))['previous_1280_sha256']==digest,'Earlier assessments changed'
    sources={s['id']:s for s in json.loads((master/'sources.json').read_text(encoding='utf-8'))}
    for key,(title,url) in SOURCES.items():
        sid='b15_'+key
        sources[sid]={'id':sid,'title':title,'url':url,'accessed':'2026-09-13','use':'人物の参照事項とリンク。数値は編集評価。原文・画像の転載なし。'}
    bibliography={r['name']:r for r in json.loads((master/'fifteenth_100_bibliography.json').read_text(encoding='utf-8'))}
    selected=[]
    lines=ROWS.strip().splitlines()
    assert len(lines)==len(candidates)==100
    for rank,(line,candidate) in enumerate(zip(lines,candidates,strict=True),1):
        name,extras,evidence,items=line.split('|');q=candidate['external_id']
        assert name==candidate['research_name'] and candidate['display_name']==roster[q]['display_name'],(rank,name)
        display_name=candidate['display_name']
        assert q not in assessments or assessments[q].get('cohort')=='fifteenth_100',name
        refs=['b15_'+key if key in SOURCES else key for key in extras.split(',') if key]
        if display_name in bibliography:
            source=bibliography[display_name];sid='b15_bio_'+q.lower()
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
        assessments[q]={'status':'editorial_draft','cohort':'fifteenth_100','selection_rank':rank,'basis':'lifetime','scores':scores,'source_refs':refs,'evidence':evidence,'score_reasons':reasons,'score_basis':basis,'score_confidence':confidence,'confidence':'provisional','score_policy':'participation_standard_v2','caveat':'生涯の業績からのゲーム用比較値。参加が確認でき目立つ失策がない任務は標準遂行と解釈。成否材料なし・失敗のみは今回の参照範囲の判断であり、史料の完全な網羅を意味しない。未誕生者の評価は開始時の出仕を意味しない。','score_method':'1〜30点・1点刻み。成否材料なし12前後、失敗のみ5前後。参加のみは規模・戦域・責任を評価。掲載順は今回100人内の編集上の知名度目安であり統計順位ではない。'}
        selected.append({**candidate,'selection_rank':rank})
    assert len({r['external_id'] for r in selected})==100
    selection={'selection':'未登録の著名人物100人を追加して編集選定。名簿1520人、評価済み1380人。掲載順は統計順位ではない。','identity_notes':['宮本武蔵・柳生宗矩・島津豊久など未登録の100人を追加。戦国後期から大坂の陣・江戸初期の軍事政治担当を中心とする。開始年以後の出生者も生涯評価の対象。', '剣豪の決闘・技術指南を部隊戦果へ換算しない。世子や幼年藩主の後見者の功績は本人に付けない。', '島津忠長は宮之城家。松浦鎮信は平戸法印。長岡休無は通称細川忠隆。豊臣秀勝は小吉で於次とは別人。真田大助は幸昌。毛利勝永の史料上の署名は吉政。', '既存未評価140人には古代・中世前期・近現代・架空・重複疑義のある候補が含まれるため、今回は未登録の人物を優先。元台帳の全件整理は別の残件。', '忍者説・軍記の大兵数・美談や暴君譚は確定実績とせず注記。今回の参照範囲で成否材料のない項目は12前後、失敗のみは5前後、任務参加は標準遂行として評価。', '旧1280人の全評価をSHA-256で保持確認。新規人物の年代判定と能力評価を分離し、未誕生者を開始時に出仕させない。', '掲載順は今回100人内の編集上の知名度目安であり、統計的な人気順位ではない。'],'previous_1280_sha256':digest,'officers':selected}
    for filename,value in [('assessments.json',assessments),('sources.json',list(sources.values())),('fifteenth_100_selection.json',selection)]:
        (master/filename).write_text(json.dumps(value,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print('Assessed',len(selected),'new officers; total',len(assessments))

if __name__=='__main__':main()
