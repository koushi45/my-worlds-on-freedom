> 2026-10-02：商用ゲーム画像を参照した旧素材は使用を取り消し、該当する実ファイル・キャッシュ・ゲーム登録を削除した。この文書は過去の制作経緯の記録であり、再生成・再採用の指示ではない。対象：`hojo_naosada.png`, `hojo_ujikuni.png`, `hojo_ujimasa.png`, `hojo_ujinao.png`, `hojo_ujinari.png`, `hojo_ujinori.png`, `hojo_ujishige.png`, `hojo_ujitaka.png`, `hojo_ujiteru.png`, `hojo_ujiyasu-v2.png`。独立に作り直した `_oil_` 版の採用記録は別文書を参照。

# 武将肖像 第31組

内蔵 imagegen を使用。1名ずつ別生成し、PNGアルファを維持して保存。
保存先: `C:/Users/nanoa/projects/my-worlds-on-freedom/assets/officers/portraits/`

## 検索と参照

個人名と「信長の野望」「顔グラ」「肖像」でWeb・画像検索。8名は本人名に対応する『信長の野望・新生』画像を確認し、ダウンロードして目視した画像を生成に直接入力した。氏成・直定は本人画像を確認できず、別人画像は画風・材質のみの参照と明示し、容姿は創作。氏成は氏繁の子で、千葉直重と区別。史実の容貌の再現を保証するものではない。

|人物|ファイル|参照URL・役割|
|---|---|---|
|北条氏尭|`hojo_ujitaka.png`|[本人ゲーム画像](https://altema.jp/nobunagashinsei/busyo/1747)|
|北条氏康|`hojo_ujiyasu-v2.png`（既存PNGは保存）|[本人ゲーム画像](https://altema.jp/nobunagashinsei/busyo/1754)|
|北条氏成|`hojo_ujinari.png`|[別人画像・画風と材質のみ（容姿は創作）](https://altema.jp/nobunagashinsei/busyo/1745)|
|北条氏政|`hojo_ujimasa.png`|[本人ゲーム画像](https://altema.jp/nobunagashinsei/busyo/1753)|
|北条氏照|`hojo_ujiteru.png`|[本人ゲーム画像](https://altema.jp/nobunagashinsei/busyo/1749)|
|北条氏直|`hojo_ujinao.png`|[本人ゲーム画像](https://altema.jp/nobunagashinsei/busyo/1750)|
|北条氏繁|`hojo_ujishige.png`|[本人ゲーム画像](https://altema.jp/nobunagashinsei/busyo/1745)|
|北条氏規|`hojo_ujinori.png`|[本人ゲーム画像](https://altema.jp/nobunagashinsei/busyo/1751)|
|北条氏邦|`hojo_ujikuni.png`|[本人ゲーム画像](https://altema.jp/nobunagashinsei/busyo/1744)|
|北条直定|`hojo_naosada.png`|[別人画像・画風と材質のみ（容姿は創作）](https://altema.jp/nobunagashinsei/busyo/1750)|

## 最終プロンプトセット

検証: 全10枚1254×1254の32bpp ARGB。左右上隅アルファ0、中央252〜253。全画像を目視し文字なし・首と胴体の向きを確認。氏照の兜飾り、氏直・氏邦の髷は構図を修正して余白を確保。Godotインポート10件、登録IDの重複なし、diff --check成功。

2026-09-26: Windowsリリースビルド終了コード0、export_report.jsonのerror_linesは空。EXEをOpenGLで120フレーム起動し終了コード0、起動ログにエラーなし。ログ: `builds/windows-latest/portraits-batch31-startup.log`。個別武将画面の操作確認は未実施。

### hojo_ujitaka

参照入力: 1747-ref.png

Use case: stylized-concept. Create one square 1:1 true alpha-transparent PNG bust portrait for a modern historical strategy game. Photorealistic contemporary character illustration, natural Japanese facial anatomy, skin pores, fine silk and armor texture. Period Japanese costume, NOT modern clothing. No antique painting style, anime, text of any language, letters, writing, logos, watermark, frame, scenery, weapons or hands. Full headgear contained inside canvas with visible padding above. Coherent head, neck and torso anatomy. Input image is the named person's game portrait design reference. Strongly retain the distinctive facial structure, hairstyle, headgear and clothing cues; reinterpret with fresh realistic rendering, not a generic same-face samurai. Hojo Ujitaka: retain the reference's mature broad angular face, thick black moustache, intent narrow eyes, white wrapped headcloth beneath small black triangular eboshi, blue outer garment with yellow lapels and brown inner collar. Upright near frontal bust, stern composed gaze.

### hojo_ujiyasu

参照入力: 1754-ref.png

Use case: stylized-concept. Create one square 1:1 true alpha-transparent PNG bust portrait for a modern historical strategy game. Photorealistic contemporary character illustration, natural Japanese facial anatomy, skin pores, fine silk and armor texture. Period Japanese costume, NOT modern clothing. No antique painting style, anime, text of any language, letters, writing, logos, watermark, frame, scenery, weapons or hands. Full headgear contained inside canvas with visible padding above. Coherent head, neck and torso anatomy. Input image is the named person's game portrait design reference. Strongly retain the distinctive facial structure, hairstyle, headgear and clothing cues; reinterpret with fresh realistic rendering, not a generic same-face samurai. Hojo Ujiyasu: retain reference middle-aged commanding face, pronounced brow ridge, heavy moustache and short pointed chin beard, dark formal eboshi, blue silk robe patterned with subtle pale cranes and pale layered collar. Three-quarter left bust, authoritative thoughtful look; no fan or hands.

### hojo_ujinari

参照入力: 1745-ref.png

Use case: stylized-concept. Create one square 1:1 true alpha-transparent PNG bust portrait for a modern historical strategy game. Photorealistic contemporary character illustration, natural Japanese facial anatomy, skin pores, fine silk and armor texture. Period Japanese costume, NOT modern clothing. No antique painting style, anime, text of any language, letters, writing, logos, watermark, frame, scenery, weapons or hands. Full headgear contained inside canvas with visible padding above. Coherent head, neck and torso anatomy. Input image depicts a DIFFERENT person and is ONLY a rendering and material style reference. Do NOT copy its face or identity. Create the following distinctive original likeness; historical appearance is unverified. Creative likeness of Hojo Ujinari, son of Ujishige (not Chiba Naoshige): lean young adult about 26, elongated oval face, small deep-set eyes, straight slim nose, clean-shaven, simple shaved-front topknot. Dark gunmetal lamellar armor with muted rust-red ties and pale tan collar. Torso and head three-quarter right, alert restrained gaze. Distinct from the bearded older man in reference.

### hojo_ujimasa

参照入力: 1753-ref.png

Use case: stylized-concept. Create one square 1:1 true alpha-transparent PNG bust portrait for a modern historical strategy game. Photorealistic contemporary character illustration, natural Japanese facial anatomy, skin pores, fine silk and armor texture. Period Japanese costume, NOT modern clothing. No antique painting style, anime, text of any language, letters, writing, logos, watermark, frame, scenery, weapons or hands. Full headgear contained inside canvas with visible padding above. Coherent head, neck and torso anatomy. Input image is the named person's game portrait design reference. Strongly retain the distinctive facial structure, hairstyle, headgear and clothing cues; reinterpret with fresh realistic rendering, not a generic same-face samurai. Hojo Ujimasa: retain reference narrow angular adult face, neatly swept-back black hair and small topknot, narrow dark moustache, defined cheekbones, dignified sharp eyes. Yellow-green silk sleeveless outer robe over reddish brown inner garment, very subtle woven pattern. Three-quarter right bust, chin slightly raised.

### hojo_ujiteru

参照入力: 1749-ref.png

Use case: stylized-concept. Create one square 1:1 true alpha-transparent PNG bust portrait for a modern historical strategy game. Photorealistic contemporary character illustration, natural Japanese facial anatomy, skin pores, fine silk and armor texture. Period Japanese costume, NOT modern clothing. No antique painting style, anime, text of any language, letters, writing, logos, watermark, frame, scenery, weapons or hands. Full headgear contained inside canvas with visible padding above. Coherent head, neck and torso anatomy. Input image is the named person's game portrait design reference. Strongly retain the distinctive facial structure, hairstyle, headgear and clothing cues; reinterpret with fresh realistic rendering, not a generic same-face samurai. Hojo Ujiteru: retain reference lean clean-shaven elegant face, black lacquer helmet with prominent large rounded gold U/crescent-like crest, gold trim and segmented neck guard, dark green outer robe with gold ornamental fabric and dark armor, pale blue collar. Gentle three-quarter left bust, serious contemplative eyes. No flute or hands. Widen composition enough to fully contain the tall crest.

### hojo_ujinao

参照入力: 1750-ref.png

Use case: stylized-concept. Create one square 1:1 true alpha-transparent PNG bust portrait for a modern historical strategy game. Photorealistic contemporary character illustration, natural Japanese facial anatomy, skin pores, fine silk and armor texture. Period Japanese costume, NOT modern clothing. No antique painting style, anime, text of any language, letters, writing, logos, watermark, frame, scenery, weapons or hands. Full headgear contained inside canvas with visible padding above. Coherent head, neck and torso anatomy. Input image is the named person's game portrait design reference. Strongly retain the distinctive facial structure, hairstyle, headgear and clothing cues; reinterpret with fresh realistic rendering, not a generic same-face samurai. Hojo Ujinao: retain reference handsome youthful narrow face, straight eyebrows, delicate jaw, clean-shaven, neatly tied black topknot and unshaved forehead. Pale ice-blue robe with white silk inner layers and muted gold-brown collar. Slight relaxed forward lean, head angled gently, self-assured faint smile; arms and hands completely out of frame.

### hojo_ujishige

参照入力: 1745-ref.png

Use case: stylized-concept. Create one square 1:1 true alpha-transparent PNG bust portrait for a modern historical strategy game. Photorealistic contemporary character illustration, natural Japanese facial anatomy, skin pores, fine silk and armor texture. Period Japanese costume, NOT modern clothing. No antique painting style, anime, text of any language, letters, writing, logos, watermark, frame, scenery, weapons or hands. Full headgear contained inside canvas with visible padding above. Coherent head, neck and torso anatomy. Input image is the named person's game portrait design reference. Strongly retain the distinctive facial structure, hairstyle, headgear and clothing cues; reinterpret with fresh realistic rendering, not a generic same-face samurai. Hojo Ujishige: retain reference broad weathered middle-aged face, thick eyebrows, dense dark moustache and short rounded beard, low steel helmet with plain dark red cloth band, dark armor with brown-red shoulder cloth and pale inner collar. Broad strong shoulders, three-quarter left bust, vigilant eyes.

### hojo_ujinori

参照入力: 1751-ref.png

Use case: stylized-concept. Create one square 1:1 true alpha-transparent PNG bust portrait for a modern historical strategy game. Photorealistic contemporary character illustration, natural Japanese facial anatomy, skin pores, fine silk and armor texture. Period Japanese costume, NOT modern clothing. No antique painting style, anime, text of any language, letters, writing, logos, watermark, frame, scenery, weapons or hands. Full headgear contained inside canvas with visible padding above. Coherent head, neck and torso anatomy. Input image is the named person's game portrait design reference. Strongly retain the distinctive facial structure, hairstyle, headgear and clothing cues; reinterpret with fresh realistic rendering, not a generic same-face samurai. Hojo Ujinori: retain reference lean serious mature face, straight dark brows, clean-shaven chin, slightly pursed mouth, black folded eboshi. Deep forest-green brocade formal clothing with olive neck layer. Almost frontal bust, gaze slightly sideways, intelligent reserved diplomat expression.

### hojo_ujikuni

参照入力: 1744-ref.png

Use case: stylized-concept. Create one square 1:1 true alpha-transparent PNG bust portrait for a modern historical strategy game. Photorealistic contemporary character illustration, natural Japanese facial anatomy, skin pores, fine silk and armor texture. Period Japanese costume, NOT modern clothing. No antique painting style, anime, text of any language, letters, writing, logos, watermark, frame, scenery, weapons or hands. Full headgear contained inside canvas with visible padding above. Coherent head, neck and torso anatomy. Input image is the named person's game portrait design reference. Strongly retain the distinctive facial structure, hairstyle, headgear and clothing cues; reinterpret with fresh realistic rendering, not a generic same-face samurai. Hojo Ujikuni: retain reference athletic strong young-mature face, thick angled brows, clean-shaven jaw, thick swept-up black topknot and loose hair near temples. Tall red turned collar, dark black-silver armor with muted gold accents. Forward-leaning three-quarter right bust with intensely focused eyes. No spear or weapon. Avoid making face identical to Ujimasa or Ujinao.

### hojo_naosada

参照入力: 1750-ref.png

Use case: stylized-concept. Create one square 1:1 true alpha-transparent PNG bust portrait for a modern historical strategy game. Photorealistic contemporary character illustration, natural Japanese facial anatomy, skin pores, fine silk and armor texture. Period Japanese costume, NOT modern clothing. No antique painting style, anime, text of any language, letters, writing, logos, watermark, frame, scenery, weapons or hands. Full headgear contained inside canvas with visible padding above. Coherent head, neck and torso anatomy. Input image depicts a DIFFERENT person and is ONLY a rendering and material style reference. Do NOT copy its face or identity. Create the following distinctive original likeness; historical appearance is unverified. Creative likeness of Hojo Naosada: young adult about 22, soft round face, wider-set dark eyes, short broad nose, clean-shaven, neat shaved-front small topknot. Simple deep plum robe over off-white collar and modest dark shoulder armor. Near-frontal upright bust with earnest slightly uncertain expression. Distinct from the slender handsome reference man; no hands.

### 氏照・構図修正

Edit this portrait only to fix framing: the gold helmet crest currently touches and is clipped by the top edge. Zoom the entire character out slightly, reconstruct the complete two rounded tips of the U-shaped gold crest, and leave a clear transparent margin of at least 8% canvas height above the entire crest. Preserve the same face, costume, realistic style, colors, no text, no hands, square 1:1 true alpha transparent PNG. Do not change identity.

### 氏直・氏邦・構図修正

Edit only the framing of this portrait: zoom out the entire character slightly and reconstruct any clipped hair at the very top, leaving at least 6% clear transparent space above the COMPLETE topknot and hair. Preserve identity, face, expression, hairstyle, clothing, proportions and realistic style exactly. Square 1:1 true alpha transparent PNG. No text, no hands, no scenery.
