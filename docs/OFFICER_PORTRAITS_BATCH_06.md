# Officer Portraits Batch 06

Ten square PNG portraits were created with real alpha transparency and no in-image text. Each was generated separately with a primary searched image and the project's `oda_nobunaga.png` as a finish-only style reference.

## Reference choices

The source of the Uesugi Kagekatsu portrait is a historical painting held by the Yonezawa City Uesugi Museum. The museum identifies it as a nineteenth-century painting, so it is a historical image of the person, not a portrait painted during his lifetime. The Sengoku Deep Research images are person-labeled modern reconstructions, not historical paintings. For the four people without a verified person-specific image in the search results, distinct Nobunaga's Ambition images were used as design references; these fallback images are not asserted to depict those particular people.

| Officer | Registry ID | Output | Primary visual source | Source type | Identity and pose instructions |
| --- | --- | --- | --- | --- | --- |
| Mitamura Kunisada | `officer_q108781592` | `mitamura_kunisada.png` | [Nobunaga's Ambition portrait](https://ameblo.jp/tetu522/entry-12753155276.html) | Fallback | Lean face, tall crescent-front helm, rust-red mantle; slightly left-facing. |
| Mita Tsunahide | `officer_q17212681` | `mita_tsunahide.png` | [Nobunaga's Ambition portrait](https://ameblo.jp/tetu522/entry-12753186194.html) | Fallback | Broad expressive face, tied topknot, brown robe with pale round marks; older three-quarter portrait. |
| Sanga Yoriteru | `officer_q109358474` | `sanga_yoriteru.png` | [Nobunaga's Ambition portrait](https://ameblo.jp/tetu522/entry-12753200946.html) | Fallback | Bald crown, white moustache and beard, red-gold mantle and blue armor; authoritative chest-up pose. |
| Mikumo Narimochi | `officer_q10867117` | `mikumo_narimochi.png` | [Person-labeled reconstructed portrait](https://deep-sengoku.net/?page=page-bushou-%E4%B8%89%E9%9B%B2%E6%88%90%E6%8C%81) | Modern reconstruction | High forehead, lowered eyes, sideburns, terra-cotta robe; contemplative downcast gaze. |
| Uwai Kakuken | `officer_q7903777` | `uwai_kakuken.png` | [Person-labeled reconstructed portrait](https://deep-sengoku.net/?page=page-bushou-%E4%B8%8A%E4%BA%95%E8%A6%9A%E5%85%BC) | Modern reconstruction | Rounded smiling face, shaved forehead, red-brown armor and green-gold shoulder tabs; relaxed three-quarter pose. |
| Uesaka Kageyu | `officer_q121643707` | `uesaka_kageyu.png` | [Nobunaga's Ambition portrait](https://ameblo.jp/tetu522/entry-12753185015.html) | Fallback | Bald head, fierce brows, white scarf, gray armor and beads; turned left. |
| Uesugi Sadakatsu | `officer_q8514762` | `uesugi_sadakatsu.png` | [Person-labeled reconstructed portrait](https://deep-sengoku.net/?page=page-bushou-%E4%B8%8A%E6%9D%89%E5%AE%9A%E5%8B%9D) | Modern reconstruction | High topknot, clean-shaven broad face, jade-green ceremonial robes and gold cords; upright. |
| Uesugi Sadazane | `officer_q11359151` | `uesugi_sadazane.png` | [Person-labeled reconstructed portrait](https://deep-sengoku.net/?page=page-bushou-%E4%B8%8A%E6%9D%89%E5%AE%9A%E5%AE%9F) | Modern reconstruction | Tall black eboshi, thin moustache and beard, indigo robe over ochre; right-facing. |
| Uesugi Norimasa | `officer_q906593` | `uesugi_norimasa.png` | [Person-labeled reconstructed portrait](https://deep-sengoku.net/?page=page-bushou-%E4%B8%8A%E6%9D%89%E6%86%B2%E6%94%BF) | Modern reconstruction | Black folded eboshi, moustache, rust-brown mantle over dark armor; guarded left-facing pose. |
| Uesugi Kagekatsu | `officer_q1376605` | `uesugi_kagekatsu.png` | [Historical painting](https://commons.wikimedia.org/wiki/File:Uesugi_Kagekatsu_Portrait_Yonezawa_City_Uesugi_Museum.png) | Historical portrait | Broad pale face, paired antler-like gold helm crest, red armor, blue patterned sleeves, gold chest plate; right-facing bust. |

The Uesugi Kagekatsu painting's attribution and nineteenth-century date are described in the [Yonezawa City Uesugi Museum annual report](https://www.denkoku-no-mori.yonezawa.yamagata.jp/pdf/nenpo/nenpo19.pdf).

## Shared generation prompt

Use case: `stylized-concept`. Asset type: transparent square game officer portrait. Image 1 controls the individual's face, hairstyle, age, expression, clothing, colors, and equipment. Image 2 (`oda_nobunaga.png`) controls only the game's premium painterly finish. Draw one modern strategy-game portrait per officer, with the individual identity and pose instructions in the table. Keep head, neck, and shoulders aligned and hands outside the crop. Output a genuine transparent-alpha 1:1 PNG, without scenery, panel, writing, Japanese characters, frame, watermark, or UI.
