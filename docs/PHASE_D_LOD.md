# フェーズD：5段階LOD

作成日: 2026-09-06  
入力正本: `japan_land` 版`1.0.0`  
状態: **生成・自動検証済み**

## 成果物

| 成果物 | パス |
|---|---|
| 5段階陸地・海岸線GeoPackage | `data/derived/lod/japan_lod.gpkg` |
| 共有点列・表示設定JSON | `data/derived/lod/japan_lod.json` |
| LODマニフェスト | `data/derived/lod/lod_manifest.json` |
| 自動検証結果 | `data/derived/lod/lod_verification.json` |
| 全景プレビュー | `data/derived/lod/preview/` |

## LOD仕様

正本をフェーズCと同じ8192平面座標へ変換してから、詳細側から広域側へネスト型で簡略化する。ShapelyのDouglas–Peucker簡略化を`preserve_topology=True`で使用する。

| LOD | 用途 | 累積簡略化目標 | 小島表示面積 | 表示数 / 保持数 |
|---:|---|---:|---:|---:|
| 0 | 全国 | 4.0px | 100km²以上 | 21 / 154 |
| 1 | 地方 | 2.0px | 25km²以上 | 40 / 154 |
| 2 | 地域 | 1.0px | 10km²以上 | 66 / 154 |
| 3 | 狭域 | 0.5px | 2km²以上 | 154 / 154 |
| 4 | 最大詳細 | 0px | 全件 | 154 / 154 |

面積しきい値未満の島も削除しない。全LODの`land_lod*`と`coastline_lod*`に154件すべてを保持し、`visible`フラグだけを切り替える。

## 陸地と海岸線の共有

GeoPackageには各LODについて`land_lod0`～`land_lod4`と`coastline_lod0`～`coastline_lod4`を収録した。海岸線は各LODの簡略化済み陸地ポリゴン外周から直接生成する。

`japan_lod.json`ではLODごとに海岸点列レジストリを一度だけ保持する。通常表示と選択表示は同じ`coastline_registry`と`visible_coastline_ids`を参照するため、別点列を持たない。

## LOD切替差分

粗いLODは直後の詳細LODから追加分だけ頂点を間引く。粗いLODで保持された全頂点は、次の詳細LOD海岸線上に残る。

| 切替 | 最大Hausdorff差 | 許容値 | 保持頂点移動 |
|---|---:|---:|---:|
| LOD0 → LOD1 | 2.6688px | 4px | 0px |
| LOD1 → LOD2 | 1.1720px | 2px | 0px |
| LOD2 → LOD3 | 0.3971px | 1px | 0px |
| LOD3 → LOD4 | 0.7145px | 1px | 0px |

最大詳細LODはフェーズCの`coastline_8192`と点列が完全一致する。

## 検証

自動検査11項目はすべて合格した。

- 全5段階を収録
- 全LODで154陸地フィーチャを保持
- 妥当性、空形状0、意図しない重なり0
- 陸地外周と同LOD海岸線の点列一致
- 通常表示・選択表示の共有参照
- JSONとGeoPackageの海岸点列一致
- 全LOD頂点が詳細正本点列由来
- LOD4とフェーズC海岸線の完全一致
- 全切替の差分予算と保持頂点移動検査
- GeoPackage整合性
- 2回再生成した全成果物のSHA-256一致

再生成は`python tools/build_phase_d_lod.py`、検証は`python tools/verify_phase_d_lod.py`で行う。
