"""Generate a reproducible local report from the FPS ablation JSON files."""
import json
import statistics
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "builds/performance_800"
NAMES = {
    "baseline": ("通常画質", "基準"),
    "material_400": ("素材1536→768px", "地表素材の細部が粗くなる"),
    "material_100": ("素材1536→192px", "地表素材の細部が粗くなる"),
    "atlas_half": ("地図描画先を縦横1/2", "地図上の線・塗りがぼける。画素数1/4"),
    "atlas_quarter": ("地図描画先を縦横1/4", "地図上の線・塗りがぼける。画素数1/16"),
    "no_shadows": ("影を無効", "山の影が消える"),
    "simple_surface": ("地表シェーダー簡略化", "素材合成・法線素材・独自の霞を省く"),
    "no_markers": ("地図マーカー全体を非表示", "家紋・名称・部隊マーカーが消える"),
    "no_occlusion": ("マーカーの遮蔽判定を省略", "山の裏のマーカーも見える"),
    "no_marker_text": ("マーカー文字を非表示", "名称を省く。家紋と遮蔽判定は維持"),
    "no_crests": ("マーカー家紋を非表示", "名称と遮蔽判定は維持"),
    "no_hex": ("六角形グループを非表示", "六角形の線・子の道路・奉行所タイルが消える"),
    "no_hex_lines": ("六角形の線だけ非表示", "道路・奉行所タイルは維持"),
    "no_roads": ("共有道路を非表示", "道路が消える"),
    "no_borders": ("郡境・勢力境界を非表示", "境界ノードを隠す"),
    "no_source": ("地図の2D描画全体を非表示", "地図描画先が黒くなる。診断用"),
    "freeze_near": ("近景の再生成を停止", "移動先の近景を更新しない。診断用"),
    "no_near": ("近景を非表示・再生成停止", "遠景地形を使う。遮蔽判定のセルも粗くなる"),
    "cache_far": ("遠景メッシュを保持", "最大64区画。粗さの再選択を抑止する診断用"),
    "combined": ("遠景保持＋六角形グループ非表示＋近景固定", "上記3試行の組み合わせ"),
    "fast_diagnostic": ("マーカー・六角形グループ非表示＋地図解像度1/2", "地形密度・素材解像度・影は通常のまま"),
    "single_marker_redraw": ("マーカーの更新要求を同一フレーム内でまとめる", "カメラ操作の比較用。通常起動には未適用"),
    "markers_fast": ("マーカー文字と遮蔽判定を省略", "家紋は残す。山の裏も表示"),
}


def throughput(rows):
    return sum(r["frames"] for r in rows) / sum(r["frames"] / r["fps"] for r in rows)


def main():
    runs = {}
    for path in sorted(OUT.glob("fps_*_r[1234].json")):
        key, round_name = path.stem.removeprefix("fps_").rsplit("_", 1)
        if key not in NAMES:
            continue
        data = json.loads(path.read_text(encoding="utf-8"))
        process = json.loads(path.with_name(path.stem + "_process.json").read_text(encoding="utf-8"))
        assert process["exit_code"] == 0 and not process["errors"] and not process["timed_out"]
        assert len(data["results"]) == 9
        runs.setdefault(key, {})[round_name] = data
    rows = []
    for key, group in runs.items():
        metrics = {mode: statistics.median(throughput([r for r in d["results"] if r["mode"] == mode])
                                          for d in group.values()) for mode in ("pan", "orbit")}
        ratios = []
        for round_name, data in group.items():
            base = runs["baseline"][round_name]
            ratios.append(throughput([r for r in data["results"] if r["mode"] != "idle"])
                          / throughput([r for r in base["results"] if r["mode"] != "idle"]))
        rows.append({"variant": key, "runs": len(group), **metrics,
                     "paired_gain_percent": (statistics.median(ratios) - 1) * 100})
    rows.sort(key=lambda r: r["paired_gain_percent"], reverse=True)
    summary = {"conditions": {"date_jst": "2026-10-03", "viewport": [1920, 1080],
                              "zoom": 8, "angle_degrees": 15, "max_fps": 0,
                              "vsync": False, "frames_per_phase": 120},
               "run_count": sum(len(g) for g in runs.values()), "variants": rows}
    (OUT / "fps_investigation_summary.json").write_text(json.dumps(summary, ensure_ascii=False, indent=2), encoding="utf-8")
    lines = ["# FPSへの影響の比較調査", "", "実施日：2026年10月3日。現在の未コミットの作業ツリーを対象とした。", "",
             f"基準を含む{len(rows)}条件、合計{summary['run_count']}回のリリース版計測。各回3地点×3操作を測った。", "",
             "## 結論", "",
             "**800%・視点角15度で移動・回転するときの最大の負荷は、地図マーカーの処理。特に山による遮蔽判定が大きい。六角形の線も次の主要な負荷である。**",
             "素材画像の縮小、地表シェーダーの簡略化、影の停止、近景の生成停止、遠景の保持を試したが、マーカー非表示ほどの改善は確認できなかった。",
             "", "## 計測条件と集計", "",
             "- Windowsリリース版、Godot 4.7.2 Compatibility、Core i7-12700F、RTX 4060。",
             "- 1920×1080、800%、視点角15度、VSync無効、FPS上限なし。通常ゲームの上限設定は変更していない。",
             "- 日付を止め、画像・近景の読み込みと30フレームの安定待ち後に計測。各区間の冒頭2フレームを除く120フレーム。",
             "- A=(4480,5504)、B=(4768,5440)、C=(5500,4100)。ログ識別名はkinki/fuji/kanto。",
             "- 各地点で静止、半径160の円移動、360度の回転。同じフレーム数で同じ経路を使う。実時間あたりの移動速度を揃えた試験ではない。",
             "- GPU測定は同時実行せず順番に行った。r1/r2/r3/r4は各回の同じ実行版内で基準と比較。タイマーなどの追加で書き出し直した回をまたいだ直接比較は避けた。",
             "- 下表の移動・回転FPSは3地点の総フレーム数÷総所要時間。複数回ある条件はその中央値。改善率は同じ回の基準に対する移動＋回転6区間の総FPS比の中央値。単純なFPSの算術平均ではない。",
             "- 単回の小さな差は測定のばらつきと区別できない。全倍率・全地域・大量部隊・日付進行時の最悪条件を保証する結果ではない。",
             "", "## 全試行", "",
             "| 試行 | 回数 | 移動FPS | 回転FPS | 基準比 | 画質・表示への影響 |", "|---|---:|---:|---:|---:|---|"]
    for row in rows:
        name, effect = NAMES[row["variant"]]
        lines.append(f"| {name} | {row['runs']} | {row['pan']:.1f} | {row['orbit']:.1f} | {row['paired_gain_percent']:+.1f}% | {effect} |")
    lines += ["", "## マーカー処理の内訳", "",
              "既存の`markers_p95_ms`は最後に実行した描画1回の時間であり、1フレームの合計ではなかった。今回、累積時間と描画回数を追加した。通常画質では移動・回転120フレームに238回、約2回/フレームの描画を確認した。静止では計測中の再描画0回。",
              "`marker_frame_p95_ms`はフレーム間の累積描画時間差、`occlusion_p95_ms`は`marker_visible()`内で遮蔽を判定したCPU時間差。後者は前者の一部であり、足し合わせない。遠景・近景の更新タイマーはメインスレッドの呼び出し時間で、バックグラウンドの地形生成時間全体ではない。",
              "", "通常画質r2のp95：", "",
              "| 地点・操作 | フレーム | マーカー合計 | 遮蔽判定 | 六角形の線 | 遠景更新 | 近景更新呼び出し |", "|---|---:|---:|---:|---:|---:|---:|"]
    for r in runs["baseline"]["r2"]["results"]:
        if r["mode"] == "idle": continue
        label = {"kinki": "A", "fuji": "B", "kanto": "C"}[r["label"]]
        mode = {"pan": "移動", "orbit": "回転"}[r["mode"]]
        lines.append(f"| {label} {mode} | {r['p95_ms']:.2f}ms | {r['marker_frame_p95_ms']:.2f}ms | {r['occlusion_p95_ms']:.2f}ms | {r['hex_p95_ms']:.2f}ms | {r['far_visibility_p95_ms']:.2f}ms | {r['near_update_p95_ms']:.2f}ms |")
    lines += ["", "各項目のp95は別々に集計した値であり、同一フレームの内訳として合算しない。文字非表示の試行は文字の幅計算・重なり回避・文字描画をまとめて省略する。これら各処理の寄与を個別に断定していない。",
              "", "更新要求をまとめたr4の試行では、移動・回転中のマーカー描画は238回から119回へ減った。同じ回の基準に対する移動＋回転の総FPSは約14.3%改善したが、単回比較である。3地点の固定画面のRGB画素はすべて一致した。遮蔽判定の回数は減らず、これだけでは60fpsを満たさない。",
              "", "## 次の改善の優先順位", "",
              "1. マーカーの遮蔽判定：画面候補を絞る、更新頻度を下げる、深度情報など別の判定方法を比較する。遮蔽を単に省略すると山の裏の家紋・名称が見えるため、本採用には見え方の検証が必要。",
              "2. 六角形の線：静的な線を再利用し、表示範囲の移動ごとに全頂点を再計算する処理とアンチエイリアス描画の負荷を減らす。",
              "3. マーカーの文字配置と重複描画：名称の候補数・重なり判定の量を減らし、同一フレームの更新要求をまとめる。試行の数値は全試行表を参照。",
              "4. 素材解像度・影・シェーダー：静止時の余力を増やせるが、今回の操作中の低FPSを解決する第一優先にはしない。",
              "", "## 変更・再現方法", "",
              "通常起動の画質・表示を変えず、ベンチマーク専用の引数と計測を追加した。資産画像、セーブ形式、UIアイコンを変更していない。非表示・遮蔽省略・近景固定・粗さの固定は調査用で、本番設定として採用していない。",
              "", "```powershell", "python tools/export_windows_release.py",
              "python tools/qa/run_fps_investigation.py --round r3 --variants baseline single_marker_redraw markers_fast no_markers no_occlusion",
              "python tools/qa/summarize_fps_investigation.py", "```", "",
              "各試行の引数は`tools/qa/run_fps_investigation.py`に記載。生データ、プロセスCPU/メモリ測定、ログ、1920×1080の固定画面は`builds/performance_800/fps_*`。集計は`fps_investigation_summary.json`。",
              "", "プロセスのメモリは実行間の差が大きいため、画像を縮小したことによる総RAM・VRAM削減率は断定しない。Godotのテクスチャ推定値もドライバーの専用VRAM実測値ではない。",
              "", "## 検証", "",
              "- 集計対象の全リリースベンチマークで終了コード0、SCRIPT ERROR/ERROR/FAILなし。",
              "- `test_map_optimization.gd`：480本の視線判定、静止中の更新抑止、イベントによる更新、読み込み予算の確認にPASS。",
              "- `test_terrain_chunks.gd`：地形頂点、8区画の再利用、読み込み・解放にPASS。",
              "- Windowsリリースの書き出し、通常起動の検証記録は`builds/performance_800/fps_final_validation.json`。",
              "- 最初のPCK内の視線判定試験は機能判定PASSだったが、終了時にObjectDB/リソース解放の警告が出た。同じ確認を再実行した最終回では両試験とも終了コード0、エラーなし。初回記録は`fps_final_validation_initial.json`。警告の原因を修正した結果ではなく、再現しなかった結果である。",
              "- 同一フレームの更新要求をまとめる試行の固定画面比較は`builds/performance_800/fps_single_marker_visual.json`。固定画面の比較だけで、全ゲームイベントの正しさを保証するものではない。", ""]
    (ROOT / "docs/FPS_IMPACT_INVESTIGATION_20261003.md").write_text("\n".join(lines), encoding="utf-8")
    print(json.dumps(summary, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
