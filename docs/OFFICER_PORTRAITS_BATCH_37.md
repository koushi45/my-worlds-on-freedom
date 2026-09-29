# 武将肖像 Batch 37

## 制作条件と状態

2026-09-27。imagegen スキルの built-in image_gen モードで、1名1画像として生成。検索した参照画像を実際に閲覧し、画像入力として直接指定した。特徴のみ参考にし、現代的・写実的な人物画に再構成。文字なし、正方形、実アルファ透過PNG。生成後の画像加工は行わず、選定ファイルをそのままコピーした。

7名を登録。吉田弥三・和仁親宗・和田信維は本人と確認できる現代ゲーム画像を見つけられず、創作肖像で制作するか質問中のため未生成・未登録。過去バッチの創作承認を今回の3名には適用しない。

ゲーム絵は史実の容貌の証拠ではない。吉田長利の参照はファン作成の登録武将用画像で、公式の本人専用肖像とは未確認。

## 参照と保存先

|人物|ID|PNG（assets/officers/portraits/）|参照種別・出典|
|---|---|---|---|
|吉良義堯|officer_q11414257|kira_yoshitaka.png|新生ゲーム画像（掲載名：吉良義尭）：[掲載ページ](https://altema.jp/nobunagashinsei/busyo/775)|
|吉良義安|officer_q11414260|kira_yoshiyasu.png|新生ゲーム画像（別掲載の人物名でも照合）：[掲載ページ](https://altema.jp/nobunagashinsei/busyo/776)|
|吉良親貞|officer_q9605578|kira_chikasada.png|新生ゲーム画像：[掲載ページ](https://altema.jp/nobunagashinsei/busyo/773)|
|吉見正頼|officer_q10917380|yoshimi_masayori.png|新生ゲーム画像：[掲載ページ](https://altema.jp/nobunagashinsei/busyo/2163)|
|和田惟政|officer_q7958925|wada_koremasa.png|信長の野望 出陣ゲーム画像：[掲載ページ](https://gamewith.jp/nobunaga-shutsujin/article/show/413459)|
|吉田長利|officer_q24885353|yoshida_nagatoshi.png|ユーザー作成の登録武将用画像（公式の本人専用画とは未確認）：[掲載ページ](https://shinsei.eich516.com/?p=2494)|
|和智誠春|officer_q7958754|wachi_masaharu.png|創造PKゲーム画像：[掲載ページ](https://ameblo.jp/tetu522/entry-12042969643.html)|

吉良義堯は掲載名「吉良義尭」を確認。吉良義安は [別掲載](https://gwynt.liblo.jp/archives/%E6%96%B0%E6%AD%A6%E5%B0%86%20%E5%90%89%E8%89%AF%E7%BE%A9%E5%AE%89.html) の本人名付き画像でも照合。

参照素材は C:/Users/nanoa/AppData/Local/Temp/officer_refs_batch37/ に取得。アルテマの画像は `https://img.altema.jp/nobunagashinsei/busyo/banner/{773,775,776,2163}.jpg`、顔部分（180,62,120,120）を切り出して入力した。

追加参照画像URL：

- 吉田長利：https://shinsei.eich516.com/wp-content/uploads/2024/04/吉田長利.jpg
- 和智誠春：https://stat.ameba.jp/user_images/20150625/11/tetu522/20/49/j/o0595031713347320004.jpg （左上の肖像部分を参照）
- 和田惟政：https://img.gamewith.jp/service/hd/images/e076f361aa3b3a2bc7ee61c95d8da13a.png

## 最終プロンプトセット

以下を各1回、記載の参照画像と共に入力。吉良義堯と吉田長利のみ頭上余白を追加修正し、その結果を採用した。

### 吉良義堯

入力画像：`775-ref.png`

```text
Use case: stylized-concept. ONE square 1:1 game officer bust, true alpha transparent PNG. Modern photorealistic Japanese human portrait, realistic skin pores and eyes, fabric weave and metal; period attire but NOT antique painting or anime. Chest-up, hands and weapons excluded. Entire headgear and hair visible with clear transparent space above. Coherent head/neck/torso anatomy. No text, symbols resembling writing, UI, card border, scenery, fog, watermark or invented family crests. Image 1 is a GAME DESIGN reference, not a historical likeness: strongly preserve distinguishing facial proportions, facial hair, colors and headwear, rendered afresh in modern realistic style. Kira Yoshitaka: angular long face, prominent cheekbones, stern narrow eyes and furrowed brow, straight mustache and pointed dark beard. High upright black topknot, no helmet. Muted purple silk robe and ivory crossed collars. Near frontal composed bust, mature man around forty-five.
```

選定元：`C:\Users\nanoa\.codex\generated_images\01a0c84d-d157-7500-a5e1-c9eb55e0ca04\exec-5562184b-c4e8-4dbc-aef0-11281f59a044.png`

### 吉良義安

入力画像：`776-ref.png`

```text
Use case: stylized-concept. ONE square 1:1 game officer bust, true alpha transparent PNG. Modern photorealistic Japanese human portrait, realistic skin pores and eyes, fabric weave and metal; period attire but NOT antique painting or anime. Chest-up, hands and weapons excluded. Entire headgear and hair visible with clear transparent space above. Coherent head/neck/torso anatomy. No text, symbols resembling writing, UI, card border, scenery, fog, watermark or invented family crests. Image 1 is a GAME DESIGN reference, not a historical likeness: strongly preserve distinguishing facial proportions, facial hair, colors and headwear, rendered afresh in modern realistic style. Kira Yoshiyasu: youthful narrow oval face, finely arched brows, a small thin mustache, no chin beard; concerned attentive eyes. Tousled topknot with dark plain metal forehead band. Sage green garment, off-white collar, modest lamellar chest armor with gold cord fastenings. Slight three-quarter bust, head and shoulders consistent. Do not include the reference's raised hand.
```

選定元：`C:\Users\nanoa\.codex\generated_images\01a0c84d-d157-7500-a5e1-c9eb55e0ca04\exec-e1bc7cf7-e561-4972-bfe7-5e59c4ef827a.png`

### 吉良親貞

入力画像：`773-ref.png`

```text
Use case: stylized-concept. ONE square 1:1 game officer bust, true alpha transparent PNG. Modern photorealistic Japanese human portrait, realistic skin pores and eyes, fabric weave and metal; period attire but NOT antique painting or anime. Chest-up, hands and weapons excluded. Entire headgear and hair visible with clear transparent space above. Coherent head/neck/torso anatomy. No text, symbols resembling writing, UI, card border, scenery, fog, watermark or invented family crests. Image 1 is a GAME DESIGN reference, not a historical likeness: strongly preserve distinguishing facial proportions, facial hair, colors and headwear, rendered afresh in modern realistic style. Kira Chikasada: broad forceful face, thick sharply angled eyebrows, piercing eyes, short mustache and tightly trimmed chin beard, powerful neck. Large black kabuto with prominent rounded gold U-shaped crest, metallic segmented side guards, red laced armor and gold fittings. Slightly forward confident posture, looking toward viewer. Entire helmet and crest must fit with top clearance.
```

選定元：`C:\Users\nanoa\.codex\generated_images\01a0c84d-d157-7500-a5e1-c9eb55e0ca04\exec-a9acce90-35cd-4261-a45b-59ca3a4c0fc4.png`

### 吉見正頼

入力画像：`2163-ref.png`

```text
Use case: stylized-concept. ONE square 1:1 game officer bust, true alpha transparent PNG. Modern photorealistic Japanese human portrait, realistic skin pores and eyes, fabric weave and metal; period attire but NOT antique painting or anime. Chest-up, hands and weapons excluded. Entire headgear and hair visible with clear transparent space above. Coherent head/neck/torso anatomy. No text, symbols resembling writing, UI, card border, scenery, fog, watermark or invented family crests. Image 1 is a GAME DESIGN reference, not a historical likeness: strongly preserve distinguishing facial proportions, facial hair, colors and headwear, rendered afresh in modern realistic style. Yoshimi Masayori: long intelligent face with a long straight nose, lifted brows, neat narrow mustache and slender pointed beard. Black folded soft cap with light gray wrapped band, long dark hair down the back. Brick-red sleeveless outer robe over restrained dark lamellar armor and pale inner collar. Three-quarter gaze to image left; shoulders aligned with head. Calm mature forty-something face.
```

選定元：`C:\Users\nanoa\.codex\generated_images\01a0c84d-d157-7500-a5e1-c9eb55e0ca04\exec-8e3bc92b-18a2-474a-9b6e-a420d4eb09c1.png`

### 和田惟政

入力画像：`wada_koremasa-ref.png`

```text
Use case: stylized-concept. ONE square 1:1 game officer bust, true alpha transparent PNG. Modern photorealistic Japanese human portrait, realistic skin pores and eyes, fabric weave and metal; period attire but NOT antique painting or anime. Chest-up, hands and weapons excluded. Entire headgear and hair visible with clear transparent space above. Coherent head/neck/torso anatomy. No text, symbols resembling writing, UI, card border, scenery, fog, watermark or invented family crests. Image 1 is a GAME DESIGN reference, not a historical likeness: strongly preserve distinguishing facial proportions, facial hair, colors and headwear, rendered afresh in modern realistic style. Wada Koremasa: strongly receding shaved pate with black side hair and small vertical topknot, very angular long face, sharp slanted eyebrows, intense deep-set eyes, hooked straight nose, narrow black mustache without beard. Dark brown kimono with muted green sleeveless vest, wide pale gray-white lapels and gray horizontal bands. Lean build, stern head tilted slightly down while eyes look up. Keep skull anatomy natural.
```

選定元：`C:\Users\nanoa\.codex\generated_images\01a0c84d-d157-7500-a5e1-c9eb55e0ca04\exec-7dee393a-1933-435a-8a3e-ce198e2ea442.png`

### 吉田長利

入力画像：`yoshida_nagatoshi-ref.jpg`

```text
Use case: stylized-concept. ONE square 1:1 game officer bust, true alpha transparent PNG. Modern photorealistic Japanese human portrait, realistic skin pores and eyes, fabric weave and metal; period attire but NOT antique painting or anime. Chest-up, hands and weapons excluded. Entire headgear and hair visible with clear transparent space above. Coherent head/neck/torso anatomy. No text, symbols resembling writing, UI, card border, scenery, fog, watermark or invented family crests. Image 1 is a GAME DESIGN reference, not a historical likeness: strongly preserve distinguishing facial proportions, facial hair, colors and headwear, rendered afresh in modern realistic style. Yoshida Nagatoshi: refer to this user-created officer design. Broad jaw, full cheekbones, thick eyebrows, wide alert eyes, flared thin mustache and a long pointed chin beard. Voluminous dark ponytail and cream headband with blue-gray studded forehead plate. Black lacquer shoulder armor with red cords, bronze chest edging, patterned charcoal inner fabric. A muscular mature man, three-quarter bust toward image left; avoid copying painterly surface, render realistic skin.
```

選定元：`C:\Users\nanoa\.codex\generated_images\01a0c84d-d157-7500-a5e1-c9eb55e0ca04\exec-1025efe6-5001-414f-9452-2bca4d1f759f.png`

### 和智誠春

入力画像：`wachi_masaharu-ref.png`

```text
Use case: stylized-concept. ONE square 1:1 game officer bust, true alpha transparent PNG. Modern photorealistic Japanese human portrait, realistic skin pores and eyes, fabric weave and metal; period attire but NOT antique painting or anime. Chest-up, hands and weapons excluded. Entire headgear and hair visible with clear transparent space above. Coherent head/neck/torso anatomy. No text, symbols resembling writing, UI, card border, scenery, fog, watermark or invented family crests. Image 1 is a GAME DESIGN reference, not a historical likeness: strongly preserve distinguishing facial proportions, facial hair, colors and headwear, rendered afresh in modern realistic style. Wachi Masaharu: middle-aged, broad long rectangular face, slightly heavy cheeks, narrow watchful eyes, straight dark eyebrows, downturned lips and cleft chin, NO facial hair. Black hair gathered in a high compact topknot. Teal-blue silk outer robe, gray-beige crossed collars. Plain civilian-style samurai robe rather than armor. Near-frontal erect bust looking slightly to image right, subdued calculating expression.
```

選定元：`C:\Users\nanoa\.codex\generated_images\01a0c84d-d157-7500-a5e1-c9eb55e0ca04\exec-76366186-5ce8-4006-ad47-0c391f8f5c6a.png`

### 余白修正

吉良義堯の初回生成画像を編集対象として入力：

```text
Use case: identity-preserve. Edit Image 1 only by adjusting framing: show his ENTIRE topknot with a clear 7 percent transparent margin above it. Zoom the same bust out slightly and place lower; natural shoulders continue to bottom. Keep precisely the same Japanese man's facial identity, stern expression, purple robe, beard, lighting and photorealistic finish. No new props, no text. Square 1:1 PNG with genuine alpha transparency. Do not crop the top of the hair.
```

吉田長利の初回生成画像を編集対象として入力：

```text
Use case: identity-preserve. Edit Image 1 only by adjusting framing: show the ENTIRE ponytail and top of his hair with a clear 7 percent transparent margin above. Zoom the same bust out slightly and place lower, shoulders continue naturally to bottom. Keep exactly this Japanese man's facial identity, expression, blue studded headband, long pointed beard, black armor with red cords and bronze chest trim, same pose, lighting and modern photorealistic finish. No new props, no text. Square 1:1 PNG with genuine alpha transparency. Do not clip hair at any edge.
```

## 検証

- 7点とも1254×1254、Format32bppArgb。両上隅はアルファ0、中央は不透明を確認。
- 生成画像を目視し、文字なし、顔・首・胴の整合、髷・兜が画面内に入ることを確認。手は構図外。
- 既存PNG・既存IDとの衝突なしを確認後、専用マッピングへ追加。
- Windowsリリースビルド：終了コード0、error_linesなし。EXE/PCKの書き出しを確認。
- 7件のマッピング一意性とPNGインポートを確認。git diff --checkでエラーなし。
- Windows版を --quit-after 120 で起動、終了コード0。起動ログ：builds/windows-latest/portraits-batch37-startup.log。武将個別画面の全件目視テストは未実施。
