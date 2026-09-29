# 武将肖像 Batch 33

## 仕様と制作方法

- 2026-09-26。内蔵 image_gen（参照画像入力による新規生成）を使用。CLI/APIは未使用。
- 文字なし、現代的でリアルな人物画、正方形、背景透過PNG。
- 保存先: `C:/Users/nanoa/projects/my-worlds-on-freedom/assets/officers/portraits/`
- Web検索・画像検索で候補を調査し、人物名が表示された記事と画像を照合。ローカルで画像を目視してから生成入力に使用。
- 検索時は名前に「信長の野望」「顔グラ」「画像」「イラスト」などを併記。無関係な人物・息子・同名人物の画像は本人の根拠として採用しない。
- 十河景滋はゲーム内の別名・十河存春を採用（ゲームデータの人物解説にも「存春とも」と記載）。
- 千本資俊・千種忠治はユーザー作成武将の画像。公式専用顔画像または史実の容貌とは断定しない。
- 千徳政武は『津軽為信統一記』制作記事のカード画像。動物キャラクターの甲冑色・形だけを参考にして人間に再構成。顔は創作。
- 千々石直員・千坂長朝・千本義隆は本人と確認できる顔画像が見つからず、別人物の画像を画風・衣装材質だけの参考に使用。顔立ちは創作。3名を「本人画像に基づく」とは扱わない。

## 参照元と保存名

|人物|ファイル|参照の扱い|記事URL|入力画像|
|---|---|---|---|---|
|十河一存|sogo_kazumasa.png|本人のゲーム顔画像|https://altema.jp/nobunagashinsei/busyo/1179|1179-ref.png|
|十河景滋|sogo_kageshige.png|別名・十河存春のゲーム顔画像|https://altema.jp/nobunagashinsei/busyo/1180|1180-ref.png|
|千坂景親|chisaka_kagechika.png|本人のゲーム顔画像|https://altema.jp/nobunagashinsei/busyo/1300|1300-ref.png|
|千本資俊|senbon_suketoshi.png|ユーザー作成武将画像（公式専用顔の確認なし）|https://ameblo.jp/tetu522/entry-12616581925.html|senbon-ref.png|
|千種忠治|chigusa_tadaharu.png|ユーザー作成武将画像（公式専用顔の確認なし）|https://www.ear-phone-review.com/entry/2019/03/12/【コラム】信長の野望・大志PK_新武将作成_長野氏|chigusa-ref.png|
|千秋季忠|senshu_suetada.png|『戦魂』本人画像の特徴参照|https://dengekionline.com/elem/000/001/016/1016824/|senshu-ref.png|
|千徳政武|sentoku_masatake.png|『津軽為信統一記』カードの甲冑のみ参照（人物の顔は創作）|https://note.com/tsukerat_games/n/n7773d2c7a142|sentoku-card.png|
|千々石直員|chijiwa_naokazu.png|別人物画像を画風・甲冑の質感のみ参照（顔は創作）|https://altema.jp/nobunagashinsei/busyo/1179|1179-ref.png|
|千坂長朝|chisaka_nagatomo.png|別人物画像を画風・甲冑の質感のみ参照（顔は創作）|https://altema.jp/nobunagashinsei/busyo/1300|1300-ref.png|
|千本義隆|senbon_yoshitaka.png|別人物画像を画風・布の質感のみ参照（顔は創作）|https://www.ear-phone-review.com/entry/2019/03/12/【コラム】信長の野望・大志PK_新武将作成_長野氏|chigusa-ref.png|

参照用切り出し画像は `C:/Users/nanoa/AppData/Local/Temp/officer_refs_batch33/` に保存（ゲームには含めない）。元画像の名前欄等は参照準備時に除外。生成PNGは後処理で背景削除や拡大縮小をせず、生成されたアルファを維持してコピーする。

## 最終生成プロンプト

### 十河一存 / sogo_kazumasa.png

```text
Use case: stylized-concept. Asset: one officer bust icon for a modern historical strategy game. Square 1:1 PNG with genuinely transparent alpha background. Contemporary photorealistic character illustration, natural Japanese facial anatomy, detailed skin texture and realistic cloth and armor. Period costume, modern rendering, NOT an antique painting, NOT anime. One human only. No text of any language, writing, logos, watermarks, frames, scenery, weapons or hands. Entire headgear and hair must fit within canvas with at least 8% transparent top margin. Head, neck and torso must be anatomically coherent. Waist-up or chest-up cutout. Input image: character reference for Sogo Kazumasa. Strongly retain the broad fierce young angular face, taut cheeks, thick arched eyebrows, clean-shaven jaw, lifted energetic black ponytail, and scarlet coat over black and gold armor. Mouth closed in a tense determined expression; head and shoulders in matching three-quarter view. Translate these distinctive traits to cinematic natural realism rather than copying pixels.
```

### 十河景滋 / sogo_kageshige.png

```text
Use case: stylized-concept. Asset: one officer bust icon for a modern historical strategy game. Square 1:1 PNG with genuinely transparent alpha background. Contemporary photorealistic character illustration, natural Japanese facial anatomy, detailed skin texture and realistic cloth and armor. Period costume, modern rendering, NOT an antique painting, NOT anime. One human only. No text of any language, writing, logos, watermarks, frames, scenery, weapons or hands. Entire headgear and hair must fit within canvas with at least 8% transparent top margin. Head, neck and torso must be anatomically coherent. Waist-up or chest-up cutout. Input image: character reference for Sogo Kageshige, also called Masuharu. Strongly retain this mature stocky man's wide heavy face, broad low cheekbones, furrowed forehead, compact mouth, thick eyebrows, lightly graying short side hair, uneven high topknot and no beard. Keep charcoal outer robe, muted green inner garment and violet collar. Calm but obstinate expression, slight three-quarter head and shoulder angle. Realistic natural skin and cloth.
```

### 千坂景親 / chisaka_kagechika.png

```text
Use case: stylized-concept. Asset: one officer bust icon for a modern historical strategy game. Square 1:1 PNG with genuinely transparent alpha background. Contemporary photorealistic character illustration, natural Japanese facial anatomy, detailed skin texture and realistic cloth and armor. Period costume, modern rendering, NOT an antique painting, NOT anime. One human only. No text of any language, writing, logos, watermarks, frames, scenery, weapons or hands. Entire headgear and hair must fit within canvas with at least 8% transparent top margin. Head, neck and torso must be anatomically coherent. Waist-up or chest-up cutout. Input image: character reference for Chisaka Kagechika. Strongly retain this mature man's dignified long face, arched brows, straight nose, neatly trimmed mustache and pointed short beard, distinctive plain dark steel pointed kabuto with flared side protectors and a blue-green collar under dark armor. Slightly lifted chin and thoughtful gaze, three-quarter view, composed diplomatic bearing. Do not add horns or crests.
```

### 千本資俊 / senbon_suketoshi.png

```text
Use case: stylized-concept. Asset: one officer bust icon for a modern historical strategy game. Square 1:1 PNG with genuinely transparent alpha background. Contemporary photorealistic character illustration, natural Japanese facial anatomy, detailed skin texture and realistic cloth and armor. Period costume, modern rendering, NOT an antique painting, NOT anime. One human only. No text of any language, writing, logos, watermarks, frames, scenery, weapons or hands. Entire headgear and hair must fit within canvas with at least 8% transparent top margin. Head, neck and torso must be anatomically coherent. Waist-up or chest-up cutout. Input image: fan-created game character reference labeled Senbon Suketoshi, not a historical likeness. Retain the severe angular lean face, high shaved forehead, erect tousled small topknot, sharply angled eyebrows, deep-set focused eyes, connected black mustache and full pointed chin beard. Indigo-blue subtly patterned robe and pale cream layered collar. Slight three-quarter view with a guarded calculating expression. Render as a living realistic Japanese man about fifty.
```

### 千種忠治 / chigusa_tadaharu.png

```text
Use case: stylized-concept. Asset: one officer bust icon for a modern historical strategy game. Square 1:1 PNG with genuinely transparent alpha background. Contemporary photorealistic character illustration, natural Japanese facial anatomy, detailed skin texture and realistic cloth and armor. Period costume, modern rendering, NOT an antique painting, NOT anime. One human only. No text of any language, writing, logos, watermarks, frames, scenery, weapons or hands. Entire headgear and hair must fit within canvas with at least 8% transparent top margin. Head, neck and torso must be anatomically coherent. Waist-up or chest-up cutout. Input image: fan-created game character reference labeled Chigusa Tadaharu, not a historical likeness. Strongly retain the high bald forehead with hair tied behind, thin upright mustache and tiny goatee, narrow intense eyes, prominent cheekbones and long nose, thin tense lips, upright reserved posture. Ochre brocade outer robe and chestnut-brown collar. Mature slender man with a skeptical upward glance, head and shoulders together in three-quarter view.
```

### 千秋季忠 / senshu_suetada.png

```text
Use case: stylized-concept. Asset: one officer bust icon for a modern historical strategy game. Square 1:1 PNG with genuinely transparent alpha background. Contemporary photorealistic character illustration, natural Japanese facial anatomy, detailed skin texture and realistic cloth and armor. Period costume, modern rendering, NOT an antique painting, NOT anime. One human only. No text of any language, writing, logos, watermarks, frames, scenery, weapons or hands. Entire headgear and hair must fit within canvas with at least 8% transparent top margin. Head, neck and torso must be anatomically coherent. Waist-up or chest-up cutout. Input image: actual game design for Senshu Suetada from Sentama. Use only character traits and costume, NOT its anime rendering. Retain youthful slender clean-shaven Japanese face, straight black hair with short fringe, small purple eboshi hat secured with gold-toned trim, layered black armor and flowing white outer mantle with restrained dark red edging. Make the person a believable Japanese adult in his twenties with natural proportions and photorealistic skin. Upright composed posture, near-frontal face and torso, hands completely outside the frame. No sword, no text, no symbols resembling text.
```

### 千徳政武 / sentoku_masatake.png

```text
Use case: stylized-concept. Asset: one officer bust icon for a modern historical strategy game. Square 1:1 PNG with genuinely transparent alpha background. Contemporary photorealistic character illustration, natural Japanese facial anatomy, detailed skin texture and realistic cloth and armor. Period costume, modern rendering, NOT an antique painting, NOT anime. One human only. No text of any language, writing, logos, watermarks, frames, scenery, weapons or hands. Entire headgear and hair must fit within canvas with at least 8% transparent top margin. Head, neck and torso must be anatomically coherent. Waist-up or chest-up cutout. Input image: game card labeled Sentoku Masatake. It depicts an anthropomorphic animal; use ONLY its lavender-purple lamellar armor palette, layered shoulder plates and tall bifurcated helmet silhouette as costume inspiration. Final subject MUST be a realistic HUMAN Japanese Sengoku commander, no animal features, no muzzle, no fur, no rabbit ears. Transform the silhouette into a plausible metal kabuto with two slim upright metal crest fins and subdued purple lacing. Invent a distinct human face: middle-aged stocky man with round broad cheeks, short salt-and-pepper mustache and stubble, square broad nose, heavy-lidded eyes, firm but compassionate expression. Slight three-quarter head and torso, headwear fully visible with 8% clear top margin. No card elements.
```

### 千々石直員 / chijiwa_naokazu.png

```text
Use case: stylized-concept. Asset: one officer bust icon for a modern historical strategy game. Square 1:1 PNG with genuinely transparent alpha background. Contemporary photorealistic character illustration, natural Japanese facial anatomy, detailed skin texture and realistic cloth and armor. Period costume, modern rendering, NOT an antique painting, NOT anime. One human only. No text of any language, writing, logos, watermarks, frames, scenery, weapons or hands. Entire headgear and hair must fit within canvas with at least 8% transparent top margin. Head, neck and torso must be anatomically coherent. Waist-up or chest-up cutout. Input image: STYLE AND MATERIAL reference only, depicts a DIFFERENT officer. Do NOT copy its face, ponytail, color scheme or pose. Original interpretive portrait of Chijiwa Naokazu, for whom no verified portrait was found. Distinct youthful Japanese man in his mid twenties: slim oval face, slightly rounded chin, clear almond eyes, soft straight brows, clean-shaven, black hair neatly tied in a low compact topknot, no helmet. Restrained dark teal and charcoal armor with ivory undercollar, subtle indigo lacing. Direct quietly resolute gaze; almost frontal head and torso, modest build. Grounded human realism, period dress, no religious cross or European clothing.
```

### 千坂長朝 / chisaka_nagatomo.png

```text
Use case: stylized-concept. Asset: one officer bust icon for a modern historical strategy game. Square 1:1 PNG with genuinely transparent alpha background. Contemporary photorealistic character illustration, natural Japanese facial anatomy, detailed skin texture and realistic cloth and armor. Period costume, modern rendering, NOT an antique painting, NOT anime. One human only. No text of any language, writing, logos, watermarks, frames, scenery, weapons or hands. Entire headgear and hair must fit within canvas with at least 8% transparent top margin. Head, neck and torso must be anatomically coherent. Waist-up or chest-up cutout. Input image: STYLE AND MATERIAL reference only, depicts Chisaka Kagechika, NOT this subject. Original interpretive portrait of Chisaka Nagatomo; do NOT reproduce Kagechika's face, beard, helmet or pose. Distinct middle-aged Japanese retainer with a compact rectangular face, flat broad brows, narrow deep-set eyes, straight medium nose, clean-shaven strong jaw, neat black topknot and a shaved forecrown. Muted burgundy formal outer coat over understated black lamellar armor with gray inner collar. Upright shoulders and near-frontal forward gaze, reserved confidence. No tall helmet or crest.
```

### 千本義隆 / senbon_yoshitaka.png

```text
Use case: stylized-concept. Asset: one officer bust icon for a modern historical strategy game. Square 1:1 PNG with genuinely transparent alpha background. Contemporary photorealistic character illustration, natural Japanese facial anatomy, detailed skin texture and realistic cloth and armor. Period costume, modern rendering, NOT an antique painting, NOT anime. One human only. No text of any language, writing, logos, watermarks, frames, scenery, weapons or hands. Entire headgear and hair must fit within canvas with at least 8% transparent top margin. Head, neck and torso must be anatomically coherent. Waist-up or chest-up cutout. Input image: STYLE AND CLOTH MATERIAL reference only, depicts a DIFFERENT character, NOT this subject. Original interpretive portrait of Senbon Yoshitaka. Do NOT copy its face, hair, expression or colors. Distinct Japanese man about forty, broad soft oblong face, calm slightly drooping eyes, mildly rounded nose, small neatly trimmed mustache but no chin beard, medium black hair gathered into a compact topknot, receding natural hairline. Muted sage-green silk outer robe, cream and dark navy layered collars, unadorned period attire, no helmet. Three-quarter pose with head and torso facing the same direction, warm restrained expression. Different recognizable identity from all other men.
```

## 検証

千徳政武のみ、頭頂の兜飾りが上端に接していたため構図を修正。修正プロンプト:

```text
Edit ONLY framing: zoom the entire character out and center him with a clear transparent top margin of at least 8% of image height above the complete helmet crest. Restore the clipped tip if necessary. Keep the identical realistic human face, expression, purple armor, tall two-pronged metal helmet crest, colors and anatomy unchanged. Square 1:1 PNG with true alpha transparent background. No text, no scenery, no hands. The whole head and complete crest must fit comfortably within the canvas.
```

- 10枚すべて1254×1254、32bit ARGB、背景角のアルファ0。中心部アルファ252〜253。生成時のアルファをそのまま維持。
- 10枚を個別に目視確認。文字・手なし、頭頸部と胴体の向きに明らかな不整合なし。千徳政武の兜見切れは構図修正後に再確認。
- `scripts/game/officer_portraits.gd` に10名のIDとPNGを登録。データセットの人物名とIDを照合し、辞書キー重複なし。既存ファイルの上書きなし。
- 10件すべてGodotの `.png.import` 生成確認。
- Windowsリリースビルド成功（2026-09-26、exit_code 0、error_lines空）。`builds/windows-latest/export_report.json` に記録。
- リリースEXEを `--quit-after 120` で起動し終了コード0を確認。`builds/windows-latest/portraits-batch33-startup.log` に記録。個々の武将をゲームUIで開く操作確認は未実施。
