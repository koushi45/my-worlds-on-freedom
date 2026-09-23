# Officer Portraits Batch 05

This batch adds ten officer portraits as square PNG assets with genuine alpha transparency and no in-image text.

## Reference-first workflow

1. Search the web for each officer by exact name plus portrait and Nobunaga's Ambition terms.
2. Prefer a person-specific reconstructed portrait where one is available.
3. If no usable person-specific portrait is found, assign a different Nobunaga's Ambition portrait selected for compatible age, clan, face structure, equipment, or historical role.
4. Feed the selected image as the primary identity reference. Feed `oda_nobunaga.png` separately as a rendering-quality reference only.
5. Explicitly preserve the primary reference's facial proportions, hair, age, expression, clothing, helmet, and armor colors while assigning a distinct pose.

Person-specific reconstructed references from Sengoku Deep Research were used for Saegusa Masasada, Misawa Tamekiyo, Miura Sadahisa, Miura Sadakatsu, Miura Sadahiro, Miura Sadamori, and Mitsubuchi Harukazu. Distinct Nobunaga's Ambition fallback portraits were used for Saegusa Torayoshi, Miura Yoshinari, and Miura Takasuke because usable person-specific portraits were not found.

## Reference sources

- Sengoku Deep Research officer portraits: `https://deep-sengoku.net/`
- Saegusa-family Nobunaga's Ambition portrait: `https://ameblo.jp/tetu522/entry-12759068938.html`
- Nobunaga's Ambition fallback portrait collection: `https://ameblo.jp/tetu522/entry-12753199791.html`
- Mitsubuchi Harukazu game-profile cross-check: `https://tsukumogatari.hatenablog.com/entry/2019/08/04/200000`

## Shared prompt constraints

- Modern premium painterly historical strategy-game portrait.
- True 1:1 composition with genuine alpha transparency.
- No environment, floor, frame, UI, badge, floating crest, writing, Japanese characters, watermark, or signature.
- Reference image 1 controls identity; reference image 2 controls finish only.
- No complex hand poses. Most portraits keep both hands completely outside the crop.
- Head, neck, shoulders, and torso must face a physically coherent direction.

## Registry mapping

| Officer | Registry ID | Output |
| --- | --- | --- |
| Saegusa Masasada | `officer_q2436811` | `saegusa_masasada.png` |
| Saegusa Torayoshi | `officer_q11355934` | `saegusa_torayoshi.png` |
| Misawa Tamekiyo | `officer_q45829921` | `misawa_tamekiyo.png` |
| Miura Yoshinari | `officer_q11356537` | `miura_yoshinari.png` |
| Miura Sadahisa | `officer_q11356568` | `miura_sadahisa.png` |
| Miura Sadakatsu | `officer_q11356567` | `miura_sadakatsu.png` |
| Miura Sadahiro | `officer_q11356569` | `miura_sadahiro.png` |
| Miura Sadamori | `officer_q11356570` | `miura_sadamori.png` |
| Miura Takasuke | `officer_q11356601` | `miura_takasuke.png` |
| Mitsubuchi Harukazu | `officer_q11356604` | `mitsubuchi_harukazu.png` |

## Pose and silhouette differentiation

- Masasada: rugged hachimaki commander looking to viewer-left in red and navy armor.
- Torayoshi: elderly frontal veteran beneath a tall gold helmet crest.
- Tamekiyo: practical helmeted provincial warrior looking to viewer-right.
- Yoshinari: youthful Imagawa officer in an eboshi, looking upward to viewer-left.
- Sadahisa: older, bearded statesman in layered blue and green robes.
- Sadakatsu: strict symmetrical armored command portrait with a circular helmet crest.
- Sadahiro: refined gold-robed court warrior in left-facing profile.
- Sadamori: skeptical green-robed veteran in a right-facing three-quarter pose.
- Takasuke: bald, heavily bearded late-Muromachi warrior in burgundy robes and shoulder armor.
- Harukazu: elderly shogunate official in black court headwear and muted-purple formal robes.
