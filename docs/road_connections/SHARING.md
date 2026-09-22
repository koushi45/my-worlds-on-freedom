# 推定連絡路のみの道路表示

2026-09-12、「1582年の道」を削除した。81回廊のJSON、専用資料、専用レイヤー・生成スクリプト・テスト・資料表示・地域選択UIを削除。拠点の旧道路アンカー参照とエクスポート設定からも依存を除いた。

推定連絡路281路線、接続済み246拠点、陸路対象外4拠点、渡河625区間を維持。既存の固定通過域は推定連絡路の独立した `waypoints.json` と `plan.json` で管理する。拠点250件の座標と採否は変更していない。

描画は推定連絡路だけから1574本の共有描画区間を生成し、一度だけ描く。画面上の「推定連絡路」をオフにすると道路表示はすべて消える。路線の選択、番号付き通過点、接続状態の表示、平面・立体切替は維持。

距離・方向・並走長による推定連絡路同士の共有化は引き続き有効。設定は `data/editorial/road_connections/sharing.json`。距離6px、方向差25度、並走長16pxを基準にし、全水系・陸地・勾配を検査する。道路形状はゲーム用の推定。

再生成は `python tools/build_settlements.py` と `python tools/build_road_connections.py`。入力が不変の場合、後者は `--reuse-routes` で探索済み線形を利用できる。表示だけなら `python tools/build_shared_road_display.py`。

検証は道路・拠点のPythonテスト、`tools/audit_road_connection_topology.py`、Godotの `test_road_connections.gd`、`test_settlements.gd`、実描画の `test_connections_only.gd`。

[平面の確認画像](../../builds/connections_only_flat.png)・[立体の確認画像](../../builds/connections_only_oblique.png)。配布版は `builds/windows-connections-only/`。過去の配布版とは別フォルダー。
