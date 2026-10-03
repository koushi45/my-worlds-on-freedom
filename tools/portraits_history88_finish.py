import hashlib, html, json, re, sys
from pathlib import Path
from PIL import Image
from portraits_history88 import ROOT, MANIFEST

rows=json.loads(MANIFEST.read_text(encoding='utf-8'))
FRAMING_EDIT = 'Edit this existing portrait only to correct framing. Keep exactly the same Japanese person, facial identity, expression, clothes, hat/hair design, oil painting technique and colors. Square transparent PNG. Reduce the entire bust slightly and reframe so that a completely empty transparent horizontal band of 6 percent of the canvas height spans the full top edge, above the complete highest hat tip or hair. The entire head, hair and all headgear must be visible, no clipping. Keep natural proportions. Preserve alpha transparency; no background, no text, no added props. Reference image is the edit target of this same production, not a historical source.'

def framing():
    for i in (24,51,83):
        rows[i]['framing_edit_prompt']=FRAMING_EDIT
    MANIFEST.write_text(json.dumps(rows,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')

def sync():
    for r in rows:
        assert r['status']=='generated'
        (ROOT/r['path'].removeprefix('res://')).with_suffix('.prompt.txt').write_text(r['prompt']+'\n'+('Framing edit: '+r['framing_edit_prompt']+'\n' if r.get('framing_edit_prompt') else ''),encoding='utf-8')
        r['qa_generated_image_viewed']=True
    MANIFEST.write_text(json.dumps(rows,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
def report():
    done=[r for r in rows if r['status']=='generated']
    cards=[]
    for r in done:
        p='../'+r['path'].removeprefix('res://')
        kind='史料参照' if r['reference_paths'] else '独自創作'
        cards.append(f'<article><img src="{html.escape(p)}" alt="{html.escape(r["name"])}"><h2>{html.escape(r["name"])}</h2><p>{kind} / 能力 {r["ability"]}</p></article>')
    page='<!doctype html><html lang="ja"><meta charset="utf-8"><title>武将肖像88名</title><style>body{background:#171819;color:#eee;font-family:sans-serif;margin:24px}button{padding:8px;margin-bottom:16px}.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(220px,1fr));gap:12px}article{border:1px solid #777;padding:12px;background:#222}img{width:100%;aspect-ratio:1;object-fit:contain;background:repeating-conic-gradient(#353535 0% 25%,#292929 0% 50%) 50%/20px 20px}h2{font-size:18px}p{font-size:13px;color:#aaa}.light article{background:#eee;color:#222}.light img{background:#fff}</style><h1>武将肖像88名</h1><p>完成 '+str(len(done))+'/88名。512×512px背景透過PNG。外見史料未確認の人物は独自創作。</p><button onclick="document.body.classList.toggle(\'light\')">明色・暗色背景の切り替え</button><div class="grid">'+''.join(cards)+'</div></html>'
    (ROOT/'docs/OFFICER_PORTRAITS_HISTORY88_20261003.html').write_text(page,encoding='utf-8')
    doc=['# 武将肖像88名：史料から現代風アイコンへ（2026-10-03）','','完成 '+str(len(done))+'/88名。builtin image_genによる個別生成。日本語を含む一切の文字なし、写実的な西洋油彩、現代的な人物表現、1:1、512×512pxの背景透過RGBA PNG。制作時の変換はプリマルチプライしたアルファを保つLANCZOS縮小。','','外見参照画像14名、今回利用できる本人の外見画像を確認できず独自創作74名。史料未確認は不存在を意味しない。後世の肖像も含み、本人の実際の容貌の確定的復元ではない。史料からは顔・髪・衣装のみを採用し、構図・身体比率・背景・姿勢は引き継がない。商用ゲーム画像・その派生素材を使用していない。','','伊達政宗は仙台市博物館所蔵の狩野安信筆1676年像を参照し、両目を描き、黒い冠と装束を保持。眼帯や三日月兜は追加していない。九鬼嘉隆は常安寺の1672年模写像を参照し、黒い装束を保持。伊東義益の白黒史料の色は控えめな推定。井伊直虎は伝統的な女性像の解釈による創作であり、人物同定・性別の異説を記録している。二階堂盛義は二階堂照行の嫡男のIDに対応。','','能力合計は現行officers_1546.jsonを使用。全88名がAGENTS.mdの高能力演出の目安120点未満（最高は伊達政宗113点）。能力値は変更せず、姿勢と照明を控えめに調整した。','','## 一覧','','|武将|ID|能力合計|外見参考|状態|完成PNG|','|---|---|---:|---|---|---|']
    for r in rows:
        kind='史料参照' if r['reference_paths'] else '独自創作'
        p='../'+r['path'].removeprefix('res://')
        doc.append(f'|{r["name"]}|{r["id"]}|{r["ability"]}|{kind}|{r["status"]}|[{r["stem"]}.png]({p})|')
    doc+=['','## 出典と生成指示','','[制作マニフェスト](portraits_history_modern_20261003_88.json)に検索語・URL・利用条件・資料年代と未確認事項・採用特徴・創作区分・全プロンプト・生成原本・PNG検証を保存。各PNGの隣にも.prompt.txtを保存。[一覧](OFFICER_PORTRAITS_HISTORY88_20261003.html)で明暗背景を切り替え可能。','','史料原画像はゲーム配布から除外し、[出典表示](../assets/officers/portraits/ATTRIBUTION.txt)を配布する。','','## 検証','']
    if (ROOT/'docs/PORTRAITS_HISTORY88_VALIDATION_20261003.json').exists():
        doc+=['88名の登録・一覧アイコン・詳細肖像・名前とIDの対応を検証済み。全88枚の512×512 RGBA、透過、個別ハッシュを確認。生成原本と明暗背景22枚の確認用画像を目視し、冠・兜・髪の見切れを修正した。','','Windowsリリースの書き出しとGUI実行ファイルの起動は終了コード0。配布PCKでも88名の表示テストが成功し、史料画像14点の除外と出典TXTの存在を確認。従来50名の維持と削除済み310素材の不在も配布PCKで確認。前回55名の表示テストも成功。','','[検証記録](PORTRAITS_HISTORY88_VALIDATION_20261003.json)にログと出力ファイルのハッシュを保存。証明書ストア読み取り、Roaming配下のエディター設定・マップ診断の書き込みには環境由来の警告が残るが、肖像の読み込みと起動の検証は成功。']
    else:
        doc+=['ゲームへの登録、Windows版の書き出しと起動は全画像完成後に確認する。']
    (ROOT/'docs/OFFICER_PORTRAITS_HISTORY88_20261003.md').write_text('\n'.join(doc)+'\n',encoding='utf-8')
    print('Report',len(done),'of88')

def integrate():
    assert len(rows)==88 and all(r['status']=='generated' for r in rows)
    assert len({r['sha256'] for r in rows})==88
    for r in rows:
        p=ROOT/r['path'].removeprefix('res://');im=Image.open(p)
        assert im.size==(512,512) and im.mode=='RGBA' and im.getchannel('A').getextrema()==(0,255)
        assert hashlib.sha256(p.read_bytes()).hexdigest()==r['sha256']
    registry=ROOT/'scripts/game/officer_portraits.gd';text=registry.read_text(encoding='utf-8');new=[]
    for r in rows:
        pattern='"'+re.escape(r['id'])+'": "[^"]+"';entry=json.dumps(r['id'])+': '+json.dumps(r['path'])
        if re.search(pattern,text):text=re.sub(pattern,lambda _:entry,text)
        else:new.append('\t'+entry+',')
    text=text.replace('const PATH_BY_OFFICER_ID := {','const PATH_BY_OFFICER_ID := {\n'+'\n'.join(new))
    registry.write_text(text,encoding='utf-8')
    template=(ROOT/'tests/officers/godot/test_portraits_history55_20261003.gd').read_text(encoding='utf-8')
    targets='\n'.join('\t'+json.dumps(r['id'])+': ['+json.dumps(r['name']+(' (二階堂照行の嫡男)' if r['index']==14 else ''),ensure_ascii=False)+', '+json.dumps(r['path'])+'],' for r in rows)
    template=re.sub(r'const TARGETS := \{.*?\n\}',lambda _: 'const TARGETS := {\n'+targets+'\n}',template,flags=re.S)
    refs=[ 'res://'+str(Path(p).relative_to(ROOT)).replace('\\','/') for r in rows for p in r['reference_paths']]
    template=re.sub(r'for reference_path in \[.*?\]:',lambda _:'for reference_path in '+json.dumps(refs)+':',template)
    template=template.replace('portraits_history55_20261003','portraits_history88_20261003').replace('EXCLUDED_8_OK','EXCLUDED_14_OK').replace('PORTRAITS_55_OK','PORTRAITS_88_OK')
    (ROOT/'tests/officers/godot/test_portraits_history88_20261003.gd').write_text(template,encoding='utf-8')
    credits=ROOT/'assets/officers/portraits/ATTRIBUTION.txt';prior=credits.read_text(encoding='utf-8');marker='\nHISTORICAL MODERN PORTRAITS: 88 OFFICERS (2026-10-03)\n'
    prior=prior.split(marker)[0];lines=[marker,'Modern oil-style bust reconstructions. Historical images used only for face, hair and dress. Poses, anatomy and lighting newly created. Not definitive likeness restorations. Unverified appearances independently invented. Reference originals excluded from distribution.']
    for r in rows:
        if r['reference_paths']:lines+=['',r['name']+' / '+r['stem'],r.get('historical_date_note','制作年代未確認'),r.get('rights',''),*r['sources']]
    credits.write_text(prior+'\n'.join(lines)+'\n',encoding='utf-8')
    print('Registered88 PNGs; UI and packed-reference audit test saved; attribution appended')

def verify():
    registry=(ROOT/'scripts/game/officer_portraits.gd').read_text(encoding='utf-8')
    for r in rows:
        assert r['status']=='generated' and r['qa_generated_image_viewed']
        p=ROOT/r['path'].removeprefix('res://');im=Image.open(p)
        assert im.size==(512,512) and im.mode=='RGBA' and im.getchannel('A').getextrema()==(0,255)
        assert hashlib.sha256(p.read_bytes()).hexdigest()==r['sha256']
        assert '"'+r['id']+'": "'+r['path']+'"' in registry
        assert r['prompt'] in p.with_suffix('.prompt.txt').read_text(encoding='utf-8')
        assert r['search_queries'] and (r['sources'] or not r['reference_paths'])
        r['qa_dark_light_backgrounds_viewed']=True
    assert len({r['sha256'] for r in rows})==88
    sheets=list((ROOT/'builds/qa/portraits_history88_backgrounds').glob('sheet_*.png'))
    captures=list((ROOT/'builds/qa/portraits_history88_20261003').glob('officer_*.png'))
    assert len(sheets)==22 and len(captures)==88
    logs={
        'builds/qa/history88_ui.log':['HISTORICAL_MODERN_PORTRAITS_88_OK'],
        'builds/qa/history88_backgrounds.log':['BACKGROUND_CONTACT_SHEETS_22_OK'],
        'builds/qa/history88_prior55.log':['HISTORICAL_MODERN_PORTRAITS_55_OK'],
        'builds/qa/history88_withdrawal.log':['RETAINED_PORTRAITS_50_OK','WITHDRAWN_PORTRAIT_RESOURCES_310_OK'],
        'builds/windows-latest/history88_pack.log':['HISTORICAL_MODERN_PORTRAITS_88_OK','REFERENCE_IMAGES_EXCLUDED_14_OK'],
        'builds/windows-latest/history88_withdrawal_pack.log':['RETAINED_PORTRAITS_50_OK','WITHDRAWN_PORTRAIT_RESOURCES_310_OK'],
    }
    for path,markers in logs.items():
        log=(ROOT/path).read_text(encoding='utf-8')
        assert all(marker in log for marker in markers)
        assert 'SCRIPT ERROR' not in log and 'Assertion failed' not in log
    export=json.loads((ROOT/'builds/windows-latest/export_report.json').read_text(encoding='utf-8'))
    assert export['exit_code']==0 and not export['resource_shortage_detected']
    launch_exit=int((ROOT/'builds/windows-latest/history88_launch_exit.txt').read_text(encoding='utf-8-sig').strip())
    assert launch_exit==0
    launch=(ROOT/'builds/windows-latest/history88_launch.log').read_text(encoding='utf-8')
    assert 'OpenGL API' in launch and 'SCRIPT ERROR' not in launch
    for filename in export['artifacts']:assert (ROOT/'builds/windows-latest'/filename).stat().st_size==export['artifacts'][filename]['bytes']
    validation=dict(officers=88,historical_image_references=14,independent_creative_appearances=74,rgba512_transparent_unique_sha256_verified=True,source_ui=True,release_pack_ui=True,contact_sheets_viewed=22,ui_captures=88,retained_portraits=50,prior55_source_ui=True,withdrawn_resource_paths_absent=310,historical_reference_images_excluded=14,attribution_in_pack=True,release_executable_launch_exit_code=launch_exit,logs=logs,windows_export=export,environment_notes=['証明書ストア読み取り、Roaming配下のエディター設定・マップ診断の書き込みに環境由来の警告。肖像読み込みと起動検証は成功。'])
    MANIFEST.write_text(json.dumps(rows,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    (ROOT/'docs/PORTRAITS_HISTORY88_VALIDATION_20261003.json').write_text(json.dumps(validation,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print('88 PNGs, 22 background sheets, source/packed UI, withdrawal audit and release launch verified')

if __name__=='__main__':
    if sys.argv[1]=='report':report()
    elif sys.argv[1]=='integrate':integrate()
    elif sys.argv[1]=='framing':framing()
    elif sys.argv[1]=='sync':sync()
    elif sys.argv[1]=='verify':verify()
