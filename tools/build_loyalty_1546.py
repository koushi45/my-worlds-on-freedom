"""Build the gameplay loyalty ledger for every registered officer."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ROSTER = ROOT / "data/derived/officers/officers_1546.json"
OUTPUT = ROOT / "data/derived/officers/loyalty_1546.json"

# These are editorial gameplay exceptions based on documented later actions.
# They do not claim to establish a person's private motives or loyalty in 1546.
EXCEPTIONS = {
    "officer_q313320": (70, "明智光秀", "後に本能寺の変で主君・信長を討った。動機は未確定。", "https://www.city.fukuchiyama.lg.jp/site/mitsuhidemuseum/18089.html"),
    "officer_q1143038": (70, "松永久秀", "後に織田信長に反旗を翻した。", "https://www.city.yamatokoriyama.lg.jp/section/rekisi/src/history_data/h_027.html"),
    "officer_q1045148": (65, "宇喜多直家", "後に主家の浦上宗景を領国から追い出した。", "https://www.pref.okayama.jp/site/kenhaku/1048173.html"),
    "officer_q8047875": (25, "山中幸盛", "尼子家再興のために戦い続けた。", "https://www1.pref.shimane.lg.jp/life/bunka/bunkazai/event/challange/challange_Q2a.html"),
    "officer_q859759": (25, "高橋紹運", "大友家に従い岩屋城で籠城して戦死した。", "https://www.city.dazaifu.lg.jp/site/kanko/12002.html"),
    "officer_q665518": (30, "鳥居元忠", "家康の家臣として伏見城を守り戦死した。", "https://kyoto-bunkaisan.city.kyoto.lg.jp/report/pdf/tyousa/03/maizou_11.pdf"),
    "officer_q707587": (30, "柴田勝家", "織田家への厚い忠義を示す資料が紹介されている。", "https://www.pref.fukui.lg.jp/muse/Cul-Hist/info/kouhoushi/fm67.pdf"),
}


def main() -> None:
    officers = json.loads(ROSTER.read_text(encoding="utf-8"))["officers"]
    ids = {officer["id"] for officer in officers}
    if not set(EXCEPTIONS) <= ids:
        raise ValueError("exception references an unknown officer")
    entries = {}
    for officer in officers:
        officer_id = officer["id"]
        requirement, _, note, source = EXCEPTIONS.get(officer_id, (35, "", "", ""))
        entry = {"initial_loyalty": 40, "initial_required_loyalty": requirement}
        if source:
            entry.update({"basis": "later_record_gameplay", "note": note, "source_url": source})
        entries[officer_id] = entry
    OUTPUT.write_text(json.dumps({"schema_version": 1, "scenario_year": 1546,
        "maximum_loyalty": 100, "maximum_initial_required_loyalty": 70,
        "maximum_required_loyalty": 90, "officers": entries}, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Wrote {len(entries)} loyalty entries to {OUTPUT}")


if __name__ == "__main__":
    main()
