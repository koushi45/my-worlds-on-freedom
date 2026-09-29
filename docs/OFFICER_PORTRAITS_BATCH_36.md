# 武将肖像 Batch 36

## 制作

2026-09-27。内蔵image_genで人物ごとに生成。CLI/API不使用。検索→人物名の照合→参考画像の目視→画像を直接入力して生成。現代的でリアルな人物描写、文字なし、1:1、真のアルファ透過PNG。

保存先: `C:/Users/nanoa/projects/my-worlds-on-freedom/assets/officers/portraits/`

古川済堯・右田隆次は本人と確認できる現代ゲーム顔画像が見つからず、創作での制作可否を質問中。現時点では未生成・未登録。古田重然は古田織部と照合。吉江景資は真田信之の顔を流用した投稿ではなく、本人名の戦国大戦カードを採用。

## 参照元

|人物|出力|掲載元|入力|
|---|---|---|---|
|口羽通良|kuchiba_michiyoshi.png|https://altema.jp/nobunagashinsei/busyo/786|786-ref.png|
|古田重然|furuta_shigenari.png|https://altema.jp/nobunagashinsei/busyo/1732|1732-ref.png|
|吉川元春|kikkawa_motoharu.png|https://altema.jp/nobunagashinsei/busyo/747|747-ref.png|
|吉川広家|kikkawa_hiroie.png|https://altema.jp/nobunagashinsei/busyo/744|744-ref.png|
|吉川興経|kikkawa_okitsune.png|https://altema.jp/nobunagashinsei/busyo/740|740-ref.png|
|吉弘鎮信|yoshihiro_shigenobu.png|https://altema.jp/nobunagashinsei/busyo/2157|2157-ref.png|
|吉田康俊|yoshida_yasutoshi.png|https://altema.jp/nobunagashinsei/busyo/2154|2154-ref.png|
|吉江景資|yoshie_kagesuke.png|https://www.suruga-ya.com/ja/product/G8943304|yoshie-card.jpg|

参照画像: `C:/Users/nanoa/AppData/Local/Temp/officer_refs_batch36/`。
アルテマ画像は `https://img.altema.jp/nobunagashinsei/busyo/banner/{ID}.jpg` の顔部分180,62,120,120を抽出。吉江景資は `https://www.suruga-ya.jp/database/pics_light/game/g8943304.jpg`。参考原本はゲームに含めない。

## 生成プロンプト・原本

### 口羽通良

```text
Use case: stylized-concept. ONE square 1:1 game officer bust, true alpha transparent PNG. Modern photorealistic Japanese human portrait, realistic skin pores and eyes, fabric weave and metal; period attire but NOT antique painting or anime. Chest-up, hands and weapons excluded. Entire headgear and hair visible with clear transparent space above. Coherent head/neck/torso anatomy. No text, symbols resembling writing, UI, card border, scenery, fog, watermark or invented family crests. Image 1 is the named officer's GAME DESIGN reference: strongly preserve distinguishing facial proportions, facial hair, colors and headwear, rendered afresh in modern realistic style. Middle-aged man, narrow angular face, high receding forehead with compact topknot, pointed moustache and thin goatee, intelligent piercing gaze. Muted purple formal robe, white and dull red collars, dignified three-quarter view.
```

生成原本: `C:\Users\nanoa\.codex\generated_images\01a0c84d-d157-7500-a5e1-c9eb55e0ca04\exec-65ab7476-17dd-4124-b32a-53c3b38d210b.png`

### 古田重然

```text
Use case: stylized-concept. ONE square 1:1 game officer bust, true alpha transparent PNG. Modern photorealistic Japanese human portrait, realistic skin pores and eyes, fabric weave and metal; period attire but NOT antique painting or anime. Chest-up, hands and weapons excluded. Entire headgear and hair visible with clear transparent space above. Coherent head/neck/torso anatomy. No text, symbols resembling writing, UI, card border, scenery, fog, watermark or invented family crests. Image 1 is the named officer's GAME DESIGN reference: strongly preserve distinguishing facial proportions, facial hair, colors and headwear, rendered afresh in modern realistic style. Furuta Oribe, mature slender man, playful knowing subtle smile, sharply arched brows, narrow eyes, thin moustache and small pointed goatee. Tall folded black court cap with pale cross ties, green patterned silk robe and orange inner collar. Slightly angled posture, sophisticated tea-master presence without cup or hands.
```

生成原本: `C:\Users\nanoa\.codex\generated_images\01a0c84d-d157-7500-a5e1-c9eb55e0ca04\exec-abc507dd-7416-4718-b417-39512e062fe6.png`

### 吉川元春

```text
Use case: stylized-concept. ONE square 1:1 game officer bust, true alpha transparent PNG. Modern photorealistic Japanese human portrait, realistic skin pores and eyes, fabric weave and metal; period attire but NOT antique painting or anime. Chest-up, hands and weapons excluded. Entire headgear and hair visible with clear transparent space above. Coherent head/neck/torso anatomy. No text, symbols resembling writing, UI, card border, scenery, fog, watermark or invented family crests. Image 1 is the named officer's GAME DESIGN reference: strongly preserve distinguishing facial proportions, facial hair, colors and headwear, rendered afresh in modern realistic style. Strong broad-faced mature warrior with dark moustache and short goatee, furrowed eyebrows, firm expression. Black soft folded cap bound by white headband, turquoise outer coat with ochre-gold lapels over dark armor. Broad chest, natural three-quarter head and body alignment. Remove the source polearm entirely.
```

生成原本: `C:\Users\nanoa\.codex\generated_images\01a0c84d-d157-7500-a5e1-c9eb55e0ca04\exec-68b87dd5-474a-4b8c-bf9f-62a6fdf56253.png`

### 吉川広家

```text
Use case: stylized-concept. ONE square 1:1 game officer bust, true alpha transparent PNG. Modern photorealistic Japanese human portrait, realistic skin pores and eyes, fabric weave and metal; period attire but NOT antique painting or anime. Chest-up, hands and weapons excluded. Entire headgear and hair visible with clear transparent space above. Coherent head/neck/torso anatomy. No text, symbols resembling writing, UI, card border, scenery, fog, watermark or invented family crests. Image 1 is the named officer's GAME DESIGN reference: strongly preserve distinguishing facial proportions, facial hair, colors and headwear, rendered afresh in modern realistic style. Man in his thirties-forties, wiry shaggy black hair tied back, thin patterned dark headband, angular cheeks, compact moustache and small chin beard, intent tense gaze, dark red lacquer armor with dark cord lacing. No helmet, alert slight three-quarter pose.
```

生成原本: `C:\Users\nanoa\.codex\generated_images\01a0c84d-d157-7500-a5e1-c9eb55e0ca04\exec-18fe4cfe-7416-4981-a089-bb3a65d6be1c.png`

### 吉川興経

```text
Use case: stylized-concept. ONE square 1:1 game officer bust, true alpha transparent PNG. Modern photorealistic Japanese human portrait, realistic skin pores and eyes, fabric weave and metal; period attire but NOT antique painting or anime. Chest-up, hands and weapons excluded. Entire headgear and hair visible with clear transparent space above. Coherent head/neck/torso anatomy. No text, symbols resembling writing, UI, card border, scenery, fog, watermark or invented family crests. Image 1 is the named officer's GAME DESIGN reference: strongly preserve distinguishing facial proportions, facial hair, colors and headwear, rendered afresh in modern realistic style. Older sturdy man, broad cheeks, deep smile lines, distinctive thick bristly moustache, slightly protruding chin and forceful watchful eyes. Bronze-gold kabuto with large crescent/disc ornament exactly inspired by reference, dark purple neckcloth and olive-gold shoulder armor. Upright solid bearing.
```

生成原本: `C:\Users\nanoa\.codex\generated_images\01a0c84d-d157-7500-a5e1-c9eb55e0ca04\exec-e3529014-be3a-4655-a826-b2bd99e11b2d.png`

### 吉弘鎮信

```text
Use case: stylized-concept. ONE square 1:1 game officer bust, true alpha transparent PNG. Modern photorealistic Japanese human portrait, realistic skin pores and eyes, fabric weave and metal; period attire but NOT antique painting or anime. Chest-up, hands and weapons excluded. Entire headgear and hair visible with clear transparent space above. Coherent head/neck/torso anatomy. No text, symbols resembling writing, UI, card border, scenery, fog, watermark or invented family crests. Image 1 is the named officer's GAME DESIGN reference: strongly preserve distinguishing facial proportions, facial hair, colors and headwear, rendered afresh in modern realistic style. Slender middle-aged man, tall narrow forehead, swept-back black hair and compact topknot, long thin moustache and pointed chin beard, long straight nose, contemplative sidelong gaze. Muted teal sleeveless outer robe over dusty burgundy inner garment, simple dark collar. Head and torso naturally turned together, no armor or helmet.
```

生成原本: `C:\Users\nanoa\.codex\generated_images\01a0c84d-d157-7500-a5e1-c9eb55e0ca04\exec-e26dd462-b235-4359-8639-5d5491eedf83.png`

### 吉田康俊

```text
Use case: stylized-concept. ONE square 1:1 game officer bust, true alpha transparent PNG. Modern photorealistic Japanese human portrait, realistic skin pores and eyes, fabric weave and metal; period attire but NOT antique painting or anime. Chest-up, hands and weapons excluded. Entire headgear and hair visible with clear transparent space above. Coherent head/neck/torso anatomy. No text, symbols resembling writing, UI, card border, scenery, fog, watermark or invented family crests. Image 1 is the named officer's GAME DESIGN reference: strongly preserve distinguishing facial proportions, facial hair, colors and headwear, rendered afresh in modern realistic style. Middle-aged man with rounder rugged cheeks, compact thin moustache, tight lips and alert eyes. Dark blue rounded helmet bearing a small silver crescent, thick brick-red chin cord, red-black lamellar armor, olive-gold shoulder trim and purple inner robe. Calm three-quarter bust.
```

生成原本: `C:\Users\nanoa\.codex\generated_images\01a0c84d-d157-7500-a5e1-c9eb55e0ca04\exec-1422404f-e70b-4546-8b27-26695c3dfe02.png`

### 吉江景資

```text
Use case: stylized-concept. ONE square 1:1 game officer bust, true alpha transparent PNG. Modern photorealistic Japanese human portrait, realistic skin pores and eyes, fabric weave and metal; period attire but NOT antique painting or anime. Chest-up, hands and weapons excluded. Entire headgear and hair visible with clear transparent space above. Coherent head/neck/torso anatomy. No text, symbols resembling writing, UI, card border, scenery, fog, watermark or invented family crests. Image 1 is the named officer's GAME DESIGN reference: strongly preserve distinguishing facial proportions, facial hair, colors and headwear, rendered afresh in modern realistic style. Yoshie Kagesuke, physically believable stern older warrior: high shaved crown with black upright topknot, heavy brows, narrow cold eyes and broad rugged forehead. Preserve black segmented armor with silver studs and raised gray collar; black lower-face armor covers mouth and jaw. Dark gray cloth beneath cuirass. Natural thick neck and stocky shoulders. Remove ALL written kanji from armor, remove swords, banners, gun, hands, card frame and text. Plain black chest plates only. Realistic human proportions instead of exaggerated cartoon.
```

生成原本: `C:\Users\nanoa\.codex\generated_images\01a0c84d-d157-7500-a5e1-c9eb55e0ca04\exec-ef14c5fb-7802-4b6f-8057-579a55288abd.png`

## 最終調整

吉川興経:

```text
Change ONLY framing: zoom the entire warrior out to leave a clear transparent top margin of 8 percent. Restore the clipped tip of the golden helmet crescent, with complete headgear visible. Keep identical face, mustache, expression, clothing, armor, pose, realistic style and colors. Square 1:1 true alpha transparent PNG. No text or new objects.
```

吉江景資:

```text
Change only framing: slightly zoom entire character out so ALL topknot hair fits, with 8 percent clear transparent top margin. Preserve face, mask, armor, pose, colors, materials and modern realistic style exactly. Square 1:1 true alpha transparent PNG. No text, props or background.
```

## 検証

8枚すべて1254×1254、32bit ARGB、左右上隅alpha=0。生成画像は加工せずコピーしアルファを維持。目視で文字なし・頭部の収まり・顔と体の整合を確認。

Windowsリリースのビルド成功（exit 0、error_lines空）、EXE/PCKを `builds/windows-latest/` に書き出し。EXEを `--quit-after 120` で一時起動しexit 0を確認。ログ: `builds/windows-latest/portraits-batch36-startup.log`。8件のIDが重複なく登録され、PNG importファイルが生成されたことを確認。`git diff --check` 成功。各武将詳細画面を開く操作確認は未実施。
