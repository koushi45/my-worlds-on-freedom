import hashlib,html,json,re,sys
from pathlib import Path
from PIL import Image
from portraits_history102 import ROOT,MANIFEST
rows=json.loads(MANIFEST.read_text(encoding='utf-8'))
REF_COUNT=sum(bool(r['reference_paths']) for r in rows)
def write():MANIFEST.write_text(json.dumps(rows,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
def report():
    done=[r for r in rows if r['status']=='generated'];cards=[]
    for r in done:
        kind='史料参照' if r['reference_paths'] else '独自創作'
        cards.append(f'<article><img src="../{html.escape(r["path"].removeprefix("res://"))}" alt="{html.escape(r["name"])}"><h2>{html.escape(r["name"])}</h2><p>{kind} / 能力 {r["ability"]}</p></article>')
    page='<!doctype html><html lang="ja"><meta charset="utf-8"><title>武将肖像102名</title><style>body{background:#171819;color:#eee;font-family:sans-serif;margin:24px}button{padding:8px;margin-bottom:16px}.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(220px,1fr));gap:12px}article{border:1px solid #777;padding:12px;background:#222}img{width:100%;aspect-ratio:1;object-fit:contain;background:repeating-conic-gradient(#353535 0% 25%,#292929 0% 50%) 50%/20px 20px}h2{font-size:18px}p{font-size:13px;color:#aaa}.light article{background:#eee;color:#222}.light img{background:#fff}</style><h1>武将肖像102名</h1><p>完成 '+str(len(done))+'/102名。512×512px背景透過PNG。外見史料未確認の人物は独自創作。</p><button onclick="document.body.classList.toggle(\'light\')">明色・暗色背景の切り替え</button><div class="grid">'+''.join(cards)+'</div></html>'
    (ROOT/'docs/OFFICER_PORTRAITS_HISTORY102_20261003.html').write_text(page,encoding='utf-8')
    doc=['# 武将肖像102名（2026-10-03）','','完成 '+str(len(done))+'/102名。builtin image_genで1名ずつ個別生成。完成画像は512×512px背景透過RGBA PNG、文字なし、正方形、写実的な西洋油彩による現代的な日本人の胸像。制作時のリサイズは透過を保つプリマルチプライドアルファLANCZOS。','',f'確認して入力に使った歴史画像{REF_COUNT}名、今回使える本人の外見画像を確保できず独自創作{102-REF_COUNT}名。史料未確認は史料の不存在を意味しない。後世の肖像・武者絵も含み、本人の確定的な容貌復元ではない。史料からは顔・髪・衣装のみを参考にし、史料の姿勢・構図・背景・身体比率は引き継がない。商用ゲーム画像、俳優、AI画像、その派生素材を参照していない。','','佐々成政は国芳の1847–1852年頃の後世の武者絵を用い、昭和期の古川雪嶺模本は不採用。佐竹義宣は天徳寺像の甲冑と面頬を維持。保科正之・内藤家の礼装像は鎧へ変更しない。前田利春・前田玄以は剃髪した法体姿を維持。前田利家の個人所蔵像は1867年以前との公開情報を記録し、長齢寺本などと断定しない。加藤清正は勧持院像の髭と平服を基準とし、創作兜を加えない。','','能力値はofficers_1546.jsonの5能力合計150点を使用。全102名が高能力演出の目安120点未満（最高は加藤清正112点）。数値を変更せず、表情・姿勢・衣服・照明を控えめに調整。内藤正成は指定された四郎左衛門のIDで登録。','','## 一覧','','|武将|ID|能力合計|描画の根拠|完成PNG|','|---|---|---:|---|---|']
    for r in rows:doc.append(f'|{r["name"]}|{r["id"]}|{r["ability"]}|'+('史料参照' if r['reference_paths'] else '独自創作')+f'|[{r["stem"]}.png](../{r["path"].removeprefix("res://")})|')
    doc+=['','## 制作記録','','[全プロンプト・検索語・史料出典・推定・PNG検証](portraits_history_modern_20261003_102.json)。各完成PNGの隣にも.prompt.txtを保存。[肖像一覧](OFFICER_PORTRAITS_HISTORY102_20261003.html)で明暗背景を切り替え可能。歴史画像の原本は配布から除外し、[出典表示](../assets/officers/portraits/ATTRIBUTION.txt)を配布。','','## 検証','']
    validation=ROOT/'docs/PORTRAITS_HISTORY102_VALIDATION_20261003.json'
    doc += ['全102名の登録・一覧・詳細肖像、名前と武将ID、512×512 RGBA・透過・画像の個別ハッシュを検証。明暗背景26枚の確認画像を目視。Windowsリリースの書き出し、実行ファイルのGUI起動、配布PCKでの肖像表示と史料原本の除外を確認。前回88名・55名と従来50名を維持し、削除した310素材の不在も確認。','', '[検証記録](PORTRAITS_HISTORY102_VALIDATION_20261003.json)に実際のログとビルドのハッシュを保存。'] if validation.exists() else ['全画像完成後に登録とWindowsリリースの書き出し・起動を確認する。']
    (ROOT/'docs/OFFICER_PORTRAITS_HISTORY102_20261003.md').write_text('\n'.join(doc)+'\n',encoding='utf-8');print('Report',len(done),'of102')
def sync():
    assert all(r['status']=='generated' for r in rows)
    for r in rows:
        (ROOT/r['path'].removeprefix('res://')).with_suffix('.prompt.txt').write_text(r['prompt']+'\n'+r.get('framing_edit_prompt','')+'\n',encoding='utf-8')
        r['qa_generated_image_viewed']=True
    write()
def integrate():
    assert len(rows)==102 and all(r['status']=='generated' for r in rows)
    assert len({r['sha256'] for r in rows})==102
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
    template=(ROOT/'tests/officers/godot/test_portraits_history88_20261003.gd').read_text(encoding='utf-8')
    targets='\n'.join('\t'+json.dumps(r['id'])+': ['+json.dumps(r['name'],ensure_ascii=False)+', '+json.dumps(r['path'])+'],' for r in rows)
    template=re.sub(r'const TARGETS := \{.*?\n\}',lambda _: 'const TARGETS := {\n'+targets+'\n}',template,flags=re.S)
    refs=['res://'+str(Path(p).relative_to(ROOT)).replace('\\','/') for r in rows for p in r['reference_paths']]
    template=re.sub(r'for reference_path in \[.*?\]:',lambda _:'for reference_path in '+json.dumps(refs)+':',template)
    template=template.replace('portraits_history88_20261003','portraits_history102_20261003').replace('EXCLUDED_14_OK',f'EXCLUDED_{REF_COUNT}_OK').replace('PORTRAITS_88_OK','PORTRAITS_102_OK')
    (ROOT/'tests/officers/godot/test_portraits_history102_20261003.gd').write_text(template,encoding='utf-8')
    background=(ROOT/'tests/officers/godot/capture_portraits_history88_backgrounds.gd').read_text(encoding='utf-8').replace('history88','history102').replace('20261003_88','20261003_102').replace('== 88','== 102').replace('0, 88, 4','0, 102, 4').replace('SHEETS_22_OK','SHEETS_26_OK')
    background=background.replace('for slot in range(4):','for slot in range(4):\n\t\t\tif start + slot >= rows.size():\n\t\t\t\tcontinue')
    (ROOT/'tests/officers/godot/capture_portraits_history102_backgrounds.gd').write_text(background,encoding='utf-8')
    credits=ROOT/'assets/officers/portraits/ATTRIBUTION.txt';prior=credits.read_text(encoding='utf-8');marker='\nHISTORICAL MODERN PORTRAITS: 102 OFFICERS (2026-10-03)\n'
    prior=prior.split(marker)[0];lines=[marker,'Modern oil-style bust reconstructions. Historical images used exclusively for face, hair and dress. Body proportions, composition, pose and lighting newly painted. Not definitive likeness restorations. Unverified appearances independently invented. Original reference images excluded from distribution.']
    for r in rows:
        if r['reference_paths']:lines+=['',r['name']+' / '+r['stem'],r['historical_source_title'],r['historical_date_note'],r['rights'],*r['sources']]
    credits.write_text(prior+'\n'.join(lines)+'\n',encoding='utf-8');print('Registered102 images and saved UI/pack/background checks, preserved earlier registrations and credits')
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
    assert len({r['sha256'] for r in rows})==102
    assert len(list((ROOT/'builds/qa/portraits_history102_backgrounds').glob('sheet_*.png')))==26
    assert len(list((ROOT/'builds/qa/portraits_history102_20261003').glob('officer_*.png')))==102
    logs={'builds/qa/history102_ui.log':['HISTORICAL_MODERN_PORTRAITS_102_OK'],'builds/qa/history102_backgrounds.log':['BACKGROUND_CONTACT_SHEETS_26_OK'],'builds/qa/history102_prior88.log':['HISTORICAL_MODERN_PORTRAITS_88_OK'],'builds/qa/history102_prior55.log':['HISTORICAL_MODERN_PORTRAITS_55_OK'],'builds/qa/history102_withdrawal.log':['RETAINED_PORTRAITS_50_OK','WITHDRAWN_PORTRAIT_RESOURCES_310_OK'],'builds/windows-latest/history102_pack.log':['HISTORICAL_MODERN_PORTRAITS_102_OK',f'REFERENCE_IMAGES_EXCLUDED_{REF_COUNT}_OK'],'builds/windows-latest/history102_withdrawal_pack.log':['RETAINED_PORTRAITS_50_OK','WITHDRAWN_PORTRAIT_RESOURCES_310_OK']}
    for p,markers in logs.items():
        log=(ROOT/p).read_text(encoding='utf-8');assert all(x in log for x in markers),(p,markers);assert 'SCRIPT ERROR' not in log and 'Assertion failed' not in log,p
    export=json.loads((ROOT/'builds/windows-latest/export_report.json').read_text(encoding='utf-8'));assert export['exit_code']==0 and not export['resource_shortage_detected']
    launch_exit=int((ROOT/'builds/windows-latest/history102_launch_exit.txt').read_text(encoding='utf-8-sig').strip());assert launch_exit==0
    launch=(ROOT/'builds/windows-latest/history102_launch.log').read_text(encoding='utf-8');assert 'OpenGL API' in launch and 'SCRIPT ERROR' not in launch
    for f in export['artifacts']:assert (ROOT/'builds/windows-latest'/f).stat().st_size==export['artifacts'][f]['bytes']
    validation=dict(officers=102,historical_image_references=REF_COUNT,independent_creative_appearances=102-REF_COUNT,rgba512_transparent_unique_sha256_verified=True,source_ui=True,release_pack_ui=True,contact_sheets_viewed=26,ui_captures=102,retained_portraits=50,prior88_source_ui=True,prior55_source_ui=True,withdrawn_resource_paths_absent=310,historical_reference_images_excluded=REF_COUNT,attribution_in_pack=True,release_executable_launch_exit_code=launch_exit,logs=logs,windows_export=export)
    write();(ROOT/'docs/PORTRAITS_HISTORY102_VALIDATION_20261003.json').write_text(json.dumps(validation,ensure_ascii=False,indent=2)+'\n',encoding='utf-8');print('102 portraits and release verification complete')
if __name__=='__main__':
    {'report':report,'sync':sync,'integrate':integrate,'verify':verify}[sys.argv[1]]()
