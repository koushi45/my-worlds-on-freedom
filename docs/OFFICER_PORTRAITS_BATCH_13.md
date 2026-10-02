> 2026-10-02：商用ゲーム画像を参照した旧素材は使用を取り消し、該当する実ファイル・キャッシュ・ゲーム登録を削除した。この文書は過去の制作経緯の記録であり、再生成・再採用の指示ではない。対象：`godai_tomoyoshi.png`, `ii_naohira.png`, `ii_naokatsu.png`, `ii_naomasa.png`, `ii_naotaka.png`, `inoue_arikage.png`, `inoue_daikuro.png`, `inoue_motokichi.png`, `inoue_nariari.png`, `inoue_yukifusa.png`。独立に作り直した `_oil_` 版の採用記録は別文書を参照。

# Officer portraits, batch 13

Ten individual modern strategy-game bust icons were generated with the built-in ImageGen tool, one call per officer. Each call used a web-searched picture as **Image 1, the primary design reference**, and `assets/officers/portraits/oda_nobunaga.png` as **Image 2, rendering-style reference only**. The facial proportions, apparent age, headgear, clothing structure, palette and gaze were directed by Image 1. Hands and weapons were cropped out. Output is square transparent PNG without text, scenery or a frame.

Historical portraits and the woodblock print below establish visual design, not a verified lifetime likeness. The five game-face proxies marked **different person** must not be presented as portraits of the named officer: no usable historical or exact-person game picture was verified in this search. Source images were used as references and are not bundled with the game.

| Officer | Registry ID | PNG | Web-searched primary source | Individual anchors |
| --- | --- | --- | --- | --- |
| 五代友喜 | `officer_q11372012` | `godai_tomoyoshi.png` | [Shimazu Yoshihiro game face](https://altema.jp/nobunagashinsei/busyo/1066), **different person** | Red armor, large sculptural crescent crest, mature lined face. |
| 井上之房 | `officer_q11372815` | `inoue_yukifusa.png` | [Inoue Yukifusa historical portrait](https://commons.wikimedia.org/wiki/File:Inoue_Yukihusa.jpg) | Small pale face, black double-winged helmet, copper-toned shoulder armor. |
| 井上元吉 | `officer_q30936868` | `inoue_motokichi.png` | [Inoue Motokane game face](https://altema.jp/nobunagashinsei/busyo/291), **different person** | Older mustached face, ochre and red clothing, thoughtful gaze. |
| 井上大九郎 | `officer_q57446929` | `inoue_daikuro.png` | [Inoue Daikuro woodblock depiction](https://ja.ukiyo-e.org/image/metro/5264-010-060) | Broad theatrical face, heavy brows, topknot, blue-purple garment and checked green fabric. This is a later artistic depiction. |
| 井上就在 | `officer_q30936452` | `inoue_nariari.png` | [Inoue Shigefusa game face](https://altema.jp/nobunagashinsei/busyo/290), **different person** | Lean young face, compact black helmet, layered dark armor. |
| 井上有景 | `officer_q30936910` | `inoue_arikage.png` | [Mori Takamoto game face](https://altema.jp/nobunagashinsei/busyo/2012), **different person** | Black eboshi, purple formal robe, composed narrow face. |
| 井伊直勝 | `officer_q5994900` | `ii_naokatsu.png` | [Ii Naokatsu game face](https://altema.jp/nobunagashinsei/busyo/167), exact-name | Youthful rounded face, topknot, restrained brown robe. |
| 井伊直孝 | `officer_q877175` | `ii_naotaka.png` | [Ii Naotaka historical portrait](https://commons.wikimedia.org/wiki/File:Ii_Naotaka01.jpg) | Broad mature face, black patterned formal robe, tall eboshi with trailing streamer. |
| 井伊直平 | `officer_q22123202` | `ii_naohira.png` | [Ii Naomori game face](https://altema.jp/nobunagashinsei/busyo/172), **different person** | Elderly face, black helmet, maroon armor. |
| 井伊直政 | `officer_q1334437` | `ii_naomasa.png` | [Ii Naomasa historical portrait](https://commons.wikimedia.org/wiki/File:Ii_Naomasa.jpg); [Hikone Castle Museum](https://hikone-castle-museum.jp/collection/342.html) | Slim pale face, fine mustache, wide black court robe and distinctive cap. |

Shared prompt set: `Use case: stylized-concept. Asset type: modern premium Sengoku strategy-game officer bust. Image 1 is the PRIMARY individual identity and design reference; preserve face geometry, age, headwear, garment, palette, expression and gaze. For game banners, use only the central depicted person; for prints, use the depicted person, not the setting. Image 2 is style only. Give every officer a distinct, anatomically coherent head, neck and shoulders. Crop at the chest: no hands, fingers or weapons. Square 1:1; actual alpha-transparent PNG; no lettering, UI, scenery or frame.` Each call added the row-specific anchors and reference status. Generation mode: built-in ImageGen with two referenced local images per call.
