# Historical-source portrait style revision

The nine listed game assets were regenerated individually with built-in ImageGen and replaced in place. Their existing images were inspected first, then used as **Image 1 (feature and costume guide / edit target)**. `ii_naokatsu.png` and `uesugi_kenshin_v3.png` were Images 2 and 3, respectively, **modern game-rendering references only**. This pass retains person-specific face shape, age, headwear, garment structure, and colors but rejects the flat pictorial style of historical paintings and woodblock art. The historical-source references and their caveats remain documented in the linked batch documents.

| Revised asset | Historical-source documentation | Identity/design details retained |
| --- | --- | --- |
| `ii_naomasa.png` | [Batch 13](OFFICER_PORTRAITS_BATCH_13.md) | Slim face, fine moustache, cap with pale streamer, black court robe. |
| `ii_naotaka.png` | [Batch 13](OFFICER_PORTRAITS_BATCH_13.md) | Broad mature face, black eboshi with curved streamer, patterned robe. |
| `inoue_daikuro.png` | [Batch 13](OFFICER_PORTRAITS_BATCH_13.md) | Broad face, heavy brows, topknot, blue-purple and green checked garments. |
| `inoue_yukifusa.png` | [Batch 13](OFFICER_PORTRAITS_BATCH_13.md) | Narrow face, double-winged black helmet, black and copper armor. |
| `kuki_yoshitaka.png` | [Batch 11](OFFICER_PORTRAITS_BATCH_11.md) | Broad face, tall black court cap, patterned wide robe with red trim. |
| `nomi_munekatsu.png` | [Batch 11](OFFICER_PORTRAITS_BATCH_11.md) | Bald elderly face, white facial hair, black armor and white under-robe. |
| `niwa_nagahide.png` | [Batch 10](OFFICER_PORTRAITS_BATCH_10.md) | Topknot, slim mature face, moustache and goatee, black floral robe. |
| `nakagawa_hidenari.png` | [Batch 09](OFFICER_PORTRAITS_BATCH_09.md) | Young slender face, upright court cap, black robe and crimson trim. |
| `nakagawa_kiyohide.png` | [Batch 09](OFFICER_PORTRAITS_BATCH_09.md) | Shaved crown, thin moustache, black and gold garment, patterned light sleeves. |

Final shared prompt set: `Use case: style-transfer. Asset type: replacement 1:1 transparent Sengoku officer game bust icon. Image 1 is the existing icon as edit target and guide only for this individual's distinctive face, age, headwear and garment details. Images 2 and 3 are desired contemporary realistic game-rendering references only; never copy their identities, uniforms or poses. Redraw as a fresh high-end modern semi-photorealistic historical character painting. Use believable three-dimensional craniofacial planes, nuanced pores and age-appropriate wrinkles, natural asymmetry, expressive eyes, cinematic directional light and ambient shadows, realistic fabric and metal. Preserve the stated historical visual markers but not the historical pictorial medium. No antique painted-portrait or ukiyo-e look, flat skin, ink contours, printmaking, wax doll appearance or museum patina. Chest-up naturally aligned anatomy, no hands or weapons. Actual alpha-transparent square PNG; no background, frame, UI or lettering.` Each call included its row-specific identity details.

The original nine files were copied to `C:\Users\nanoa\AppData\Local\Temp\portrait_style_revision_originals_20260925` before replacement. This is a temporary local backup, not a game asset.
