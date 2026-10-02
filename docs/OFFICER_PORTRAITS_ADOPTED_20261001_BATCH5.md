# 三枝昌貞ほか10名の肖像・正式採用記録

2026-10-01（日本時間）。組み込みimagegenで1名ずつ制作した写実的な西洋油彩の胸像。日本人の顔と日本の衣服を描き、西洋風にするのは技法のみ。史料から使うのは顔・髪・髭と服装だけとし、構図・姿勢・背景・伝統絵画の身体比率は写していない。

全10枚は1254×1254pxのRGBA透過PNG（アルファ0〜255）。文字・枠・透かしなし。生成結果を個別に目視し、頭・首・肩の比率、髪の収まり、表情と衣装を確認した。胸像の胴と袖は画像の下端で切れる。正式採用先は `scripts/game/officer_portraits.gd`。

完成PNGと同名の `.prompt.txt` を `assets/officers/portraits/` に保存。人物ID・採用パス・能力値・寸法・プロンプト全文・参照画像は `docs/portraits_adopted_20261001_batch5.json` に記録。生成元はCodexのgenerated_imagesに保持し、完成画像をプロジェクトへコピーした。

## 能力値と完成ファイル

制作時の `data/derived/officers/officers_1546.json` の5能力合計150点満点を使用。高能力演出の制作目安は120以上、今回は全員120未満。控えめな表情・姿勢と柔らかな光を基本とし、創作9名には地味な無地の衣服を指定した。ゲーム能力値は変更していない。

| 人物 | 合計 | 完成PNG | 外見の根拠 |
|---|---:|---|---|
| 三枝昌貞 | 71 | saegusa_masasada_oil_v2.png | 後世の武田二十四将図 |
| 三枝虎吉 | 74 | saegusa_torayoshi_oil_v2.png | 創作 |
| 三沢為清 | 86 | misawa_tamekiyo_oil_v2.png | 創作 |
| 三浦義就 | 70 | miura_yoshinari_oil_v2.png | 創作 |
| 三浦貞久 | 64 | miura_sadahisa_oil_v2.png | 創作 |
| 三浦貞勝 | 44 | miura_sadakatsu_oil_v2.png | 創作 |
| 三浦貞広 | 75 | miura_sadahiro_oil_v2.png | 創作 |
| 三浦貞盛 | 69 | miura_sadamori_oil_v2.png | 創作 |
| 三浦高救 | 57 | miura_takasuke_oil_v2.png | 創作 |
| 三淵晴員 | 69 | mitsubuchi_harukazu_oil_v2.png | 創作 |

## 三枝昌貞の参照

[長野市「三枝勘解由左衛門尉守友」](https://kawanakajima.nagano.jp/character/saegusa-moritomo/)の公開図版を使用した。同ページで守友と宗四郎昌貞の同定を確認。[長野市の武田方一覧](https://kawanakajima.nagano.jp/character/category/co-takeda/)は恵林寺所蔵「二十四将図」に準じると説明している。史料としての人物画を使ったが、本人の容貌の確定的復元ではない。

公開画像を `references/saegusa_moritomo_nagano.png` に保存し、実見して生成ツールへ渡した。原画像は364×398px。参照の用途は、太い眉と髭のない顔、後退した額と黒い結髪、緑の柄入り袖、赤い縁と金色の金具、白い威糸の肩部、灰色の金属的な胸部だけ。甲冑の広がりを実際の肩幅と混同せず、身体と頭の比率は写実的に構成した。文字、武器、他の武将、背景、元図の姿勢は採用していない。生成では顔の向きがプロンプト指定と逆になったが、自由な胸像ポーズとして採用した。

公開個別ページに図の作者・制作年が記載されていないため、原画の年代・作者は今回の公式情報だけでは未確定。[上田市デジタルアーカイブ「武田二十四将図」](https://museum.umic.jp/sanada/siryo/sandai/030103.html)の説明も、この種の図が江戸期の軍記普及に伴う後世の表現であることの補助確認に使った。上田市の別図の衣服や顔は生成へ混ぜていない。Commonsには松本楓湖・1861年の三枝像として類似画像の登録があるが、そのメタデータだけで今回の公開図の原画を確定していない。

[上田市「三枝昌貞起請文」](https://museum.umic.jp/ikushima/kishomon/03-saigusa.html)は文書資料であり、顔・衣装の画像の根拠にしていない。三枝昌貞の図を父の虎吉へ転用していない。

## 他9名の調査と創作

各人名を引用符で囲み「肖像」を付けた検索を実施した。今回採用できる、本人の顔と衣装を出所の確認できる画像で示した資料を確保できなかった。肖像が存在しないとは断定しない。

- 三枝虎吉：個別検索と三枝家の資料を探索。子の昌貞の肖像を転用せず創作。
- 三沢為清：[島根県「古代文化研究第30号」の公開論文](https://www.pref.shimane.lg.jp/bunkazai/kodai/library/publications/kiyou/index.data/kodai30_13.pdf)に為清の名を記した棟札があるが、外見を示す資料ではない。
- 三浦義就：個別検索で史書・家紋素材・ゲーム画像などが見つかったが、本人の顔や衣装の史料にしなかった。
- 三浦貞久・貞勝・貞広・貞盛：[真庭市公開資料](https://www.city.maniwa.lg.jp/uploaded/life/57188_191390_misc.pdf)の貞勝人物画は「想像図」と明記される現代の描写であり、外見の根拠として採用しない。[真庭市「阿波土居跡」報告書](https://sitereports.nabunken.go.jp/files/attach/42/42801/94695_1_%E9%98%BF%E6%B3%A2%E5%9C%9F%E5%B1%85%E8%B7%A1.pdf)や[石見の資料目録](https://ikr031.i-kyushu.or.jp/archives/collection/pdf/mokuroku_1996_14.pdf)も文書・史跡情報であり、肖像の顔・衣装の根拠にしていない。
- 三浦高救：[横須賀市「三浦一族の歴史」](https://www.city.yokosuka.kanagawa.jp/2120/culture_info/miura_ichizoku/outline4.html)に名の記録があるが、本人の外見は確認できない。三浦義同・義明など別人の肖像は使わない。
- 三淵晴員：高桐院所蔵「三淵晴員像」があるという書誌案内・二次資料が検索で見つかった。一方、所蔵者や研究機関の公開画像と作品解説を今回確保できず、外見の参照は行っていない。肖像がないという判断ではない。細川藤孝・玉甫紹琮など別人の肖像を転用せず創作した。

この9名の顔、髪型、髭、服装、年齢表現は制作上の創作。年齢指定は虎吉60、為清50、義就45、貞久55、貞勝22、貞広30、貞盛55、高救60、晴員60歳前後。1546年時点の年齢を再現した画像ではない。プロンプトにも個人の容貌・衣装の復元ではないと明記した。参考画像はWindows書き出しから除外される。

## 検証

- PNGの寸法・RGBA・透明アルファを全10枚で確認。
- `tests/officers/godot/test_adopted_portraits_20261001_batch5.gd` で、人物ID・名前・採用パス、画像読み込み、一覧アイコンと詳細肖像を全件確認。`ADOPTED_PORTRAITS_10_OK`、終了コード0。
- 実描画による全10画面を `builds/qa/portraits_20261001_batch5/` に保存。昌貞・貞勝の画面で透過、顔、衣装、表示の収まりを目視確認。
- `tools/export_windows_release.py` のWindowsリリース書き出しは終了コード0。EXE109127680バイト、PCK2050675120バイト。時刻・SHA256は `builds/windows-latest/export_report.json`。
- 書き出したPCKによる同じ全10名の読み込み・UI検証も成功。記録は `builds/windows-latest/portrait_batch5_pack_test.log`。
- `builds/windows-latest/MyWorldsOnFreedom.exe` をOpenGLで起動し120フレーム後に終了コード0。記録は `builds/windows-latest/portrait_batch5_launch.log`。

環境上の制限によるWindows証明書ストア読み取り、ユーザーディレクトリへの診断ログ・エディタ設定保存のエラーは残る。画像の読み込み・描画、Windows書き出しとEXE起動は成功した。既存の意図的な肖像削除や他の作業変更は保持した。

