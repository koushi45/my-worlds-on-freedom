# 武将肖像 Batch 34

## 制作方法・仕様

2026-09-27。内蔵image_genを使用し、参照画像を直接入力して新規生成。CLI/APIは使用していない。

文字なし、現代的でリアルな人物画、1:1、アルファ背景透過PNG。古い肖像画の絵柄は採用せず、顔立ち・装束の特徴を参照する。

保存先: `C:/Users/nanoa/projects/my-worlds-on-freedom/assets/officers/portraits/`

## 検索と参照元

Web検索・画像検索に人物名＋「信長の野望」「顔グラ」「画像」「登録武将」「イラスト」「戦国IXA」「肖像」等を使用。人物名のある掲載元と画像を照合し、画像を目視してから生成へ入力した。

- 千葉胤宗は戦国期の武蔵千葉氏、千葉胤頼は少弐資元の子を対象とし、鎌倉時代の同名人物の画像は不採用。
- 南条信正はユーザー作成武将の顔画像。公式専用顔や歴史的容貌とは断定しない。
- 千葉胤宗・千葉胤頼・千葉興常・千賀信親は、本人と確認できる顔画像が見つからなかった。別人物のゲーム画像を画風・素材の参考にのみ入力し、顔立ちは創作。この4枚は本人画像を根拠とする肖像ではない。
- 千葉胤宗の黄色の陣羽織は、[武蔵千葉氏の解説](https://chibasi.net/musasi6.htm)が引く『異本小田原記』の所伝を参考。容貌の根拠ではない。

|人物|ファイル|参照の扱い|掲載元|入力ファイル|
|---|---|---|---|---|
|千葉利胤|chiba_toshitane.png|本人ゲーム画像|https://altema.jp/nobunagashinsei/busyo/1306|1306-ref.png|
|千葉親胤|chiba_chikatane.png|本人ゲーム画像|https://altema.jp/nobunagashinsei/busyo/1305|1305-ref.png|
|南条宗勝|nanjo_munekatsu.png|本人ゲーム画像|https://altema.jp/nobunagashinsei/busyo/1536|1536-ref.png|
|南部信直|nanbu_nobunao.png|本人ゲーム画像|https://altema.jp/nobunagashinsei/busyo/1546|1546-ref.png|
|南条信正|nanjo_nobumasa.png|ユーザー作成武将画像（公式専用顔とは未確認）|https://ameblo.jp/tetu522/entry-12619660732.html|nanjo-ref.png|
|千葉直重|chiba_naoshige.png|『戦国IXA』本人画像|https://www.4gamer.net/games/110/G011024/20210802045/|chiba-naoshige-card.png|
|千葉胤宗|chiba_tanemune.png|別人物ゲーム画像を画風・甲冑質感のみ参照（顔は創作）|https://altema.jp/nobunagashinsei/busyo/1546|1546-ref.png|
|千葉胤頼|chiba_taneyori.png|別人物ゲーム画像を画風・布質感のみ参照（顔は創作）|https://altema.jp/nobunagashinsei/busyo/1305|1305-ref.png|
|千葉興常|chiba_okitsune.png|別人物ゲーム画像を画風・礼装のみ参照（顔は創作）|https://altema.jp/nobunagashinsei/busyo/1306|1306-ref.png|
|千賀信親|senga_nobuchika.png|別人物ゲーム画像を画風のみ参照（顔・装束は創作）|https://altema.jp/nobunagashinsei/busyo/1536|1536-ref.png|

参照画像は `C:/Users/nanoa/AppData/Local/Temp/officer_refs_batch34/` に用意。ゲームには含めない。生成後のPNGは背景削除・画像加工を行わず、アルファを維持してコピーする。

## 最終プロンプト

### 千葉利胤 / chiba_toshitane.png

```text
Use case: stylized-concept. Create one square 1:1 officer bust icon for a modern historical strategy game. True alpha-transparent PNG background. Contemporary photorealistic Japanese human character art with natural skin pores, realistic eyes, fabric weave and metal textures. Keep Sengoku-period costume, render in modern realistic style, NOT antique painting, NOT anime. Chest-up composition, hands and weapons outside frame. One man only. No text, writing, labels, logos, watermark, frame, scenery, smoke or background. Complete headgear and hair must fit with clear transparent top margin. Coherent head-neck-torso anatomy. Image 1 is the character reference for Chiba Toshitane. Strongly retain its slim young face, narrow almond-shaped eyes, high cheekbones, fine arched brows, straight nose and clean-shaven pointed chin; distinctive neatly folded black eboshi cap with narrow cords, vivid green outer garment over lavender patterned inner robes and dark collar. Quiet poised slight three-quarter head and shoulder turn, intelligent reserved expression. Do not change to an armored generic warrior.
```

### 千葉親胤 / chiba_chikatane.png

```text
Use case: stylized-concept. Create one square 1:1 officer bust icon for a modern historical strategy game. True alpha-transparent PNG background. Contemporary photorealistic Japanese human character art with natural skin pores, realistic eyes, fabric weave and metal textures. Keep Sengoku-period costume, render in modern realistic style, NOT antique painting, NOT anime. Chest-up composition, hands and weapons outside frame. One man only. No text, writing, labels, logos, watermark, frame, scenery, smoke or background. Complete headgear and hair must fit with clear transparent top margin. Coherent head-neck-torso anatomy. Image 1 is the character reference for Chiba Chikatane. Preserve youthful angular face with straight thick eyebrows, slightly narrowed eyes, prominent jaw yet youthful smooth cheeks, clean-shaven, swept-back black hair and small topknot. Pale rose-pink brocade outer robe, crisp white broad inner collar and subtle lilac underlayer. Late-adolescent young lord, no aged wrinkles or beard. Stern wary expression, nearly frontal bust. Strongly retain this distinctive outfit and face structure.
```

### 南条宗勝 / nanjo_munekatsu.png

```text
Use case: stylized-concept. Create one square 1:1 officer bust icon for a modern historical strategy game. True alpha-transparent PNG background. Contemporary photorealistic Japanese human character art with natural skin pores, realistic eyes, fabric weave and metal textures. Keep Sengoku-period costume, render in modern realistic style, NOT antique painting, NOT anime. Chest-up composition, hands and weapons outside frame. One man only. No text, writing, labels, logos, watermark, frame, scenery, smoke or background. Complete headgear and hair must fit with clear transparent top margin. Coherent head-neck-torso anatomy. Image 1 is the character reference for Nanjo Munekatsu. Preserve its mature rounded face, heavier cheeks, cheerful narrow eyes, arched eyebrows, thick black curled mustache with no chin beard, discreet wrinkles and friendly self-assured expression. Short soft black eboshi, dark blue-purple patterned outer robe and ochre inner collar over cream. Slight three-quarter head and torso, comfortable broad shoulders. Avoid a stern thin generic face.
```

### 南部信直 / nanbu_nobunao.png

```text
Use case: stylized-concept. Create one square 1:1 officer bust icon for a modern historical strategy game. True alpha-transparent PNG background. Contemporary photorealistic Japanese human character art with natural skin pores, realistic eyes, fabric weave and metal textures. Keep Sengoku-period costume, render in modern realistic style, NOT antique painting, NOT anime. Chest-up composition, hands and weapons outside frame. One man only. No text, writing, labels, logos, watermark, frame, scenery, smoke or background. Complete headgear and hair must fit with clear transparent top margin. Coherent head-neck-torso anatomy. Image 1 is the character reference for Nanbu Nobunao. Strongly retain distinctive broad golden swept helmet crest and ornate central golden relief, large lateral kabuto guards, red armor lacing and muted red collar. Mature strong rectangular face, sharply raised brows, deeply focused narrow eyes, broad straight nose, neat black mustache and pointed short beard, gray flecks. Confident authoritative stern gaze, slight three-quarter bust. No hands. Fit the COMPLETE wide crest with generous transparent margins.
```

### 南条信正 / nanjo_nobumasa.png

```text
Use case: stylized-concept. Create one square 1:1 officer bust icon for a modern historical strategy game. True alpha-transparent PNG background. Contemporary photorealistic Japanese human character art with natural skin pores, realistic eyes, fabric weave and metal textures. Keep Sengoku-period costume, render in modern realistic style, NOT antique painting, NOT anime. Chest-up composition, hands and weapons outside frame. One man only. No text, writing, labels, logos, watermark, frame, scenery, smoke or background. Complete headgear and hair must fit with clear transparent top margin. Coherent head-neck-torso anatomy. Image 1 is a fan-created game officer labeled Nanjo Nobumasa, not verified historical likeness. Retain its long lean face, protruding cheekbones, slightly arched brows, small direct eyes, slim straight nose, thin extended mustache and small pointed goatee. Hair pulled back to a small upright topknot with natural hairline. Deep cobalt-blue robe with violet collar. Near-frontal upright bust, thoughtful restrained expression. Translate the reference into natural realistic human rendering.
```

### 千葉直重 / chiba_naoshige.png

```text
Use case: stylized-concept. Create one square 1:1 officer bust icon for a modern historical strategy game. True alpha-transparent PNG background. Contemporary photorealistic Japanese human character art with natural skin pores, realistic eyes, fabric weave and metal textures. Keep Sengoku-period costume, render in modern realistic style, NOT antique painting, NOT anime. Chest-up composition, hands and weapons outside frame. One man only. No text, writing, labels, logos, watermark, frame, scenery, smoke or background. Complete headgear and hair must fit with clear transparent top margin. Coherent head-neck-torso anatomy. Image 1 is Chiba Naoshige's Sengoku IXA card design. Retain only this HUMAN officer's facial and costume characteristics, not the horse or action scene. Long narrow mature face, pronounced high cheekbones, pointed narrow chin, sharply angled thin brows, black thin mustache and small beard. Low folded dark-blue eboshi cap with violet geometric band, flowing blue and violet ceremonial robes with pale purple round geometric motifs, white neckline. Upright near-frontal chest-up portrait, serious analytical expression. Render natural realistic human anatomy and textures, not cartoon; omit horse, forest, reins, hands and weapons.
```

### 千葉胤宗 / chiba_tanemune.png

```text
Use case: stylized-concept. Create one square 1:1 officer bust icon for a modern historical strategy game. True alpha-transparent PNG background. Contemporary photorealistic Japanese human character art with natural skin pores, realistic eyes, fabric weave and metal textures. Keep Sengoku-period costume, render in modern realistic style, NOT antique painting, NOT anime. Chest-up composition, hands and weapons outside frame. One man only. No text, writing, labels, logos, watermark, frame, scenery, smoke or background. Complete headgear and hair must fit with clear transparent top margin. Coherent head-neck-torso anatomy. Input image is STYLE AND ARMOR MATERIAL reference only: Nanbu Nobunao, a DIFFERENT person. Do not copy his face, helmet crest or pose. Create an original interpretive likeness for the Sengoku-era MUSASHI Chiba Tanemune, not the Kamakura namesake. Rugged middle-aged Japanese man, weathered square broad face, low straight eyebrows, wide nose, stubbled broad jaw, slightly deep-set eyes and firm closed lips. Shaved forecrown and low compact topknot, no helmet. Distinct mustard-yellow jinbaori over subdued black iron armor and dark green inner collar; yellow coat is inspired by the campaign account, face is invented. Three-quarter torso with head aligned, watchful determined gaze.
```

### 千葉胤頼 / chiba_taneyori.png

```text
Use case: stylized-concept. Create one square 1:1 officer bust icon for a modern historical strategy game. True alpha-transparent PNG background. Contemporary photorealistic Japanese human character art with natural skin pores, realistic eyes, fabric weave and metal textures. Keep Sengoku-period costume, render in modern realistic style, NOT antique painting, NOT anime. Chest-up composition, hands and weapons outside frame. One man only. No text, writing, labels, logos, watermark, frame, scenery, smoke or background. Complete headgear and hair must fit with clear transparent top margin. Coherent head-neck-torso anatomy. Input image is STYLE AND CLOTH MATERIAL reference only: Chiba Chikatane, a DIFFERENT person. Do NOT copy his face, rose robe or pose. Original interpretive portrait of the HIZEN Sengoku Chiba Taneyori, son of Shoni Sukemoto, not the medieval To Taneyori namesake. Japanese adult in his late twenties, soft oval face, broad gently curved eyebrows, large thoughtful almond eyes, small straight nose, clean-shaven rounded chin. Black hair tied low, no shaved crown and no helmet. Navy-blue outer robe with modest cream geometric pattern, ivory collar and discreet plum underlayer. Slender build, head and shoulders angled together, quiet solemn gaze slightly away from camera.
```

### 千葉興常 / chiba_okitsune.png

```text
Use case: stylized-concept. Create one square 1:1 officer bust icon for a modern historical strategy game. True alpha-transparent PNG background. Contemporary photorealistic Japanese human character art with natural skin pores, realistic eyes, fabric weave and metal textures. Keep Sengoku-period costume, render in modern realistic style, NOT antique painting, NOT anime. Chest-up composition, hands and weapons outside frame. One man only. No text, writing, labels, logos, watermark, frame, scenery, smoke or background. Complete headgear and hair must fit with clear transparent top margin. Coherent head-neck-torso anatomy. Input image is STYLE AND PERIOD CLOTHING reference only: Chiba Toshitane, a DIFFERENT person. Original interpretive portrait of Chiba Okitsune, Hizen lord; do not copy reference face, age or colors. Elderly Japanese man in his late sixties, long gaunt face, hollow cheeks, narrow contemplative eyes, high forehead, subtly hooked prominent nose, sparse silver eyebrows, thin gray mustache and short gray pointed beard. Modest black soft eboshi, dark rust-brown silk outer robe and gray-cream layered collars. Small stoop in shoulders, calm measured expression, almost frontal angle. Natural elder skin texture, dignified and restrained, no armor.
```

### 千賀信親 / senga_nobuchika.png

```text
Use case: stylized-concept. Create one square 1:1 officer bust icon for a modern historical strategy game. True alpha-transparent PNG background. Contemporary photorealistic Japanese human character art with natural skin pores, realistic eyes, fabric weave and metal textures. Keep Sengoku-period costume, render in modern realistic style, NOT antique painting, NOT anime. Chest-up composition, hands and weapons outside frame. One man only. No text, writing, labels, logos, watermark, frame, scenery, smoke or background. Complete headgear and hair must fit with clear transparent top margin. Coherent head-neck-torso anatomy. Input image is RENDERING STYLE reference only: Nanjo Munekatsu, a DIFFERENT person. Create original interpretive likeness of Senga Nobuchika, a Sengoku to early Edo Japanese naval retainer. Do not copy reference face, cap, robe or pose. Distinct sturdy middle-aged man, sun-weathered tan skin, compact broad round face, heavy eyelids, broad flat nose, clean-shaven cheeks and chin, short black hair tied into tight practical topknot. Coarse pale gray cloth headband rather than hat, practical dark navy sleeveless coat over iron armor with muted turquoise lacing and beige collar. Slight three-quarter pose, attentive resolute expression, broad shoulders. No boat, scenery, weapons, ropes, hands or maritime modern costume.
```

## 検証

- 10枚すべて1254×1254、32bit ARGB PNG。左右上隅のalpha=0、中央は不透明であることを検証。
- 目視で現代的な写実描写、文字なし、頭と身体の向き、頭部の収まりを確認。手は描かない構図。
- 千葉利胤・千葉親胤・南条信正・千葉興常の頭上余白を内蔵image_genで修正。千葉胤宗の根拠のない桐紋2点を同ツールで除去。
- `scripts/game/officer_portraits.gd` に10名のIDを登録。各IDが1件のみで、PNGのGodot importファイルが存在することを検証。
- `git diff --check -- scripts/game/officer_portraits.gd` 成功。
- `python tools/export_windows_release.py` 成功（exit 0、error_lines空）。`builds/windows-latest/MyWorldsOnFreedom.exe` とPCKを書き出し。
- Windowsリリース版を `--quit-after 120` で起動し、exit 0を確認。ログ: `builds/windows-latest/portraits-batch34-startup.log`。
- 個々の武将詳細画面を開く操作確認は未実施。

## 最終調整と出力元

### 千葉利胤 / chiba_toshitane.png

生成原本: `C:\Users\nanoa\.codex\generated_images\01a0c84d-d157-7500-a5e1-c9eb55e0ca04\exec-56121f6d-79cf-46cd-8726-c854b1d4a1e2.png`

最終調整プロンプト:

```text
Edit ONLY framing: zoom entire character out slightly and restore the clipped top of the headwear or topknot. Leave a clear genuinely transparent top margin of at least 8 percent image height. Keep identical face, expression, outfit, colors, materials, pose and modern photorealistic style. Chest-up square 1:1 true alpha transparent PNG, no text, scenery, frame or hands. The entire hair and headwear must be visible.
```

### 千葉親胤 / chiba_chikatane.png

生成原本: `C:\Users\nanoa\.codex\generated_images\01a0c84d-d157-7500-a5e1-c9eb55e0ca04\exec-acf01633-9c0f-46dc-9a58-c94ed749adcf.png`

最終調整プロンプト:

```text
Edit ONLY framing: zoom entire character out slightly and restore the clipped top of the headwear or topknot. Leave a clear genuinely transparent top margin of at least 8 percent image height. Keep identical face, expression, outfit, colors, materials, pose and modern photorealistic style. Chest-up square 1:1 true alpha transparent PNG, no text, scenery, frame or hands. The entire hair and headwear must be visible.
```

### 南条宗勝 / nanjo_munekatsu.png

生成原本: `C:\Users\nanoa\.codex\generated_images\01a0c84d-d157-7500-a5e1-c9eb55e0ca04\exec-4c8608df-6b00-4b0b-be5c-8c9c2e7c2653.png`

### 南部信直 / nanbu_nobunao.png

生成原本: `C:\Users\nanoa\.codex\generated_images\01a0c84d-d157-7500-a5e1-c9eb55e0ca04\exec-347d9a75-2ece-4b61-83eb-c4def2e8d7b0.png`

### 南条信正 / nanjo_nobumasa.png

生成原本: `C:\Users\nanoa\.codex\generated_images\01a0c84d-d157-7500-a5e1-c9eb55e0ca04\exec-3f3f66da-a730-41ca-9a98-e9832bdf4356.png`

最終調整プロンプト:

```text
Edit ONLY framing: zoom entire character out slightly and restore the clipped top of the headwear or topknot. Leave a clear genuinely transparent top margin of at least 8 percent image height. Keep identical face, expression, outfit, colors, materials, pose and modern photorealistic style. Chest-up square 1:1 true alpha transparent PNG, no text, scenery, frame or hands. The entire hair and headwear must be visible.
```

### 千葉直重 / chiba_naoshige.png

生成原本: `C:\Users\nanoa\.codex\generated_images\01a0c84d-d157-7500-a5e1-c9eb55e0ca04\exec-914e0856-f710-408a-988e-61be0ea9c29a.png`

### 千葉胤宗 / chiba_tanemune.png

生成原本: `C:\Users\nanoa\.codex\generated_images\01a0c84d-d157-7500-a5e1-c9eb55e0ca04\exec-1b0135b4-28b2-42e1-8567-988daf80496c.png`

最終調整プロンプト:

```text
Edit only the two black paulownia-like crests on the mustard yellow jinbaori: remove BOTH emblems and replace with uninterrupted plain mustard yellow woven fabric matching the surrounding garment. Preserve exactly the same face, hair, expression, pose, armor, lighting, colors and contemporary photorealistic rendering. Square 1:1 true alpha transparent PNG. No new symbols, text, scenery or hands.
```

### 千葉胤頼 / chiba_taneyori.png

生成原本: `C:\Users\nanoa\.codex\generated_images\01a0c84d-d157-7500-a5e1-c9eb55e0ca04\exec-a05b1511-1ba5-462d-a075-7143ca63d313.png`

### 千葉興常 / chiba_okitsune.png

生成原本: `C:\Users\nanoa\.codex\generated_images\01a0c84d-d157-7500-a5e1-c9eb55e0ca04\exec-a6b7d35a-d669-4a8c-9bc4-44351dd58170.png`

最終調整プロンプト:

```text
Edit ONLY framing: zoom entire character out slightly and restore the clipped top of the headwear or topknot. Leave a clear genuinely transparent top margin of at least 8 percent image height. Keep identical face, expression, outfit, colors, materials, pose and modern photorealistic style. Chest-up square 1:1 true alpha transparent PNG, no text, scenery, frame or hands. The entire hair and headwear must be visible.
```

### 千賀信親 / senga_nobuchika.png

生成原本: `C:\Users\nanoa\.codex\generated_images\01a0c84d-d157-7500-a5e1-c9eb55e0ca04\exec-0080d998-5907-4c9f-8468-6e3dc0ec2ce1.png`
