# my-worlds-on-freedom

現在のゲーム画面では、境界付近の郡クリックを最寄りの1郡へ自動確定します。重複確認用の赤塗りUIと左側の統治情報パネルは削除済みです。支配家・統治担当・拠点等の統治台帳はセーブ処理を含む内部データとして維持しています。

2026-09-18現在、島郡は対馬・平戸島・村上水軍領地・淡路島の4件だけです。旧自動生成島郡77件は現行データと表示設定から削除し、4件をベース地形の海岸線と完全一致する新しい形状で収録しました。通常郡672件と合わせて全676郡です。島には重複する専用郡境線を描かず、ベース海岸線をそのまま境界に使います。[実装と検証](docs/DISTRICT_ENCLAVE_MERGES.md)。

[重複優先設定・追加8組対応Windows](builds/windows-district-priorities-2/MyWorldsOnFreedom.exe)を追加しました。田村郡・耶麻郡・東蒲原郡・久慈郡・那須郡が関わる指定8組を追加反映しました。全749郡を維持し、判断待ちの重複は93組です。[全16組の優先設定](docs/districts/overlaps/RESOLVED_PRIORITIES.md)。

[指定優先・微細重複整理版Windows](builds/windows-district-priorities/MyWorldsOnFreedom.exe)を追加しました。指定8組の重複を優先郡へ残し、微細な重複と赤丸の14片を整理しました。749郡を維持し、残る大きな重複101組を赤く表示しています。[処理内容と名称の対応](docs/districts/overlaps/RESOLVED_PRIORITIES.md)。

[消滅区画の整理版Windows](builds/windows-retired-districts/MyWorldsOnFreedom.exe)を追加しました。知多郡周辺（仮）など、重複除去後に極細の残片だけが残った33郡を区画単位で削除。ラベル・検索・統治・拠点参照・セーブを749郡に統一しました。[削除した区画の一覧](docs/districts/overlaps/RETIRED_DISTRICTS.md)。

[重複・未確定範囲の赤塗り表示版Windows](builds/windows-district-warning/MyWorldsOnFreedom.exe)を追加しました。通常郡同士の重複1422組と統合先未確定14片を赤く塗り、14片には位置を示す赤い丸を追加しています。右下の「赤塗り：重複・統合先未確定」で表示を切り替えられます。

[仮称郡の重複修正版Windows](builds/windows-provisional-overlap-fix/MyWorldsOnFreedom.exe)を追加しました。「（仮）」の郡から重複部分を除去し、描画・選択・セーブを782郡に更新しました。通常郡同士の重複と統合先未確定の14片は[判断待ちの報告](docs/PROVISIONAL_OVERLAPS.md)に記載しています。

[飛び地整理版Windows](builds/windows-connected-districts/MyWorldsOnFreedom.exe)を追加しました。飛び地を近隣郡へ統合し、島は77の独立郡としました。全786郡を外周1本の連続した形状に統一。旧セーブの読み込みにも対応。[統合内容と検証](docs/DISTRICT_ENCLAVE_MERGES.md)。

[郡境独立版Windows](builds/windows-independent-districts/MyWorldsOnFreedom.exe)を追加しました。郡境を国境より上に描き、634郡は国境で切り取る前の形状から復元しました。国境を越える部分も郡として表示・選択できます。[変更と検証](docs/INDEPENDENT_DISTRICT_BORDERS.md)。

[開始画面・セーブ付きWindows版](builds/windows-start-menu/MyWorldsOnFreedom.exe)を追加しました。静止画のタイトルから大名家を選択して開始し、5スロットで保存・再開できます。右上またはEscでメニューを開きます。オプションでは1280×720から4Kまでのウィンドウサイズを選択でき、初期値は1920×1080です。辞典は準備中。[仕様と検証](docs/START_MENU.md)。

郡・城・港・都市の支配家、大名、統治担当を表示するようにしました。[統治情報付きWindows版](builds/windows-governance/MyWorldsOnFreedom.exe)・[検索付き統治台帳](docs/governance/register_1546.html)・[設定方針と検証](docs/governance/IMPLEMENTATION.md)。709郡・採用済み254拠点に対応。既存武将設定を優先し、不足箇所を調査資料で補完。ゲーム用の任命・暫定領有と史料確認済みの役職を区別し、未詳・自治・未築城も明記しています。

ゲーム内時間と操作欄を追加しました。[時間システム付きWindows版を起動](builds/windows-game-time/MyWorldsOnFreedom.exe)。1546年1月1日開始、通常は1秒1日。スペースで停止／再開、数字キー1・2・3・4で1倍・2倍・4倍・8倍に切り替えます。右上に年月日、再生／停止、減速・加速、現在速度を表示。[仕様・検証](docs/GAME_TIME.md)。

シームレス地図版を追加しました。[Windows版を起動](builds/windows-seamless/MyWorldsOnFreedom.exe)。色付き全国図の常駐、表示を保持した差し替え、先読み、CPUワーカー、GPU破線、非同期ログを実装しています。[実装・検証・スマホ実機での残件](docs/SEAMLESS_MAP_IMPLEMENTATION.md)。

ゲーム画面をマップのみの表示に変更しました。[マップのみのWindows版](builds/windows-map-only/MyWorldsOnFreedom.exe)。情報パネル・ボタン・一覧・詳細ダイアログを通常起動から除外し、城などの拠点名・郡名に付けていた「※」も削除しています。武将・拠点・郡・出典等の内部データは保持。開発用UIは明示的な起動引数 `-- --developer-ui` でのみ生成します。

スクロール拡大・縮小時に郡境の破線処理が無限ループになる不具合を修正しました。[修正版Windowsを起動](builds/windows-zoom-fix/MyWorldsOnFreedom.exe)。停止の検知・直前のズーム操作・エラーを通常起動から自動保存します。[原因・ログの場所・検証](docs/ZOOM_FREEZE_FIX.md)。

武将名簿1598人の全5能力を評価し、未評価は0人になりました。今回の残件40件は、名簿18人の評価・時代違い16人の参考評価・誤収録6件の対象外整理として記録しています。[今回の評価・理由](docs/officers/REMAINING_40.md)・[検索付き武将台帳](docs/officers/officers_1546.html)。既存1580人の点数を保持。資料不足は12前後、失敗のみは5前後、失策のない任務参加は標準遂行として評価。開始年1546年、地図1582年、生涯評価、各最大30点・1点刻み、総合150点。[実装と検証](docs/officers/IMPLEMENTATION.md)。

マップの軽量化版を追加しました。描画線の集約、地形・郡メッシュの事前生成、非同期読み込み、キャッシュ制限、画像のGPU圧縮を実装しています。[Windows配布ZIP](builds/windows-performance/MyWorldsOnFreedom-Windows-Performance.zip)・[Android確認用APK](builds/android-performance/MyWorldsOnFreedom.apk)・[性能比較と検証・残件](docs/MAP_PERFORMANCE_RESULTS.md)。400%・709区画の未確定表示を維持。Android実機での性能は未検証です。

道路を実線表示に変更しました。[Windows版を起動](builds/windows-solid-roads/MyWorldsOnFreedom.exe)・[配布ZIP](builds/windows-solid-roads/MyWorldsOnFreedom-Windows-SolidRoads.zip)。道路形状・接続関係は維持し、凡例も「黄実線＝道」に更新しました。郡の推定境界は破線です。

養父郡を神崎郡へ追加合併し、未確定75領域に資料由来の仮称を付けました。現在は709区画です。[命名一覧と参照元](docs/districts/PROVISIONAL_NAMES.md)・[Windows版を起動](builds/windows-district-named/MyWorldsOnFreedom.exe)・[面積一覧](docs/districts/areas/district_areas.html)。

35 km²以下の郡を近隣の郡へ合併した未確定版を追加しました。郡候補635・未確定75、計710区画です。[合併一覧と残件](docs/districts/MERGE_SMALL_35.md)・[更新後の面積一覧](docs/districts/areas/district_areas.html)・[Windows版を起動](builds/windows-district-merged-35/MyWorldsOnFreedom.exe)。

全郡候補を表示する未確定Windows版を追加しました。現在は676区画です。本州・九州・四国・北海道外の島郡は対馬・平戸島・村上水軍領地・淡路島の4件だけを残し、ベース地図の海岸線をそのまま範囲に使用します。郡中央は白い家紋を表示し、領有線と半透明塗りには189家それぞれの固定テーマカラーを使用します。武田家の赤、伊達家の黒など明確なイメージを優先し、残りは隣接勢力間で近似色にならないよう配色します。右下から同色の半透明塗りを切り替えられます。[Windows版を起動](builds/windows-district-unconfirmed/MyWorldsOnFreedom.exe)・[配布ZIP](builds/windows-district-unconfirmed/MyWorldsOnFreedom-Windows-Unconfirmed.zip)・[家紋表示](docs/governance/KAMON.md)・[仕様と検証](docs/districts/UNCONFIRMED_WINDOWS.md)。

工程GのWindows版をビルドしました。[Windows版を起動](builds/windows-district-stage-g/MyWorldsOnFreedom.exe)・[配布ZIP](builds/windows-district-stage-g/MyWorldsOnFreedom-Windows-StageG.zip)。採用済み国は0のため、通常表示では郡境・郡名は表示されません。

郡の工程Gを追加しました。66領域の国別比較資料を作成し、採用済みの国だけを通常実行へ取り込む方式へ切り替えています。現在は全件保留のため通常起動の郡は0件です。[工程Gの仕様・検証・採用比較](docs/districts/STAGE_G.md)・[国別一覧](docs/districts/STAGE_G_INDEX.md)。保留候補の比較はエディター版Godotの起動引数 `-- --district-review` で利用できます。

[郡区画の工程A・B：調査報告と国別台帳](docs/districts/SURVEY_AB.md)を作成しました。全66親領域の入力版・史料上の国との暫定対応を固定し、比較一覧697件と別資料から追加した候補10件を記録しています。名称・年代・位置の根拠と利用条件を分け、1582年の採用可否は個別に管理しています。[工程Cの比較境界網と位置合わせ記録](docs/districts/STAGE_C.md)を追加しました。全国66領域の後世比較形状を共有境界網にし、和泉の古地図補正案は精度不足で保留しています。[工程Dの閉区画・差分・隣接記録](docs/districts/STAGE_D.md)では、66領域を郡候補673区画と未確定75区画に閉じました。[工程Eの拠点・道路対応](docs/districts/STAGE_E.md)を追加しました。254拠点の座標照合と285路線の通過区画を派生し、史料所属の未確認・不一致は保留しています。[工程Fの郡表示・選択](docs/districts/STAGE_F.md)を現在のGodotプロジェクトに追加しました。郡境切替・国／郡モード・検索・詳細・立体対応が利用できます。1582年の境界確定とWindows配布版への同梱は未実施です。[全体の作業手順書](docs/DISTRICT_BOUNDARIES_WORK_INSTRUCTIONS.md)。

ズーム上限を400%に統一し、拡大時の陸地・海岸線をポリゴンと線で描画、高解像度の地形・陰影タイルへ切り替えるようにしました。座標は8192×8192を維持。[400%高精細版Windowsを起動](builds/windows-detail-400/MyWorldsOnFreedom.exe)。[仕様と検証](docs/DETAIL_MAP_400.md)。

和泉に岸和田城、摂津に石山本願寺、河内に高屋城、大和に筒井城を追加しました。合計254拠点・推定連絡路285路線。年代上の相違は拠点詳細に明記しています。[近畿4城追加版Windowsを起動](builds/windows-kinki-four/MyWorldsOnFreedom.exe)。[追加内容と接続経路](docs/settlements/KINKI_FOUR_CASTLES.md)。

「1582年の道」は表示・専用データ・生成処理ごと削除しました。道路は推定連絡路281路線のみです。接続済み246拠点・陸路対象外4拠点を維持しています。[推定連絡路のみのWindows版を起動](builds/windows-connections-only/MyWorldsOnFreedom.exe)。[変更内容](docs/road_connections/SHARING.md)。

250拠点の道路接続初版を追加しました。281本のゲーム用推定連絡路で246拠点を本州・九州・四国の陸路網へ接続し、海峡を挟む4拠点は航路の別工程としています。上部の「推定連絡路」で表示を切り替え、「道・接続状態を調べる」から路線と番号付き通過点を選択できます。「拠点一覧・検索」には接続状態と残件を表示します。新しい渡河625区間は全て方法・対象年の位置が未確認です。[接続台帳](docs/road_connections/CONNECTIONS_1582.md)・[検証記録](docs/road_connections/QA_1582.md)。

[1582年の城・主要集落・港を自然な道でつなぐ作業手順書](docs/ROAD_CONNECTIONS_1582_WORK_INSTRUCTIONS.md)。拠点の出入口、幹線への接続、地形に沿う通過点、渡河、接続網の検証と地域別の完了条件を定めています。

城・主要集落・港を合計250拠点に拡張しました。地方別の比率を維持し、同じ都市・城下の9件を統合して別の場所を204件追加しています。上部の「1582年・250拠点」と「城」「集落」「港」で表示を切り替え、「拠点一覧・検索」から地域・名称で探せます。平面・立体の両表示に対応。年代・位置は推定を含む地域代表点で、全史料の網羅調査・精密比定は未完了です。 [配分と統合方針](docs/settlements/EXPANSION_250.md)・[配置台帳](docs/settlements/PLACEMENT_1582.md)・[検証記録](docs/settlements/QA_1582.md)。

[1582年の城・主要集落・港を配置する作業手順書](docs/SETTLEMENTS_1582_WORK_INSTRUCTIONS.md)を作成しました。年代・位置・採用判断を分けて管理し、日向・大隅・薩摩から地域別に配置する手順を定めています。

現在は主要41河川の本流と湖を表示します。その他の川は非表示です。[最新版Windowsを起動](builds/windows-latest/MyWorldsOnFreedom.exe)。「主要河川」「湖」の切替と「琵琶湖へ移動」で確認できます。[水系レイヤー・検証記録](docs/WATER_LAYERS.md)を参照してください。最新版は `builds/windows-latest/` にまとめています。旧ビルドの削除は実行環境の自動承認審査に拒否され、未実行です。

標高の別レイヤーと、実標高に基づく傾斜・起伏のあるゲーム内地図を追加しました。起動時の切替スイッチで平面表示と比較できます。[標高レイヤーの仕様・Windows版・検証記録](docs/ELEVATION_LAYER.md)を参照してください。

九州本島の9旧国境界 v1.0.0 を承認済みとして本番マップへ組み込みました。[Windows版と検証記録](docs/KYUSHU_PRODUCTION_RELEASE.md)を参照してください。起動後の「九州へ移動」から確認できます。

Godot開発環境のみを保持した再構築用プロジェクトです。

日本マップを作り直す際は、最初に[基盤ポリゴン起点の作業指示書](docs/BASE_MAP_REBUILD_WORK_INSTRUCTIONS.md)に従って基盤データを確定してください。

Natural Earth 1:10m Land 5.1.1の正式採用後、[フェーズB基盤ポリゴン作成](docs/PHASE_B_BASE_POLYGON_REPORT.md)、[検証ゲート1の承認](docs/GATE1_BASE_POLYGON_VERIFICATION.md)、[フェーズC海岸線・陸地マスク](docs/PHASE_C_COASTLINE_AND_LAND_MASK.md)、[フェーズD・5段階LOD](docs/PHASE_D_LOD.md)、[フェーズE・地図画像と地形レイヤー基盤](docs/PHASE_E_MAP_IMAGES_AND_TERRAIN.md)、[フェーズF・政治境界とクリック判定](docs/PHASE_F_POLITICAL_AND_CLICK.md)、[フェーズG・その他派生レイヤー](docs/PHASE_G_OTHER_DERIVATIVES.md)まで進行しています。正本は`data/base/japan_land.gpkg`の`japan_land`版`1.0.0`です。フェーズF・Gは処理系検証済みですが、実データは承認済み原本待ちです。

[地図基盤テスト10件](docs/MAP_TEST_REQUIREMENTS.md)は`python tools/run_map_test_suite.py`で実行でき、現在すべて合格しています。

戦国期向けの令制国境界を追加する際は、指定Wikimedia Commons画像の時代補正、地域別位置合わせ、共有境界、海岸線参照、クリック判定を定めた[政治境界レイヤー作業指示書](docs/SENGOKU_POLITICAL_BOUNDARY_WORK_INSTRUCTIONS.md)に従います。

1546年の[所属家・立場・配置郡の一覧](docs/officers/AFFILIATIONS_1546.md)を追加しました。所属家の案550人、ゲーム用の郡配置535人。全1598人について未誕生・故人・史料不足を区別し、所属未確認を確定史実として扱わないよう記録しています。郡は各家の本拠圏内へ分散配置しています。
