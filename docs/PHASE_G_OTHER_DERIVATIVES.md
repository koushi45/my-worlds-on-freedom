# フェーズG：その他の派生レイヤー

作成日: 2026-09-06  
入力正本: `japan_land` 版`1.0.0`  
状態: **生成・検証パイプライン完成／各原本待ち**

## 現在の状態

河川、湖、道路、城、文化、人口、地形分類について承認済み原本は存在しない。位置や属性を推測せず、全カテゴリを`missing`、件数0として記録した。

## 成果物

| 成果物 | パス |
|---|---|
| 派生レイヤーGeoPackage | `data/derived/phase_g/phase_g_layers.gpkg` |
| データレジストリ | `data/derived/phase_g/phase_g_registry.json` |
| 地形分類ラスター | `data/derived/phase_g/terrain_classification_8192.png` |
| 地形分類コード | `data/derived/phase_g/terrain_codes.json` |
| マニフェスト | `data/derived/phase_g/phase_g_manifest.json` |
| 自動検証結果 | `data/derived/phase_g/phase_g_verification.json` |

現在のGeoPackageは、陸地全体を未割当として保持する`unassigned_land`だけを収録する。地形分類ラスターは8192×8192で、全画素が`unclassified = 0`である。

## 入力契約

承認済み原本は`data/sources/approved/phase_g/`へ配置する。

| 種別 | ファイル | レイヤー | 必須属性 |
|---|---|---|---|
| 河川 | `rivers.gpkg` | `rivers` | river_id, name, geometry |
| 湖 | `lakes.gpkg` | `lakes` | lake_id, name, geometry |
| 道路 | `roads.gpkg` | `roads` | road_id, name, geometry |
| 城 | `castles.gpkg` | `castles` | castle_id, name, rank, geometry |
| 文化 | `cultures.gpkg` | `culture_regions` | culture_id, name, geometry |
| 人口 | `population.gpkg` | `population_regions` | population_id, population, year, geometry |
| 地形 | `terrain.gpkg` | `terrain_regions` | terrain_id, terrain_class, geometry |

全ファイルにCRSと一意IDが必要である。不足属性、CRS欠落、重複IDがあれば生成を停止する。

## 変換・包含規則

- 河川と道路はWGS 84地理座標を正本とし、基盤陸地へクリップしてから共通8192変換を適用する。
- 湖、文化、人口、地形領域は基盤陸地との積集合を取る。
- 城は基盤陸地内のPointだけを採用し、外部の城は拒否一覧へ記録する。
- 城は`castle_master`へ地理座標だけを保存する。表示座標は実行時に共通変換から計算し、別保存しない。
- 地形分類はフェーズCの`land_mask_8192.png`をハッシュ付きで直接参照し、陸地外を0へクリップする。
- 斜め表示は実行時の視覚変換だけとし、斜め座標や斜め用地理データを保存しない。

## 生成されるレイヤー

原本採用後は必要に応じて次のレイヤーを生成する。

- `river_master` / `river_game_8192`
- `lake_master`
- `road_master` / `road_game_8192`
- `castle_master`
- `culture_master`
- `population_master`
- `terrain_master`

城に`castle_game_8192`は生成しない。

## 検証

全11項目が合格した。

- 7種類の入力契約と欠落状態
- 未承認データが0件であること
- 基盤陸地全体の未割当保持
- 不要な空レイヤーを生成しないこと
- 合成河川・道路の陸地クリップと共通変換一致
- 合成城の陸地内採用・陸地外拒否
- 城の地理座標限定保存契約
- 地形分類とフェーズCマスクのハッシュ一致
- 陸上要素の包含規則
- 斜め座標成果物が存在しないこと
- 全成果物の決定論的再生成

再生成は`python tools/build_phase_g_derivatives.py`、検証は`python tools/verify_phase_g_derivatives.py`で行う。
