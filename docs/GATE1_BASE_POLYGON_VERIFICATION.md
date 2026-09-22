# 検証ゲート1：基盤ポリゴン承認レポート

検証日: 2026-09-06  
確定版: `1.0.0`  
状態: **承認済み**

## 結果

自動検査14項目はすべて合格した。

| 検査 | 結果 |
|---|---:|
| 無効ジオメトリ | 0件 |
| 空ジオメトリ | 0件 |
| 自己交差 | 0件 |
| 重複面 | 0件 |
| NaN座標 | 0件 |
| 想定範囲外 | 0件 |
| 意図しない重なり（許容0.01m²） | 0件 |
| 修復前後の面積差（許容1m²） | 0m² |
| GeoPackage / GeoJSON面積差（許容0.01m²） | 0.00006103515625m² |
| GeoPackage / GeoJSON構成数 | 154 / 154 |
| 原本座標との最大変位 | 0m |
| 修復箇所 | 0件 |
| GeoPackage整合性 | OK |
| 承認前派生レイヤー | 0件（`japan_land`のみ） |

GeoPackageとGeoJSONはそれぞれ2回再生成し、各形式でSHA-256が一致した。

- GeoPackage: `258BAE08B94EBC870DE0CF59779780B4A623CA5B7D56E8539EEC6CD749E12B59`
- GeoJSON: `CFC5C7DADFCDD11975B9945B1B03DADECDB87E5B6476AA2573C48D5A680444DE`

機械可読の全検査値は`data/base/verification/gate1_report.json`を正とする。

## 目視検査成果物

- 全国全景: `data/base/verification/visual/national_overview.png`
- 地方別一覧: `data/base/verification/visual/regions_index.png`
- 地方別原寸8枚: `data/base/verification/visual/regions/`
- 海岸頂点表示: `data/base/verification/visual/coast_vertices.png`
- 原本との差分ヒートマップ: `data/base/verification/visual/source_difference_heatmap.png`
- 修復箇所一覧: `data/base/verification/visual/repair_locations.png`

確認対象は海岸形状、対象島の過不足、地域ごとの切断・異常線の有無である。南西諸島と小笠原諸島、および2km²未満の島は承認済み仕様により対象外である。

## 承認記録

ユーザーからフェーズCへ進む明示指示を受け、`data/base/japan_land_master_manifest.json`へ承認者、承認日時、確定版`1.0.0`を記録した。`derived_layers_allowed`は`true`である。

以後の派生物は、承認済み正本の版とSHA-256を入力条件として記録する。
