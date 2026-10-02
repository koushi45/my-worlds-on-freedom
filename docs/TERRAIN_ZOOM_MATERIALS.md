# 倍率別の地形素材と、のっぺりした見え方の改善

2026年10月1日。対象：My Worlds on Freedom。

## 採用した構成

ユーザーの指摘は画像の粗さではなく、地表に表情がなく滑らかな面に見えることだった。実標高から作る地形と75°→15°の視点を維持し、地表色へ草地・森林・岩肌・雪面の連続した素材を重ね、微細な表面法線を別に照明へ渡す構成にした。

大きな植生分布は既存の地理座標に従う色画像、表面の変化は新しい素材PNG、山の斜面の明暗は実形状と平行光源、微細な明暗は表面法線で作る。表面法線は美術的な素材の凹凸で、測量済みの微地形ではない。樹冠の丸い模様・草地の離散的な斑点・岩の割れ目は追加していない。

## 制作した画像

内蔵image_genで草地・森林・岩肌・雪面のオリジナル素材を各1枚制作した。保存された原画像は1254×1254pxで、これを超える拡大画像は作っていない。原画像は `assets/map/materials/source/` に保存し、制作時に縁を接続して各倍率用PNGと微細法線PNGへ加工した。

| ゲーム倍率 | 素材PNGの実寸 | 色画像 | 微細法線画像 |
| --- | ---: | ---: | ---: |
| 100%以下 | 192×192 | 地形4種類 | 地形4種類 |
| 200%以下 | 384×384 | 地形4種類 | 地形4種類 |
| 400%以下 | 768×768 | 地形4種類 | 地形4種類 |
| 600%以下 | 1024×1024 | 地形4種類 | 地形4種類 |
| 800%まで | 1254×1254 | 地形4種類 | 地形4種類 |

合計40枚。`assets/map/materials/zoom/` に `{地形}_{倍率}.png` と `{地形}_{倍率}_normal.png` を保存した。素材の繰り返し尺度は24世界単位で統一し、段階が変わっても模様の位置が大きく跳ねないようにした。実行時には専用PNGを選び、画像のリサイズや生成は行わない。ミップマップと異方性フィルターを制作・取り込み時に設定し、低い視点や遠景のちらつきを抑える。

原画像制作に使った内蔵image_genのプロンプトは [生成プロンプト記録](TERRAIN_MATERIAL_PROMPTS.md) に保存した。生成原画像と変換後のファイル対応は [素材manifest](../assets/map/materials/manifest.json) に記録する。

## 描画と読み込み

素材は3D地表へ直接重ねる。既存の合成画像が届かない奥の地形も同じ素材を使える。地形の色・傾斜・雪面に応じて4種類を混合し、遠方では細かな変化を減衰させる。河川、道路の強い色、所属家の色などは素材を掛ける範囲から除外し、文字・家紋・部隊アイコンは従来の画面レイヤーを維持する。

素材の平均色はシェーダーが最も小さいミップから取得し、素材の色空間によって地形全体が白くなるのを防ぐ。素材の相対的な色の変化を既存の大きな植生色へ乗せる。微細法線は同じUVから読み、実形状の法線へ小さく加える。法線の描画を止めても、大きな山の形・照明・クリック面は変わらない。

素材画像はスレッド読み込みを使い、現在表示中・現在必要・目標倍率の段階だけを保持する。新しい段階が準備できるまでは現在の段階を使う。全5段階を常時保持しない。

## 再生成

```powershell
godot_console --headless --path . --script tools/godot/build_terrain_materials.gd
godot_console --headless --path . --editor --quit
python tools/qa/measure_map_appearance.py materials_check --view-angle
python tools/export_windows_release.py
python tools/qa/measure_map_appearance.py release_materials_check --view-angle --pack
```

画像制作時の変換は [素材コンパイラー](../tools/godot/build_terrain_materials.gd)、段階の選択は [倍率別素材の管理](../scripts/map/terrain_material_set.gd)、混合と照明は [3D地表シェーダー](../scripts/map/map_surface_3d.gdshader) に集約した。処理はGodotの [Image](https://docs.godotengine.org/en/stable/classes/class_image.html) と [Spatial shader](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/spatial_shader.html) の仕様に従う。

## 確認項目

3地域×5倍率で画像段階と実画像寸法を確認する。素材を有効・無効にした実画面を同じ構図で保存し、質感が描画に反映されていることを画素の差と目視で確認する。角度、クリックと地表の一致、道路、家紋、保存復元、等高線からの復帰も再確認する。最後にWindows版を書き出し、配布PCKでの検査と実行ファイルの起動を確認する。

## 実施結果

Windows配布PCKで15表示すべての専用素材段階、地表色と微細法線の実画像寸法、角度、クリック、家紋・部隊、画面サイズ変更、保存復元、等高線からの復帰を確認し、失敗0件。素材を止めた比較画面との差も検出した。Windows版の書き出しは終了コード0・エラー行なし、実行ファイルの通常起動も終了コード0だった。

同じ富士山の構図で素材を有効・無効にした画像を比較した。画像の一部の確認領域では全体の平均色をほぼ維持し、細かな表面の濃淡が増えた。細部の指標は1.5pxのガウス平滑化との差を使ったもので、画質全体の評価や他のゲームとの同等性を示す値ではない。

レイ再投影の最大誤差は0.00385物理ピクセル、拡大中の注目点の最大誤差は0.12855物理ピクセル、描いた検査点との実画素位置の誤差は0.56295物理ピクセル。新しい素材で地形の位置とクリック面は変わらない。

- [800%の素材適用後](../builds/qa/map_view_angle/release_materials_fuji_map_only_800.png)
- [同じ構図で素材を止めた比較画像](../builds/qa/map_view_angle/release_materials_fuji_material_disabled.png)
- [通常UIを含む800%](../builds/qa/map_view_angle/release_materials_fuji_800.png)
- [素材の実画面比較](../builds/qa/map_materials/appearance_comparison.json)
- [Windows配布PCKの検査](../builds/qa/map_view_angle/release_materials_results.json)
- [実メモリ記録](../builds/qa/map_view_angle/release_materials_process_memory.json)
- [Windows実行ファイルの起動](../builds/qa/map_materials/native.json)
- [Windows書き出し結果](../builds/windows-latest/export_report.json)
