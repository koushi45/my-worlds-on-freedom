import json,html
from pathlib import Path
from PIL import Image
root=Path(__file__).resolve().parents[1];rows=json.loads((root/'docs/portraits_history_modern_20261002_55.json').read_text(encoding='utf-8'))
generated=[r for r in rows if r['status']=='generated']
for r in generated:
    a=Image.open(root/r['path'].removeprefix('res://')).getchannel('A')
    bbox=a.point(lambda x:255 if x>=128 else 0).getbbox();r['alpha_subject_bbox']=list(bbox)
print('Generated',len(generated),'of55; head-top margin:',[(r['index'],r['alpha_subject_bbox'][1]) for r in generated])
doc=['# 武将肖像55名：史料調査から現代風アイコンへ（2026-10-03）','','指定55名を個別にbuiltin image_genで制作。日本語を含む文字なし、写実的な西洋油彩、現代的な人物表現、1:1、ゲーム完成画像は512×512pxの背景透過RGBA PNG。生成結果は構図を維持して、アルファをプリマルチプライしたLANCZOS縮小で制作時に512pxへ変換。','','商用ゲームの画像・派生画像・創作意匠を参照していない。史料は顔・髪・衣装のみの参考。座像、背景、体型、姿勢、平面的な描画技法は継承しない。','','## 史料と創作の区別','','外見参照画像8名、今回の調査で本人の外見画像を確認できず独自に創作47名。史料の未確認は「史料が存在しない」という断定ではない。後世の肖像・模本・同定に異説のある資料を含むため、本人の実際の容貌の確定的な復元とは扱わない。','','三田村国定は伝三田村左衛門像の国定への比定に異説がある。上杉景勝像は19世紀後半か。上杉謙信像は模本で、図中の上部に座る甲冑人物だけを参照した。「上杉景虎」という史料銘は謙信の旧名であり、別人物の上杉景虎の参考には転用していない。上杉定勝は群像の中央に定勝公と記された人物のみを参照し、白黒資料の布の色は推定。中川清秀は1867年の芳幾の歴史創作版画で、同時代の容貌を証明するものではない。中川秀成のファイル名のHideshige表記は日本語の秀成と所蔵情報で確認。丹羽長秀は16世紀の肖像。その他の制作年を確認できない資料は未確認とした。','','能力値は現行data/derived/officers/officers_1546.jsonの5能力合計150点満点を使用。高能力演出の目安はAGENTS.mdの120点。本対象の最高は上杉謙信112点で、全55名とも120点未満。数値の改変はせず、顔の立体感・視線・素材の質感で完成度を揃え、演出を抑えた。','','## 一覧','','|武将|ID|能力合計|外見参考|完成PNG|','|---|---|---:|---|---|']
for r in rows:
    kind='歴史資料（同定に異説）' if r['index']==0 else ('歴史資料' if r['reference_paths'] else '独自創作')
    p='../'+r['path'].removeprefix('res://');doc.append(f'|{r["name"]}|{r["id"]}|{r["ability"]}|{kind}|[{r["stem"]}.png]({p})|')
doc+=['','## 調査・採用特徴・プロンプト','','各人の検索語、出典URL、補助調査先、利用条件、採用特徴、推定・創作区分、全プロンプト、生成原本、完成寸法・アルファ・SHA256は[制作マニフェスト](portraits_history_modern_20261002_55.json)に記録。各完成PNGの隣に.prompt.txtも保存。','','[配布用出典](../assets/officers/portraits/ATTRIBUTION.txt)をゲームのPCKに含める。京都大学総合博物館所蔵の上杉謙信像(模本)は京都大学貴重資料デジタルアーカイブの再利用条件に従い、所蔵・URL・再構成した変更を明記。史料参照画像そのものはリリースの対象外。','','## 検証','','検証結果は完了後に追記する。']
(root/'docs/OFFICER_PORTRAITS_HISTORY55_20261003.md').write_text('\n'.join(doc)+'\n',encoding='utf-8')
cards=[]
for r in generated:
    path='../'+r['path'].removeprefix('res://');kind='史料参照' if r['reference_paths'] else '創作'
    cards.append(f'<article><img src="{html.escape(path)}" alt="{html.escape(r["name"])}"><h2>{html.escape(r["name"])}</h2><p>{kind} / 能力 {r["ability"]}</p></article>')
page='<!doctype html><html lang="ja"><meta charset="utf-8"><title>武将肖像55名</title><style>body{background:#171819;color:#eee;font-family:sans-serif;margin:24px}button{padding:8px;margin-bottom:16px}.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(220px,1fr));gap:12px}article{border:1px solid #777;padding:12px;background:#222}img{width:100%;aspect-ratio:1;object-fit:contain;background:repeating-conic-gradient(#353535 0% 25%,#292929 0% 50%) 50%/20px 20px}h2{font-size:18px}p{font-size:13px;color:#aaa}.light article{background:#eee;color:#222}.light img{background:#fff}</style><h1>武将肖像55名</h1><p>512×512pxの透過PNG。史料未確認の人物の外見は独自創作です。</p><button onclick="document.body.classList.toggle(\'light\')">明色・暗色背景の切り替え</button><div class="grid">'+''.join(cards)+'</div></html>'
(root/'docs/OFFICER_PORTRAITS_HISTORY55_20261003.html').write_text(page,encoding='utf-8')
(root/'builds/history55_alpha_review.json').write_text(json.dumps(generated,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
