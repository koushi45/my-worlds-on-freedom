# 武将肖像 Batch 38

## 状態・制作方法

2026-09-27。imagegen スキルの built-in image_gen モードで個別生成。検索した実画像を閲覧した後、参照画像として直接入力。人物ごとの輪郭・表情・髪型・衣装を保持しつつ現代的な写実画へ再構成した。正方形・文字なし・実アルファ透過PNG。生成結果を加工せず、採用ファイルをコピーしてゲームへ登録。

7名登録済み。喜多村政信（officer_q109288049）・国分盛廉（officer_q11420554）・国富貞次（officer_q124426307）は、本人と確認できる現代的ゲーム肖像を見つけられず創作制作の可否を質問中。回答前のため未生成・未登録。国富貞次は旧作登場の記述はあるが、適切な参照画像の確認には至らなかった。過去の他人物への創作承認は今回には流用しない。

ゲーム画像は史実の容貌を証明する資料ではない。品川将員は別名「品川大膳」で検索。喜入季久は「太閤VDX vol.32」の本人名付き掲載画像を使用し、公式の原画出典までは断定しない。

## 参照・保存先

PNGはすべて assets/officers/portraits/ 以下。

|人物|ID|PNG|参照|
|---|---|---|---|
|和賀義忠|officer_q108781568|waga_yoshitada.png|[新生](https://altema.jp/nobunagashinsei/busyo/2185)|
|品川将員|officer_q7497244|shinagawa_masakazu.png|[100万人の信長の野望・品川大膳として掲載](https://uu.getuploader.com/sengoku101/download/30)|
|唐沢玄蕃|officer_q6368627|karasawa_genba.png|[覇道](https://gamewith.jp/nobunaga-hadou/article/show/515271)|
|喜入季久|officer_q11162231|kiire_suehisa.png|[太閤VDX向け掲載画像](https://ameblo.jp/tetu522/entry-12885882407.html)|
|国分盛氏|officer_q11420557|kokubun_moriuji.png|[新生](https://altema.jp/nobunagashinsei/busyo/861)|
|国分盛顕|officer_q11420562|kokubun_moriaki.png|[新生](https://altema.jp/nobunagashinsei/busyo/860)|
|国司元相|officer_q6444764|kunishi_motosuke.png|[新生](https://altema.jp/nobunagashinsei/busyo/792)|

参照の一時保存先：C:/Users/nanoa/AppData/Local/Temp/officer_refs_batch38/

- 新生画像：`https://img.altema.jp/nobunagashinsei/busyo/banner/{2185,861,860,792}.jpg` の顔部分（180,62,120,120）を切り出して参照。
- 唐沢玄蕃：https://img.gamewith.jp/img/908ba7a8c1dccaf22cfb5ba941c33298.png
- 喜入季久：https://stat.ameba.jp/user_images/20250210/13/tetu522/52/f7/j/o0341034115542665518.jpg
- 品川大膳：https://downloadx.getuploader.com/g/sengoku101/30/%E5%93%81%E5%B7%9D%E5%A4%A7%E8%86%B3.jpg

## プロンプトセットと選定元

### 和賀義忠

参照：`2185-ref.png`

```text
Use case: stylized-concept. Generate ONE square 1:1 officer portrait PNG with genuine alpha-transparent background. Modern photorealistic Japanese person, realistic skin pores, individual facial anatomy, natural eyes, detailed cloth and metal. Period costume but not antique painting, not anime. Image 1 is the named officer's GAME DESIGN reference, not historical proof of likeness. Strongly retain its individual facial proportions, hairstyle, beard, clothing colors and headgear, reinterpreted in modern realism. Chest-up bust, hands and weapons out of frame. Keep entire headgear/hair inside image with 7 percent transparent space above. Anatomically consistent head, neck and torso. No text, Japanese writing, logos, card frames, watermark, scenery or fog. Waga Yoshitada: rugged broad jaw, mustache connected to close jaw beard, wide thoughtful eyes gazing slightly upwards to image right. Low dark riveted kabuto, broad segmented neck guards, brown-plum lamellar armor with yellow-gold cords and dark blue collar. Mature weathered face, sturdy neck. Confident upright three-quarter bust.
```

採用元：`C:\Users\nanoa\.codex\generated_images\01a0c84d-d157-7500-a5e1-c9eb55e0ca04\exec-88c6d78b-9237-48da-adee-bbd305f98ca1.png`

### 品川将員

参照：`shinagawa_masakazu-ref.jpg`

```text
Use case: stylized-concept. Generate ONE square 1:1 officer portrait PNG with genuine alpha-transparent background. Modern photorealistic Japanese person, realistic skin pores, individual facial anatomy, natural eyes, detailed cloth and metal. Period costume but not antique painting, not anime. Image 1 is the named officer's GAME DESIGN reference, not historical proof of likeness. Strongly retain its individual facial proportions, hairstyle, beard, clothing colors and headgear, reinterpreted in modern realism. Chest-up bust, hands and weapons out of frame. Keep entire headgear/hair inside image with 7 percent transparent space above. Anatomically consistent head, neck and torso. No text, Japanese writing, logos, card frames, watermark, scenery or fog. Shinagawa Masakazu / Daizen: youthful long narrow face with strong sharply slanted eyebrows, narrow focused eyes, high cheekbones, closed fine lips, absolutely no beard or mustache. Tall black ponytail with pale blue tie, a simple white forehead band. Pale blue-gray robe and white crossed collar. Frontal erect bust, slightly sideways focused gaze, lean youthful build. Exclude all reference frame and symbols.
```

採用元：`C:\Users\nanoa\.codex\generated_images\01a0c84d-d157-7500-a5e1-c9eb55e0ca04\exec-b3879891-a3bb-4331-8e39-de18fc9e5b0b.png`

### 唐沢玄蕃

参照：`karasawa_genba-ref.png`

```text
Use case: stylized-concept. Generate ONE square 1:1 officer portrait PNG with genuine alpha-transparent background. Modern photorealistic Japanese person, realistic skin pores, individual facial anatomy, natural eyes, detailed cloth and metal. Period costume but not antique painting, not anime. Image 1 is the named officer's GAME DESIGN reference, not historical proof of likeness. Strongly retain its individual facial proportions, hairstyle, beard, clothing colors and headgear, reinterpreted in modern realism. Chest-up bust, hands and weapons out of frame. Keep entire headgear/hair inside image with 7 percent transparent space above. Anatomically consistent head, neck and torso. No text, Japanese writing, logos, card frames, watermark, scenery or fog. Karasawa Genba: lean angular fierce face, sharp cheekbones and deep brow, dark narrow eyes, short trimmed beard along jaw ending in a pointed chin, fine mustache. Swept black hair in long high ponytail bound with red cord. Rust-brown rough layered ninja robe with charcoal scarf collar. Change the jumping/crouching reference to a stable dynamic three-quarter chest-up stance: shoulders leaning slightly forward, head aligned, looking up with sly confidence. Ponytail fully visible, no weapons or hands.
```

採用元：`C:\Users\nanoa\.codex\generated_images\01a0c84d-d157-7500-a5e1-c9eb55e0ca04\exec-62e6c29f-46ff-496e-957b-3016022cabcb.png`

### 喜入季久

参照：`kiire_suehisa-ref.jpg`

```text
Use case: stylized-concept. Generate ONE square 1:1 officer portrait PNG with genuine alpha-transparent background. Modern photorealistic Japanese person, realistic skin pores, individual facial anatomy, natural eyes, detailed cloth and metal. Period costume but not antique painting, not anime. Image 1 is the named officer's GAME DESIGN reference, not historical proof of likeness. Strongly retain its individual facial proportions, hairstyle, beard, clothing colors and headgear, reinterpreted in modern realism. Chest-up bust, hands and weapons out of frame. Keep entire headgear/hair inside image with 7 percent transparent space above. Anatomically consistent head, neck and torso. No text, Japanese writing, logos, card frames, watermark, scenery or fog. Kiire Suehisa: slim long face, high cheekbones, curved thin brows, attentive narrow eyes, small fine mustache, no chin beard. Glossy black hair pulled into short upright topknot, no headband. Muted ochre-gold brocade robe with fine botanical weave and gray inner collar. Calm three-quarter bust facing image left. Hands omitted, preserve distinctive delicate facial structure.
```

採用元：`C:\Users\nanoa\.codex\generated_images\01a0c84d-d157-7500-a5e1-c9eb55e0ca04\exec-c0099d64-62bc-40ed-9777-aefe025fdedb.png`

### 国分盛氏

参照：`861-ref.png`

```text
Use case: stylized-concept. Generate ONE square 1:1 officer portrait PNG with genuine alpha-transparent background. Modern photorealistic Japanese person, realistic skin pores, individual facial anatomy, natural eyes, detailed cloth and metal. Period costume but not antique painting, not anime. Image 1 is the named officer's GAME DESIGN reference, not historical proof of likeness. Strongly retain its individual facial proportions, hairstyle, beard, clothing colors and headgear, reinterpreted in modern realism. Chest-up bust, hands and weapons out of frame. Keep entire headgear/hair inside image with 7 percent transparent space above. Anatomically consistent head, neck and torso. No text, Japanese writing, logos, card frames, watermark, scenery or fog. Kokubun Moriuji: older middle-aged broad square face, strong rectangular jaw, thick dark horizontal eyebrows, narrowed eyes, short broad mustache but clean chin. Traditional low black folded cap. Earthy ochre-brown robe, charcoal gray and ivory crossed collars. Near frontal upright bust and firm closed mouth, sober authority. Not a young model.
```

採用元：`C:\Users\nanoa\.codex\generated_images\01a0c84d-d157-7500-a5e1-c9eb55e0ca04\exec-7a5e6de1-3f37-48a2-8d67-3c80d5bd65ca.png`

### 国分盛顕

参照：`860-ref.png`

```text
Use case: stylized-concept. Generate ONE square 1:1 officer portrait PNG with genuine alpha-transparent background. Modern photorealistic Japanese person, realistic skin pores, individual facial anatomy, natural eyes, detailed cloth and metal. Period costume but not antique painting, not anime. Image 1 is the named officer's GAME DESIGN reference, not historical proof of likeness. Strongly retain its individual facial proportions, hairstyle, beard, clothing colors and headgear, reinterpreted in modern realism. Chest-up bust, hands and weapons out of frame. Keep entire headgear/hair inside image with 7 percent transparent space above. Anatomically consistent head, neck and torso. No text, Japanese writing, logos, card frames, watermark, scenery or fog. Kokubun Moriaki: distinct long balding forehead and small topknot, black side hair, eyebrows raised at center, slightly drooping wide eyes, long nose, small sparse mustache and short uneven chin beard. Slightly open lips as in reference but natural dignified realism, not a caricature. Gray-brown patterned robe and desaturated blue collars. Lean three-quarter bust facing image left, slightly hesitant thoughtful expression.
```

採用元：`C:\Users\nanoa\.codex\generated_images\01a0c84d-d157-7500-a5e1-c9eb55e0ca04\exec-5c71f3f6-c759-487e-97e7-6252f4702e41.png`

### 国司元相

参照：`792-ref.png`

```text
Use case: stylized-concept. Generate ONE square 1:1 officer portrait PNG with genuine alpha-transparent background. Modern photorealistic Japanese person, realistic skin pores, individual facial anatomy, natural eyes, detailed cloth and metal. Period costume but not antique painting, not anime. Image 1 is the named officer's GAME DESIGN reference, not historical proof of likeness. Strongly retain its individual facial proportions, hairstyle, beard, clothing colors and headgear, reinterpreted in modern realism. Chest-up bust, hands and weapons out of frame. Keep entire headgear/hair inside image with 7 percent transparent space above. Anatomically consistent head, neck and torso. No text, Japanese writing, logos, card frames, watermark, scenery or fog. Kunishi Motosuke: older weathered face with wrinkles around narrow eyes, pronounced cheekbones and broad nose, salt-and-pepper mustache and jaw beard. Rounded blue-black ridged kabuto with dark side guards. Blue-gray armor, muted red cords, teal-blue cloth and white collar. Proud three-quarter pose looking image left, faint confident smile, mature broad build.
```

採用元：`C:\Users\nanoa\.codex\generated_images\01a0c84d-d157-7500-a5e1-c9eb55e0ca04\exec-b0203b1c-7e2d-4ae7-98b9-87fb91ce8fef.png`

### 頭上余白の修正

唐沢玄蕃・喜入季久・国分盛氏は初回生成画像を編集対象として次のプロンプトを各1回入力し、その結果を採用。

```text
Use case: identity-preserve. Edit Image 1: change ONLY the framing to fit the entire hair and hat silhouette well inside the square. Zoom out the same bust 15 percent and position lower, leaving a definite 8 percent fully transparent space above the highest hair/hat point. Keep exactly the same face, expression, clothing, hair, pose, materials and realistic style. Shoulders continue naturally to bottom. No text, no new props. 1:1 PNG with genuine alpha-transparent background.
```

## 検証

- 7点とも1254×1254・Format32bppArgb、両上隅アルファ0・中央不透明を確認。
- 目視で文字なし、頭部の欠けなし、顔・首・胴の整合を確認。手と武器は構図外。
- 既存PNG・IDと衝突しないことを確認して追加。
- 7件のIDマッピング一意性とPNGインポートを確認。git diff --checkエラーなし。
- Windowsリリースビルド終了コード0、error_linesなし。EXE/PCKの書き出しを確認。
- Windows版を --quit-after 120 で起動、終了コード0。起動ログ：builds/windows-latest/portraits-batch38-startup.log。個別武将画面の全件目視テストは未実施。
