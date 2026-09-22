# 標高レイヤーと立体地図

2026-09-11 実装。起動時に「標高レイヤー」「立体表示（傾斜・起伏）」が有効になります。それぞれ独立して切替可能です。「九州へ移動」などの地域ボタン、ホイールによる5段階拡大、ドラッグ、旧国選択を利用できます。

Windows版: `builds/windows-elevation/MyWorldsOnFreedom.exe`。同じフォルダーの `.pck` が必要です。

## 描画

- 承認済み `data/base/japan_land.gpkg` v1.0.0 と共通のLCC→8192座標変換を使用。
- 標高色と斜面の陰影は `assets/map/elevation/` の独立した41タイル。アルファは各LODの既存基盤ポリゴンカバレッジと完全一致。
- 緑の低地・丘陵から岩色の高山へ変化。陰影は実標高の勾配から生成。
- 地図面は16座標単位の三角形メッシュ。標高で頂点を上げ、縦方向を0.72倍、斜交成分0.18で投影。画像全体の傾斜だけではなく、山地の頂点自体が変位する。
- 表示用の標高は平滑化して起伏を強調。原標高値や基盤ポリゴンには表示変換を保存しない。最大標高サンプルは約3,704mで、山頂の公称値とは異なる。
- 境界線をメッシュの各辺で分割し、地表と同じ変換で描画。選択時は逆変換して既存の国ポリゴンで判定する。
- 変位勾配を0.60以下に制限して地図面の折り返しを防ぐ。平面表示では元の真上向き座標に戻る。

## 標高原本

[AWS Terrain Tiles](https://registry.opendata.aws/terrain-tiles/) のMapzen Terrarium、zoom 8を127タイル取得。日本の緯度では約420–530m/原本ピクセル。全国地図の地形判読用で、近距離の戦闘地形や測量用の精度ではない。

出典: Mapzen / SRTM・GMTED2010（USGS）、ETOPO1（NOAA）。[提供元の帰属・利用条件](https://github.com/tilezen/joerd/blob/master/docs/attribution.md)を `data/derived/elevation/attribution.md` に保存。原本URL・SHA-256・加工内容は同フォルダーの `elevation_manifest.json` に記録。ゲーム内「出典・ライセンス」にも表示する。

原本の `8/225/99.png` に18,111mの異常値が1点あったため、派生モザイク内で周辺3×3ピクセルの中央値へ置換。原本ファイルは変更せず、位置・変更前後の値をマニフェストに記録している。海陸境界はDEMから作り直さず、既存のポリゴンを使う。

再生成: `python tools/build_elevation_layer.py`。依存: NumPy、Pillow、PyProj、SciPy。取得済みタイルを再利用し、ゲーム実行中のネットワーク通信は不要。

## 検証結果

- 地図基盤10テスト: 合格。標高2テスト: 合格（基盤ハッシュ、富士山と関東平野の高さ、海域クリップ、全41タイルのカバレッジ・ハッシュ）。
- Godot: 5段階LOD、独立した表示切替、メッシュと国境の一致、実際のマウス操作による国選択が合格。
- 約27,000点の表示→逆変換誤差は最大0.000977座標単位。国境の線分中点も地表と一致。
- エクスポートしたWindows PCKでも標高の実行時テストに合格。
- `builds/qa/elevation_kyushu.png`、`elevation_mountains.png`、`elevation_flat.png` を実際のGodot画面から生成し目視確認。
- 全体の旧テストも実行。15件中12件合格、標高変更の対象外である境界下書き3件が不合格。`test_chugoku_aligned_draft` と `test_honshu_remaining` は旧24国・旧参照ハッシュを前提とし、現行の66国データと一致しない。`test_kinki_handdrawn` は下書き線と現行の承認領域の重なりを検出。これらの原本や下書きは本作業で変更していない。詳細は `builds/qa/elevation_full_suite.log`。
