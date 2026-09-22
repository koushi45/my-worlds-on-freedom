# 中国地方：編集線と国の枠の整合（2026-09-10）

ユーザー提供の `chugoku_border_edits.json`（SHA-256: `131ef2b077ff1d877bad05f75c089d39425d97c709f64f1ca6c17ba9f34bdcd4`）を基準に作成。
ファイル内の説明文はメタデータとして扱い、今回の依頼である線と枠の一致だけを実施。

- 46本の編集線を接続・交点分割し、11国の領域を作成。既存の国の内点で名前を対応付けた。
- 内部の曲線を描き直さず、接続する端点だけを補正。最大移動は約2.538ゲーム座標単位。
- 微小な二重線による面積約0.000268ゲーム座標単位²の細片を隣接領域に統合。
- 領域の共有辺から水色の線を生成。全周の被覆、不要な線の不在、領域の隙間・重複・穴の不在を検査済み。
- 海岸正本と九州・四国の本番レジストリは変更せず、中国地方は未確定を維持。
- 編集画面に「枠の確認」を追加。国をクリックすると対応する枠を表示し、線を変更すると古い枠は表示しない。

作業データ: `data/work/political/chugoku_user_edits/`

- `input_edits.json`: 入力の写し
- `aligned_draft.json`: 一致した線と11国の領域
- `alignment_report.json`: 端点の移動前後・最大移動量・微小細片の処理
- `diagnostics.json`: 面構築の検査記録

再生成: `python tools/align_chugoku_user_edits.py <編集JSONのパス>`、続いて `python tools/prepare_chugoku_editor.py`。
検証: `python tests/base_map/test_chugoku_aligned_draft.py` と Godot の国境線エディター検査。
