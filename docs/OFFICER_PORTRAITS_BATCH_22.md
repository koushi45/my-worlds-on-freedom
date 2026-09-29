# Officer portraits: batch 22

Ten final square transparent PNGs are saved under `assets/officers/portraits/` and registered by officer ID in `scripts/game/officer_portraits.gd`. Each officer was created with a separate built-in image-generation call. Exact-person historical or game images were supplied as direct visual-reference images where found; source images are not shipped in the game.

| Officer | Final PNG | Direct image reference | Reference status |
| --- | --- | --- | --- |
| 佐野秀綱 | `sano_hidetsuna.png` | [Nobunaga's Ambition: Shinsei](https://altema.jp/nobunagashinsei/busyo/998) | Exact-person game face; white headband, moustache, armor |
| 佐野豊綱 | `sano_toyotsuna.png` | [Nobunaga's Ambition: Shinsei](https://altema.jp/nobunagashinsei/busyo/997) | Exact-person game face; tall black hat, dark robe, face angle |
| 依田信政 | `yoda_nobumasa.png` | No verified exact-person portrait or game face found | Imaginative reconstruction, no image input |
| 保土原行藤 | `hodohara_yukifuji.png` | [Nobunaga's Ambition: Shinsei](https://altema.jp/nobunagashinsei/busyo/1786) | Exact-person game face; topknot, facial hair, teal robe |
| 保科正之 | `hoshina_masayuki.png` | [Historical portrait copy, Aizuwakamatsu City Library digital collection](https://adeac.jp/city-aizuwakamatsu/catalog/mp500320-100050) | Exact-person historical painting; older facial features and black formal robe. Modern photorealistic style only. |
| 保科正俊 | `hoshina_masatoshi.png` | [Nobunaga's Ambition: Shinsei](https://altema.jp/nobunagashinsei/busyo/1762) | Exact-person game face; crescent kabuto and dark armor |
| 保科正直 | `hoshina_masanao.png` | [Nobunaga's Ambition: Shinsei](https://altema.jp/nobunagashinsei/busyo/1763) | Exact-person game face; hairstyle and lavender robe |
| 保科正貞 | `hoshina_masasada.png` | [Historical portrait attributed to Jōshin-ji](https://kazusa.jpn.org/b/hoshina/masasada) | Low-resolution historical reference; only hat and formal-garment cues are reliable, not facial likeness |
| 児玉就光 | `kodama_narimitsu.png` | No verified exact-person portrait or game face found; [Hiroshima Prefecture historical family material](https://www.pref.hiroshima.lg.jp/uploaded/attachment/395702.pdf) for biographical context only | Imaginative reconstruction, no image input |
| 児玉景唯 | `kodama_kagetada.png` | No verified exact-person portrait or game face found; [Yamaguchi Prefecture Archives material](https://archives.pref.yamaguchi.lg.jp/user_data/upload/File/archivesexhibition/AW18hajimeru/R05_all.pdf) for biographical context only | Imaginative reconstruction, no image input |

## Final prompt set and mode

Built-in image-generation mode, one call per final image. Seven verified subject-specific source images were passed using `referenced_image_paths`; the three subjects with no reliable portrait/game image received text-only prompts so another person's image would not be presented as their likeness.

Common prompt requirements: “Single finished game officer icon, square 1:1 PNG with genuine transparent alpha. Modern cinematic photorealistic living Japanese historical person, realistic skin, hair, fabric and armor; recognizable visual cues from the subject-specific image reference, but no antique painting or flat game-illustration style. Coherent head, neck and torso; whole head visible; hands entirely outside crop. Distinct faces and angles across the series. No scene, background, halo, frame, writing in any language, seal, watermark or other person.”

Each subject prompt specified separate age, face shape, expression, pose, hair or helmet, clothing materials and source-image features. For the low-resolution Masasada portrait, the prompt explicitly limited the historical reference to attire and silhouette and did not claim a verifiable facial likeness.
