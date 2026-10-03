# 武将肖像55名：史料調査から現代風アイコンへ（2026-10-03）

指定55名を個別にbuiltin image_genで制作。日本語を含む文字なし、写実的な西洋油彩、現代的な人物表現、1:1、ゲーム完成画像は512×512pxの背景透過RGBA PNG。生成結果は構図を維持して、アルファをプリマルチプライしたLANCZOS縮小で制作時に512pxへ変換。

商用ゲームの画像・派生画像・創作意匠を参照していない。史料は顔・髪・衣装のみの参考。座像、背景、体型、姿勢、平面的な描画技法は継承しない。

## 史料と創作の区別

外見参照画像8名、今回の調査で本人の外見画像を確認できず独自に創作47名。史料の未確認は「史料が存在しない」という断定ではない。後世の肖像・模本・同定に異説のある資料を含むため、本人の実際の容貌の確定的な復元とは扱わない。

三田村国定は伝三田村左衛門像の国定への比定に異説がある。上杉景勝像は19世紀後半か。上杉謙信像は模本で、図中の上部に座る甲冑人物だけを参照した。「上杉景虎」という史料銘は謙信の旧名であり、別人物の上杉景虎の参考には転用していない。上杉定勝は群像の中央に定勝公と記された人物のみを参照し、白黒資料の布の色は推定。中川清秀は1867年の芳幾の歴史創作版画で、同時代の容貌を証明するものではない。中川秀成のファイル名のHideshige表記は日本語の秀成と所蔵情報で確認。丹羽長秀は16世紀の肖像。その他の制作年を確認できない資料は未確認とした。

能力値は現行data/derived/officers/officers_1546.jsonの5能力合計150点満点を使用。高能力演出の目安はAGENTS.mdの120点。本対象の最高は上杉謙信112点で、全55名とも120点未満。数値の改変はせず、顔の立体感・視線・素材の質感で完成度を揃え、演出を抑えた。

## 一覧

|武将|ID|能力合計|外見参考|完成PNG|
|---|---|---:|---|---|
|三田村国定|officer_q108781592|74|歴史資料（同定に異説）|[mitamura_kunisada_history_modern_v1.png](../assets/officers/portraits/mitamura_kunisada_history_modern_v1.png)|
|三田綱秀|officer_q17212681|58|独自創作|[mita_tsunahide_history_modern_v1.png](../assets/officers/portraits/mita_tsunahide_history_modern_v1.png)|
|三箇頼照|officer_q109358474|67|独自創作|[sanga_yoriteru_history_modern_v1.png](../assets/officers/portraits/sanga_yoriteru_history_modern_v1.png)|
|三雲成持|officer_q10867117|71|独自創作|[mikumo_narimochi_history_modern_v1.png](../assets/officers/portraits/mikumo_narimochi_history_modern_v1.png)|
|上井覚兼|officer_q7903777|82|独自創作|[uwai_kakuken_history_modern_v1.png](../assets/officers/portraits/uwai_kakuken_history_modern_v1.png)|
|上坂勘解由|officer_q121643707|68|独自創作|[uesaka_kageyu_history_modern_v1.png](../assets/officers/portraits/uesaka_kageyu_history_modern_v1.png)|
|上杉定勝|officer_q8514762|91|歴史資料|[uesugi_sadakatsu_history_modern_v1.png](../assets/officers/portraits/uesugi_sadakatsu_history_modern_v1.png)|
|上杉定実|officer_q11359151|68|独自創作|[uesugi_sadazane_history_modern_v1.png](../assets/officers/portraits/uesugi_sadazane_history_modern_v1.png)|
|上杉憲政|officer_q906593|46|独自創作|[uesugi_norimasa_history_modern_v1.png](../assets/officers/portraits/uesugi_norimasa_history_modern_v1.png)|
|上杉景勝|officer_q1376605|95|歴史資料|[uesugi_kagekatsu_history_modern_v1.png](../assets/officers/portraits/uesugi_kagekatsu_history_modern_v1.png)|
|上杉景虎|officer_q1190934|48|独自創作|[uesugi_kagetora_history_modern_v1.png](../assets/officers/portraits/uesugi_kagetora_history_modern_v1.png)|
|上杉朝定|officer_q277361|44|独自創作|[uesugi_tomosada_history_modern_v1.png](../assets/officers/portraits/uesugi_tomosada_history_modern_v1.png)|
|上杉謙信|officer_q311080|112|歴史資料|[uesugi_kenshin_history_modern_v1.png](../assets/officers/portraits/uesugi_kenshin_history_modern_v1.png)|
|上条政繁|officer_q6127646|74|独自創作|[jojo_masashige_history_modern_v1.png](../assets/officers/portraits/jojo_masashige_history_modern_v1.png)|
|上林政重|officer_q119926786|74|独自創作|[kanbayashi_masashige_history_modern_v1.png](../assets/officers/portraits/kanbayashi_masashige_history_modern_v1.png)|
|上泉信綱|officer_q1375744|65|独自創作|[kamiizumi_nobutsuna_history_modern_v1.png](../assets/officers/portraits/kamiizumi_nobutsuna_history_modern_v1.png)|
|下曾根出羽守|officer_q17213585|72|独自創作|[shimosone_dewanokami_history_modern_v1.png](../assets/officers/portraits/shimosone_dewanokami_history_modern_v1.png)|
|下曾根浄喜|officer_q17213578|84|独自創作|[shimosone_joki_history_modern_v1.png](../assets/officers/portraits/shimosone_joki_history_modern_v1.png)|
|下田直久|officer_q50640323|70|独自創作|[shimoda_naohisa_history_modern_v1.png](../assets/officers/portraits/shimoda_naohisa_history_modern_v1.png)|
|下間仲世|officer_q11361411|63|独自創作|[shimotsuma_nakayo_history_modern_v1.png](../assets/officers/portraits/shimotsuma_nakayo_history_modern_v1.png)|
|下間真頼|officer_q6606038|67|独自創作|[shimotsuma_sanrai_history_modern_v1.png](../assets/officers/portraits/shimotsuma_sanrai_history_modern_v1.png)|
|下間頼亮|officer_q11361416|76|独自創作|[shimotsuma_yorisuke_history_modern_v1.png](../assets/officers/portraits/shimotsuma_yorisuke_history_modern_v1.png)|
|下間頼廉|officer_q7497031|70|独自創作|[shimotsuma_rairen_history_modern_v1.png](../assets/officers/portraits/shimotsuma_rairen_history_modern_v1.png)|
|下間頼照|officer_q6606120|66|独自創作|[shimotsuma_raisho_history_modern_v1.png](../assets/officers/portraits/shimotsuma_raisho_history_modern_v1.png)|
|中原善左衛門|officer_q11363126|64|独自創作|[nakahara_zenzaemon_history_modern_v1.png](../assets/officers/portraits/nakahara_zenzaemon_history_modern_v1.png)|
|中山勝政|officer_q11364066|74|独自創作|[nakayama_katsumasa_history_modern_v1.png](../assets/officers/portraits/nakayama_katsumasa_history_modern_v1.png)|
|中山勝時|officer_q11364086|75|独自創作|[nakayama_katsutoki_history_modern_v1.png](../assets/officers/portraits/nakayama_katsutoki_history_modern_v1.png)|
|中山田泰吉|officer_q20041913|78|独自創作|[nakayamada_yasuyoshi_history_modern_v1.png](../assets/officers/portraits/nakayamada_yasuyoshi_history_modern_v1.png)|
|中島可之助|officer_q11364434|66|独自創作|[nakajima_kanosuke_history_modern_v1.png](../assets/officers/portraits/nakajima_kanosuke_history_modern_v1.png)|
|中島正時|officer_q11364532|62|独自創作|[nakajima_masatoki_history_modern_v1.png](../assets/officers/portraits/nakajima_masatoki_history_modern_v1.png)|
|中島豊後守|officer_q11364622|81|独自創作|[nakajima_bungonokami_history_modern_v1.png](../assets/officers/portraits/nakajima_bungonokami_history_modern_v1.png)|
|中島重房|officer_q11364629|80|独自創作|[nakajima_shigefusa_history_modern_v1.png](../assets/officers/portraits/nakajima_shigefusa_history_modern_v1.png)|
|中川清秀|officer_q6960145|62|歴史資料|[nakagawa_kiyohide_history_modern_v1.png](../assets/officers/portraits/nakagawa_kiyohide_history_modern_v1.png)|
|中川秀成|officer_q11364924|83|歴史資料|[nakagawa_hidenari_history_modern_v1.png](../assets/officers/portraits/nakagawa_hidenari_history_modern_v1.png)|
|中川秀政|officer_q851268|77|独自創作|[nakagawa_hidemasa_history_modern_v1.png](../assets/officers/portraits/nakagawa_hidemasa_history_modern_v1.png)|
|中村元勝|officer_q121648626|72|独自創作|[nakamura_motokatsu_history_modern_v1.png](../assets/officers/portraits/nakamura_motokatsu_history_modern_v1.png)|
|中村元明|officer_q11365321|79|独自創作|[nakamura_motoaki_history_modern_v1.png](../assets/officers/portraits/nakamura_motoaki_history_modern_v1.png)|
|中村可近|officer_q45830232|70|独自創作|[nakamura_yoshichika_history_modern_v1.png](../assets/officers/portraits/nakamura_yoshichika_history_modern_v1.png)|
|中村次郎兵衛|officer_q11365740|81|独自創作|[nakamura_jirobe_history_modern_v1.png](../assets/officers/portraits/nakamura_jirobe_history_modern_v1.png)|
|中村豊重|officer_q11366019|69|独自創作|[nakamura_toyoshige_history_modern_v1.png](../assets/officers/portraits/nakamura_toyoshige_history_modern_v1.png)|
|中条景資|officer_q11366154|78|独自創作|[chujou_kagesuke_history_modern_v1.png](../assets/officers/portraits/chujou_kagesuke_history_modern_v1.png)|
|中条藤資|officer_q11366171|78|独自創作|[chujou_fujisuke_history_modern_v1.png](../assets/officers/portraits/chujou_fujisuke_history_modern_v1.png)|
|中西元如|officer_q124483507|71|独自創作|[nakanishi_motoyuki_history_modern_v1.png](../assets/officers/portraits/nakanishi_motoyuki_history_modern_v1.png)|
|中野一安|officer_q124426163|86|独自創作|[nakano_kazuyasu_history_modern_v1.png](../assets/officers/portraits/nakano_kazuyasu_history_modern_v1.png)|
|中野宗時|officer_q11367555|72|独自創作|[nakano_munetoki_history_modern_v1.png](../assets/officers/portraits/nakano_munetoki_history_modern_v1.png)|
|丸尾義清|officer_q108459152|70|独自創作|[maruo_yoshikiyo_history_modern_v1.png](../assets/officers/portraits/maruo_yoshikiyo_history_modern_v1.png)|
|丸毛光兼|officer_q123415498|78|独自創作|[marumo_mitsukane_history_modern_v1.png](../assets/officers/portraits/marumo_mitsukane_history_modern_v1.png)|
|丸目長恵|officer_q10877248|75|独自創作|[marume_nagayoshi_history_modern_v1.png](../assets/officers/portraits/marume_nagayoshi_history_modern_v1.png)|
|丹羽氏勝|officer_q11368644|77|独自創作|[niwa_ujikatsu_history_modern_v1.png](../assets/officers/portraits/niwa_ujikatsu_history_modern_v1.png)|
|丹羽長秀|officer_q2900560|94|歴史資料|[niwa_nagahide_history_modern_v1.png](../assets/officers/portraits/niwa_nagahide_history_modern_v1.png)|
|乃美宗勝|officer_q7048552|81|歴史資料|[nomi_munekatsu_history_modern_v1.png](../assets/officers/portraits/nomi_munekatsu_history_modern_v1.png)|
|乃美景継|officer_q123415143|68|独自創作|[nomi_kagetsugu_history_modern_v1.png](../assets/officers/portraits/nomi_kagetsugu_history_modern_v1.png)|
|乃美景興|officer_q123415134|60|独自創作|[nomi_kageoki_history_modern_v1.png](../assets/officers/portraits/nomi_kageoki_history_modern_v1.png)|
|久松俊勝|officer_q11369424|70|独自創作|[hisamatsu_toshikatsu_history_modern_v1.png](../assets/officers/portraits/hisamatsu_toshikatsu_history_modern_v1.png)|
|久松定益|officer_q114590862|73|独自創作|[hisamatsu_sadamasu_history_modern_v1.png](../assets/officers/portraits/hisamatsu_sadamasu_history_modern_v1.png)|

## 調査・採用特徴・プロンプト

各人の検索語、出典URL、補助調査先、利用条件、採用特徴、推定・創作区分、全プロンプト、生成原本、完成寸法・アルファ・SHA256は[制作マニフェスト](portraits_history_modern_20261002_55.json)に記録。各完成PNGの隣に.prompt.txtも保存。

[配布用出典](../assets/officers/portraits/ATTRIBUTION.txt)をゲームのPCKに含める。京都大学総合博物館所蔵の上杉謙信像(模本)は京都大学貴重資料デジタルアーカイブの再利用条件に従い、所蔵・URL・再構成した変更を明記。史料参照画像そのものはリリースの対象外。

## 検証

- 55枚すべて512×512 RGBA、アルファ0〜255、固有IDと画像パス、制作マニフェストのSHA256一致を確認。
- GPU描画で全55名の一覧アイコンと詳細肖像を確認。上杉謙信・丹羽長秀の実画面キャプチャも目視確認。
- Windows配布PCKを配布フォルダーから読み込み、55名の対応と出典TXTの収録、参照画像8枚の除外を確認。
- 既存50名の肖像と、撤回済み310素材パスの非存在を開発側・配布PCK側の両方で確認。新規の独立制作画像のみを再登録。
- Windowsリリース書き出しと実行ファイルの起動は終了コード0。配布用出典TXTを実行ファイルの隣にも配置。
- 起動時に環境由来の証明書・診断ログ書き込みの警告があるが、肖像表示の検証は成功。

配布パックの検証では、プロジェクトの参照ファイルをフォールバック読み込みしないよう、配布フォルダーを作業ディレクトリとして使用。

[検証記録とビルド情報](PORTRAITS_HISTORY55_VALIDATION_20261003.json) / [55名の表示一覧](OFFICER_PORTRAITS_HISTORY55_20261003.html)
