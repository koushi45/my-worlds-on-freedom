# 武将肖像 Batch 39

2026-09-28。指定10名のうち、本人名付きの参照画像を確認できた7名を制作・登録。古画は顔立ち・髪型・装束のみを参考にし、現代的な写実画で再構成した。各PNGは正方形、文字なし、背景アルファ透過。参照画像の出典と生成画像は混同しない。

|人物|ID|PNG|参照画像|
|---|---|---|---|
|土井利勝|officer_q1042428|doi_toshikatsu.png|[茨城県教育委員会・肖像画](https://kyoiku.pref.ibaraki.jp/bunkazai/ken-171/)（晩年の黒い束帯と冠を参照。元絵は小さく、顔の細部は再現可能な資料ではない）|
|土居清良|officer_q11423192|doi_kiyora.png|[信長の野望・新生の本人名付き画像](https://altema.jp/nobunagashinsei/busyo/1361)（史実の容貌を証明するものではない）|
|土屋昌続|officer_q2295119|tsuchiya_masatsugu.png|[武田二十四将図に基づく掲載画像](https://bushoojapan.com/bushoo/takeda/2025/12/12/202521)（画像右上の土屋右衛門。後世の描画であり、史実の容貌の証明ではない）|
|土屋貞綱|officer_q11473873|tsuchiya_sadatsuna.png|[旧名・岡部貞綱として掲載された顔画像](https://ameblo.jp/tetu522/entry-12885611074.html)・[旧姓を記す研究資料](https://www.chiba-muse.or.jp/NATURAL/files/1521536220667/simple/jinbun_4-2_01uchida.pdf)（掲載画像の原作者は未確認。史実の容貌を証明するものではない）|
|土岐頼春|officer_q119927069|toki_yoriharu.png|[信長の野望・新生の本人名付き画像](https://altema.jp/nobunagashinsei/busyo/1389)（史実の容貌を証明するものではない）|
|土岐頼純|officer_q11423418|toki_yorizumi.png|[南泉寺所蔵肖像の模写](https://commons.wikimedia.org/wiki/File:Toki_Yorizumi.jpg)・[山県市の所蔵記録](https://www.city.yamagata.gifu.jp/site/yamanavi/1124.html)（模写のため史実の容貌の証明ではない）|
|土岐頼芸|officer_q837179|toki_yorinori.png|[信長の野望・新生の「土岐賴芸」画像](https://altema.jp/nobunagashinsei/busyo/1388)（史実の容貌を証明するものではない）|

参照画像の一時保存先：`C:/Users/nanoa/AppData/Local/Temp/officer_refs_batch39/`。新生の参照画像は `https://img.altema.jp/nobunagashinsei/busyo/banner/{1361,1389,1388}.jpg` の人物部分を切り出した。

## 保留

国重信正（officer_q38279385）、坂崎成政（officer_q55531376）、坂本貞吉（officer_q108781555）は本人と確認できる肖像・ゲーム画像を発見できず、創作肖像の可否について回答待ち。坂崎成政は津和野藩主・坂崎直盛とは別人であり、画像を流用しない。

## 制作・確認メモ

生成には本人別の参照画像ファイルを直接渡し、容貌・髪型・服装・兜などの固有特徴を強く保持する指示を使用。古画の筆致、背景、文字、カード枠は出力しない。手指・武器を出さない胸上構図で人物ごとの顔・向きを区別。土屋昌続画像の上端の孤立した色点は画像生成の編集機能で除去し、人物自体は維持した。採用した生成PNGは加工せずゲームにコピー。

採用元：

- 土井利勝：`exec-42a8fe7c-08a7-401e-86d8-4c62b7247f5c.png`
- 土居清良：`exec-d3bf055b-cfb7-43ad-9407-2f3ff913114e.png`
- 土屋昌続：`exec-b723deb3-011b-465f-bba5-d67302f52bc6.png`
- 土屋貞綱：`exec-bd7a8c66-bc5d-4f87-b70d-cd987ade2c8f.png`
- 土岐頼春：`exec-8f306f96-0776-48c5-908a-8a069372d94a.png`
- 土岐頼純：`exec-6e78f047-bbaf-4942-9538-2dc58637f860.png`
- 土岐頼芸：`exec-01cbf417-d4b3-485f-8e43-63fe8b8ce5bb.png`

採用元の保存フォルダ：`C:/Users/nanoa/.codex/generated_images/01a0c84d-d157-7500-a5e1-c9eb55e0ca04/`。
