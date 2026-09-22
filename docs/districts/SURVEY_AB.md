# 郡台帳：工程A・B 初回調査

版：district-survey-ab-2026-09-12-v1

現行の全66親領域を固定し、全親領域の郡候補一覧を一巡した。比較一覧697件＋別資料の追加候補10件、計707項目。対応先は史料調査用の61国。

**工程Aの入力・対象一覧と工程Bの初回候補台帳は作成済み。1582年の郡の確定・位置合わせ・郡境作成は未実施。**

後世比較一覧を入口にしており、中世に存在し後世に消えた郡は今後追加が必要。一覧の件数を1582年の全国郡数とはしない。

## 台帳

- [対象・進捗](../../data/editorial/districts/scope.json)
- [入力版とSHA-256](../../data/editorial/districts/input_lock.json)
- [現行親領域と史料上の国の対応](../../data/editorial/districts/province_mapping.json)
- [郡候補と判断根拠](../../data/editorial/districts/districts.json)
- [資料・参照箇所・利用条件](../../data/editorial/districts/sources.json)
- [読みやすい資料一覧](SOURCES.md)
- [個別の照合・判断記録](../../data/editorial/districts/review_decisions.json)
- [全親領域の調査記録](../../data/editorial/districts/country_reviews.json)
- [未収録国・親領域外の陸地](../../data/editorial/districts/backlog.json)
- [整合検査](../../data/editorial/districts/qa.json)

## 対応の読み方

国IDの結合は既存IDごとの明示対応表。各面の座標・隣接領域・内包拠点と、比較資料の府県・国ID関係を併記した。名称一致だけの結合ではない。対応は暫定であり、外部と現行の境界一致を意味しない。

東北7親領域は、分割前陸奥・出羽の調査IDへ対応させた。郡候補の親IDは調査の振り分け先であり、郡の全域がその親に収まると決めたものではない。同名郡・表示断片は史料照合まで統合しない。

## 国別一覧

|現行名・詳細|親ID|史料上の国（暫定）|候補数|初回の根拠|
|---|---|---|---:|---|
|[筑前国](countries/chikuzen.md)|`chikuzen`|筑前国|15|後世資料のみ|
|[豊前国](countries/buzen.md)|`buzen`|豊前国|8|後世資料のみ|
|[肥前国](countries/hizen.md)|`hizen`|肥前国|16|後世資料のみ|
|[筑後国](countries/chikugo.md)|`chikugo`|筑後国|10|後世資料のみ|
|[豊後国](countries/bungo.md)|`bungo`|豊後国|10|後世資料のみ|
|[肥後国](countries/higo.md)|`higo`|肥後国|15|後世資料のみ|
|[日向国](countries/hyuga.md)|`hyuga`|日向国|10|後世資料のみ|
|[薩摩国](countries/satsuma.md)|`satsuma`|薩摩国|13|後世資料のみ|
|[大隅国](countries/osumi.md)|`osumi`|大隅国|11|後世資料のみ|
|[伊予国](countries/iyo.md)|`iyo`|伊予国|18|後世資料のみ|
|[讃岐国](countries/sanuki.md)|`sanuki`|讃岐国|14|比較資料＋個別照合（1582年未確定）|
|[土佐国](countries/tosa.md)|`tosa`|土佐国|7|後世資料のみ|
|[阿波国](countries/awa_shikoku.md)|`awa_shikoku`|阿波国|10|後世資料のみ|
|[長門国](countries/nagato.md)|`nagato`|長門国|6|後世資料のみ|
|[周防国](countries/suo.md)|`suo`|周防国|6|後世資料のみ|
|[石見国](countries/iwami.md)|`iwami`|石見国|6|後世資料のみ|
|[安芸国](countries/aki.md)|`aki`|安芸国|8|後世資料のみ|
|[備後国](countries/bingo.md)|`bingo`|備後国|14|後世資料のみ|
|[備中国](countries/bitchu.md)|`bitchu`|備中国|11|後世資料のみ|
|[出雲国](countries/izumo.md)|`izumo`|出雲国|10|後世資料のみ|
|[伯耆国](countries/hoki.md)|`hoki`|伯耆国|6|後世資料のみ|
|[因幡国](countries/inaba.md)|`inaba`|因幡国|8|後世資料のみ|
|[美作国](countries/mimasaka.md)|`mimasaka`|美作国|12|後世資料のみ|
|[備前国](countries/bizen.md)|`bizen`|備前国|8|後世資料のみ|
|[陸奥国](countries/honshu-area-01.md)|`honshu-area-01`|陸奥国|9|後世資料のみ|
|[羽後国](countries/honshu-area-03.md)|`honshu-area-03`|出羽国|9|後世資料のみ|
|[陸中国](countries/honshu-area-04.md)|`honshu-area-04`|陸奥国|18|後世資料のみ|
|[陸前国](countries/honshu-area-05.md)|`honshu-area-05`|陸奥国|14|後世資料のみ|
|[羽前国](countries/honshu-area-06.md)|`honshu-area-06`|出羽国|10|後世資料のみ|
|[越後国](countries/echigo.md)|`echigo`|越後国|15|後世資料のみ|
|[磐城国](countries/honshu-area-08.md)|`honshu-area-08`|陸奥国|14|後世資料のみ|
|[岩代国](countries/honshu-area-09.md)|`honshu-area-09`|陸奥国|10|後世資料のみ|
|[能登国](countries/noto.md)|`noto`|能登国|4|後世資料のみ|
|[下野国](countries/shimotsuke.md)|`shimotsuke`|下野国|9|後世資料のみ|
|[越中国](countries/etchu.md)|`etchu`|越中国|5|後世資料のみ|
|[常陸国](countries/hitachi.md)|`hitachi`|常陸国|12|後世資料のみ|
|[加賀国](countries/kaga.md)|`kaga`|加賀国|4|後世資料のみ|
|[信濃国](countries/shinano.md)|`shinano`|信濃国|22|比較資料＋個別照合（1582年未確定）|
|[飛騨国](countries/hida.md)|`hida`|飛騨国|3|後世資料のみ|
|[武蔵国](countries/musashi.md)|`musashi`|武蔵国|28|後世資料のみ|
|[越前国](countries/echizen.md)|`echizen`|越前国|8|後世資料のみ|
|[甲斐国](countries/kai.md)|`kai`|甲斐国|13|比較資料＋個別照合（1582年未確定）|
|[丹後国](countries/tango.md)|`tango`|丹後国|5|後世資料のみ|
|[美濃国](countries/mino.md)|`mino`|美濃国|22|後世資料のみ|
|[但馬国](countries/tajima.md)|`tajima`|但馬国|8|後世資料のみ|
|[上総国](countries/kazusa.md)|`kazusa`|上総国|9|後世資料のみ|
|[相模国](countries/sagami.md)|`sagami`|相模国|9|後世資料のみ|
|[近江国](countries/omi.md)|`omi`|近江国|13|後世資料のみ|
|[丹波国](countries/tanba.md)|`tanba`|丹波国|7|後世資料のみ|
|[駿河国](countries/suruga.md)|`suruga`|駿河国|6|後世資料のみ|
|[尾張国](countries/owari.md)|`owari`|尾張国|9|後世資料のみ|
|[安房国](countries/honshu-area-30.md)|`honshu-area-30`|安房国|4|後世資料のみ|
|[山城国](countries/yamashiro.md)|`yamashiro`|山城国|8|後世資料のみ|
|[播磨国](countries/harima.md)|`harima`|播磨国|16|後世資料のみ|
|[三河国](countries/mikawa.md)|`mikawa`|三河国|10|後世資料のみ|
|[遠江国](countries/totomi.md)|`totomi`|遠江国|12|後世資料のみ|
|[伊豆国](countries/izu.md)|`izu`|伊豆国|4|後世資料のみ|
|[伊賀国](countries/iga.md)|`iga`|伊賀国|4|後世資料のみ|
|[伊勢国](countries/ise.md)|`ise`|伊勢国|13|後世資料のみ|
|[河内国](countries/kawachi.md)|`kawachi`|河内国|16|比較資料＋個別照合（1582年未確定）|
|[大和国](countries/yamato.md)|`yamato`|大和国|15|比較資料＋個別照合（1582年未確定）|
|[紀伊国](countries/kii.md)|`kii`|紀伊国|10|後世資料のみ|
|[上野国](countries/kozuke.md)|`kozuke`|上野国|17|後世資料のみ|
|[下総国](countries/shimosa.md)|`shimosa`|下総国|15|後世資料のみ|
|[摂津国](countries/settsu.md)|`settsu`|摂津国|12|比較資料＋個別照合（1582年未確定）|
|[和泉国](countries/izumi.md)|`izumi`|和泉国|4|比較資料＋個別照合（1582年未確定）|

## 初回照合で反映した事項

- 甲斐：近代の9分郡は1582年の採用から除外し、分割前の山梨・八代・巨摩・都留を別候補に追加。[山梨県の解説](https://www.pref.yamanashi.jp/shigaku-kgk/10_035.html)
- 信濃：古い区分から伊那・筑摩・安曇・水内・高井・佐久の候補を追加。対象年までの継続は未確認。[長野市誌](https://adeac.jp/nagano-city/texthtml/d100150/ct00000011/ht000710)
- 大和：比較一覧の「宇蛇」を原表記として保持し、「宇陀郡」を編集上の優先候補にした。1585年の回顧記述と1582年の確認を区別。[宇陀市の歴史](https://www.city.uda.lg.jp/soshiki/41/1068.html)
- 讃岐：直島・塩飽島は区画種別未確認の地域項目として扱い、「郡」を自動付加しない。[旧郡一覧](https://geoshape.ex.nii.ac.jp/kg/resource/K60.html#gun-list)
- 和泉・河内・大和と摂津の大阪側：計42項目の名称を別の後世資料で照合。郡境の確定には使っていない。[大阪府公文書館](https://archives.pref.osaka.lg.jp/search/information.do?id=58&method=initPage)

国立公文書館の旧案内URLは取得失敗を記録した。和泉の元禄図は[個別ギャラリー](https://www.digital.archives.go.jp/gallery/0000000226)の本文と図版識別子を確認できたが、画像は未判読。日根荘の紹介も原文書への調査入口として扱い、荘園の範囲を郡境に転用していない。

## 残件

現行親IDとの対応がない国：志摩・若狭・佐渡・隠岐・淡路・壱岐・對馬。未収録として別管理し、隣国へ郡を押し込まない。

親領域の外に面積が残る正本陸地成分：152件。島の丸ごと未収録、北海道、本土沿岸の差分等を含み、件数を「島数」とは呼ばない。原本のfeature/part番号、座標、面積比から追跡できる。

全候補の成立・改称・分郡・合併・村郷所属は今後の年代補正対象。資料台帳に所在のみの史料を含む場合、取得失敗・個別文書未調査を明記した。

## 利用条件と保存範囲

HTMLと一覧項目を調査用に保存した。ポリゴン・地図タイル・史料画像は取得していない。CODH旧国旧郡ページの本文はCC BY-NCで、HTMLメタのCC BY表記と一致しないため本文側の制限を記録した。各出典の条件を相互に流用しない。

この調査台帳は既存export除外対象のdata/editorial、data/sources、docs以下に保存。実行時郡レジストリや配布版は作らない。

## 再確認

```powershell
python -X utf8 tools/prepare_district_ledgers.py check
python -X utf8 tools/prepare_district_ledgers.py report
```

`fetch`は取得済みHTMLのハッシュを確認して再利用する。`initialize`は編集台帳の存在時に停止し、追加の研究を上書きしない。入力が変わった場合は旧ハッシュを黙って更新せず、調査版を分ける。
