# Officer portraits: batch 26

Ten individually generated 1:1 genuine-alpha PNG busts are stored in `assets/officers/portraits/` and registered by officer ID in `scripts/game/officer_portraits.gd`. Search and source selection preceded generation. Five exact-person modern game artworks were supplied directly as image references; five portraits without a usable verified exact-person image are imaginative reconstructions, not claimed historical likenesses. Reference images are not shipped with the game.

| Officer | Final PNG | Exact-person image supplied to generation | Reference cues / reconstruction |
| --- | --- | --- | --- |
| 内藤隆貞 | `naito_takasada.png` | No usable verified exact-person image | Imagined older Ouchi/Nagato retainer; weathered face, graying beard, indigo and dark armor |
| 冷泉為純 | `reizei_tamezumi.png` | No usable verified exact-person image | Imagined Harima court noble/poet; black eboshi and blue-gray formal robes |
| 冷泉興豊 | `reizei_okitoyo.png` | No usable verified exact-person image | Imagined older Ouchi retainer; shaved forehead, short topknot, rust and olive layers |
| 冷泉隆豊 | `reizei_takatoyo.png` | [Nobunaga's Ambition: Shinsei](https://altema.jp/nobunagashinsei/busyo/2178) | Dark helmet, high gold crescent, purple-brown armor and ochre throat plate |
| 出浦盛清 | `ideura_morikiyo.png` | [Nobunaga's Ambition: Shinsei](https://altema.jp/nobunagashinsei/busyo/259) | Spiky high topknot, pronounced brow, moustache/goatee and charcoal patterned robe |
| 初鹿野信昌 | `hajikano_nobumasa.png` | [Sengoku IXA card, reproduced by Dengeki Online](https://dengekionline.com/articles/172727/) | Tall tan hat and vivid red jinbaori over dark armor; all writing on original garment omitted |
| 初鹿野忠次 | `hajikano_tadatsugu.png` | No usable verified exact-person image | Imagined veteran Takeda cavalry officer; plain dark helmet, weathered face, ochre underlayer |
| 別所吉親 | `bessho_yoshichika.png` | No usable verified exact-person image | Imagined elder Harima adviser; graying full beard, dark teal robe, black armor |
| 別所重宗 | `bessho_shigemune.png` | [Nobunaga's Ambition: Shinsei under alternate name 重棟](https://altema.jp/nobunagashinsei/busyo/1736) | Shaved crown, narrow face, fine moustache, wine-purple robe and green inner collar; [name equivalence](https://taigacast.com/hero/hr2002829/) |
| 別所長治 | `bessho_nagaharu.png` | [Nobunaga's Ambition: Shinsei](https://altema.jp/nobunagashinsei/busyo/1737) | Folded black eboshi, distinctive facial hair, dark plum robe with pale crests and blue/red collars |

## Prompt set and mode

Built-in image-generation mode, one distinct initial call per officer. For the five source-based portraits, the exact-person image was passed through `referenced_image_paths` and its identifying features were enumerated in that officer's prompt. The other five received no substitute person image. All prompts specified contemporary cinematic realism rather than old painted or anime style; differing age, face and body angle; coherent anatomy; square PNG with genuine transparent alpha; no background, text in any language, logo, watermark, hands or weapons. 隆豊, 信昌 and 長治 were regenerated with more top margin so their complete headgear fits in the square.
