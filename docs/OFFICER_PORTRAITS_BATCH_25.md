# Officer portraits: batch 25

Ten individually generated, square transparent PNG busts are stored under `assets/officers/portraits/` and linked to the game's officer IDs in `scripts/game/officer_portraits.gd`. Six exact-person modern game images were found through web image search and supplied directly to generation. The other four portraits are imaginative reconstructions, not claimed likenesses. No reference images are shipped with the game.

| Officer | Final PNG | Exact-person reference supplied | Visual cues carried over |
| --- | --- | --- | --- |
| 内藤政長 | `naito_masanaga.png` | [Nobunaga's Ambition: Shinsei](https://altema.jp/nobunagashinsei/busyo/1452) | Black helmet and sweeping gold crescent, red armor |
| 内藤昌豊 | `naito_masatoyo.png` | [Nobunaga's Ambition: Shinsei](https://altema.jp/nobunagashinsei/busyo/1451) | Shaved crown with long side hair, fierce brow, facial hair, green outer garment |
| 内藤正成 (四郎左衛門) | `naito_masanari_shirozaemon.png` | [Nobunaga's Ambition Online: explicitly 四郎左衛門](https://kamurai.itspy.com/nobunaga/tokugawaSS/index.htm) | Blue helmet, oversized warm-gold horn crest, purple armor and moustache; not the 右京進 namesake |
| 内藤清成 | `naito_kiyonari.png` | [Nobunaga's Ambition: Shinsei](https://altema.jp/nobunagashinsei/busyo/1444) | High bun and shaved forehead, moustache, ochre robe and purple collar |
| 内藤清次 | `naito_kiyotsugu.png` | No verified exact-person image found | Imaginative clean-shaven young retainer, high topknot and charcoal-blue attire |
| 内藤清長 | `naito_kiyonaga.png` | No verified exact-person image found | Imaginative elderly veteran, grey hair and beard, dark armor and moss-green robe |
| 内藤源左衛門 | `naito_genzaemon.png` | No verified exact-person image found | Imaginative middle-aged armored retainer, shaved crown, downward over-shoulder gaze |
| 内藤興盛 | `naito_okimori.png` | [Nobunaga's Ambition: Shinsei](https://altema.jp/nobunagashinsei/busyo/1443) | Tall black eboshi, reserved moustached face, navy robe and lavender collar |
| 内藤隆世 | `naito_takayo.png` | No verified exact-person image found | Imaginative younger retainer, brown eboshi, plum-brown robe and copper-red armor |
| 内藤隆春 | `naito_takaharu.png` | [Nobunaga's Ambition: Shinsei](https://altema.jp/nobunagashinsei/busyo/1447) | Receding forehead and small topknot, tawny robe |

## Prompt set and mode

Built-in image-generation mode, one distinct initial generation call per officer. Exact-person images were supplied through `referenced_image_paths` and their distinguishing shapes, colors and costume were stated explicitly in each prompt. No other officer's image was supplied for the four unsourced portraits. Common constraints: modern cinematic realistic Japanese character art rather than period illustration; varied individual faces and poses; genuine-alpha 1:1 PNG cutout; no background, text in any language, border or watermark; hands and weapons excluded. 政長 and 正成 were regenerated to fit the complete helmet ornaments; 興盛 and 隆世 were regenerated with extra transparent space above their complete eboshi.
