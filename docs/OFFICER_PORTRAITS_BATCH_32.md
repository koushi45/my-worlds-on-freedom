> 2026-10-02：商用ゲーム画像を参照した旧素材は使用を取り消し、該当する実ファイル・キャッシュ・ゲーム登録を削除した。この文書は過去の制作経緯の記録であり、再生成・再採用の指示ではない。対象：`hojo_tsunashige.png`, `hojo_tsunataka.png`, `hongo_tadatora.png`, `hongo_tokihisa.png`, `kitabatake_harutomo.png`, `kitabatake_tomonori.png`, `kitajo_takahiro.png`。独立に作り直した `_oil_` 版の採用記録は別文書を参照。

# 武将肖像 第32組

内蔵 imagegen を使用。1名ごとに生成し、PNGアルファを保持して保存。
保存先: `C:/Users/nanoa/projects/my-worlds-on-freedom/assets/officers/portraits/`

## 検索と参考画像

個人名と「信長の野望」「顔グラ」「肖像」等でWeb・画像検索し、ダウンロードした参照画像を目視して生成に直接入力。6名は本人名に対応する『信長の野望・新生』画像、綱房は本人名の現代創作画、惟忠はファンの登録武将画像を参照。後者2名は公式本人画像や史実の容貌資料ではない。忠虎・惟次は本人画像を確認できず、他人画像は画風・材質のみに限定し、容姿を創作。北条高広は越後のきたじょう氏として区別。

綱房について別の烈風伝登録記事も確認したが、北条氏照の顔グラ流用との明記があり、本人資料として採用しなかった。惟忠のファン登録画像の顔グラ原典は未確認で、公式の本人固有デザインとは断定しない。いずれも史実の容貌再現を保証しない。

|人物|保存ファイル|参照URL・区分|
|---|---|---|
|北条綱成|`hojo_tsunashige.png`|[本人名のゲーム画像](https://altema.jp/nobunagashinsei/busyo/1758)|
|北条綱房|`hojo_tsunafusa.png`|[本人名で掲載されたファン創作](https://5houjou.blog.jp/archives/6485207.html)|
|北条綱高|`hojo_tsunataka.png`|[本人名のゲーム画像](https://altema.jp/nobunagashinsei/busyo/1759)|
|北条高広|`kitajo_takahiro.png`|[本人名のゲーム画像](https://altema.jp/nobunagashinsei/busyo/730)|
|北畠具教|`kitabatake_tomonori.png`|[本人名のゲーム画像](https://altema.jp/nobunagashinsei/busyo/734)|
|北畠晴具|`kitabatake_harutomo.png`|[本人名のゲーム画像](https://altema.jp/nobunagashinsei/busyo/736)|
|北郷忠虎|`hongo_tadatora.png`|[別人の画風・材質のみ／容姿は創作](https://altema.jp/nobunagashinsei/busyo/1804)|
|北郷時久|`hongo_tokihisa.png`|[本人名のゲーム画像](https://altema.jp/nobunagashinsei/busyo/1804)|
|十時惟忠|`totoki_koretada.png`|[本人名で掲載されたファン創作](https://ameblo.jp/tetu522/entry-12618143928.html)|
|十時惟次|`totoki_koretsugu.png`|[別人の画風・材質のみ／容姿は創作](https://ameblo.jp/tetu522/entry-12618143928.html)|

## 最終プロンプトセット

## 検証

- 全10枚1254×1254・32bpp ARGB。左右上隅アルファ0、中央252〜253。アルファは生成結果のまま保持。
- 全画像を目視し、文字なし、首と身体の向き、人物ごとの違いを確認。綱成・綱高・具教は上部余白を修正。
- 10件のGodotインポート、武将ID登録の重複なし、diff --check成功。
- 2026-09-26 Windows releaseビルド: 終了コード0、export_report.jsonのerror_linesは空。
- EXEをOpenGLで120フレーム起動: 終了コード0、起動ログにエラーなし。個別武将画面の操作確認は未実施。
- 起動ログ: builds/windows-latest/portraits-batch32-startup.log

## 使用プロンプト

### hojo_tsunashige

参照入力: 1758-ref.png

Use case: stylized-concept. Create one square 1:1 true alpha-transparent PNG officer bust for a modern historical strategy game. Contemporary photorealistic character illustration, natural Japanese facial anatomy, detailed skin pores, realistic cloth and armor materials, period costume rather than modern clothing. No antique painting, anime, text of any language, writing, logos, watermarks, labels, frame, scenery, weapons or hands. Entire headgear and hair contained within canvas with at least 7% transparent top margin. Natural anatomically coherent neck and torso. Input image is the named person's modern game design reference. Strongly retain the individual facial proportions, headwear, hairstyle, costume and color cues, rendered anew in realistic detail. Hojo Tsunashige: mature rugged broad face, powerful dark eyebrows, short black stubble and beard, voluminous swept-back black topknot; imposing muscular shoulders in black-gold plate and lamellar armor with orange cords. Three-quarter left bust with fierce confident expression, lips closed. No banner, no writing, no sword.

### hojo_tsunafusa

参照入力: tsunafusa-ref.png

Use case: stylized-concept. Create one square 1:1 true alpha-transparent PNG officer bust for a modern historical strategy game. Contemporary photorealistic character illustration, natural Japanese facial anatomy, detailed skin pores, realistic cloth and armor materials, period costume rather than modern clothing. No antique painting, anime, text of any language, writing, logos, watermarks, labels, frame, scenery, weapons or hands. Entire headgear and hair contained within canvas with at least 7% transparent top margin. Natural anatomically coherent neck and torso. Input is a fan-created depiction registered or labeled with this person's name, NOT a verified historical likeness or official identity. Use its distinctive appearance cues as an artistic reference and translate to modern realistic rendering. Hojo Tsunafusa: reinterpret the reference's youthful slender Japanese male face, large gentle almond eyes, small straight nose, clean-shaven soft jaw, dark side-parted ear-length hair tucked back. Young adult about 24, slim build. Simple pale inner robe under muted blue-gray period outer robe. Slight three-quarter right bust, mild alert expression. Preserve distinctive softness but render a realistic adult MAN, not manga and not a woman. Do not include any of the source's text.

### hojo_tsunataka

参照入力: 1759-ref.png

Use case: stylized-concept. Create one square 1:1 true alpha-transparent PNG officer bust for a modern historical strategy game. Contemporary photorealistic character illustration, natural Japanese facial anatomy, detailed skin pores, realistic cloth and armor materials, period costume rather than modern clothing. No antique painting, anime, text of any language, writing, logos, watermarks, labels, frame, scenery, weapons or hands. Entire headgear and hair contained within canvas with at least 7% transparent top margin. Natural anatomically coherent neck and torso. Input image is the named person's modern game design reference. Strongly retain the individual facial proportions, headwear, hairstyle, costume and color cues, rendered anew in realistic detail. Hojo Tsunataka: stern broad clean-shaven middle-aged face with firm jaw, helmet cheek straps crossing under chin, red lacquered kabuto with prominent gold three-pronged upturned crest, red lamellar armor and brown collar. Upright near-frontal bust, eyes intent. Scale down enough for entire gold crest with 7% top margin.

### kitajo_takahiro

参照入力: 730-ref.png

Use case: stylized-concept. Create one square 1:1 true alpha-transparent PNG officer bust for a modern historical strategy game. Contemporary photorealistic character illustration, natural Japanese facial anatomy, detailed skin pores, realistic cloth and armor materials, period costume rather than modern clothing. No antique painting, anime, text of any language, writing, logos, watermarks, labels, frame, scenery, weapons or hands. Entire headgear and hair contained within canvas with at least 7% transparent top margin. Natural anatomically coherent neck and torso. Input image is the named person's modern game design reference. Strongly retain the individual facial proportions, headwear, hairstyle, costume and color cues, rendered anew in realistic detail. Kitajo Takahiro of Echigo, not Go-Hojo: preserve the reference broad mature rounded face, high shaved forehead and small topknot, thin dark moustache, slight lower eyelid bags, shrewd sideways gaze. Brown-purple patterned silk robe over muted pale blue-green collar, no armor. Three-quarter right bust, contained confident half-smile.

### kitabatake_tomonori

参照入力: 734-ref.png

Use case: stylized-concept. Create one square 1:1 true alpha-transparent PNG officer bust for a modern historical strategy game. Contemporary photorealistic character illustration, natural Japanese facial anatomy, detailed skin pores, realistic cloth and armor materials, period costume rather than modern clothing. No antique painting, anime, text of any language, writing, logos, watermarks, labels, frame, scenery, weapons or hands. Entire headgear and hair contained within canvas with at least 7% transparent top margin. Natural anatomically coherent neck and torso. Input image is the named person's modern game design reference. Strongly retain the individual facial proportions, headwear, hairstyle, costume and color cues, rendered anew in realistic detail. Kitabatake Tomonori: preserve reference elegant narrow clean-shaven face, long straight dark hair around cheeks, tall slender black eboshi, intense narrow eyes, cobalt blue flowing period outer robe and pale gold collar. Dynamic shoulders turned three-quarter left but head naturally facing toward viewer. Swordsman poise, no sword or hands. Fully include hat with margin.

### kitabatake_harutomo

参照入力: 736-ref.png

Use case: stylized-concept. Create one square 1:1 true alpha-transparent PNG officer bust for a modern historical strategy game. Contemporary photorealistic character illustration, natural Japanese facial anatomy, detailed skin pores, realistic cloth and armor materials, period costume rather than modern clothing. No antique painting, anime, text of any language, writing, logos, watermarks, labels, frame, scenery, weapons or hands. Entire headgear and hair contained within canvas with at least 7% transparent top margin. Natural anatomically coherent neck and torso. Input image is the named person's modern game design reference. Strongly retain the individual facial proportions, headwear, hairstyle, costume and color cues, rendered anew in realistic detail. Kitabatake Harutomo: preserve reference mature long face, slightly hooded eyes and furrowed brow, thin moustache and pointed narrow goatee, black formal eboshi. Brown patterned silk outer robe and mauve layered inner collars. Frontal dignified upright bust, stern reflective expression, more aged than Tomonori.

### hongo_tadatora

参照入力: 1804-ref.png

Use case: stylized-concept. Create one square 1:1 true alpha-transparent PNG officer bust for a modern historical strategy game. Contemporary photorealistic character illustration, natural Japanese facial anatomy, detailed skin pores, realistic cloth and armor materials, period costume rather than modern clothing. No antique painting, anime, text of any language, writing, logos, watermarks, labels, frame, scenery, weapons or hands. Entire headgear and hair contained within canvas with at least 7% transparent top margin. Natural anatomically coherent neck and torso. Input depicts a DIFFERENT person and is only a rendering/material style reference. Do NOT copy that person's face or identity. The following subject's appearance is an original reconstruction, not a verified historical likeness. Creative likeness of Hongo Tadatora: young-mature man about 33, broad square face, thick low brows, short wide nose, sun-weathered skin, dark short stubble, shaved-front warrior topknot. Dark brown iron armor with muted ochre ties and moss-green undergarment. Three-quarter left bust, determined serious gaze. Distinctly broader than the slender man in the reference.

### hongo_tokihisa

参照入力: 1804-ref.png

Use case: stylized-concept. Create one square 1:1 true alpha-transparent PNG officer bust for a modern historical strategy game. Contemporary photorealistic character illustration, natural Japanese facial anatomy, detailed skin pores, realistic cloth and armor materials, period costume rather than modern clothing. No antique painting, anime, text of any language, writing, logos, watermarks, labels, frame, scenery, weapons or hands. Entire headgear and hair contained within canvas with at least 7% transparent top margin. Natural anatomically coherent neck and torso. Input image is the named person's modern game design reference. Strongly retain the individual facial proportions, headwear, hairstyle, costume and color cues, rendered anew in realistic detail. Hongo Tokihisa: preserve reference long lean mature face, high cheekbones, narrow dark eyes, thin straight moustache and sparse chin beard, large swept-back dark topknot. Dark indigo robe over pale gray collar with restrained brown patterned layer, no armor. Three-quarter left bust, calm experienced expression.

### totoki_koretada

参照入力: koretada-ref.png

Use case: stylized-concept. Create one square 1:1 true alpha-transparent PNG officer bust for a modern historical strategy game. Contemporary photorealistic character illustration, natural Japanese facial anatomy, detailed skin pores, realistic cloth and armor materials, period costume rather than modern clothing. No antique painting, anime, text of any language, writing, logos, watermarks, labels, frame, scenery, weapons or hands. Entire headgear and hair contained within canvas with at least 7% transparent top margin. Natural anatomically coherent neck and torso. Input is a fan-created depiction registered or labeled with this person's name, NOT a verified historical likeness or official identity. Use its distinctive appearance cues as an artistic reference and translate to modern realistic rendering. Totoki Koretada: follow fan design's heavy broad face, pronounced brows, dark full moustache and beard, bronze-black kabuto with a small round central crest framed by two upturned gold antler-like curves, dark segmented armor with muted russet ties. Stocky imposing neck and shoulders. Near frontal bust, alert stern gaze. Complete crest and horns inside frame, 7% top margin.

### totoki_koretsugu

参照入力: koretada-ref.png

Use case: stylized-concept. Create one square 1:1 true alpha-transparent PNG officer bust for a modern historical strategy game. Contemporary photorealistic character illustration, natural Japanese facial anatomy, detailed skin pores, realistic cloth and armor materials, period costume rather than modern clothing. No antique painting, anime, text of any language, writing, logos, watermarks, labels, frame, scenery, weapons or hands. Entire headgear and hair contained within canvas with at least 7% transparent top margin. Natural anatomically coherent neck and torso. Input depicts a DIFFERENT person and is only a rendering/material style reference. Do NOT copy that person's face or identity. The following subject's appearance is an original reconstruction, not a verified historical likeness. Creative likeness of Totoki Koretsugu: older wiry man about 55, narrow angular face, deep cheek lines, small sharp eyes, prominent aquiline nose, sparse salt-and-pepper moustache without chin beard. Black hair graying at temples tied under plain off-white headband without writing, no helmet. Practical charcoal lamellar armor and faded dark blue robe. Three-quarter right bust with observant calm expression. Clearly unlike broad bearded reference man.

### 綱成・綱高・具教の構図修正

Edit ONLY framing: zoom the whole character out slightly and restore any clipped top hair or headwear. Leave a clear transparent top margin of at least 8% of image height above the COMPLETE headwear/crest/topknot. Preserve identical face, expression, costume, colors, anatomy and realistic style. Square 1:1 true alpha transparent PNG. No text or scenery. Do not add hands.
