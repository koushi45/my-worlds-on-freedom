"""Generate a reviewable Japanese HTML report from measured counters."""
import html
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT/'builds/performance_800'
LABELS = ['feature_resources_20261003_r2','feature_ablation_20261003']
NAMES = {'title':'タイトル','house_selection':'大名選択','map_100_idle':'地図100%・静止','map_800_idle':'地図800%・静止','map_800_pan':'地図800%・移動','map_800_orbit':'地図800%・回転','map_800_no_bgm':'地図800%・BGM停止','map_800_time_x8':'地図800%・日付8倍','menu':'メニュー','dictionary':'武将辞典','retainers':'家臣管理','technology':'技術','diplomacy':'外交','options':'設定','map_after_panels':'各画面を閉じた後の地図','baseline_pan':'差分基準・移動','no_markers_pan':'マーカー非表示・移動','no_hex_group_pan':'六角形と子レイヤー非表示・移動','no_roads_pan':'共有道路省略・移動','no_shadows_pan':'影停止・移動','baseline_repeat_pan':'差分基準再計測・移動','district_info':'郡情報・建築枠','contour_map':'開発者用等高線図','army_home_idle':'出陣元の地図・部隊なし','army_one_time_x8':'出陣1部隊・日付8倍'}
def read(p): return json.loads(p.read_text(encoding='utf-8-sig'))
def num(v,d=1): return '未計測' if v is None else f'{v:.{d}f}'
def table(headers,rows):
    return '<table><thead><tr>'+''.join('<th>'+html.escape(h)+'</th>' for h in headers)+'</tr></thead><tbody>'+''.join('<tr>'+''.join('<td>'+html.escape(str(c))+'</td>' for c in row)+'</tr>' for row in rows)+'</tbody></table>'
reports=[read(OUT/(label+'_summary.json')) for label in LABELS]
release=read(OUT/'game_resources_summary.json')
report=read(ROOT/'builds/windows-latest/export_report.json')
blocks=['''<!doctype html><html lang="ja"><meta charset="utf-8"><title>機能別リソース使用量調査 2026-10-03</title><style>body{font:16px/1.7 system-ui;margin:40px auto;max-width:1300px;padding:0 24px;color:#20252b}h1,h2{line-height:1.3}table{border-collapse:collapse;width:100%;font-size:14px;margin:20px 0}td,th{border:1px solid #ccd2db;padding:8px;text-align:right}td:first-child,th:first-child{text-align:left}th{background:#eef2f6}.note{background:#f1f5fa;padding:16px}code{word-break:break-all}</style><h1>ゲームの機能別リソース使用量調査</h1><p>2026年10月3日。CPU・RAM・GPU・VRAMをWindowsの対象プロセス別カウンターで調査した。</p>
<h2>主要な発見</h2><ul><li>メモリの大きな用途は地図描画資源。800%の移動・回転では常駐RAM約1.06GiB、専用VRAM約1.32GiB。内部テクスチャ約1046MiBと描画バッファ約312〜322MiBを観測した。</li><li>CPUは地図静止で約0.94%、移動5.73%、回転5.46%。全20論理CPUでの平均なので、低い全体使用率からメインスレッドの余裕を判断できない。移動のマーカーCPU時間は平均3.25ms/フレーム、その内の遮蔽判定が約0.76ms。</li><li>管理画面の静止中は約60FPSだが、武将辞典の初回同期生成に528ms。辞典を開くとRAMが約136MiB増え、全画面を閉じた後もメニュー表示時より約147MiB多かった。辞典が独立したOfficerRegistryを作り武将JSON等を再解析することをコードで確認した。残留分すべてをこれだけに帰属させたり、単発試験でメモリリークと断定したりはしない。</li><li>日次処理の平均負荷は小さいが、月初の経済処理で最大23.12ms、家臣処理で最大7.34ms。経済だけで60FPSの1フレーム予算16.67msを超える処理を確認した。日次p95だけでは月初のピークを見落とす。</li><li>改善候補は辞典の初回生成・台帳の重複保持、月初経済処理、地図移動時のマーカー更新。GPU稼働率は今回の画面試験で主に12〜29%。解像度や地域、処理の競合で変化するので、これをGPUの最大負荷とは扱わない。</li></ul>
<h2>結果の読み方と計測条件</h2><p>CPUは全20論理CPUを100%とする平均使用率。5%は概ね1論理CPU分に相当する。RAMは実際に常駐するワーキングセット、コミットはプロセスが確保するプライベート領域。GPUは対象PIDの3Dエンジン稼働率、VRAMはWDDMが報告する専用GPUメモリ。GPU共有RAMは別に集計した。各表は機能表示中のプロセス全体の値であり、機能単独の割り当て量ではない。</p>
<p>Core i7-12700F（20論理CPU）、RAM約32GiB、RTX 4060（8188MiB）、ドライバー596.36、Godot 4.7.2 Compatibility/OpenGL。1920×1080、上限60FPS、VSync無効。地図は地点(4480,5504)、800%では俯角15°。各機能は2.5秒待機後に10秒計測。移動は10秒で半径160の円を1周、回転は10秒で360°。画面と日付8倍以外は日付を停止した。</p>
<p class="note">今回の詳細試験は既存WindowsリリースPCKをGodotのデスクトップ実行エンジンで読み、外部QAスクリプトから操作した。EXEのリリーステンプレートそのものの測定とは区別する。下に既存リリースEXEの計測結果も掲載する。別のゲームプロセスなどとの完全な競合排除はしておらず、値はこのPCでの観測値。ゲームの機能・UI・設定ファイル・ユーザーのセーブは変更していない。</p>
<p>CPU/RAMは約100ms間隔。ログの区間名が次の同期読込中にも残る場合に備え、CPU集計を実測区間の長さ−150msに制限した。GPUカウンターはWindowsの更新間隔を含むため、機能境界をまたぐ読み取りと各区間の最初の2回を除外し、最初の区間読取から実測長−1秒までに制限した。少数サンプルのGPU値や数%未満の差を精密な寄与率として扱わない。</p>''']
for r in reports:
    blocks.append('<h2>'+('画面・操作ごとの使用量' if r is reports[0] else '地図機能の差分試験・追加機能')+'</h2>')
    blocks.append(table(['機能','CPU %','RAM MiB','コミット MiB','GPU 3D %','VRAM MiB','共有GPU RAM MiB','FPS','p95 ms','GPU標本数'],[[NAMES.get(x['phase'],x['phase']),num(x['cpu_percent'],2),num(x['resident_ram_mib']),num(x['private_commit_mib']),num(x['gpu_percent']),num(x['vram_mib']),num(x['shared_gpu_ram_mib']),num(x['fps']),num(x['p95_ms']),x['gpu_samples']] for x in r['rows']]))
    blocks.append('<p>生データ識別子：<code>'+r['label']+'</code>、PID '+str(r['pid'])+'。表の平均RAMに対し、起動・読込中のピークは別途プロセスJSONに記録している。</p>')
    if r.get('recovery_source'):
        blocks.append('<p>この試行の最終JSONはチェックポイントのファイルハンドルを閉じるタイミングにより一部上書きされた。メタデータ・イベントは正常な冒頭部分、全15区間の結果は同時記録されたFEATURE_RESULTログから復元し、'+r['label']+'_recovered.jsonへ保存した。集計に補間値は使っていない。QAスクリプトの明示closeを追加して修正した。</p>')
    if r is reports[1]:
        base=next(x for x in r['rows'] if x['phase']=='baseline_pan')
        blocks.append(table(['機能停止時の差分（停止−基準）','CPUポイント','RAM MiB','GPUポイント','VRAM MiB'],[[NAMES[x['phase']],num(x['cpu_percent']-base['cpu_percent'],2),num(x['resident_ram_mib']-base['resident_ram_mib']),num(x['gpu_percent']-base['gpu_percent']) if x['gpu_percent'] is not None and base['gpu_percent'] is not None else '未計測',num(x['vram_mib']-base['vram_mib']) if x['vram_mib'] is not None and base['vram_mib'] is not None else '未計測'] for x in r['rows'] if x['phase'].startswith('no_')]))
blocks.append('''<p>差分試験は同一プロセスで順番に表示を切り替えた。非表示にしてもCPUデータ・テクスチャ・メッシュの資源参照は保持されるため、RAM/VRAMが減らないことは、その機能にメモリが不要という意味ではない。メモリ差にはストリーミング、キャッシュ、生成の履歴も含む。六角形グループには子の道路・奉行所タイルが含まれる。道路試験は共有道路描画の省略で、全道路データの解放ではない。停止時の差分は合算できない。基準再計測の差から試行中のばらつきも確認する。</p>
<p>基準CPUは初回6.22%から再計測4.65%へ1.57ポイント変化した。道路・六角形・影の停止時の小さなCPU差はこの変動と分離できない。マーカー停止で6.22→4.18%となったが、2.04ポイント全量をマーカー単独の寄与と断定せず、直接測ったマーカーCPUタイマーも合わせて見る。各機能を複数の独立プロセスで反復した寄与率測定は未実施。</p>
<h2>日次シミュレーションのCPU内訳</h2><p>日付進行のday_advancedに接続された実際のコールバックを、接続順序を維持してタイマーで囲み、365日進めた。各値にはその関数内から同期して呼ばれる通知処理を含む。月初だけ実行される処理は平均・p95が小さくても最大値が増える。出陣した1部隊を含む初期ゲーム状態の試験で、大量部隊・多数の建設命令・戦闘を伴う最大負荷ではない。</p>''')
daily=[e for e in reports[1]['events'] if 'mean_ms' in e]
blocks.append(table(['処理','日数','平均 ms/日','p95 ms/日','最大 ms/日'],[[Path(e['name']).name,e['days'],num(e['mean_ms'],4),num(e['p95_ms'],4),num(e['max_ms'],3)] for e in daily]))
blocks.append('<h2>画面を開く・セーブ形式を処理する際のCPU</h2><p>openの値は画面を開く同期呼び出し時間。画像の非同期読込や描画完了までの時間全体ではない。セーブ試験は現在形式の取得・JSON変換・解析・検証をメモリ上で実行し、ディスク保存／読込の所要時間は測っていない。</p><pre>'+html.escape(json.dumps([e for r in reports for e in r['events'] if 'mean_ms' not in e],ensure_ascii=False,indent=2))+'</pre>')
blocks.append('<h2>RAM・VRAMの用途</h2>')
blocks.append(table(['資源・機能','実装と観測','解釈'],[
['地図タイル・海・標高・地表素材','100%/800%のテクスチャ・バッファ量を下表に掲載。地図タイルのキャッシュ上限320MiB。','320MiBは地図タイル管理の予算で、ゲーム全体やVRAM全体の上限ではない。'],
['地形メッシュ・六角形','描画バッファ、地形のCPU配列、64区画の近景キャッシュ。遠景先読みは設定に応じ0/128/256MiB。','CPUとGPU双方に配置される資源がある。バッファ全体を地形単独の量と断定できない。'],
['地図描画先','別のSubViewportで2D地図を描き、3D地形に投影。最大4096×4096。','RGBA8のカラー1面は最大64MiBという理論値。深度等を含む実割当量ではない。'],
['地表素材','草・森・岩・雪それぞれ色／法線、倍率別にストリーム読込。800%は1536px。','8枚のRGBA8＋全mipmapなら約96MiBという理論値。内部形式、同時保持倍率で実量は変わる。'],
['武将肖像','辞典は表示範囲と前後3行をストリーム読込。512×512 RGBA8は1MiB/枚、mipmapなし。','全武将分の肖像を常駐させる実装ではない。PNGファイルサイズとは異なる。'],
['統治・内政・経済・外交・建設・部隊','辞書、配列、JSON由来のゲーム状態は同じプロセス内に保持。画面を閉じてもモデルは残る。','機能別の専有RAMをWindowsのプロセスカウンターから直接分離できない。'],
['BGM・効果音','OGGの音声資源とAudioStreamPlayer。計測時の保存設定ではBGM音量0。','BGM停止条件は既に無音の設定との比較。音量ありの音声負荷を代表しない。GPUへの直接描画はない。']]))
blocks.append(table(['画面','テクスチャ MiB（Godot）','描画バッファ MiB（Godot）','タイル管理内の推定コスト MiB'],[[NAMES.get(x['phase'],x['phase']),num(x['texture_bytes']/2**20),num(x['buffer_bytes']/2**20),num(x.get('map_cache_bytes',0)/2**20)] for x in reports[0]['rows']]))
blocks.append('<p>Godotの内部メモリ指標とWDDMの専用VRAMは対象・計算方法が異なり、一致する必要はない。各資源の予算と上記表も合算しない。<a href="https://docs.godotengine.org/en/stable/classes/class_performance.html">Godot公式Performance資料</a>では、一部指標がリリースで利用できないことと、最大1秒の更新遅延を説明している。</p>')
blocks.append('<h2>既存WindowsリリースEXEの測定</h2><p>本調査以前に同日取得されたresources_800の計測。800%・俯角15°・3地点、各操作600フレーム、最適化済み描画、日付停止。経路はフレーム数を基準とするため、今回の時間基準試験と直接差分比較しない。</p>')
blocks.append(table(['上限FPS・操作','CPU %','RAM GiB','GPU %','専用VRAM GiB','FPS'],[[str(r['fps_limit'])+'・'+('移動' if mode=='pan' else '回転'),num(v['cpu_percent_average'],2),num(v['resident_ram_gib']['average'],3),num(v['gpu_3d_percent']['average']),num(v['dedicated_vram_gib']['average'],3),num(v['fps'])] for r in release for mode,v in r['modes'].items()]))
blocks.append('<h2>対象リリースと再現</h2><p>対象PCK SHA256: <code>'+report['artifacts']['MyWorldsOnFreedom.pck']['sha256']+'</code>。既存の書き出し記録: builds/windows-latest/export_report.json。</p><pre>powershell -NoProfile -ExecutionPolicy Bypass -File tools/qa/measure_feature_resources.ps1 -Label feature_resources_20261003_r2\npython tools/qa/summarize_feature_resources.py feature_resources_20261003_r2\npowershell -NoProfile -ExecutionPolicy Bypass -File tools/qa/measure_feature_resources.ps1 -Label feature_ablation_20261003 -Script tests/base_map/godot/probe_feature_ablation.gd\npython tools/qa/summarize_feature_resources.py feature_ablation_20261003\npython tools/qa/report_feature_resources.py</pre><p>最初の試行は技術画面の区間途中でプロセスが終了し、完了ログと最終集計が得られなかったため採用せず、r2で取り直した。原因はログから特定できない。計測用QAスクリプトのみ追加したため、ゲーム変更に対する再ビルドは行っていない。</p></html>')
path=ROOT/'docs/FEATURE_RESOURCE_INVESTIGATION_20261003.html'
path.write_text('\n'.join(blocks),encoding='utf-8')
print(path)
