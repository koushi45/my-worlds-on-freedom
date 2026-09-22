"""Capture reproducible input hashes for district/coast alignment work."""
import hashlib
import json
from datetime import datetime, timezone
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / "data/work/districts/coast_alignment/baseline_20260919/input_hashes.json"
BACKUP = DEST.parent
INPUTS = (
    "data/base/japan_land.gpkg",
    "data/base/japan_land_master_manifest.json",
    "data/derived/land_masks/land_master_8192.json",
    "data/derived/coastline/coastline_master.gpkg",
    "data/derived/political/approved_western/political_registry.json",
    "data/derived/scenarios/independent_districts_1546.json",
    "data/derived/scenarios/district_connectivity_1546.json",
    "data/derived/governance/governance_1546.json",
    "tools/build_independent_districts.py",
    "tools/curate_island_districts.py",
    "tools/build_independent_district_fills.py",
    "tools/build_territory_fades.py",
    "builds/windows-latest/MyWorldsOnFreedom.exe",
    "builds/windows-latest/MyWorldsOnFreedom.pck",
)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def main() -> None:
    records = {}
    for relative in INPUTS:
        path = ROOT / relative
        backed_up = BACKUP / relative
        source = backed_up if backed_up.is_file() else path
        records[relative] = {
            "exists": source.is_file(),
            "size": source.stat().st_size if source.is_file() else None,
            "sha256": sha256(source) if source.is_file() else None,
            "captured_from_backup": source == backed_up,
        }
    DEST.parent.mkdir(parents=True, exist_ok=True)
    DEST.write_text(
        json.dumps(
            {
                "captured_at_utc": datetime.now(timezone.utc).isoformat(),
                "purpose": "district coastline alignment pre-change baseline",
                "files": records,
            },
            ensure_ascii=False,
            indent=2,
        ) + "\n",
        encoding="utf8",
    )
    print(DEST.relative_to(ROOT))


if __name__ == "__main__":
    main()
