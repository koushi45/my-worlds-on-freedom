# フェーズF：政治境界とクリック判定

作成日: 2026-09-06  
入力正本: `japan_land` 版`1.0.0`  
状態: **生成・検証パイプライン完成／歴史領域原本待ち**

## 現在の状態

承認済みの戦国期・旧国領域データは現在のワークスペースに存在しない。現代行政区画、画像推定、ボロノイ分割などで代替せず、政治領域は0件のままとした。

対象陸地全体は`unassigned`として保存し、理由を`historical_source_missing`、確定状態を`unconfirmed`として記録した。

## 成果物

| 成果物 | パス |
|---|---|
| 政治領域GeoPackage | `data/derived/political/political_regions.gpkg` |
| 選択・クリック参照レジストリ | `data/derived/political/political_registry.json` |
| 被覆・重複・隙間監査 | `data/derived/political/political_audit.json` |
| フェーズマニフェスト | `data/derived/political/phase_f_manifest.json` |
| 自動検証結果 | `data/derived/political/phase_f_verification.json` |

現在のGeoPackageには`unassigned_land`だけを収録する。存在しない政治領域、境界線、クリックマスクの空レイヤーは作成していない。

## 歴史領域の入力契約

将来採用する原本は次の場所と構成にする。

```text
data/sources/approved/historical_regions.gpkg
  └─ historical_regions
```

必須属性は次のとおり。

| 属性 | 内容 |
|---|---|
| `region_id` | 一意で永続的な地域ID |
| `region_name` | 国名・地域名 |
| `certainty` | confirmed / probable / unconfirmed等 |
| `geometry` | CRSが明示されたPolygonまたはMultiPolygon |

入力後は必ず次の式で生成する。

```text
political_region = historical_region ∩ japan_land_master
```

## 境界線と海岸線

政治境界は、異なる2地域の境界が実際に共有するLineString部分だけを`shared_boundaries`へ保存する。各地域ポリゴンの外周をそのまま境界線として保存しない。

海岸部分は座標を複製せず、フェーズCの`coastline_id`と`start_fraction`・`end_fraction`で参照する。国選択表示は次の組み合わせで構成する。

```text
selection_outline = shared_boundary_ids + coastline_references
```

## クリック判定

原本追加後はクリップ済み政治領域から`click_masks`を生成する。クリックマスクには次の制約を固定する。

- `purpose = hit_test_only`
- `render_enabled = false`
- 表示線をクリックマスクから逆生成しない
- 選択表示は共有境界IDと海岸線参照だけを使用する

現在は政治領域が0件のためクリックマスクも0件である。

## 現在の監査結果

| 項目 | 結果 |
|---|---:|
| 政治領域 | 0件 |
| 共有境界 | 0件 |
| クリックマスク | 0件 |
| 地域間重複 | 0件 |
| 政治領域被覆率 | 0% |
| 明示的未割当面積 | 370,015,444,691.9631m² |
| 面積収支誤差 | 0.000427m² |

全11検査が合格した。さらに合成用の仮想2地域を用いたテストで、陸地との積集合、共有辺のみの抽出、海岸線ID区間参照が機能することを確認した。

再生成は`python tools/build_phase_f_political.py`、検証は`python tools/verify_phase_f_political.py`で行う。
