"""Join frame timers, serial ablations, Windows CPU samples, and QA metadata."""
import collections
import hashlib
import html
import json
import os
import statistics
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'builds/performance_800'
GROUPS=['markers','geometry','materials','atlas','confirm']
NAMES={'baseline':'通常（開始）','baseline_end':'通常（終了）','no_crests':'家紋画像のみ省略','no_text':'名称の幅取得・配置・描画を省略','no_occlusion':'山による遮蔽判定を省略','no_markers':'家紋・名称マーカー全体非表示','no_hex_lines':'六角形の線のみ省略','no_roads':'旧共有道路レイヤーを省略（現在は非表示）','freeze_near':'近景の更新・生成を停止','no_near':'近景更新停止＋近景非表示','no_shadows':'影を停止','no_3d':'3Dカメラの描画対象を空にする','no_detail_normal':'草・森・岩・雪の法線素材を省略','no_detail_albedo':'素材の色・平均色による合成を省略','simple_surface':'地表素材合成・法線素材・独自の霞を省略','constant_surface':'全テクスチャ参照を省く定色の地表','atlas_half':'地図描画先を縦横1/2','no_source_layers':'2D地図レイヤー全体非表示','freeze_atlas':'地図描画先の更新を停止','no_actual_roads':'現在の道路レイヤーを非表示','no_hydro':'川・湖を非表示','no_borders':'政治境界・郡境・勢力境界を非表示','no_office_tiles':'奉行所タイルを非表示（画面マーカーは維持）'}
FUNC_NAMES={'map_screen_markers._draw':'マーカー全体（家紋・名称・候補選別）','map_screen_markers._crest':'家紋画像の描画命令','map_screen_markers.text_width':'名称の幅取得・キャッシュ','editable_road_layer._draw':'道路全体','editable_road_layer.scan_and_project':'道路タイル走査・隣接確認・標高投影','water_layer:rivers._draw':'河川レイヤー','water_layer:lakes._draw':'湖レイヤー','district_office_layer._draw':'奉行所タイル（背景・縁）','hex_tile_layer._draw_content':'六角形の線全体','hex_tile_layer._draw_mesh_chunks':'六角形の区画メッシュ再利用・生成','terrain_chunk_set.update_visibility':'遠景メッシュの可視判定・LOD・差替え','terrain_chunk_set.update_near':'近景のジョブ確認・GPUメッシュ反映','main_map._process':'メインの毎フレーム更新全体','main_map._refresh_visible_tiles':'表示範囲・タイル要求の更新','main_map._pump_tiles':'ロード計画・ピン留め・資源反映','main_map._desired_tiles':'必要な地図タイルの選別','main_map._plan_prefetch':'先読み計画','main_map._retire_tiles':'不要タイルの退役判定','map_view_3d.advance':'3D視点・近景・素材の更新全体','map_view_3d.sync':'カメラと地図描画先・シェーダー値の同期','terrain_material_set.update':'倍率別素材の常駐・読込確認','map_asset_stream._advance_stream':'地図資源の読込キュー進行','water_layer:rivers._process':'河川投影・アップロードキュー確認','water_layer:lakes._process':'湖投影・アップロードキュー確認'}
def read(path): return json.loads(path.read_text(encoding='utf-8'))
def fmt(value,digits=3): return '—' if value is None else f'{value:.{digits}f}'
def table(headers,rows):
    return '<table><thead><tr>'+''.join('<th>'+html.escape(x)+'</th>' for x in headers)+'</tr></thead><tbody>'+''.join('<tr>'+''.join('<td>'+html.escape(str(x))+'</td>' for x in row)+'</tr>' for row in rows)+'</tbody></table>'

def enrich(label):
    data=read(OUT/(label+'.json')); proc=read(OUT/(label+'_process.json'))
    assert proc['exit_code']==0 and not proc['errors'] and not proc['timed_out'],label
    assert 'PROCESSING_COMPLETE' in (OUT/(label+'.log')).read_text(encoding='utf-8'),label
    for row in data['rows']:
        phase=row['variant']+' '+row['mode']; s=proc['samples']
        first=min(x['wall_seconds'] for x in s if x['phase']==phase)
        pairs=[(a,b) for a,b in zip(s,s[1:]) if a['phase']==b['phase']==phase and b['wall_seconds']>a['wall_seconds'] and b['wall_seconds']-first<row['seconds']-.15]
        wall=sum(b['wall_seconds']-a['wall_seconds'] for a,b in pairs)
        cpu=sum(b['cpu_seconds']-a['cpu_seconds'] for a,b in pairs)
        row['windows_cpu_percent']=cpu/wall*100/os.cpu_count()
        row['gpu_total_ms']=row['metrics']['root_gpu']['mean']+(row['metrics']['source_gpu']['mean'] if row.get('source_enabled',True) else 0)
        row['script_self_total_ms']=sum(x['self_ms_per_frame'] for x in row['functions'].values())
        ts=[x for x in proc.get('thread_samples',[]) if x['phase']==phase and x['threads'] and x['wall_seconds']-first<row['seconds']-.15]
        if len(ts)>1:
            a,b=ts[0],ts[-1]; before={t['id']:t for t in a['threads']}; seconds=b['wall_seconds']-a['wall_seconds']
            main=min(a['threads'],key=lambda t:t['created'])['id']
            deltas=[]
            for t in b['threads']:
                if t['id'] in before:
                    used=t['user']+t['kernel']-before[t['id']]['user']-before[t['id']]['kernel']
                    deltas.append({'thread':t['id'],'name':t['name'],'main':t['id']==main,'cpu_core_equivalent':used/seconds})
            row['threads']=sorted(deltas,key=lambda t:t['cpu_core_equivalent'],reverse=True)
        clocks=[x['gpu_clock_csv'].split(',') for x in proc.get('gpu_clocks',[]) if x['phase']==phase and x['wall_seconds']-first<row['seconds']-.15]
        if clocks: row['gpu_clock_mhz']={'min':min(int(x[0]) for x in clocks),'max':max(int(x[0]) for x in clocks)}
        native=[x for x in proc.get('native_samples',[]) if x['phase']==phase and x['wall_seconds']-first<row['seconds']-.15]
        if native:
            c=collections.Counter(x['module'] for x in native)
            row['native_instruction_samples']={'samples':len(native),'modules':dict(c),'mean_suspend_us':statistics.mean(x['suspend_us'] for x in native)}
        row['label']=label
    return data

groups={g:enrich('processing800_'+g+'_r1') for g in GROUPS}
cpu=enrich('processing800_final_r1')
road=enrich('processing800_cpu_r5')
extended=enrich('processing800_extended_r1')
native=enrich('processing800_native_r1')
all_data=[*groups.values(),road,extended,native,cpu]
summary={'datasets':all_data,'notes':['CPU function timers are elapsed main-thread time, not per-function GetThreadTimes.','Inclusive CPU timings nest; only self timings can be summed within the instrumented coverage.','GPU viewport time and Windows GPU utilization are different quantities.','Disabled viewport queries can retain an old time; exclude their stale readouts from totals.']}
(OUT/'processing800_summary.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')

baseline={mode:next(r for r in cpu['rows'] if r['variant']=='baseline' and r['mode']==mode) for mode in ['pan','orbit']}
header='''<!doctype html><html lang="ja"><meta charset="utf-8"><title>800%移動・回転の内部処理別負荷</title><style>body{font:16px/1.7 system-ui;max-width:1400px;margin:40px auto;padding:0 24px;color:#1c2734}h1,h2{line-height:1.35}table{border-collapse:collapse;width:100%;font-size:14px;margin:20px 0}td,th{border:1px solid #c5cfda;padding:8px;text-align:right}td:first-child,th:first-child{text-align:left}th{background:#e9eff6}.note{background:#eef3f8;padding:16px}code,pre{white-space:pre-wrap;word-break:break-all}</style><h1>地図800%・移動／回転：内部処理別負荷</h1><p>調査日：2026年10月3日。前回の全体CPU使用率5.73%／5.46%に対し、処理単位のCPU時間とGPU描画時間を追加調査した。</p>'''
blocks=[header,'<h2>結論</h2><ul><li>CPUの大きな処理は、マーカー候補の選別・遮蔽・名称処理、川と湖の描画更新、道路タイルの走査・投影。家紋画像を描く命令自体は約0.04ms/フレームで、マーカー全体の負荷とは区別する。</li><li>GPUは2D地図をテクスチャに描く段階と、それを3D地形へ貼って描く段階に分かれる。主なGPU差分は3D地形全体・影・地表素材／法線／霞のシェーダーにある。家紋のみの省略では大きなGPU時間減少は再現しなかった。</li><li>初めて表示する郡名の幅取得・文字整形に約3〜15ms/件の同期処理が発生。同じ経路を繰り返すと幅キャッシュの未登録件数が0になり、この初回処理は消えた。平均負荷と瞬間的な引っかかりは別問題。</li></ul>']
blocks.append('<h2>CPU：処理時間の直接計測</h2><p>単位はms/フレーム。開始時の通常表示の値。CPU関数内で経過した時間には同期して呼ぶエンジン処理や待ちを含む。画面マーカーとCanvasItemの_drawはメインの_processの外でも動く。</p>')
selected=['map_screen_markers._draw','map_screen_markers._crest','map_screen_markers.text_width','water_layer:rivers._draw','water_layer:lakes._draw','editable_road_layer._draw','editable_road_layer.scan_and_project','district_office_layer._draw','hex_tile_layer._draw_content','terrain_chunk_set.update_visibility','terrain_chunk_set.update_near','main_map._refresh_visible_tiles','main_map._pump_tiles','main_map._process','map_view_3d.advance','terrain_material_set.update','map_asset_stream._advance_stream']
cpu_rows=[]
for key in selected:
    a=baseline['pan']['functions'].get(key); b=baseline['orbit']['functions'].get(key)
    cpu_rows.append([FUNC_NAMES.get(key,key),fmt(a['inclusive_ms_per_frame']) if a else '—',fmt(b['inclusive_ms_per_frame']) if b else '—',fmt(a['max_call_us']/1000) if a else '—',fmt(b['max_call_us']/1000) if b else '—'])
blocks.append(table(['処理','移動 平均','回転 平均','移動 最大1呼出し','回転 最大1呼出し'],cpu_rows))
blocks.append('<p class="note">この表には親と子が混在するため合算しない。マーカー全体には家紋・幅取得・遮蔽が、道路全体にはタイル走査が、六角形全体には区画更新が含まれる。全instrumented関数のself時間は下の集計JSONに記録した。p95は各関数が動いたフレームについて集計しており、最大値は単回の観測である。</p>')
blocks.append(table(['操作','マーカー内の遮蔽 ms/frame','主スレッド近景反映とは別の生成ジョブ数','ジョブ実行の平均経過 ms/件','生成ジョブ合計÷フレーム ms'],[[mode,fmt(r['occlusion_ms_per_frame']),r['worker_jobs'],fmt(r['worker_job_wall_us']['mean']/1000),fmt(r['worker_wall_ms_per_frame'])] for mode,r in baseline.items()]))
blocks.append('<p>この経路では移動中に32近景区画を新規生成、回転では0区画。回転時の地形負荷を「毎フレーム近景メッシュを作り直している」とは説明できない。生成ジョブの値はワーカースレッド上の経過時間で、CPU関数表へ足し合わせない。</p>')
blocks.append('<h2>河川・湖・道路の処理内容</h2>')
water=[]
for mode,r in baseline.items():
    for x in r.get('water_layers',[]): water.append([mode,x['kind'],x['records'],x['retained_line_nodes'],x['visible_records_at_end'],fmt(x['hide_cpu_ms_per_frame'])])
blocks.append(table(['操作','水系','全レコード','保持線ノード','最後のフレームで描くレコード','全線ノードhide ms/frame'],water))
blocks.append('<p>川・湖は毎回、保持する線ノードを非表示に戻し、全レコードを走査して表示範囲に入るものを選び、線ノードを再表示する。表示中のレコード数だけの処理ではない。地図移動／回転による再描画のたびにこの走査が起きる。道路は全7515タイルを走査し、範囲内のセルの隣接関係と標高投影を計算する。道路全体の時間の大半が走査・投影で、線メッシュconfigureの部分は残り約0.1ms前後。</p>')
blocks.append('<p>現在表示される道路はdeveloper_tools.road_layer（editable_road_layer.gd）。旧shared_road_layerは通常状態で非表示のため、旧レイヤーのみ停止するno_roads試験は現在の道路の寄与を表さない。追加したno_actual_roadsで実際の道路を止めた。</p>')
blocks.append('<h2>初回文字処理のピークと再利用</h2>')
blocks.append(table(['条件・操作','幅キャッシュ未登録数','ヒット数','未登録時の幅取得合計 ms','遅い幅取得の最大 ms','マーカー最大 ms'],[[NAMES[r['variant']]+'・'+r['mode'],r['font_width_cache']['misses'],r['font_width_cache']['hits'],fmt(r['font_width_cache']['miss_us']/1000),fmt(max((x['us']/1000 for x in r['font_width_cache']['slow']),default=0)),fmt(r['functions'].get('map_screen_markers._draw',{}).get('max_call_us',0)/1000)] for r in cpu['rows']]))
blocks.append('<p>計測したのはFont.get_string_sizeの同期経過時間。初回の整形・フォント／文字情報の準備等を含むが、フォント内部の各段階までは分離していない。幅の取得と文字のGPU描画は別処理。初回以外の文字配置や描画は継続する。最大マーカー時間には幅取得以外の描画準備やOSのスケジューリングも含む。</p>')
blocks.append('<h2>GPU：2つの描画段階</h2><p>Godotのviewport別GPUタイムスタンプを使用。2D地図は1968×4096のSubViewportへ描き、3D地形シェーダーがそのテクスチャを参照する。主画面のGPU時間には3D地形と家紋・名称・HUDを含む。</p>')
blocks.append(table(['通常状態・操作','地図描画先GPU ms/frame','主画面GPU ms/frame','2段階の合計 ms/frame','CPU描画命令 ms/frame（2段階）','描画呼出し数','描画頂点／索引数'],[[mode,fmt(r['metrics']['source_gpu']['mean']),fmt(r['metrics']['root_gpu']['mean']),fmt(r['gpu_total_ms']),fmt(r['metrics']['source_cpu']['mean']+r['metrics']['root_cpu']['mean']),fmt(r['metrics']['draw_calls']['mean'],0),fmt(r['metrics']['primitives']['mean'],0)] for mode,r in baseline.items()]))
blocks.append('<p>このタイマーはGPUの経過ms、前回の29%／19%はWindowsの3Dエンジン稼働率で、相互に機能別の割合として割り振れる値ではない。CPUとGPUは並行動作するため、CPU関数のmsへGPUのmsを足してフレーム時間を再構成しない。</p>')
blocks.append('<h2>処理を個別に止めたGPU比較</h2><p>同一プロセスの通常（開始）と通常（終了）の平均を基準とし、停止−基準の差を掲載。負値はその描画段階が短くなった観測。特に小さな差はクロック変動や試行中のばらつきと区別できない。</p>')
delta_rows=[]
for group,data in groups.items():
    if group=='confirm': continue
    for mode in ['pan','orbit']:
        refs=[r for r in data['rows'] if r['mode']==mode and r['variant'] in ('baseline','baseline_end')]
        ref_source=statistics.mean(r['metrics']['source_gpu']['mean'] for r in refs)
        ref_root=statistics.mean(r['metrics']['root_gpu']['mean'] for r in refs)
        for r in data['rows']:
            if r['mode']!=mode or r['variant'] in ('baseline','baseline_end','no_roads','freeze_atlas'): continue
            delta_rows.append([NAMES[r['variant']]+'・'+mode,fmt(r['metrics']['source_gpu']['mean']),fmt(r['metrics']['root_gpu']['mean']),fmt(r['metrics']['source_gpu']['mean']-ref_source),fmt(r['metrics']['root_gpu']['mean']-ref_root)])
blocks.append(table(['停止条件・操作','地図描画先GPU ms','主画面GPU ms','地図描画先差分 ms','主画面差分 ms'],delta_rows))
blocks.append('<p>影の停止は主画面GPU時間を約0.6〜0.8ms短縮。地表素材・法線・独自の霞の省略は約0.3〜0.7ms短縮し、別プロセスで再確認した。3D描画全体を止めると主画面は家紋・名称・HUD等の描画だけとなり、約0.3〜0.5msのGPU時間が残る。通常と比べ約1.5〜2msの差。これらは重なる処理を含み合算できない。</p>')
blocks.append('<p>草・森・岩・雪の色4枚、平均色取得4回、法線4枚、遠景色、地図描画先のサンプリングが地表シェーダーにある。素材合成の計算、法線処理、霞も同じシェーダーに含まれるため、「テクスチャ参照だけの厳密なGPU時間」とは断定しない。定色シェーダーも比較したが、サンプリング以外の計算と一部の頂点側計算の最適化も含む差分である。</p>')
blocks.append('<p>atlas_halfは描画先を984×2048へ縮め、描画先GPU時間を約0.9ms短縮した一方、主画面のGPU時間増加を観測した。描画先だけの短縮を全体の改善と扱わない。freeze_atlasでは更新しないviewportの取得値が過去のまま残ったため、その古いタイマー値を合計から除外した。表示は不正になる診断条件である。</p>')
blocks.append('<h2>CPU停止比較・実際の道路と水系</h2>')
blocks.append(table(['条件・操作','Windows CPU %（全20論理CPU）','instrumented自己時間合計 ms/frame','マーカー ms/frame','FPS'],[[NAMES[r['variant']]+'・'+r['mode'],fmt(r['windows_cpu_percent'],2),fmt(r['script_self_total_ms']),fmt(r['marker_ms_per_frame']),fmt(r['fps'],1)] for data in [road,extended] for r in data['rows']]))
blocks.append('<p>WindowsのCPU使用率をそのまま関数ごとへ配分していない。関数タイマーは主スレッドの経過時間、Windowsカウンターは全スレッドのuser＋kernel CPU時間。測定カバレッジ外のエンジン処理・OS／ドライバ呼出し・計測器自身があり、元の5.73%／5.46%の完全な足し算による分解ではない。</p>')
blocks.append('<h2>メインスレッド・ネイティブ処理の追加確認</h2>')
thread_rows=[]
for r in road['rows']:
    t=r.get('threads',[])
    if t: thread_rows.append([NAMES[r['variant']]+'・'+r['mode'],fmt(sum(x['cpu_core_equivalent'] for x in t)),fmt(sum(x['cpu_core_equivalent'] for x in t if x['main'])),fmt(sum(x['cpu_core_equivalent'] for x in t if not x['main']))])
blocks.append(table(['条件・操作','対象プロセスの論理CPU相当','主スレッドの論理CPU相当','その他スレッド相当'],thread_rows))
blocks.append('<p>主スレッドは通常状態で約0.9〜1論理CPUを使用。全体CPU約5%という値でも、主スレッドに余裕が大きいとは言えない。回転中の近景生成0件と合わせると、ワーカーのメッシュ生成が継続負荷の中心という説明は当てはまらない。</p>')
native_rows=[]
for r in native['rows']:
    if r['variant'] not in ('baseline','baseline_end'): continue
    n=r.get('native_instruction_samples')
    if n:
        modules=n['modules']; count=n['samples']
        native_rows.append([NAMES[r['variant']]+'・'+r['mode'],count,fmt(modules.get('godot.exe',0)/count*100,1),fmt(modules.get('nvoglv64.dll',0)/count*100,1),fmt(n['mean_suspend_us'],1)])
blocks.append(table(['FPS上限なし・条件','標本数','Godot実行コード %','NVIDIA OpenGLコード %','1標本の停止時間 μs'],native_rows))
blocks.append('<p>QAプロセスの主スレッドを短時間停止して命令位置だけを取得する統計サンプリング。関数単位のコールスタックやCPU時間配分ではない。上限なし・追加計測器ありの別条件なので前回の使用率へ乗算しない。Godotコード内の滞在が大部分で、NVIDIA OpenGLコード内にも標本があるが、描画ドライバだけが全負荷を占める観測ではない。Godot内部の未分離分をGDScript／2D描画管理等へ厳密に分類するにはネイティブ関数のシンボル付きプロファイルが必要。</p>')
blocks.append('<h2>改善候補</h2><ol><li>川・湖の全レコード走査と全線ノードhide／show：空間区画から表示候補を取得し、前フレームとの可視差分だけを更新する。</li><li>道路の全7515タイル走査：道路区画ごとの線メッシュを再利用し、カメラ移動のたびに全国のタイルを走査しない。</li><li>郡名の初回幅取得・文字準備：読込中や段階的な先読みで準備し、カメラ操作中の同期処理を減らす。</li><li>マーカー候補選別と遮蔽：表示候補を空間検索で絞り、既存の遮蔽キャッシュと選択例外を維持する。</li><li>GPU側：必要なら影と素材合成を調整。ただし家紋画像の縮小・非表示を最優先とする根拠は今回得られなかった。</li></ol><p>この依頼では改善は実装せず、効果測定用のQAコードと報告書のみ追加した。</p>')
blocks.append('<h2>条件・再現・生データ</h2><p>i7-12700F（20論理CPU）、RTX 4060、Godot 4.7.2 Compatibility/OpenGL、1920×1080、800%、俯角15°、VSync無効、日付停止。注視点(4480,5504)を中心に10秒で半径160の円を一周、回転は10秒で360°。安定待ち30フレームと各区間1.5秒待機後、各10秒計測。主試験は60FPS上限、native試験は上限なし。前回と同じPCKを計測用Godotエンジンから実行した。</p>')
blocks.append('<p>CPUタイマーはメモリ上でGDScriptを差し替えて挿入した。全メンバー状態を保存して復元し、ゲームファイルやPCKへ書き戻していない。タイマー追加のオーバーヘッドとクロック変動は残る。GPU機能停止比較は主に計測タイマーを入れないプロセスで実行した。GPUのpower stateは同じでもクロックは変わり得る。GPU小差の断定を避け、開始／終了の基準と別プロセスの再試行を併記した。</p>')
blocks.append('<p><a href="https://docs.godotengine.org/en/stable/classes/class_renderingserver.html#class-renderingserver-method-viewport-get-measured-render-time-gpu">Godot公式：viewport GPU時間</a>はviewport別の合計で全体を求めること、FPS制限時のGPUクロック変化に注意することを説明している。CPU描画タイマーはスクリプトの_processを含まない。</p>')
pack=ROOT/'builds/windows-latest/MyWorldsOnFreedom.pck'
with pack.open('rb') as f: digest=hashlib.file_digest(f,'sha256').hexdigest()
assert digest=='3f5a0feefe8050ac47e64dcd868093fb37091b76e35b7d88a6edde4534780c72'
blocks.append('<p>PCK SHA256: <code>'+digest+'</code>。受理した計測区間数：'+str(sum(len(d['rows']) for d in all_data))+'。JSONとログは<code>builds/performance_800/processing800_*</code>、統合集計は<code>processing800_summary.json</code>。初期CPU試行r1〜r3は計測器の接続／構文問題で採用せず、r4は水系・道路のカバレッジが不足していたため最終表には使わなかった。</p>')
blocks.append('<pre>python tools/qa/run_processing_800.py markers geometry materials atlas confirm\npython tools/qa/run_processing_probe.py tests/base_map/godot/probe_processing_800.gd processing800_final_r1 --pack --instrument --variants=baseline,baseline_end --output=C:/Users/nanoa/projects/my-worlds-on-freedom/builds/performance_800/processing800_final_r1.json\npython tools/qa/report_processing_800.py</pre></html>')
path=ROOT/'docs/MAP_800_PROCESSING_INVESTIGATION_20261003.html'
path.write_text('\n'.join(blocks),encoding='utf-8')
print(path)
for mode,r in baseline.items():
    print(mode,'script self',fmt(r['script_self_total_ms']),'GPU stages',fmt(r['metrics']['source_gpu']['mean']),fmt(r['metrics']['root_gpu']['mean']))
    print([(k,fmt(r['functions'][k]['inclusive_ms_per_frame'])) for k in selected if k in r['functions']])
