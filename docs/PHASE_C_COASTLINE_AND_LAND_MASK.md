# フェーズC：海岸線と陸地マスク

作成日: 2026-09-06  
入力正本: `japan_land` 版`1.0.0`  
状態: **生成・自動検証済み**

## 成果物

| 成果物 | パス |
|---|---|
| 海岸線GeoPackage | `data/derived/coastline/coastline_master.gpkg` |
| 8192陸地マスク | `data/derived/land_masks/land_mask_8192.png` |
| 8192共有データ | `data/derived/land_masks/land_master_8192.json` |
| フェーズマニフェスト | `data/derived/phase_c_manifest.json` |
| 自動検証結果 | `data/derived/phase_c_verification.json` |

既存プロジェクトで承認済み正本の物理ファイル名は`data/base/japan_land.gpkg`であり、これが作業指示書上の`japan_land_master.gpkg`に相当する。正本レイヤー名は`japan_land`である。

## 海岸線

正本154フィーチャの全外周リングだけから、154個の永続`coastline_id`を生成した。合計点数は7,499点で、別画像からの推定、平滑化、簡略化、海岸位置の補正は行っていない。

`coastline_master.gpkg`には次の2レイヤーを収録する。

- `coastline_master`: 正本外周と完全一致するEPSG:4326点列
- `coastline_8192`: 共通変換関数で8192座標へ変換した点列

各レイヤーは同じ`coastline_id`、陸地`feature_id`、構成番号、点数を持つ。

## 陸地マスクと共有参照

`land_mask_8192.png`は8192×8192、8-bitグレースケールの二値画像である。海を0、陸を255とし、`coastline_8192`と同じ変換済み点列を使って塗りつぶした。

`land_master_8192.json`では、海岸点列を`coastlines`レジストリへ一度だけ保持する。通常表示と選択表示はともに次の共有参照を使用し、点列を複製しない。

```json
{
  "registry": "coastlines",
  "id_list": "all_coastline_ids"
}
```

## 自動検証

全12項目が合格した。

- 正本外周と地理座標海岸線の点列一致
- 8192海岸線と共通変換結果の一致
- JSON海岸点列とGeoPackageの一致
- 通常表示と選択表示のレジストリ・IDリスト共有
- 海岸線IDの一意性と全件収録
- 変換メタデータの一致
- マスク寸法、画像モード、二値性
- 陸・海サンプル判定
- GeoPackage整合性とレイヤー構成
- 2回再生成した3成果物のSHA-256一致

再生成は`python tools/build_phase_c_coastline_mask.py`、検証は`python tools/verify_phase_c_coastline_mask.py`で行う。
