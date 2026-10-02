# 三宅康貞ほか10名の肖像・正式採用記録

2026-09-30。組み込みimagegenで1名ずつ制作した写実的な西洋油彩の胸像。西洋風にするのは描画技法のみとし、日本人の顔と日本の衣服を描いた。史料から使用できるのは顔・髪・髭と服装だけで、伝統絵画の姿勢・背景・身体比率は模倣しない。今回の10名は本人の外見を確認できる史料画像を採用できなかったため、肖像AGENTS.mdの資料未確認時の創作ルールを適用した。本人の容貌や衣装の確定的復元ではない。

全10枚は1254×1254pxのRGBA透過PNG（アルファ0〜255）。文字・枠・透かしなし。生成結果を個別に目視し、自然な頭・首・肩の比率、髪の収まり、衣装と表情を確認した。頭頂と肩上部には透明余白を設け、胴と袖は胸像の下端で切れる。

正式採用先は `scripts/game/officer_portraits.gd`。完成PNGと同名の `.prompt.txt` を `assets/officers/portraits/` に保存した。人物ID・パス・能力値・プロンプト全文・寸法は `docs/portraits_adopted_20260930_batch4.json` に記録。生成元はCodexのgenerated_imagesに保持し、採用ファイルをプロジェクトへコピーした。

## 能力値と完成ファイル

制作時の `data/derived/officers/officers_1546.json` の5能力合計150点満点を使用。高能力演出の制作目安は120点以上で、今回は全員が120未満。普通の顔立ち、無地の落ち着いた衣装、控えめな姿勢と柔らかな光で制作した。ゲームの能力値は変更していない。

| 人物 | 合計 | 完成PNG | 外見の根拠 |
|---|---:|---|---|
| 三宅康貞 | 79 | miyake_yasusada_oil_v2.png | 創作 |
| 三宅正次 | 66 | miyake_masatsugu_oil_v2.png | 創作 |
| 三宅総広 | 66 | miyake_fusahiro_oil_v2.png | 創作 |
| 三戸景道 | 73 | mito_kagemichi_oil_v2.png | 創作 |
| 三木国綱 | 54 | miki_kunitsuna_oil_v2.png | 創作 |
| 三木清閑 | 71 | miki_seikan_oil_v2.png | 創作 |
| 三木直頼 | 73 | miki_naoyori_oil_v2.png | 創作 |
| 三木通秋 | 70 | miki_michiaki_oil_v2.png | 創作 |
| 三木顕綱 | 77 | miki_akitsuna_oil_v2.png | 創作 |
| 三村家親 | 83 | mimura_iechika_oil_v2.png | 創作 |

## 調査と創作の区別

全10名について、各人名を引用符で囲み「肖像」を付けた検索を実施。自治体・博物館の資料を追加探索したが、今回採用できる、本人と出所が確認できる顔・衣装画像を確保できなかった。肖像が存在しないとは断定しない。別人の肖像、現代の人物写真、ゲーム・生成イラストを外見の根拠に使用していない。

- 三宅康貞・正次・総広：個別の肖像検索と、康貞について田原市公式サイトを対象にした検索を実施した。
- 三戸景道：個人名の肖像検索を実施。本人の外見に使用できる画像は採用しなかった。
- 三木国綱・清閑・直頼・通秋・顕綱：各人の肖像検索と岐阜の博物館資料を探索。[岐阜県博物館・館報第8号（昭和60年度）](https://www.gifu-kenpaku.jp/wp-content/uploads/2022/09/%E5%B2%90%E9%98%9C%E7%9C%8C%E5%8D%9A%E7%89%A9%E9%A4%A8_%E9%A4%A8%E5%A0%B1%E7%AC%AC8%E5%8F%B7_%E6%98%AD%E5%92%8C60%E5%B9%B4%E5%BA%A6%EF%BC%881985%EF%BC%89.pdf)の検索結果には三木直頼寄進の梵鐘があるが、本人の容貌を示すものではない。別人の肖像項目は転用しない。
- 三村家親：肖像検索と高梁市の公式資料を探索。[三村氏居館跡](https://www.city.takahashi.lg.jp/bunkazai/map/0147.html)と[高梁市歴史的風致維持向上計画](https://www.city.takahashi.lg.jp/uploaded/attachment/19844.pdf)は史跡・歴史の情報であり、今回の顔や衣装の出典としていない。

全員の顔、髪型、髭、服装と年齢表現は創作。清閑という名から剃髪や僧衣を史実と推定せず、通常の髪と衣服にした。年齢指定は制作上の選択として、康貞55、正次40、総広50、景道50、国綱45、清閑65、直頼55、通秋45、顕綱35、家親55歳前後。1546年時点の年齢を描いた画像ではない。個人の復元ではない旨は各生成プロンプトにも明記した。

## 検証結果

- PNGの寸法、RGBA形式、透明・不透明アルファを全10枚で確認。
- `tests/officers/godot/test_adopted_portraits_20260930_batch4.gd` で人物ID・表示名・採用パス・読み込み、武将一覧アイコンと詳細肖像を全10名確認。`ADOPTED_PORTRAITS_10_OK`、終了コード0。
- 実描画による全10画面を `builds/qa/portraits_20260930_batch4/` に保存。康貞・清閑の画面で透過・顔・衣装・収まりを目視確認。
- `tools/export_windows_release.py` によるWindowsリリース書き出しは終了コード0。EXE109127680バイト、PCK2037732020バイト。書き出し時刻・SHA256は `builds/windows-latest/export_report.json`。
- 書き出したPCKを使い同じ全10名の読み込み・UI検証に成功。記録は `builds/windows-latest/portrait_batch4_pack_test.log`。
- 書き出した `builds/windows-latest/MyWorldsOnFreedom.exe` をOpenGLで起動し、120フレーム後に終了コード0。記録は `builds/windows-latest/portrait_batch4_launch.log`。

環境上の制限によりWindows証明書ストア読み取り、ユーザーディレクトリへの診断ログとエディタ設定保存のエラーが残る。肖像の読み込み・描画、書き出しとEXE起動は成功した。既存の意図的な肖像削除や他の作業内容は保持した。

