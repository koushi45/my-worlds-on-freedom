> 2026-10-02：商用ゲーム画像を参照した旧素材は使用を取り消し、該当する実ファイル・キャッシュ・ゲーム登録を削除した。この文書は過去の制作経緯の記録であり、再生成・再採用の指示ではない。対象：`hojo_genan.png`, `hojo_yasutane.png`, `kagai_shigemune.png`, `kato_shigenori.png`, `kato_yorimori.png`, `katsu_shigehisa.png`, `katsunuma_nobumoto.png`, `kita_narikatsu.png`, `kita_nobuchika.png`, `kitajo_kagehiro.png`。独立に作り直した `_oil_` 版の採用記録は別文書を参照。

# 武将肖像 第30組

内蔵 imagegen を使用し、1名ごとに別生成。生成PNGを加工せずアルファを保持して保存。
保存先: `C:/Users/nanoa/projects/my-worlds-on-freedom/assets/officers/portraits/`

## 検索と参照

個人名と「信長の野望」「顔グラ」「肖像」でWeb・画像検索後、参照画像を目視確認して入力した。3名は本人名に対応する現代ゲーム画像を確認。残る7名は本人画像を確認できず、他人画像を画風・材質のみの参照に限定し、顔立ちは創作した。史実の容貌を保証しない。勝沼信元のファン登録記事は画像を取得できず採用せず。加藤重徳のファン登録記事は別人顔グラの流用との説明があるため本人資料として採用しなかった。北条景広は越後のきたじょう氏、北就勝は毛利家臣として区別。

|人物|保存ファイル|参照の役割・URL|
|---|---|---|
|加藤重徳|`kato_shigenori.png`|本人画像未確認・創作。別人画像は画風と材質のみ: https://altema.jp/nobunagashinsei/busyo/726|
|加藤順盛|`kato_yorimori.png`|本人画像未確認・創作。別人画像は画風と材質のみ: https://altema.jp/nobunagashinsei/busyo/726|
|加賀井重宗|`kagai_shigemune.png`|本人画像未確認・創作。別人画像は画風と材質のみ: https://altema.jp/nobunagashinsei/busyo/729|
|勝沼信元|`katsunuma_nobumoto.png`|本人画像未確認・創作。別人画像は画風と材質のみ: https://altema.jp/nobunagashinsei/busyo/729|
|勝重久|`katsu_shigehisa.png`|本人画像未確認・創作。別人画像は画風と材質のみ: https://altema.jp/nobunagashinsei/busyo/729|
|北信愛|`kita_nobuchika.png`|本人ゲーム画像: https://altema.jp/nobunagashinsei/busyo/726|
|北就勝|`kita_narikatsu.png`|本人画像未確認・創作。別人画像は画風と材質のみ: https://altema.jp/nobunagashinsei/busyo/726|
|北条幻庵|`hojo_genan.png`|本人ゲーム画像: https://altema.jp/nobunagashinsei/busyo/1755|
|北条康種|`hojo_yasutane.png`|本人画像未確認・創作。別人画像は画風と材質のみ: https://altema.jp/nobunagashinsei/busyo/726|
|北条景広|`kitajo_kagehiro.png`|本人ゲーム画像: https://altema.jp/nobunagashinsei/busyo/729|

## 最終プロンプト

## 検証結果

- 全10枚: 1254×1254、32bpp ARGB。左右上隅アルファ0、中央252〜253。生成時のアルファを保持。
- 全画像を目視し、文字なし、首と胴体の向き、顔の描き分けを確認。
- 全10名のID登録とGodotインポートファイルを確認。
- Windows release: 2026-09-26、終了コード0、export_report.jsonのerror_linesは空。
- 書き出したEXEをOpenGLで120フレーム起動。終了コード0、起動ログにエラーなし。個別武将画面の操作確認までは行っていない。
- ログ: builds/windows-latest/portraits-batch30-startup.log

## 生成に使用したプロンプト

### kato_shigenori

参照入力: 726-ref.png

Use case: stylized-concept. One square 1:1 true alpha-transparent PNG officer bust for a modern historical strategy game. Contemporary realistic character illustration with natural Japanese facial anatomy, skin pores, rich period cloth and armor materials. No antique painting, no anime. No text of any language, writing, label, logo, watermark, frame, scenery, hands or weapons. Entire headgear within canvas, breathing room above head. Anatomically coherent head, neck and torso. Input image is ONLY a modern rendering/material style reference depicting a DIFFERENT person. Do NOT copy its face, hairstyle or identity. The following character is a clearly differentiated creative reconstruction, not a verified historical likeness. Creative likeness of Kato Shigenori: mature man about 48, long rectangular face, compassionate steady eyes, broad straight nose, narrow moustache and short salt-and-pepper chin beard. Tied dark hair with slightly receding forehead, dark brown practical armor and olive shoulder garment. Torso angled right, head also right, eyes towards viewer.

### kato_yorimori

参照入力: 726-ref.png

Use case: stylized-concept. One square 1:1 true alpha-transparent PNG officer bust for a modern historical strategy game. Contemporary realistic character illustration with natural Japanese facial anatomy, skin pores, rich period cloth and armor materials. No antique painting, no anime. No text of any language, writing, label, logo, watermark, frame, scenery, hands or weapons. Entire headgear within canvas, breathing room above head. Anatomically coherent head, neck and torso. Input image is ONLY a modern rendering/material style reference depicting a DIFFERENT person. Do NOT copy its face, hairstyle or identity. The following character is a clearly differentiated creative reconstruction, not a verified historical likeness. Creative likeness of Kato Yorimori: stocky dignified man about 57, rounded broad cheeks, hooded eyes, wide nose, no beard, shaved-front topknot. Ink navy formal silk robe with muted russet inner collar, no armor. Near frontal symmetrical composed bust, subtle hospitable expression.

### kagai_shigemune

参照入力: 729-ref.png

Use case: stylized-concept. One square 1:1 true alpha-transparent PNG officer bust for a modern historical strategy game. Contemporary realistic character illustration with natural Japanese facial anatomy, skin pores, rich period cloth and armor materials. No antique painting, no anime. No text of any language, writing, label, logo, watermark, frame, scenery, hands or weapons. Entire headgear within canvas, breathing room above head. Anatomically coherent head, neck and torso. Input image is ONLY a modern rendering/material style reference depicting a DIFFERENT person. Do NOT copy its face, hairstyle or identity. The following character is a clearly differentiated creative reconstruction, not a verified historical likeness. Creative likeness of Kagai Shigemune: weathered lean man about 50, angular jaw, narrow eyes, pronounced cheekbones, rough thin moustache. Simple iron kabuto without fantastic crest, indigo lacing, dark lamellar armor. Three-quarter left bust, serious alert expression.

### katsunuma_nobumoto

参照入力: 729-ref.png

Use case: stylized-concept. One square 1:1 true alpha-transparent PNG officer bust for a modern historical strategy game. Contemporary realistic character illustration with natural Japanese facial anatomy, skin pores, rich period cloth and armor materials. No antique painting, no anime. No text of any language, writing, label, logo, watermark, frame, scenery, hands or weapons. Entire headgear within canvas, breathing room above head. Anatomically coherent head, neck and torso. Input image is ONLY a modern rendering/material style reference depicting a DIFFERENT person. Do NOT copy its face, hairstyle or identity. The following character is a clearly differentiated creative reconstruction, not a verified historical likeness. Creative likeness of Katsunuma Nobumoto: youthful adult about 30, elegant oval face, straight thick brows, clean-shaven, confident but restrained. Small black eboshi, russet armor with dark violet undergarment, long neck naturally seated between shoulders. Turned three-quarter right, looking to right.

### katsu_shigehisa

参照入力: 729-ref.png

Use case: stylized-concept. One square 1:1 true alpha-transparent PNG officer bust for a modern historical strategy game. Contemporary realistic character illustration with natural Japanese facial anatomy, skin pores, rich period cloth and armor materials. No antique painting, no anime. No text of any language, writing, label, logo, watermark, frame, scenery, hands or weapons. Entire headgear within canvas, breathing room above head. Anatomically coherent head, neck and torso. Input image is ONLY a modern rendering/material style reference depicting a DIFFERENT person. Do NOT copy its face, hairstyle or identity. The following character is a clearly differentiated creative reconstruction, not a verified historical likeness. Creative likeness of Katsu Shigehisa: muscular rugged warrior about 40, broad square jaw, low eyebrows, flattened broad nose, short dark stubble, dark hair tied back without helmet. Worn charcoal cuirass with tan and dark green cloth shoulder layers. Forward-facing firm upright stance, intense eyes.

### kita_nobuchika

参照入力: 726-ref.png

Use case: stylized-concept. One square 1:1 true alpha-transparent PNG officer bust for a modern historical strategy game. Contemporary realistic character illustration with natural Japanese facial anatomy, skin pores, rich period cloth and armor materials. No antique painting, no anime. No text of any language, writing, label, logo, watermark, frame, scenery, hands or weapons. Entire headgear within canvas, breathing room above head. Anatomically coherent head, neck and torso. Input image is this named officer's modern game design reference. Strongly preserve its facial proportions, hairstyle and costume cues, re-render with fresh detailed realism. Kita Nobuchika: retain reference elongated mature face, strong cheekbones, receding shaved crown and topknot, dark angular moustache and pointed goatee, penetrating sideways eyes. Charcoal blue robe over pale blue-white collar, no armor. Three-quarter left bust, calculating thoughtful expression.

### kita_narikatsu

参照入力: 726-ref.png

Use case: stylized-concept. One square 1:1 true alpha-transparent PNG officer bust for a modern historical strategy game. Contemporary realistic character illustration with natural Japanese facial anatomy, skin pores, rich period cloth and armor materials. No antique painting, no anime. No text of any language, writing, label, logo, watermark, frame, scenery, hands or weapons. Entire headgear within canvas, breathing room above head. Anatomically coherent head, neck and torso. Input image is ONLY a modern rendering/material style reference depicting a DIFFERENT person. Do NOT copy its face, hairstyle or identity. The following character is a clearly differentiated creative reconstruction, not a verified historical likeness. Creative likeness of Kita Narikatsu, Mori retainer (not Nanbu family): older thin man about 60, fine long face, high cheekbones, gentle drooping eyes, thin silver moustache, short wispy silver chin hair. Soft black eboshi, olive brown formal robe and pale cream collar. Turned three-quarter right, quiet thoughtful dignity.

### hojo_genan

参照入力: 1755-ref.png

Use case: stylized-concept. One square 1:1 true alpha-transparent PNG officer bust for a modern historical strategy game. Contemporary realistic character illustration with natural Japanese facial anatomy, skin pores, rich period cloth and armor materials. No antique painting, no anime. No text of any language, writing, label, logo, watermark, frame, scenery, hands or weapons. Entire headgear within canvas, breathing room above head. Anatomically coherent head, neck and torso. Input image is this named officer's modern game design reference. Strongly preserve its facial proportions, hairstyle and costume cues, re-render with fresh detailed realism. Hojo Genan: strongly retain reference bald elderly head, deeply wrinkled broad warm face, softly arched silver brows, short white moustache and tapered white goatee. Black-brown outer robe, cream inner kimono, muted burgundy edge. Slight smiling mouth, three-quarter right bust, relaxed wise eyes.

### hojo_yasutane

参照入力: 726-ref.png

Use case: stylized-concept. One square 1:1 true alpha-transparent PNG officer bust for a modern historical strategy game. Contemporary realistic character illustration with natural Japanese facial anatomy, skin pores, rich period cloth and armor materials. No antique painting, no anime. No text of any language, writing, label, logo, watermark, frame, scenery, hands or weapons. Entire headgear within canvas, breathing room above head. Anatomically coherent head, neck and torso. Input image is ONLY a modern rendering/material style reference depicting a DIFFERENT person. Do NOT copy its face, hairstyle or identity. The following character is a clearly differentiated creative reconstruction, not a verified historical likeness. Creative likeness of Hojo Yasutane: mature slender man about 43, long slightly aquiline nose, clean-shaven narrow jaw, small alert eyes, glossy black topknot. Restrained black iron shoulder armor over deep teal clothing with beige collar. Profile-biased left-facing bust, both face and torso aligned left.

### kitajo_kagehiro

参照入力: 729-ref.png

Use case: stylized-concept. One square 1:1 true alpha-transparent PNG officer bust for a modern historical strategy game. Contemporary realistic character illustration with natural Japanese facial anatomy, skin pores, rich period cloth and armor materials. No antique painting, no anime. No text of any language, writing, label, logo, watermark, frame, scenery, hands or weapons. Entire headgear within canvas, breathing room above head. Anatomically coherent head, neck and torso. Input image is this named officer's modern game design reference. Strongly preserve its facial proportions, hairstyle and costume cues, re-render with fresh detailed realism. Kitajo Kagehiro of Echigo, not Go-Hojo: preserve reference strong youthful square face, thick straight eyebrows, clean-shaven jaw, black hair and plain white fabric headband with no writing, dark blue lamellar armor with red-purple ties and dark cloak. Three-quarter left bust, determined eyes looking toward viewer.
