# Officer portraits: batch 21

Ten final, square transparent PNGs are in `assets/officers/portraits/` and are registered in `scripts/game/officer_portraits.gd`. Each officer received one separate built-in image-generation call. For verified historical or exact-person game images, a local copy of the source image was supplied directly to the image tool as its primary visual reference. The original source images are not shipped with the game.

| Officer | Final PNG | Source used for visual identity | Status |
| --- | --- | --- | --- |
| 佐久間信辰 | `sakuma_nobutatsu.png` | No verifiable exact-person portrait or game face found | Imaginative reconstruction, no image input |
| 佐久間盛重 | `sakuma_morishige.png` | [Nobunaga's Ambition: Shinsei face](https://altema.jp/nobunagashinsei/busyo/951) | Exact-person game image; crescent helmet, face and blue armor referenced |
| 佐渡長重 | `sado_nagashige.png` | No verifiable exact-person portrait or game face found | Imaginative reconstruction, no image input |
| 佐田九郎左衛門 | `sada_kurozaemon.png` | No verifiable exact-person portrait or game face found | Imaginative reconstruction, no image input |
| 佐竹義喬 | `satake_yoshitaka.png` | No verifiable exact-person portrait or game face found | Imaginative reconstruction, no image input |
| 佐竹義宣 | `satake_yoshinobu.png` | [Historical armored portrait](https://commons.wikimedia.org/wiki/File:Satake_Yoshinobu.jpg) | Exact-person historical painting; armor, helmet and white round chest emblem referenced; painted facial detail remains uncertain |
| 佐竹義昭 | `satake_yoshiaki.png` | [Nobunaga's Ambition: Shinsei face](https://altema.jp/nobunagashinsei/busyo/965) | Exact-person game image; hair, face angle and ochre robe referenced |
| 佐竹義重 | `satake_yoshishige.png` | [Nobunaga's Ambition: Shinsei face](https://altema.jp/nobunagashinsei/busyo/970) | Exact-person game image; headgear and purple-black armor referenced. A different image labeled as his historical portrait proved identical to Yoshinobu's and was rejected. |
| 佐野昌綱 | `sano_masatsuna.png` | [Historical posthumous Kano-school portrait, Sano City](https://www.city.sano.lg.jp/soshikiichiran/kyouiku/bunkazaika/gyomuannai/4/2/4914.html) | Exact-person historical painting; face/hair and gray-green robes referenced |
| 佐野泰綱 | `sano_yasutsuna.png` | [Nobunaga's Ambition: Shinsei face](https://altema.jp/nobunagashinsei/busyo/1003) | Exact-person game image; horned helmet, face and purple armor referenced |

## Final generation prompt set

Mode: built-in image generation; one independent call per portrait, with `referenced_image_paths` for six verifiable exact-person source images. The four unverified subjects used no reference image to avoid misrepresenting a different person as the subject.

Common instruction: “Create one finished game officer icon as a true PNG with fully transparent alpha background, 1:1 square. Modern cinematic photorealistic living historical character, believable realistic skin pores, eyes, hair and material surface; sophisticated contemporary historical-game design, NOT antique painting, scroll illustration, ink wash, anime, or 2D game art. Make this person's face and camera angle unmistakably distinct from generic samurai portrait templates. Bust only, hands and forearms entirely outside crop, no weapon held, anatomically coherent head/neck/shoulders. Soft dramatic studio light; cutout figure only, no backdrop, floor, landscape, halo, border, watermark or any writing of any script.”

Each portrait then received its own description of facial structure, age, pose, hair, expression, materials and color. The six image-referenced prompts instructed the model to preserve particular source features while rendering a new, modern, realistic person—not to imitate the period painting or game illustration style. The four imaginative reconstructions were explicitly labeled as not verified likenesses.
