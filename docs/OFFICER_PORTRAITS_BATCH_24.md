> 2026-10-02：商用ゲーム画像を参照した旧素材は使用を取り消し、該当する実ファイル・キャッシュ・ゲーム登録を削除した。この文書は過去の制作経緯の記録であり、再生成・再採用の指示ではない。対象：`naito_ienaga.png`, `naito_nobumasa.png`, `naito_nobunari.png`, `naito_tadaoki.png`, `uchida_sanehisa.png`。独立に作り直した `_oil_` 版の採用記録は別文書を参照。

# Officer portraits: batch 24

Ten individually generated, square transparent PNG busts are stored under `assets/officers/portraits/` and linked to the game's officer IDs in `scripts/game/officer_portraits.gd`. No source images are shipped with the game. Five exact-person modern game images were used as direct image inputs. For 信照, no exact-person modern game image was verified, so an authenticated historical portrait was supplied for features only, explicitly *not* as a style reference. The other four are imaginative reconstructions, not claimed likenesses.

| Officer | Final PNG | Source image directly supplied to generation | Visual cues carried over |
| --- | --- | --- | --- |
| 内田実久 | `uchida_sanehisa.png` | [Nobunaga's Ambition: Shinsei](https://altema.jp/nobunagashinsei/busyo/360) | High swept topknot, slender face and moustache, ochre robe over blue collar; source hand omitted |
| 内藤信成 | `naito_nobunari.png` | [Nobunaga's Ambition: Shinsei](https://altema.jp/nobunagashinsei/busyo/1449) | Ribbed black helmet with side flaps, red under-helmet tie, red-ochre armor |
| 内藤信正 | `naito_nobumasa.png` | [Nobunaga's Ambition: Shinsei](https://altema.jp/nobunagashinsei/busyo/1450) | Round helmet with central gold boss, moustache and goatee, dark armor and green collar |
| 内藤信照 | `naito_nobuteru.png` | [Actual historical portrait, Fujimoto Shrine](https://fujimotojinja.jp/shouzouga/) | Black formal cap, older narrow face, downturned eyes, dark red court robe; original painting technique not copied |
| 内藤元家 | `naito_motoie.png` | No verified exact-person image found | Imaginative older tactician in teal and black, profile view |
| 内藤元康 | `naito_motoyasu.png` | No verified exact-person image found | Imaginative scarred veteran with plain helmet and dark armor |
| 内藤元忠 | `naito_mototada.png` | No verified exact-person image found | Imaginative clean-shaven younger officer in blue-grey |
| 内藤家長 | `naito_ienaga.png` | [Nobunaga's Ambition: 20XX, exact-person figure](https://wikiwiki.jp/nobuyabo201x/%E6%AD%A6%E5%B0%86%E5%9B%B3%E9%91%91/%E5%BE%B3%E5%B7%9D%E5%AE%B6) | Indigo feathered hat, eye-covering hair, purple-blue attire and fur collar; realism substituted for anime rendering |
| 内藤忠興 | `naito_tadaoki.png` | [Nobunaga's Ambition: Shinsei](https://altema.jp/nobunagashinsei/busyo/1448) | Clean-shaven young face, swept hair, black and ochre armor |
| 内藤忠郷 | `naito_tadasato.png` | No verified exact-person image found | Imaginative older Mikawa retainer, grey facial hair and dark green robe, over-the-shoulder pose |

## Prompt set and mode

Built-in image-generation mode, one call per officer. The five game figures and one historical image were supplied through `referenced_image_paths`. The four unsourced portraits were generated without another person's picture. Common prompt constraints: one 1:1 genuine-alpha PNG cutout, modern cinematic realistic Japanese character painting, lifelike and varied faces, head/neck/torso aligned, complete head, hands out of frame, no background, no text in any language, no logo, frame or watermark. Each source-based prompt explicitly enumerated the image cues in the table and instructed the generator to carry those cues into a modern realistic rendering. For the historical 信照 portrait, the prompt specifically rejected the antique painting style. 家長 was regenerated once to preserve the whole feathered hat within the square.
