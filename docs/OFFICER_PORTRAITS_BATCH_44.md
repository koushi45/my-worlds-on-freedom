> 2026-10-02：商用ゲーム画像を参照した旧素材は使用を取り消し、該当する実ファイル・キャッシュ・ゲーム登録を削除した。この文書は過去の制作経緯の記録であり、再生成・再採用の指示ではない。対象：`oi_nobutame.png`, `okubo_nagayasu.png`, `okubo_noritaka.png`, `okubo_tadachika.png`, `okubo_tadahisa.png`, `okubo_tadakazu.png`, `okubo_tadashige.png`, `okubo_tadataka.png`, `okubo_tadatame.png`。独立に作り直した `_oil_` 版の採用記録は別文書を参照。

# Officer portraits, batch 44

Ten original, separate 1254 × 1254 RGBA transparent PNG officer portraits were generated with the built-in image-generation tool. All are modern realistic busts without image text, scenery, frames, or visible hands. Each named game image was searched and inspected before generation. The source images themselves are not shipped with the game.

| Officer | Game asset | Reference and identity status |
| --- | --- | --- |
| 大久保忠員 | `okubo_tadakazu.png` | [本人名義の『信長の野望・新生』画像](https://altema.jp/nobunagashinsei/busyo/429); specific face and armor referenced |
| 大久保忠教 | `okubo_tadataka.png` | [本人名義の『信長の野望・新生』画像](https://altema.jp/nobunagashinsei/busyo/431); face, hairline, robe referenced |
| 大久保忠為 | `okubo_tadatame.png` | No verified named portrait found. Original interpretive face; [忠員のゲーム画像](https://altema.jp/nobunagashinsei/busyo/429) used for family-period costume materials only |
| 大久保忠舊 | `okubo_tadahisa.png` | No verified named portrait found. Original interpretive face; [忠隣のゲーム画像](https://altema.jp/nobunagashinsei/busyo/432) used for period robe materials only |
| 大久保忠重 | `okubo_tadashige.png` | No verified named portrait found. Original interpretive face; [長安のゲーム画像](https://altema.jp/nobunagashinsei/busyo/435) used for period dress style only |
| 大久保忠隣 | `okubo_tadachika.png` | [本人名義の『信長の野望・新生』画像](https://altema.jp/nobunagashinsei/busyo/432); specific face and robe referenced |
| 大久保教隆 | `okubo_noritaka.png` | No verified named portrait found. Original interpretive face; [忠教のゲーム画像](https://altema.jp/nobunagashinsei/busyo/431) used for period formal dress only |
| 大久保長安 | `okubo_nagayasu.png` | [本人名義の『信長の野望・新生』画像](https://altema.jp/nobunagashinsei/busyo/435); face, hair and costume referenced |
| 大井信広 | `oi_nobuhiro.png` | No verified named portrait found. Original interpretive face; [信為の登録武将画像](https://note.com/deejay_sengoku/n/nb1b7297653e8) used only for family-period armor materials; no shared helmet or crest |
| 大井信為 | `oi_nobutame.png` | [本人名義の現代的な登録武将画像](https://note.com/deejay_sengoku/n/nb1b7297653e8); fan-created game portrait, not a historical likeness; face and armor referenced |

Prompt set: each portrait was requested as a single distinct modern realistic cinematic Sengoku bust, square transparent PNG, person-specific reference features retained where available, no old-picture style, text, backdrop, hands, or watermark. For the five interpretive portraits, prompts explicitly limited their reference image to clothing and required an original face. 大井信広 was regenerated after visual inspection because the first draft resembled 大井信為's helmet and armor too closely; the selected version is bareheaded with different costume and face.

All ten final files were visually inspected. Every file is square RGBA with a transparent upper-left pixel; the identity lookup in `scripts/game/officer_portraits.gd` maps each requested officer to exactly one file.
