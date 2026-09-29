# 武将肖像 Batch 35

## 制作方法・仕様

2026-09-27。内蔵image_genで1人物につき1画像を生成。CLI/API不使用。検索→人物名照合→ローカル画像を目視→参照画像を直接入力、の順で制作。

現代的でリアルな人物画、文字なし、1:1、アルファ透過PNG。衣装は時代装束、絵柄は現代の写実描写。手・武器は構図から外す。

保存先: `C:/Users/nanoa/projects/my-worlds-on-freedom/assets/officers/portraits/`

## 検索・参考画像

Web検索と画像検索で各人物名＋信長の野望・顔グラ・画像・登録武将・戦国大戦等を検索。原田宗資は伊達049のカード名・人物説明を照合。原昌胤はユーザー作成武将の掲載画像であり、公式専用顔や史実の容貌とは断定しない。

原田宗輔・原胤従・原胤義・原虎吉は本人と確認できる現代ゲーム画像が見つからず、ユーザーの明示承認を得て創作肖像とした。別人物の画像は画風・素材・装束だけの参考で、顔は新規デザイン。原田宗輔（甲斐）と父・宗資を別人として扱い、ファイル名も区別した。原氏各人の同姓・別系統を混同しない。

|人物|出力ファイル|参照の扱い|掲載元|入力画像|
|---|---|---|---|---|
|南部晴政|nanbu_harumasa.png|本人ゲーム画像|https://altema.jp/nobunagashinsei/busyo/1547|1547-ref.png|
|原昌胤|hara_masatane.png|ユーザー作成武将画像|https://gwynt.liblo.jp/archives/%E6%96%B0%E6%AD%A6%E5%B0%86%20%E5%8E%9F%E6%98%8C%E8%83%A4.html|masatane-ref.png|
|原田宗時|harada_munetoki.png|本人ゲーム画像|https://altema.jp/nobunagashinsei/busyo/1667|1667-ref.png|
|原虎胤|hara_toratane.png|本人ゲーム画像|https://altema.jp/nobunagashinsei/busyo/1659|1659-ref.png|
|原長頼|hara_nagayori.png|本人ゲーム画像|https://altema.jp/nobunagashinsei/busyo/1660|1660-ref.png|
|原田宗資|harada_munesuke.png|『戦国大戦』本人カード|https://www.suruga-ya.jp/product/detail/G5327231|munesuke-card.jpg|
|原田宗輔|harada_munesuke_kai.png|画風・装束のみ参照／顔は創作|https://gwynt.liblo.jp/archives/%E6%96%B0%E6%AD%A6%E5%B0%86%20%E5%8E%9F%E6%98%8C%E8%83%A4.html|masatane-ref.png|
|原胤従|hara_taneyori.png|画風・甲冑のみ参照／顔は創作|https://altema.jp/nobunagashinsei/busyo/1660|1660-ref.png|
|原胤義|hara_taneyoshi.png|画風・素材のみ参照／顔は創作|https://altema.jp/nobunagashinsei/busyo/1667|1667-ref.png|
|原虎吉|hara_torayoshi.png|画風・素材のみ参照／顔は創作|https://altema.jp/nobunagashinsei/busyo/1659|1659-ref.png|

参考原本の保存先: `C:/Users/nanoa/AppData/Local/Temp/officer_refs_batch35/`。参考画像はゲームへ配布しない。

- アルテマ参考画像: `https://img.altema.jp/nobunagashinsei/busyo/banner/{1547,1659,1660,1667}.jpg`。各顔を180,62,120,120で抽出。
- 原昌胤: `https://livedoor.blogimg.jp/saoirse/imgs/4/e/4eb1e90d.jpg`。顔部分8,29,98,125を抽出。
- 原田宗資: `https://www.suruga-ya.jp/database/pics_light/game/g5327231.jpg`。カード全体を入力し、文字・枠・旗・槍を生成から除外。

## 全生成プロンプト

### 南部晴政 / nanbu_harumasa.png

```text
Use case: stylized-concept. Create ONE square 1:1 transparent PNG officer bust for a historical strategy game. Contemporary photorealistic Japanese character art: natural skin pores, realistic eyes, woven fabric and detailed metal. Period costume, modern realistic rendering, NOT antique painting, NOT anime. Chest-up, hands and weapons OUTSIDE frame. Whole headgear/hair visible with at least 8 percent genuinely transparent top margin. One man only, coherent head-neck-torso orientation. Absolutely no text, writing, labels, watermark, UI, border, scenery, fog, invented crests or background. Image 1 is a visual reference: retain its distinctive facial structure, facial hair, headgear and costume cues, but freshly render as a realistic human with natural proportions. Nanbu Harumasa: imposing middle-aged commander, long broad nose, strong square jaw, thick low brows and a thick dark moustache, resolute slightly frowning mouth. Blue-black armor, dark helmet with gold ornamental central crest and two pale pointed projections, as in reference. Heavy shoulders and nearly frontal authoritative bearing. No sword visible.
```

### 原昌胤 / hara_masatane.png

```text
Use case: stylized-concept. Create ONE square 1:1 transparent PNG officer bust for a historical strategy game. Contemporary photorealistic Japanese character art: natural skin pores, realistic eyes, woven fabric and detailed metal. Period costume, modern realistic rendering, NOT antique painting, NOT anime. Chest-up, hands and weapons OUTSIDE frame. Whole headgear/hair visible with at least 8 percent genuinely transparent top margin. One man only, coherent head-neck-torso orientation. Absolutely no text, writing, labels, watermark, UI, border, scenery, fog, invented crests or background. Image 1 is a visual reference: retain its distinctive facial structure, facial hair, headgear and costume cues, but freshly render as a realistic human with natural proportions. Hara Masatane: retain reference's strongly receding/bald crown, black hair at sides, long narrow angular face, pointed black beard connected to drooping mustache, sharp raised brows and thoughtful intense stare. Middle-aged man wearing restrained slate-gray layered robe with pale collar, slight three-quarter pose. No helmet. Reference is a user-created game portrait, not historical evidence.
```

### 原田宗時 / harada_munetoki.png

```text
Use case: stylized-concept. Create ONE square 1:1 transparent PNG officer bust for a historical strategy game. Contemporary photorealistic Japanese character art: natural skin pores, realistic eyes, woven fabric and detailed metal. Period costume, modern realistic rendering, NOT antique painting, NOT anime. Chest-up, hands and weapons OUTSIDE frame. Whole headgear/hair visible with at least 8 percent genuinely transparent top margin. One man only, coherent head-neck-torso orientation. Absolutely no text, writing, labels, watermark, UI, border, scenery, fog, invented crests or background. Image 1 is a visual reference: retain its distinctive facial structure, facial hair, headgear and costume cues, but freshly render as a realistic human with natural proportions. Harada Munetoki: young adult in late twenties, clean-shaven fair oval face, lively wide eyes, straight nose, lips slightly parted with alert confident expression. Purple-burgundy helmet with small gold crescent on forehead, gold breastplate and dark shoulder armor, green neck cord from reference. Looking to the side in three-quarter view while torso follows naturally.
```

### 原虎胤 / hara_toratane.png

```text
Use case: stylized-concept. Create ONE square 1:1 transparent PNG officer bust for a historical strategy game. Contemporary photorealistic Japanese character art: natural skin pores, realistic eyes, woven fabric and detailed metal. Period costume, modern realistic rendering, NOT antique painting, NOT anime. Chest-up, hands and weapons OUTSIDE frame. Whole headgear/hair visible with at least 8 percent genuinely transparent top margin. One man only, coherent head-neck-torso orientation. Absolutely no text, writing, labels, watermark, UI, border, scenery, fog, invented crests or background. Image 1 is a visual reference: retain its distinctive facial structure, facial hair, headgear and costume cues, but freshly render as a realistic human with natural proportions. Hara Toratane: seasoned Japanese warrior, thick downward brows, sun-weathered square face, deep-set intense eyes, thick black moustache and compact beard. Distinctive ivory cloth hood covers top and sides of head and wraps around shoulders, brown woven surcoat over black-and-gold armor. Strong short neck and solid build; slightly turned torso with stern forward gaze. Match hood folds, not a modern hoodie.
```

### 原長頼 / hara_nagayori.png

```text
Use case: stylized-concept. Create ONE square 1:1 transparent PNG officer bust for a historical strategy game. Contemporary photorealistic Japanese character art: natural skin pores, realistic eyes, woven fabric and detailed metal. Period costume, modern realistic rendering, NOT antique painting, NOT anime. Chest-up, hands and weapons OUTSIDE frame. Whole headgear/hair visible with at least 8 percent genuinely transparent top margin. One man only, coherent head-neck-torso orientation. Absolutely no text, writing, labels, watermark, UI, border, scenery, fog, invented crests or background. Image 1 is a visual reference: retain its distinctive facial structure, facial hair, headgear and costume cues, but freshly render as a realistic human with natural proportions. Hara Nagayori: lean middle-aged warrior with narrow cheeks, almond eyes, slim nose, short sparse mustache, firm closed lips. Simple dark hemispherical ribbed helmet with no crest, iron lamellar armor, dark purple neck robe and dull teal/maroon lacing. Head and torso in slight three-quarter view, subtle composed expression. Keep face notably lean and helmet unornamented.
```

### 原田宗資 / harada_munesuke.png

```text
Use case: stylized-concept. Create ONE square 1:1 transparent PNG officer bust for a historical strategy game. Contemporary photorealistic Japanese character art: natural skin pores, realistic eyes, woven fabric and detailed metal. Period costume, modern realistic rendering, NOT antique painting, NOT anime. Chest-up, hands and weapons OUTSIDE frame. Whole headgear/hair visible with at least 8 percent genuinely transparent top margin. One man only, coherent head-neck-torso orientation. Absolutely no text, writing, labels, watermark, UI, border, scenery, fog, invented crests or background. Image 1 is a visual reference: retain its distinctive facial structure, facial hair, headgear and costume cues, but freshly render as a realistic human with natural proportions. Harada Munesuke (Munetsugu), the man on the provided card. Translate the cartoon into a physically believable robust heavyset Japanese man: round broad cheeks, small eyes, wide nose, dark moustache, warm boisterous confident smile. Preserve blue and silver swirling-relief armor and distinctive black angular helmet with blue side panels. Keep proportionate human body, strong thick neck and broad shoulders. Chest-up with both arms lowered outside crop; no raised arm, spear, banner, letters or card border. Restrained believable metal ornament, not a robot.
```

### 原田宗輔 / harada_munesuke_kai.png

```text
Use case: stylized-concept. Create ONE square 1:1 transparent PNG officer bust for a historical strategy game. Contemporary photorealistic Japanese character art: natural skin pores, realistic eyes, woven fabric and detailed metal. Period costume, modern realistic rendering, NOT antique painting, NOT anime. Chest-up, hands and weapons OUTSIDE frame. Whole headgear/hair visible with at least 8 percent genuinely transparent top margin. One man only, coherent head-neck-torso orientation. Absolutely no text, writing, labels, watermark, UI, border, scenery, fog, invented crests or background. Image 1 is a STYLE/CLOTHING reference of a DIFFERENT person, not a facial identity reference. Create original Harada Munesuke (Kai, son of Harada Munesuke), an early Edo administrator. Distinct long oval clean-shaven face, high cheekbones, fine straight eyebrows, narrow calm eyes, slightly pursed lips. Japanese man about fifty, neatly shaved front crown with compact black chonmage. Dark indigo formal kataginu over muted pale blue kimono, plain fabric without crests, upright slim shoulders. Nearly frontal, thoughtful reserved expression, no scowl and no villain caricature. Do NOT copy reference face, beard, head shape or pose.
```

### 原胤従 / hara_taneyori.png

```text
Use case: stylized-concept. Create ONE square 1:1 transparent PNG officer bust for a historical strategy game. Contemporary photorealistic Japanese character art: natural skin pores, realistic eyes, woven fabric and detailed metal. Period costume, modern realistic rendering, NOT antique painting, NOT anime. Chest-up, hands and weapons OUTSIDE frame. Whole headgear/hair visible with at least 8 percent genuinely transparent top margin. One man only, coherent head-neck-torso orientation. Absolutely no text, writing, labels, watermark, UI, border, scenery, fog, invented crests or background. Image 1 is STYLE/ARMOR TEXTURE reference of a DIFFERENT person. Original Hara Taneyori, veteran spear captain: Japanese man around sixty with long rectangular face, prominent cheekbones, broad bridge of nose, patient narrow eyes, gray stubble and short gray mustache. Uncovered salt-and-pepper topknot with thinning crown, no helmet. Worn iron lamellar cuirass with subdued brown lacing, russet cloth vest, cream collar. Lean upright build, relaxed mouth and alert sidelong gaze in three-quarter view. Do not copy reference identity or headgear. No emblems.
```

### 原胤義 / hara_taneyoshi.png

```text
Use case: stylized-concept. Create ONE square 1:1 transparent PNG officer bust for a historical strategy game. Contemporary photorealistic Japanese character art: natural skin pores, realistic eyes, woven fabric and detailed metal. Period costume, modern realistic rendering, NOT antique painting, NOT anime. Chest-up, hands and weapons OUTSIDE frame. Whole headgear/hair visible with at least 8 percent genuinely transparent top margin. One man only, coherent head-neck-torso orientation. Absolutely no text, writing, labels, watermark, UI, border, scenery, fog, invented crests or background. Image 1 is RENDERING/MATERIAL reference of a DIFFERENT person. Original Hara Taneyoshi of the Shimosa Hara clan: Japanese adult late twenties to early thirties, delicate triangular face, high smooth forehead, thin arched eyebrows, close-set thoughtful eyes, narrow straight nose, clean-shaven small chin, quiet serious expression. Black hair in neat modest topknot, no helmet. Moss-green silk outer garment over subdued dark bronze lamellar armor and pale beige collar. Slim shoulders turned slightly sideways, face looks gently toward viewer, anatomically aligned. Do not use reference face, crescent, helmet or golden armor. No invented family crest.
```

### 原虎吉 / hara_torayoshi.png

```text
Use case: stylized-concept. Create ONE square 1:1 transparent PNG officer bust for a historical strategy game. Contemporary photorealistic Japanese character art: natural skin pores, realistic eyes, woven fabric and detailed metal. Period costume, modern realistic rendering, NOT antique painting, NOT anime. Chest-up, hands and weapons OUTSIDE frame. Whole headgear/hair visible with at least 8 percent genuinely transparent top margin. One man only, coherent head-neck-torso orientation. Absolutely no text, writing, labels, watermark, UI, border, scenery, fog, invented crests or background. Image 1 is RENDERING/TEXTILE reference of Hara Toratane, a DIFFERENT person. Original Hara Torayoshi: sturdy mature Japanese man about fifty, round-square face, thick straight eyebrows, wide-set eyes with smile lines, broad flat nose, clean-shaven cheeks, tiny gray soul patch only, firm calm mouth. Plain low black iron jingasa helmet without crests, pale gray chin tie, simple black armor with burgundy lacing over faded brown sleeves. Broad shoulders in three-quarter view, composed protective bearing. Do NOT copy reference face, hood or beard; no white hood, no invented emblems.
```

## 検証

10枚の生成・登録完了。全画像1254×1254の32bit ARGB PNG、上隅のalpha=0と中央が不透明であることを検証。目視で文字なし、現代的な人物描写、頭と身体の整合、頭部が枠内に収まることを確認。画像は加工せず原本をコピーし、アルファを維持。

## 生成原本（保存維持）

Windows検証: `python tools/export_windows_release.py` 成功（exit 0、error_lines空）。EXE/PCKを `builds/windows-latest/` へ書き出し。リリースEXEを `--quit-after 120` で起動しexit 0、起動ログにエラーなし。ログ: `builds/windows-latest/portraits-batch35-startup.log`。10件のID登録がそれぞれ1件であることと、全PNGのimport生成を検証。`git diff --check -- scripts/game/officer_portraits.gd` 成功。個別の武将詳細画面を開く操作確認は未実施。

- nanbu_harumasa.png: `C:\Users\nanoa\.codex\generated_images\01a0c84d-d157-7500-a5e1-c9eb55e0ca04\exec-9f080866-d7d4-4492-b592-52042512b2bf.png`
- hara_masatane.png: `C:\Users\nanoa\.codex\generated_images\01a0c84d-d157-7500-a5e1-c9eb55e0ca04\exec-037fdb34-cadc-4fea-8316-5355b26b1fda.png`
- harada_munetoki.png: `C:\Users\nanoa\.codex\generated_images\01a0c84d-d157-7500-a5e1-c9eb55e0ca04\exec-87ef3a58-7563-4a43-9890-6d0b095a5c38.png`
- hara_toratane.png: `C:\Users\nanoa\.codex\generated_images\01a0c84d-d157-7500-a5e1-c9eb55e0ca04\exec-cf1931cc-d46b-46e8-ab7e-6b9ec5b9b44b.png`
- hara_nagayori.png: `C:\Users\nanoa\.codex\generated_images\01a0c84d-d157-7500-a5e1-c9eb55e0ca04\exec-275ca4f6-a4e6-455a-a16d-611b3df0d558.png`
- harada_munesuke.png: `C:\Users\nanoa\.codex\generated_images\01a0c84d-d157-7500-a5e1-c9eb55e0ca04\exec-e4fd346e-acbc-430e-9fda-a82f9c4781ce.png`
- harada_munesuke_kai.png: `C:\Users\nanoa\.codex\generated_images\01a0c84d-d157-7500-a5e1-c9eb55e0ca04\exec-aba9c775-c7cb-4e65-8fa7-b76208f2d7aa.png`
- hara_taneyori.png: `C:\Users\nanoa\.codex\generated_images\01a0c84d-d157-7500-a5e1-c9eb55e0ca04\exec-f040224a-9945-40e8-9d26-2bcc33ffad9e.png`
- hara_taneyoshi.png: `C:\Users\nanoa\.codex\generated_images\01a0c84d-d157-7500-a5e1-c9eb55e0ca04\exec-bdd287ff-438b-4b4b-b2bc-e426b7527d3d.png`
- hara_torayoshi.png: `C:\Users\nanoa\.codex\generated_images\01a0c84d-d157-7500-a5e1-c9eb55e0ca04\exec-0dbabd20-88fe-4e27-be75-398ca07df714.png`
