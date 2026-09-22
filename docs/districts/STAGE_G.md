# 工程G：国別の検証・採用・差し戻し

2026-09-12。現行66親領域の候補図、時代補正、検査結果、現行国との差分を国別の版として保存した。取り込み・再生成・差し戻しの仕組みは実装・検証済み。**現時点の採用済み国は0、通常実行の郡区画も0**。技術検査の合格から歴史的な採用を自動決定しない。

[66領域の比較一覧](STAGE_G_INDEX.md)から、各国の候補図・差分面・入力ハッシュ・時代補正・拠点照合へ進める。[検証記録](../../data/editorial/districts/stage_g/qa.json)と[採用中の実行時台帳](../../data/derived/districts/accepted/index.json)を併せて保存した。

## 採用判断の比較案

各国のA案は「現行国の外周を維持し、後世資料による郡候補と未確定領域をゲーム用推定として採用」。B案は「史料確認まで保留し、通常実行には取り込まない」。A案でも未確定面を周囲の郡へ吸収せず、1582年の確定境界・確定所属にはしない。

|国|閉区画数|未確定面積率|具体的な判断点|
|---|---:|---:|---|
|[和泉](stage_g/izumi.md)|5|8.30%|A案は後世比較形状を使う。元禄図の位置合わせはRMSE約1.75kmで保留のため取り込まない。B案は境界の追加比定を待つ。|
|[摂津](stage_g/settsu.md)|13|16.50%|A案でも石山本願寺の史料上の東成と面判定の西成の不一致を保持。所属だけを西成へ確定しない。B案は個別比定を待つ。|
|[河内](stage_g/kawachi.md)|16|30.54%|A案は約3割の未確定面を明示して使用。B案は大きな隙間・差分の検討を優先する。|
|[大和](stage_g/yamato.md)|16|9.17%|A案でも筒井城の添下という間接的な手掛かりと面判定の平群の相違を残す。B案は直接史料の確認を待つ。|

甲斐・信濃は工程Bの旧郡候補と後世の郡区分が一致しない。位置根拠のない旧郡を新たな面として足さず、対象年代から除外した郡を復活させない。各国ページの時代補正を採用判断に含める。

東北の7表示領域は後世の国区分と陸奥・出羽との暫定対応を含む。A案では現在の表示領域を維持し、史料上の国との対応を別属性で保持する。B案では保留する。陸奥・出羽として親国そのものを統合する案は、現行国の別改訂として差分検討が必要であり、今回の郡取り込みでは行わない。

出典のCODH／人間文化研究機構データはCC BY-NC 4.0。現行の取り込みゲートは非商用利用の判断を要求する。商用用途への転用判断はこの採用処理に含まない。

## 保存単位と実行時の分離

- `data/work/districts/stage_g/packages/<国ID>/<候補版>/`：不変の比較資料。候補図、Dの面・差分、Fの表示形状・地表メッシュ、入力・史料・検査の記録をまとめる。原本のheld状態を保持する。
- `data/editorial/districts/stage_g/countries/`：国別の比較版への参照。`decisions/`：対象版、判断理由・参照、国対応、時代差、全区画の採否、利用範囲を記録する採用台帳。再生成で採用判断を上書きしない。
- `data/master/districts/releases/<国ID>/<採用版>/`：採用判断付きの不変の採用済み版。比較原本と分離する。
- `data/derived/districts/accepted/`：採用済み版と、現在使う国別の版を指定するindex。選んだ国の行だけを更新し、他国の版・形状を保持する。

取り込みには、対象国と候補版の一致、国対応・時代差の明示、全区画の扱いが必要。候補は `accepted_game_estimate`、未確定面は `accepted_unresolved_area` として明示採用する。保留区画の欠落や残存、入力改変、現行親国の変更を検出した場合は拒否する。未確定面の採用は、その面を郡として確定する意味ではない。

通常起動は採用済みindexだけを読み、候補キャッシュへの代替読み込みはしない。実行時も採用状態、版、国別メタデータ、形状・メッシュのハッシュを確認する。エディター版Godotで `-- --district-review` を明示した場合だけ、工程Fの保留候補を比較表示する。配布版ではこの比較モードを有効にできない。

エクスポート設定には採用済みデータを追加し、work・editorial・masterの除外を維持した。過去の採用済み版は差し戻し用に残るが、実行時はindexで指定した版だけを読む。既存Windows実行ファイルは保持し、工程G版を別フォルダーへビルドした。[Windows版](../../builds/windows-district-stage-g/MyWorldsOnFreedom.exe)・[配布ZIP](../../builds/windows-district-stage-g/MyWorldsOnFreedom-Windows-StageG.zip)・[ビルド検証](../../builds/windows-district-stage-g/build-verification.json)。Godot 4.7.2で出力し、ヘッドレスおよびOpenGLの起動・終了が正常であることを確認した。

## 再生成と差し戻し

```powershell
# 和泉のD・Eから表示用キャッシュと国別比較版を再生成する
python -X utf8 tools/manage_district_stage_g.py regenerate izumi

# 記録された採用判断と候補版を検証して取り込む（現在の保留台帳では拒否する）
python -X utf8 tools/manage_district_stage_g.py integrate izumi

# 指定国を通常実行から外す。他国は維持する
python -X utf8 tools/manage_district_stage_g.py rollback izumi --revision none

# 採用版へ戻す場合、noneの代わりにその国の既存採用版IDを指定する
python -X utf8 tools/manage_district_stage_g.py verify
```

`prepare` は現行候補を国別に凍結して比較資料を更新する。`regenerate` は一国を必須指定とし、上流の史料判断や国境を変更せず、D・Eからその国の表示用成果を再生成する。どちらも自動で通常実行へ取り込まない。通常の変換や検査のための承認操作は不要で、採用台帳が必要になるのはゲーム用の採用判断を反映する時だけである。

## 検証結果

66領域・748閉区画について、包含、重複、共有線、表示面と元面の一致、代表点、地表格子に沿う三角形を検査した。国別packetに結果と入力ハッシュを保存した。

隔離したテスト用台帳で和泉・河内を採用し、和泉の版切替・差し戻し・除外の間、河内のメタデータと採用ファイルが不変であることを確認した。保留・古い版・不完全な区画判断・国対応未記録・改変ファイルは取り込みを拒否した。テスト用採用は実際の採用台帳へ書き込んでいない。

和泉の再生成では、他国の808ファイルと実行時indexが同じハッシュを維持し、和泉自身も同じ候補版を再現した。Godotで採用済みデータの読み込み・クリック・塗り、通常起動での保留除外、比較モードの全区画検査、既存400%ズームの回帰検査を実施した。

```powershell
python -X utf8 tests/base_map/test_district_stage_g.py
godot_console --headless --path . --script res://tests/base_map/godot/test_district_default.gd
godot_console --headless --path . --script res://tests/base_map/godot/test_districts.gd -- --district-review
godot_console --headless --path . --script res://tests/base_map/godot/test_detail_zoom.gd
```
