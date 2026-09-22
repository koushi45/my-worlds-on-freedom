# Natural Earth 1:10m Land単独比較レポート

> **後続決定:** 本レポートは比較時点の評価を保存したものである。2026-09-06にユーザーがNatural Earth 1:10m Land 5.1.1単独を正式採用したため、「不採用推奨」は意思決定として上書きされた。正本は`PHASE_B_BASE_POLYGON_REPORT.md`を参照すること。

作成日: 2026-09-06  
対象: **Natural Earth 1:10m Land 5.1.1のみ**  
除外: Natural Earth Minor Islands、その他のNatural Earthテーマ  
比較対象: 国土交通省「国土数値情報 行政区域データ N03-20260101」

## 結論

Natural Earth 1:10m Land単独は、世界・日本全体を表示する広域参考図には使用できるが、日本地図の基盤ポリゴンには採用しないことを推奨する。

主な理由は、Landテーマが主要な陸地・島を対象とする1:10,000,000の一般化済みデータであり、小島が別テーマのMinor Islandsへ分離されていることである。Land単独に限定すると、瀬戸内海、九州西岸、南西諸島を中心に島の欠落がさらに増える。湾奥、港湾、細い水道、複雑な半島もN03より大幅に単純化されている。

権利面ではパブリックドメインで、商用利用、改変、再配布が可能であり、表示義務と継承義務はない。ただし、権利処理の容易さだけでは本プロジェクトの狭域表示精度を満たさない。

## 取得データ

| 項目 | 内容 |
|---|---|
| データ名 | Natural Earth 1:10m Land |
| 配布元 | Natural Earth |
| 版番号 | 5.1.1 |
| 取得日 | 2026-09-06 |
| 配布ページ | `https://www.naturalearthdata.com/downloads/10m-physical-vectors/10m-land/` |
| ダウンロードURL | `https://naturalearth.s3.amazonaws.com/10m_physical/ne_10m_land.zip` |
| 原本 | `data/sources/candidates/natural_earth_10m/raw/ne_10m_land.zip` |
| 原本サイズ | 3,269,070 bytes |
| SHA-256 | `E547D749445EAA0964ABA76738090EC88F5E63C4585122170F98C67A7EA922DC` |
| CRS | WGS 84経緯度（EPSG:4326、配布`.prj`で確認） |
| 公称縮尺 | 1:10,000,000 |
| ライセンス | Public domain |
| 商用利用 / 改変 / 再配布 | 可 / 可 / 可 |
| 表示義務 / 継承義務 | なし / なし |

保存した利用条件本文:

- `data/sources/candidates/natural_earth_10m/license/terms-of-use.html`
- SHA-256: `02A4B0B61D556BF5BB5BB48F034D21C017497B9FE715EFF29D0453EA1E06259A`

## 原本形状監査

`ne_10m_land.shp`を加工前の状態で検査した。

| 検査項目 | 結果 |
|---|---:|
| フィーチャ数 | 11 |
| 総頂点数 | 446,175 |
| リング数 | 6,838 |
| 無効形状 | 0 |
| 空形状 | 0 |
| 面積0形状 | 0 |
| 完全重複形状 | 0 |

これは世界全体の配布Shapefileに対する形状検査であり、日本の海岸が現地測量精度を持つことを意味しない。Natural Earth自身も位置精度を保証しておらず、地図表示向けに一般化されたデータである。

## 比較条件

次の条件を両候補で統一した。

- 地点ごとに同じJGD2011平面直角座標系へ変換
- 同じ中心座標、物理幅・高さ、ピクセル寸法
- 平滑化、簡略化、海岸補正、島の追加を行わない
- Natural Earth側は`ne_10m_land.shp`だけを描画
- `ne_10m_minor_islands.shp`は読み込まない

比較一覧:

`data/phase_a/comparisons_natural_earth_land_only/00_all_areas_index.png`

## 地域別結果

| 地域 | Land単独の評価 | 除外されたMinor Islandsフィーチャ数（比較窓内） |
|---|---|---:|
| 北海道 | 本島形状は維持されるが、周辺の小島と海岸の細部が少ない | 6 |
| 東京湾 | 湾形状は判別可能。埋立地、港湾、細い水路が大幅に省略 | 1 |
| 伊勢湾 | 湾奥・志摩半島・島嶼が一般化される | 2 |
| 大阪湾 | 淡路島等の主要島は残るが、小島・港湾形状が不足 | 6 |
| 瀬戸内海 | 多島海表現には不足。Land単独化の影響が特に大きい | 64 |
| 九州西岸 | 長崎・天草周辺の小島と複雑な水道が不足 | 70 |
| 南西諸島 | 主要島は残るが、島列の連続性と小島収録が不足 | 21 |

フィーチャ数は各比較窓と交差するNatural Earth Minor Islandsの数であり、日本領のみの法的・行政的集計ではない。九州西岸などの窓には周辺国の範囲も含まれる。

## 画像一覧

- `01_hokkaido.png`
- `02_tokyo_bay.png`
- `03_ise_bay.png`
- `04_osaka_bay.png`
- `05_seto_inland_sea.png`
- `06_western_kyushu.png`
- `07_nansei_islands.png`
- `comparison_manifest.json`

## 採用判断

| 用途 | 判断 |
|---|---|
| 日本陸地の基盤ポリゴン | 不採用推奨 |
| 狭域マップ | 不適 |
| クリック判定・海岸道路・城配置の基準 | 不適 |
| 世界規模の参考図 | 適 |
| 品質比較用ベンチマーク | 適 |
| 商用同梱 | 法的には可能だが、本プロジェクトでは品質不足 |

本比較は評価資料であり、Natural Earth Landから基盤ポリゴンやLODは生成していない。
