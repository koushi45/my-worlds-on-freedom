# Officer Portraits Batch 04

This batch adds ten officer portraits as square PNG assets with genuine alpha transparency and no in-image text.

## Reference-first workflow

1. Search the web for each officer by exact name plus portrait and Nobunaga's Ambition terms.
2. Prefer a person-specific reconstructed portrait where one is available.
3. If no usable person-specific portrait is found, assign a different Nobunaga's Ambition portrait selected for compatible age, face structure, equipment, or historical role.
4. Feed the selected image as the primary identity reference. Feed `oda_nobunaga.png` separately as a rendering-quality reference only.
5. Explicitly preserve the primary reference's facial proportions, hair, age, expression, clothing, and equipment cues while assigning a distinct pose to every officer.

Person-specific reconstructed references were used for Miyake Fusahiro, Miki Kunitsuna, Miki Naoyori, Miki Michiaki, Miki Akitsuna, and Mimura Iechika. Distinct Nobunaga's Ambition fallback portraits were used for Miyake Yasusada, Miyake Masatsugu, Mito Kagemichi, and Miki Seikan because usable person-specific portraits were not found.

## Shared prompt constraints

- Modern premium semi-realistic historical strategy-game portrait.
- True 1:1 composition with genuine alpha transparency.
- No environment, floor, frame, UI, badge, floating crest, writing, Japanese characters, watermark, or signature.
- Reference image 1 controls identity; reference image 2 controls finish only.
- No repeated frontal arms-crossed pose or shared generic facial structure.

## Registry mapping

| Officer | Registry ID | Output |
| --- | --- | --- |
| Miyake Yasusada | `officer_q10524017` | `miyake_yasusada.png` |
| Miyake Masatsugu | `officer_q108781564` | `miyake_masatsugu.png` |
| Miyake Fusahiro | `officer_q11355078` | `miyake_fusahiro.png` |
| Mito Kagemichi | `officer_q11355442` | `mito_kagemichi.png` |
| Miki Kunitsuna | `officer_q11355591` | `miki_kunitsuna.png` |
| Miki Seikan | `officer_q27920679` | `miki_seikan.png` |
| Miki Naoyori | `officer_q11355682` | `miki_naoyori.png` |
| Miki Michiaki | `officer_q11355703` | `miki_michiaki.png` |
| Miki Akitsuna | `officer_q11355719` | `miki_akitsuna.png` |
| Mimura Iechika | `officer_q6862455` | `mimura_iechika.png` |

## Pose and silhouette differentiation

- Yasusada: matchlock over the shoulder while tightening a white scarf.
- Masatsugu: bearded officer resting a hand on a short-sword pommel.
- Fusahiro: stocky armored councilor gripping a navy shoulder cord.
- Kagemichi: elderly ascetic commander holding prayer beads.
- Kunitsuna: lean mountain fighter gripping a short spear.
- Seikan: merchant-scholar opening an unglazed tea caddy.
- Naoyori: veteran lord examining a blank rolled map.
- Michiaki: castle commander raising a closed iron war fan.
- Akitsuna: simple chest-up three-quarter officer portrait with both hands below the crop.
- Iechika: helmeted battlefield lord gripping his chin cord and bow.
