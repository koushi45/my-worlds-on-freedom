> 2026-10-02：商用ゲーム画像を参照した旧素材は使用を取り消し、該当する実ファイル・キャッシュ・ゲーム登録を削除した。この文書は過去の制作経緯の記録であり、再生成・再採用の指示ではない。対象：`date_hidemune.png`, `date_masamichi.png`, `date_sanemoto.png`。独立に作り直した `_oil_` 版の採用記録は別文書を参照。

# Officer portraits: Date clan batch 19

All ten final assets are square, transparent PNG cutouts under `assets/officers/portraits/`. They are newly generated modern realistic portraits, not reproductions of the reference art. Each exact-person source image was passed directly to image generation as the primary visual reference, except where no confirmed image was found. No letters or Japanese text were requested in the portraits. Hands were kept outside the crop.

| Officer | Asset | Primary visual reference | Treatment |
| --- | --- | --- | --- |
| 伊達定宗 | `date_sadamune.png` | None verified | Imaginative Date-clan reconstruction; no claim of historical likeness |
| 伊達実元 | `date_sanemoto.png` | [Nobunaga's Ambition: Shinsei image](https://altema.jp/nobunagashinsei/busyo/1266) | Face, topknot, olive robe |
| 伊達忠宗 | `date_tadamune.png` | [Historical portrait, Sendai City Museum](https://commons.wikimedia.org/wiki/File:Date_Tadamune.jpg) | Facial structure, black robes, court headgear |
| 伊達成実 | `date_shigezane.png` | [Historical portrait reproduction](https://sengoku-g.net/men/view/204); [Sendai City Museum catalog evidence](https://www.city.sendai.jp/museum/shisetsuannai/documents/nenpo46.pdf) | Armor and helmet silhouette |
| 伊達政宗 | `date_masamune.png` | [Historical portrait by Kanō Yasunobu](https://commons.wikimedia.org/wiki/File:Date_Masamune.jpg); [Sendai City Museum explanation](https://www.city.sendai.jp/museum/kidscorner/kids-08/kidscorner/kids-09.html) | Face, black formal robe, headgear; both eyes visible rather than a fictional eyepatch |
| 伊達政道 | `date_masamichi.png` | [Nobunaga's Ambition: Shinsei, listed as Kojirō](https://altema.jp/nobunagashinsei/busyo/1265); [name equivalence](https://senjp.com/masamichi/) | Face, tied hair, pale lavender robe |
| 伊達晴宗 | `date_harumune.png` | [Historical portrait, Sendai City Museum](https://commons.wikimedia.org/wiki/File:Date_Harumune.jpg) | Retired-ruler expression, pale hood, brown robe |
| 伊達秀宗 | `date_hidemune.png` | [Nobunaga's Ambition: Shinsei image](https://altema.jp/nobunagashinsei/busyo/1272) | Armor and crescent helmet |
| 伊達稙宗 | `date_tanemune.png` | [Historical portrait, Sendai City Museum](https://commons.wikimedia.org/wiki/File:Date_Tanemune.JPG) | Elderly face, beard, patterned robe |
| 伊達輝宗 | `date_terumune.png` | [Historical portrait, Sendai City Museum](https://commons.wikimedia.org/wiki/File:Date_Terumune.JPG) | Rounded face, white headcloth, green and red armor |

Generation mode: one fresh AI image-generation call per officer; nine image-conditioned on the specified exact-person reference, one text-conditioned reconstruction. Shared constraints: modern realistic rendering, transparent 1:1 PNG, no background/text, distinct face and pose, coherent anatomy. The reference images are not included in the game assets.
