# 武将肖像 Batch 40

2026-09-29。指定10名のうち、本人名付きの参照画像を確認できた2名を、built-in imagegenで個別制作・登録。正方形1254×1254・文字なし・実アルファ透過PNG。参照元の絵柄や背景を複製せず、容貌・髪型・装束の特徴を現代的な写実画へ再構成した。本人と確認できない別人の画像は流用しない。

|人物|ID|PNG|参照・確認事項|
|---|---|---|---|
|坪内利定|officer_q11425729|`assets/officers/portraits/tsubouchi_toshisada.png`|[本人名を表示する信長の野望の登録武将画面](https://ameblo.jp/tetu522/entry-12617805091.html)。顔画像のみ切り出して参照。登録武将画像は史実の容貌を証明しない。|
|城井鎮房|officer_q11425978|`assets/officers/portraits/kii_shigefusa.png`|[築上町教育委員会のチラシ（2ページ目）](https://www.chikujo-rekishi.jp/.assets/%E6%98%A5%E3%81%AE%E8%8C%B6%E4%BC%9A2025%E3%83%81%E3%83%A9%E3%82%B7.pdf)にある「宇都宮鎮房肖像画（部分）」（天徳寺所蔵）。肖像画の古い筆致ではなく特徴を参照。|

参照画像の一時保存先：`C:/Users/nanoa/AppData/Local/Temp/officer_refs_batch40/`。

## 制作プロンプト

共通：`Use case: stylized-concept. Asset type: 1:1 game officer bust icon. Create exactly one square true transparent PNG. Use the supplied person-specific portrait or named game face as a strong identity and costume reference. Repaint as a premium contemporary photorealistic Japanese human portrait, with natural skin and believable silk/armor. Keep entire headgear/hair and both shoulders inside frame with transparent space above. Correct head-neck-shoulder anatomy. No hands, weapons, text of any language, Japanese characters, scene, logo, crest, frame or watermark.`

- 坪内利定：`Preserve slim angular face, strong straight brows, narrow alert eyes, small clean moustache, black high tied topknot, steel-blue layered robe over brown iron breast armor, alert but composed expression.` 初回は髷の上端が切れたため、同じ顔・衣装・ポーズを保って約12%引いたフレーミングに編集。
- 城井鎮房：`Preserve black upright eboshi headwear with trailing upper stem, narrow long face, small straight moustache, subtle downturned eyes, near-black expansive formal robes and dignified quiet bearing.`

採用生成ファイル（フォルダ `C:/Users/nanoa/.codex/generated_images/01a0c84d-d157-7500-a5e1-c9eb55e0ca04/`）：

- 坪内利定：`exec-e0709cba-d89c-4d84-b169-a2c0a73c0193.png`
- 城井鎮房：`exec-2f11262a-1584-4dd1-b4ca-cb41594cb74c.png`

## 保留

坂本貞次（officer_q108781567）、坪内勝長（officer_q108781574）、坪内友定（officer_q109598880）、坪内広綱（officer_q108703373）、坪内忠勝（officer_q108701318）、坪内昌家（officer_q108701507）、坪内頼定（officer_q108701254）、埴原八蔵（officer_q108781510）は本人と確認できる肖像・ゲーム顔画像を発見できず、創作肖像で補うか質問中。坂本貞次と前回の坂本貞吉は別人物として扱う。各務原市の[坪内氏企画展チラシ](https://www.city.kakamigahara.lg.jp/kankobunka/1010039/rekishi/1027838.html)左の肖像は「坪内定堅」であり、今回の坪内利定・頼定に流用しない。
