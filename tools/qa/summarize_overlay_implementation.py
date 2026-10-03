"""Compare legacy and production overlays in the same Windows release."""
import json
import statistics
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'builds/performance_800'

def fps(rows):
    return sum(r['frames'] for r in rows) / sum(r['frames']/r['fps'] for r in rows)

def main():
    for name in ('overlay_exported_test_process','overlay_angle_gpu_process','overlay_normal_startup'):
        verification = json.loads((OUT/(name+'.json')).read_text(encoding='utf-8'))
        assert verification['exit_code']==0 and not verification['errors']
    export = json.loads((ROOT/'builds/windows-latest/export_report.json').read_text(encoding='utf-8'))
    assert export['exit_code']==0 and not export['error_lines'] and len(export['artifacts'])==2
    runs = {}
    for variant in ('baseline', 'production_overlays'):
        runs[variant] = []
        for round_number in (1, 2):
            name = f'fps_{variant}_implemented{round_number}'
            data = json.loads((OUT / (name+'.json')).read_text(encoding='utf-8'))
            process = json.loads((OUT / (name+'_process.json')).read_text(encoding='utf-8'))
            assert process['exit_code']==0 and not process['errors'] and len(data['results'])==9
            runs[variant].append(data['results'])
    summary = {}
    for variant, rounds in runs.items():
        summary[variant] = {
            mode: statistics.median(fps([r for r in rows if r['mode']==mode]) for rows in rounds)
            for mode in ('pan','orbit')
        }
        summary[variant]['moving_p95_ms_range'] = [
            fn(r['p95_ms'] for rows in rounds for r in rows if r['mode']!='idle')
            for fn in (min,max)
        ]
    (OUT/'overlay_implementation_summary.json').write_text(json.dumps(summary,indent=2)+'\n',encoding='utf-8')
    lines = ['# 近距離描画を維持するFPS改善の実装結果（2026-10-03）','',
             '通常起動に六角形メッシュ再利用・マーカー更新要求の集約・遠方マーカー制限・遮蔽結果の100ms再利用を組み込んだ。','',
             '- 六角形の線は区画ごとのGPUメッシュを保持し、共有辺を1回だけ描画する。ズーム・色はシェーダー値で更新し、投影の変更時に再生成する。ズームアウト時は区画を拡大し、保持する区画数を64以内に制限する。道や奉行所タイルは既存の表示を維持する。',
             '- 家紋・名称・部隊の表示は800%で注視点から半径512世界座標以内。倍率を下げると半径を倍率に反比例して広げ、200%未満の国表示では制限しない。画面外・山の裏のマーカーを強制表示する仕様ではない。',
             '- 選択中の郡（郡パネルを開いている場合を含む）・史跡・部隊は距離制限と遮蔽キャッシュの例外。選択中の名称は他の名称との重なりによる省略からも除外する。',
             '- 通常マーカーの遮蔽結果を最大100ms再利用し、画面位置は毎回更新する。大きな移動・回転、ズーム・角度・地形状態の変更では再判定する。操作を止めても期限に再判定する。移動部隊はIDで保持し、位置変化を確認する。クリック時は正確な判定を使う。','',
             '## Windowsリリース版の比較','',
             '同一リリースの最適化無効／通常設定を各2回測定。1920×1080、800%、俯角15°、3地点（近畿・富士・関東）、各モード120フレーム、VSync・FPS制限を無効、日付進行停止。3地点のフレーム数／所要時間でFPSを集計し、2回の中央値を掲載。','',
             '| 操作 | 最適化無効 | 通常設定 | 改善倍率 |','|---|---:|---:|---:|']
    for mode, label in [('pan','移動'),('orbit','回転')]:
        before,after = summary['baseline'][mode],summary['production_overlays'][mode]
        lines.append(f'| {label} | {before:.1f} FPS | {after:.1f} FPS | {after/before:.2f}倍 |')
    p95 = summary['production_overlays']['moving_p95_ms_range']
    lines += ['',f'通常設定の移動・回転中のp95フレーム時間は{p95[0]:.1f}〜{p95[1]:.1f}ms。平均60 FPS以上でも常時60 FPSを保証する結果ではない。カメラ移動はフレーム数基準なので、高FPSでは現実時間に対する移動速度が速くなる。時間ベースのキャッシュ効果はこの条件の測定値。','',
              '## 確認','',
              '- 近距離29マーカーの可視性、六角形の端点が従来と一致（ヘッドレス試験1,662辺、書き出しPCKのGPU試験1,629辺）。メッシュ再利用、拡大率による区画サイズ変更、保持数上限、選択例外、正確なクリック判定、キャッシュの期限と停止後の再更新を検証。',
              '- 既存の480本の視線判定・静止中の描画保持・HUDの更新、部隊の出陣・移動・帰還・現在形式の保存／読み込みを確認。',
              '- GPU上の視点角度QAはPASS。クリック位置の最大誤差0.003px、注視点固定の最大誤差0.015px。200%・400%・800%、平面表示、山地・沿岸を含む画面を確認。',
              '- Windowsリリースを書き出し、EXE/PCKの存在・SHA256・エラーなしを確認。書き出したPCKの追加試験と通常EXE起動も確認。','',
              '六角形の線の縁はメッシュ用シェーダーの描画になる。遠方の家紋・名称は非表示となり、非選択マーカーの山による隠れ／出現には最大約100ms（次のフレームまでの時間を加算）の遅延がある。距離境界ではフェードせず表示が切り替わる。大量の部隊が移動する場面など、全状況のFPSを測定した結果ではない。','',
              '生データ・ログ・固定画面: `builds/performance_800/fps_*_implemented[12]*`。集計: `overlay_implementation_summary.json`。リリース記録: `builds/windows-latest/export_report.json`。','']
    (ROOT/'docs/NEAR_OVERLAY_OPTIMIZATION_RESULTS_20261003.md').write_text('\n'.join(lines),encoding='utf-8')
    print(json.dumps(summary,indent=2))

if __name__=='__main__': main()
