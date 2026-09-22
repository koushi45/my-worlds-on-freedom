# 地図基盤テスト要件

作成日: 2026-09-06  
状態: **10件すべて合格**

## 実行方法

```powershell
python tools/run_map_test_suite.py
```

Pythonの地理・画像検査に加え、インストール済みGodotをヘッドレス起動してランタイム読込、タイルカリング、表示変換を検査する。結果は`data/derived/testing/map_test_report.json`へ出力する。

## テスト対応表

| 要件 | 自動テスト |
|---|---|
| 基盤ポリゴンの妥当性とハッシュ固定 | `test_01_master_validity_and_fixed_hash` |
| CRSと8192座標の往復変換 | `test_02_crs_game_coordinate_round_trip` |
| LOD海岸線と陸地外周の距離0 | `test_03_each_lod_coastline_equals_land_exterior` |
| 通常・選択海岸線の点列ID共有 | `test_04_normal_and_selection_share_coastline_ids` |
| 全国・地方・狭域の重複範囲 | `test_05_overlapping_view_families_have_consistent_land` |
| タイル継ぎ目 | `test_06_tile_seams_only_change_at_vector_coast` |
| 真上・斜め表示の逆変換 | `test_07_top_down_oblique_inverse` |
| クリック対象と表示境界 | `test_08_click_targets_match_display_contract` |
| 画面外タイルの非描画 | `test_09_offscreen_tile_culling_contract` |
| Windows・Android・iOS・Web読込契約 | `test_10_platform_runtime_asset_compatibility` |

## 検査の詳細

### 基盤・座標

正本の妥当性、空形状、承認ハッシュ、再生成ハッシュを確認する。WGS 84から8192座標へ変換した形状を逆変換し、原座標との差が`1e-10`度以内であることを検査する。

### LOD・海岸線

全5段階について、陸地ポリゴン外周と対応海岸線のHausdorff距離が0で、点列も完全一致することを確認する。通常表示と選択表示が同じレジストリ・IDリストを参照することも検査する。

LOD間では簡略化による差を認めるが、差分は海岸線の許容バッファ内に限定し、陸地内部や海上へ独立した差分が生じていないことを確認する。

### タイル継ぎ目

同一LODの隣接タイル境界を全件走査する。左右・上下端のカバレッジ差は、4pxブリードとLANCZOSカーネルを考慮した海岸線近傍だけに存在できる。海岸線から離れた位置での不連続は0件でなければならない。

### 表示変換・カリング

真上座標から斜め表示へのアフィン変換と逆変換をPythonとGodotの両方で検査する。斜め座標は保存しない。

`scripts/map/map_tile_catalog.gd`は8192グローバル表示範囲と各タイル矩形の交差だけで可視タイルを選ぶ。Godotヘッドレステストでは、画面内検索で1枚、画面外検索で0枚が読み込まれることを確認する。

### クリック判定

政治領域が存在する場合、クリックマスクが非表示であり、選択表示の共有境界IDと海岸線IDが実在することを確認する。現在は歴史領域原本が未採用なので、クリック対象0件・表示境界0件の一致を検査している。

### プラットフォーム互換性

Windows、Android、iOS、Webの4エクスポートプリセットと、共通JSON・PNG・GDScriptの同梱設定を検査する。ランタイム用テクスチャは最大2048×2048で、パスは小文字を含む相対POSIX形式とする。8192マスクをGPUへ一括ロードせず、表示中の2048タイルだけを読む。

このテストが保証するのは共通資産と読込契約の互換性であり、署名、ストア提出、Android/iOS実機動作、各プラットフォームのネイティブエクスポートテンプレートまでは含まない。

## 関連実装

- `tests/base_map/test_map_pipeline.py`
- `tests/base_map/godot/test_map_runtime.gd`
- `scripts/map/map_tile_catalog.gd`
- `scripts/map/map_display_transform.gd`
- `tools/run_map_test_suite.py`
