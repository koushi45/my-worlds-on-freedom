> 2026-10-02：商用ゲーム画像を参照した旧素材は使用を取り消し、該当する実ファイル・キャッシュ・ゲーム登録を削除した。この文書は過去の制作経緯の記録であり、再生成・再採用の指示ではない。対象：`hisamatsu_sadamasu.png`, `hisamatsu_toshikatsu.png`, `kuno_muneyoshi.png`, `kunohe_masazane.png`, `kunohe_sanechika.png`, `nomi_kageoki.png`, `nomi_kagetsugu.png`, `otobe_hachibe.png`。独立に作り直した `_oil_` 版の採用記録は別文書を参照。

# Officer portraits, batch 11

Ten modern game bust portraits were generated with built-in ImageGen, one call per officer. Each call supplied the web-searched source as Image 1 and the project's `assets/officers/portraits/oda_nobunaga.png` as Image 2 (style only). For game banners, only the central character face was used; banner lettering and interface were explicitly excluded. Reference downloads were not copied into the game.

Historical portraits are later depictions, not verified lifetime likenesses. When no portrait or exact-name game face was located, a **different named game officer** was deliberately used as a disclosed design proxy—not a purported depiction of the requested officer.

| Officer | Registry ID | Output PNG | Source and status | Individual anchors |
| --- | --- | --- | --- | --- |
| 乃美宗勝 | `officer_q7048552` | `nomi_munekatsu.png` | [Shōunji collection portrait](https://commons.wikimedia.org/wiki/File:Nomimunekatu01.jpg), historical depiction | Elderly pale bald face, black broad-shouldered lamellar armor, white under-robe. |
| 乃美景継 | `officer_q123415143` | `nomi_kagetsugu.png` | [Nomi Takaoki game face](https://altema.jp/nobunagashinsei/busyo/1604), **different-person fallback** | Loose dark hair, narrow angular face, pointed beard, blue coat and gold/red lapels. |
| 乃美景興 | `officer_q123415134` | `nomi_kageoki.png` | [Nomi Kageoki game face](https://altema.jp/nobunagashinsei/busyo/1603), exact-name | Young clean-shaven face, high topknot, brown robe, navy collar, sideways gaze. |
| 久松俊勝 | `officer_q11369424` | `hisamatsu_toshikatsu.png` | [Matsudaira Hirotada game face](https://altema.jp/nobunagashinsei/busyo/1892), **different-person fallback** | Sharp eyes, slender moustache, tall topknot, deep green robe and pale collar. |
| 久松定益 | `officer_q114590862` | `hisamatsu_sadamasu.png` | [Mizuno Nobumoto game face](https://altema.jp/nobunagashinsei/busyo/1934), **different-person fallback** | Square young face, thick brows, high knot, moss green robe and blue inner collar. |
| 久野宗能 | `officer_q22127318` | `kuno_muneyoshi.png` | [久能宗能 game face](https://altema.jp/nobunagashinsei/busyo/793), same-person variant spelling | Broad face, crescent kabuto, teal cords, green armor. |
| 乙部八兵衛 | `officer_q124483506` | `otobe_hachibe.png` | [Matsudaira Nobuyasu game face](https://altema.jp/nobunagashinsei/busyo/1890), **different-person fallback** | Square rugged face, thick brows, high knot, red armor, pale collar. |
| 九戸実親 | `officer_q10878858` | `kunohe_sanechika.png` | [Kunohe Sanechika game face](https://altema.jp/nobunagashinsei/busyo/794), exact-name | Narrow older face, wiry moustache, high knot, beige outer and teal inner robe. |
| 九戸政実 | `officer_q10878859` | `kunohe_masazane.png` | [Kunohe Masazane game face](https://altema.jp/nobunagashinsei/busyo/796), exact-name | Broad shouting face, beard, maroon helmet, round gold crest, red armor. |
| 九鬼嘉隆 | `officer_q921113` | `kuki_yoshitaka.png` | [Jōanji collection portrait](https://commons.wikimedia.org/wiki/File:Kukiyoshitaka2.jpg), historical depiction | Half-closed eyes, small pale face, tall black court cap and voluminous black robe. |

Shared prompt set: `Modern premium strategy-game Sengoku officer bust. Image 1 is primary for facial geometry, age, gaze, pose, hair/headgear, clothing structure and palette; Image 2 only determines a consistent polished painterly finish. Preserve each row's unique anchors. Use only the central officer in a game banner, or only the person in a hanging scroll, omitting UI and writing. Align head, neck and shoulders naturally. Crop above hands and weapons. One square 1:1 true-transparent PNG, no background, frame, halo, text or characters of any script.` The actual calls expanded this with the officer-specific anchors and source status above.
