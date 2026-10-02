> 2026-10-02：商用ゲーム画像を参照した旧素材は使用を取り消し、該当する実ファイル・キャッシュ・ゲーム登録を削除した。この文書は過去の制作経緯の記録であり、再生成・再採用の指示ではない。対象：`kato_akinari.png`, `kato_kiyomasa.png`, `kato_masayori.png`, `kato_mitsuyasu.png`, `kato_yoshiaki.png`, `maeno_nagayasu.png`。独立に作り直した `_oil_` 版の採用記録は別文書を参照。

# 武将肖像 第29組

内蔵 imagegen を使用。1名ごとに別生成し、PNGのアルファを保持して assets/officers/portraits/ に配置。

## 検索と参照

個人名・肖像・顔グラ・信長の野望、加藤昌頼は加藤虎景の別名でも検索。6名は掲載名との対応を確認した画像を直接入力。残る4名は本人の現代肖像を確認できず、他人画像は画風・材質のみの参照と明記し、容姿は独自に創作した。史実の容貌を保証するものではない。

|人物|ファイル|参照|
|---|---|---|
|前野長康|`maeno_nagayasu.png`|[本人ゲーム画像](https://altema.jp/nobunagashinsei/busyo/1845)|
|加藤光泰|`kato_mitsuyasu.png`|[本人ゲーム画像](https://altema.jp/nobunagashinsei/busyo/645)|
|加藤嘉明|`kato_yoshiaki.png`|[本人ゲーム画像](https://altema.jp/nobunagashinsei/busyo/646)|
|加藤明成|`kato_akinari.png`|[本人ゲーム画像](https://altema.jp/nobunagashinsei/busyo/639)|
|加藤清正|`kato_kiyomasa.png`|[本人ゲーム画像](https://altema.jp/nobunagashinsei/busyo/640)|
|加藤昌頼|`kato_masayori.png`|[本人ゲーム画像](https://ameblo.jp/tetu522/entry-12345141070.html)|
|前野長宗|`maeno_nagamune.png`|本人画像未確認・創作（他人画像は画風のみ）|
|前野長義|`maeno_nagayoshi.png`|本人画像未確認・創作（他人画像は画風のみ）|
|加木屋正則|`kagiya_masanori.png`|本人画像未確認・創作（他人画像は画風のみ）|
|加藤弥三郎|`kato_yasaburo.png`|本人画像未確認・創作（他人画像は画風のみ）|

## 最終プロンプト

### maeno_nagayasu

参照入力: 1845-ref.png

Use case: stylized-concept. One square 1:1 true alpha-transparent PNG officer bust for a modern historical strategy game. Contemporary photorealistic character illustration, real Japanese facial anatomy, skin pores, fine cloth and armor, no antique painting style. No text of any language, writing, labels, logo, watermark, frame, scenery, hands or weapons. Entire headgear inside the canvas with generous top padding. Input image is an exact-person design reference; strongly retain the named person's distinctive face structure, costume and headwear cues, reinterpret them in fresh realistic rendering. Maeno Nagayasu: broad mature face, thin moustache, short beard, thoughtful eyes, dark teal armor, gold crescent-like crest and small round disc on black kabuto. Composed three-quarter turn left.

### kato_mitsuyasu

参照入力: 645-ref.png

Use case: stylized-concept. One square 1:1 true alpha-transparent PNG officer bust for a modern historical strategy game. Contemporary photorealistic character illustration, real Japanese facial anatomy, skin pores, fine cloth and armor, no antique painting style. No text of any language, writing, labels, logo, watermark, frame, scenery, hands or weapons. Entire headgear inside the canvas with generous top padding. Input image is an exact-person design reference; strongly retain the named person's distinctive face structure, costume and headwear cues, reinterpret them in fresh realistic rendering. Kato Mitsuyasu: elderly bald man with silver side hair, prominent brows, broad nose, narrow white moustache and pointed white beard, orange Buddhist robe over pale inner collar. Calm experienced eyes looking slightly right, unarmored.

### kato_yoshiaki

参照入力: 646-ref.png

Use case: stylized-concept. One square 1:1 true alpha-transparent PNG officer bust for a modern historical strategy game. Contemporary photorealistic character illustration, real Japanese facial anatomy, skin pores, fine cloth and armor, no antique painting style. No text of any language, writing, labels, logo, watermark, frame, scenery, hands or weapons. Entire headgear inside the canvas with generous top padding. Input image is an exact-person design reference; strongly retain the named person's distinctive face structure, costume and headwear cues, reinterpret them in fresh realistic rendering. Kato Yoshiaki: stern clean-shaven angular face, deeply set eyes, very distinctive enormous dark angular fan-like helmet, black-gold armor, plum collar. Dynamic three-quarter left body with gaze right; fit entire helmet within square by widening bust framing.

### kato_akinari

参照入力: 639-ref.png

Use case: stylized-concept. One square 1:1 true alpha-transparent PNG officer bust for a modern historical strategy game. Contemporary photorealistic character illustration, real Japanese facial anatomy, skin pores, fine cloth and armor, no antique painting style. No text of any language, writing, labels, logo, watermark, frame, scenery, hands or weapons. Entire headgear inside the canvas with generous top padding. Input image is an exact-person design reference; strongly retain the named person's distinctive face structure, costume and headwear cues, reinterpret them in fresh realistic rendering. Kato Akinari: striking severe broad face, high shaved forehead with small topknot, raised brows, small moustache, black patterned formal robes, ivory collar. Chest facing forward, eyes looking sideways, imposing self-contained expression.

### kato_kiyomasa

参照入力: 640-ref.png

Use case: stylized-concept. One square 1:1 true alpha-transparent PNG officer bust for a modern historical strategy game. Contemporary photorealistic character illustration, real Japanese facial anatomy, skin pores, fine cloth and armor, no antique painting style. No text of any language, writing, labels, logo, watermark, frame, scenery, hands or weapons. Entire headgear inside the canvas with generous top padding. Input image is an exact-person design reference; strongly retain the named person's distinctive face structure, costume and headwear cues, reinterpret them in fresh realistic rendering. Kato Kiyomasa: powerful youthful angular face with narrow dark eyes, small moustache, iconic very tall silver-white eboshi-shaped helmet with gold disc and crescent front crest, orange-gold mantle over black armor. Frame widely enough to include full helmet, no writing on helmet. Slightly lowered chin, determined frontal gaze.

### kato_masayori

参照入力: masayori.jpg

Use case: stylized-concept. One square 1:1 true alpha-transparent PNG officer bust for a modern historical strategy game. Contemporary photorealistic character illustration, real Japanese facial anatomy, skin pores, fine cloth and armor, no antique painting style. No text of any language, writing, labels, logo, watermark, frame, scenery, hands or weapons. Entire headgear inside the canvas with generous top padding. Input image is an exact-person design reference; strongly retain the named person's distinctive face structure, costume and headwear cues, reinterpret them in fresh realistic rendering. Kato Masayori: swept-back dark hair with gray temples, broad elongated face, impressive horizontal long moustache with outward tips, heavy brows, navy-gray robe and burgundy inner collar. Midlife stern dignified official, three-quarter right with relaxed shoulders.

### maeno_nagamune

参照入力: 1845-ref.png

Use case: stylized-concept. One square 1:1 true alpha-transparent PNG samurai officer bust. Modern realistic premium strategy-game character art with natural Japanese facial anatomy, skin pores and richly modeled historical materials. No antique painting texture. No text in any language, writing, labels, frames, logos, watermarks, hands or weapons. Entire head well inside square with top margin. The input is a DIFFERENT officer's contemporary game portrait, STYLE AND MATERIAL REFERENCE ONLY. The requested officer has no verified exact-person portrait found in search. Invent a distinct plausible face, do not copy input facial identity or its characteristic helmet. Maeno Nagamune: adult campaign retainer aged 35, lean face with high cheekbones and a short broad nose, clean-shaven, tied loose black hair; practical dark olive-black armor over muted blue cloth, no helmet. Alert sideward glance, body three-quarter right, head tilted slightly down.

### maeno_nagayoshi

参照入力: 1845-ref.png

Use case: stylized-concept. One square 1:1 true alpha-transparent PNG samurai officer bust. Modern realistic premium strategy-game character art with natural Japanese facial anatomy, skin pores and richly modeled historical materials. No antique painting texture. No text in any language, writing, labels, frames, logos, watermarks, hands or weapons. Entire head well inside square with top margin. The input is a DIFFERENT officer's contemporary game portrait, STYLE AND MATERIAL REFERENCE ONLY. The requested officer has no verified exact-person portrait found in search. Invent a distinct plausible face, do not copy input facial identity or its characteristic helmet. Maeno Nagayoshi: older early-Sengoku military administrator aged 60, wide forehead, lined round face, receding salt-gray hair tied in short topknot, sparse gray moustache, no beard. Burgundy formal robe over dark brown light armor, thoughtful gaze slightly upward, shoulders squared.

### kagiya_masanori

参照入力: 646-ref.png

Use case: stylized-concept. One square 1:1 true alpha-transparent PNG samurai officer bust. Modern realistic premium strategy-game character art with natural Japanese facial anatomy, skin pores and richly modeled historical materials. No antique painting texture. No text in any language, writing, labels, frames, logos, watermarks, hands or weapons. Entire head well inside square with top margin. The input is a DIFFERENT officer's contemporary game portrait, STYLE AND MATERIAL REFERENCE ONLY. The requested officer has no verified exact-person portrait found in search. Invent a distinct plausible face, do not copy input facial identity or its characteristic helmet. Kagiya Masanori: youthful fierce Mori retainer around 28, pronounced angular jaw, narrow eyes, thick straight eyebrows, no facial hair, rugged short tied hair with black hachimaki. Russet leather and worn black iron armor with subdued ochre cord. Torso leaning slightly forward toward left with resolute direct gaze.

### kato_yasaburo

参照入力: 639-ref.png

Use case: stylized-concept. One square 1:1 true alpha-transparent PNG samurai officer bust. Modern realistic premium strategy-game character art with natural Japanese facial anatomy, skin pores and richly modeled historical materials. No antique painting texture. No text in any language, writing, labels, frames, logos, watermarks, hands or weapons. Entire head well inside square with top margin. The input is a DIFFERENT officer's contemporary game portrait, STYLE AND MATERIAL REFERENCE ONLY. The requested officer has no verified exact-person portrait found in search. Invent a distinct plausible face, do not copy input facial identity or its characteristic helmet. Kato Yasaburo: youthful Oda page and warrior later serving Tokugawa, around 25, slender oval face with fine brows, alert large eyes, straight thin nose, clean-shaven. Restrained tied black hair, pale-gray kimono beneath dark blue light armor, red horo-inspired folded fabric visible behind one shoulder but not huge. Modest poised three-quarter profile looking right, no helmet.

## 確認

10枚を目視確認。画像内に文字なし、1254×1254・背景アルファあり。ゲーム内のID対応を登録。

2026-09-26: `python tools/export_windows_release.py` による Windows リリース書き出し成功（終了コード0、最終 error_lines は空）。`builds/windows-latest/MyWorldsOnFreedom.exe` と `.pck` を更新。初回のサンドボックス起因の証明書・ユーザー設定保存エラーは権限を適切に付けた再書き出しで解消。

書き出したEXEを `--quit-after 120` で非ヘッドレス起動し、OpenGL/NVIDIA初期化と終了コード0を確認。起動ログ: `builds/windows-latest/portraits-batch29-startup.log`。今回の確認は起動スモークテストであり、全ゲーム画面の手動操作検証ではない。
