# 全郡候補を表示する未確定Windows版

2026-09-18更新。ユーザーの「未確定版として郡をすべて描画」の依頼に基づき、現行66親領域と採用島郡4件の全676区画をWindows版へ収録した。島郡は対馬・平戸島・村上水軍領地・淡路島だけとし、ベース地図の海岸線を直接使用する。

[Windows版を起動](../../builds/windows-district-unconfirmed/MyWorldsOnFreedom.exe)／[配布ZIP](../../builds/windows-district-unconfirmed/MyWorldsOnFreedom-Windows-Unconfirmed.zip)。ZIPは展開し、exeとpckを同じフォルダーに置いて起動する。

起動引数は不要。「郡境」は初期状態でオン。上部に「未確定版：全郡候補・破線＝推定」と表示する。拡大すると郡境・郡名が現れ、「郡を選択」または「郡一覧・検索」で詳細を確認できる。詳細にも未確定版・史料上の採用は保留と明記する。

全国表示での線・ラベルの抑制、画面外データの解放、文字衝突の回避は維持する。全候補を収録しているが、画面に全ての文字を同時表示する仕様ではない。形状根拠のない旧郡候補を新たに描き起こす処理は含まない。既存の未確定領域を別の郡へ割り当てずに表示する。

## 採用済み版との区別

`Windows Unconfirmed` エクスポートプリセットに `district_unconfirmed` 機能を付け、`data/derived/districts/unconfirmed/` の専用スナップショットを読み込む。元の比較形状・地表メッシュをそのまま複製し、出典・確度・残件を保持する。各区画の採否はheldのままである。

採用済み台帳、工程Gの国別採用判断、国境、海岸、道路、拠点の座標は変更しない。採用済み国は引き続き0。従来の `Windows` プリセットは採用済みデータのみを収録し、今回の未確定版は別フォルダーへ出力する。

## 再生成・ビルド

```powershell
python -X utf8 tools/build_district_unconfirmed.py
python -X utf8 tools/build_independent_district_fills.py
godot_console --headless --path . --export-release "Windows Unconfirmed" builds/windows-district-unconfirmed/MyWorldsOnFreedom.exe
```

開発環境で同じデータを確認する場合は `-- --district-unconfirmed` を指定する。これは従来の `--district-review` と異なり、配布用スナップショットを使う。

## 検証

全676区画の収録、全代表点の包含、穴の除外、クリック候補、表示切替、検索・詳細、平面・立体の400%表示を検証した。島郡4件の外周座標列がベース海岸線と完全一致し、旧自動生成島郡77件が現行データ・検索・統治表示から消えていることも検証する。

[配布スナップショットのハッシュ台帳](../../data/derived/districts/unconfirmed/manifest.json)／[ビルド・起動検証](../../builds/windows-district-unconfirmed/build-verification.json)／[400%平面](../../builds/windows-district-unconfirmed/district_400_flat.png)／[400%立体](../../builds/windows-district-unconfirmed/district_400_oblique.png)／[詳細欄](../../builds/windows-district-unconfirmed/district_details.png)

出典：CODH／人間文化研究機構、CC BY-NC 4.0。境界と所属の年代・位置には未確認事項が残る。史料上の採用・配布条件の扱いは工程Gの記録を引き継ぐ。
