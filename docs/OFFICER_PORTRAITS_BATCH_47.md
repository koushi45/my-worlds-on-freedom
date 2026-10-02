> 2026-10-02：商用ゲーム画像を参照した旧素材は使用を取り消し、該当する実ファイル・キャッシュ・ゲーム登録を削除した。この文書は過去の制作経緯の記録であり、再生成・再採用の指示ではない。対象：`okawa_tadahide.png`, `omura_yoshiaki.png`, `ooka_tadakatsu.png`, `osaki_katsunaga.png`, `osaki_yoshinobu.png`, `otsuka_yagiuemon.png`, `oyama_hoki.png`, `oyama_mitsutaka.png`。独立に作り直した `_oil_` 版の採用記録は別文書を参照。

# 武将肖像・第47組

2026-09-30 制作。画像はいずれも正方形の背景透過 PNG。絵柄は現代的な写実表現で、画像内に文字は入れない。参照画像は調査・制作にのみ使用し、ゲームには同梱しない。

| 武将 | ゲーム画像 | ベースに調べた画像 | 反映範囲 |
| --- | --- | --- | --- |
| 大塚八木右衛門 | `otsuka_yagiuemon.png` | [一条兼定・ゲーム画像](https://altema.jp/nobunagashinsei/busyo/243) | 同時代・土佐勢の装束のみ。本人の顔は未確認のため創作。 |
| 大山伯耆 | `oyama_hoki.png` | [石田三成・ゲーム画像](https://altema.jp/nobunagashinsei/busyo/219) | 石田方の装束のみ。本人の顔は未確認のため創作。 |
| 大山光隆 | `oyama_mitsutaka.png` | [最上義光・ゲーム画像](https://altema.jp/nobunagashinsei/busyo/2020) | 最上家の装束のみ。本人の顔は未確認のため創作。 |
| 大岡忠勝 | `ooka_tadakatsu.png` | [徳川家康・ゲーム画像](https://altema.jp/nobunagashinsei/busyo/1394) | 徳川家臣の装束のみ。本人の顔は未確認のため創作。 |
| 大島光朝 | `oshima_mitsutomo.png` | [父・大島光義の肖像画](https://commons.wikimedia.org/wiki/File:Oshima_Mitsuyoshi.jpg) | 白い装束の方向性のみ。本人の顔は未確認のため創作。 |
| 大島光義 | `oshima_mitsuyoshi.png` | [本人の肖像画](https://commons.wikimedia.org/wiki/File:Oshima_Mitsuyoshi.jpg) | 高齢の風貌と白い衣装を参考に、現代的な写実画へ再構成。 |
| 大崎勝長 | `osaki_katsunaga.png` | [大崎義隆・ゲーム画像](https://altema.jp/nobunagashinsei/busyo/437) | 大崎家の装束のみ。本人の顔は未確認のため創作。 |
| 大崎義宣 | `osaki_yoshinobu.png` | [本人のゲーム画像](https://altema.jp/nobunagashinsei/busyo/439) | 若い風貌、髪型、紫系の装束を参考に再構成。 |
| 大川忠秀 | `okawa_tadahide.png` | [上杉謙信・ゲーム画像](https://altema.jp/nobunagashinsei/busyo/325) | 越後上杉家の装束のみ。本人の顔は未確認のため創作。 |
| 大村喜前 | `omura_yoshiaki.png` | [本人のゲーム画像](https://altema.jp/nobunagashinsei/busyo/488) | 若い風貌、髪型、緑系の装束を参考に再構成。 |

共通生成指示: 「参照した人物・装束の特徴を確認したうえで、現代のリアルなゲーム肖像として新規制作。胸上構図、各人で異なる顔立ちと視線、正方形、完全な透明背景、文字・ロゴ・枠・手を描かない」。参照が他人の画像の場合は顔立ちを転写しない。生成には組み込み ImageGen を用いた。

ゲームでの割り当ては `scripts/game/officer_portraits.gd` に記録。画像は `assets/officers/portraits/` に配置。
