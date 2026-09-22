"""Audit acquired Phase-A source files without producing a canonical dataset."""

from __future__ import annotations

import hashlib
import json
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path

import shapefile
from shapely.geometry import shape
from shapely.validation import explain_validity


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "data/phase_a"
SOURCES = {
    "mlit_n03_2026": ROOT / "data/sources/candidates/mlit_n03_2026/extracted/N03-20260101.shp",
    "natural_earth_10m": ROOT / "data/sources/candidates/natural_earth_10m/extracted/ne_10m_land.shp",
    "natural_earth_10m_minor_islands": ROOT / "data/sources/candidates/natural_earth_10m/extracted/ne_10m_minor_islands.shp",
}
REGIONS = {
    "mainland": (129.0, 30.0, 146.5, 46.0),
    "hokkaido": (139.0, 41.2, 146.5, 45.8),
    "okinawa_nansei": (122.5, 23.0, 132.0, 30.0),
    "ogasawara": (140.0, 24.0, 143.5, 28.5),
    "minamitorishima": (153.7, 24.1, 154.2, 24.6),
}


def sha256(path: Path):
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest().upper()


def ring_count(shp):
    return len(shp.parts)


def audit_shapefile(path: Path):
    reader = shapefile.Reader(str(path))
    invalid = Counter()
    empty = 0
    zero_area = 0
    exact_duplicate_geometries = 0
    seen = set()
    vertices = 0
    rings = 0
    for shp in reader.iterShapes():
        vertices += len(shp.points)
        rings += ring_count(shp)
        try:
            geom = shape(shp.__geo_interface__)
        except Exception as exc:
            invalid[f"parse error: {type(exc).__name__}"] += 1
            continue
        if geom.is_empty:
            empty += 1
        if geom.area == 0:
            zero_area += 1
        if not geom.is_valid:
            invalid[explain_validity(geom).split("[")[0]] += 1
        key = hashlib.sha256(geom.wkb).digest()
        if key in seen:
            exact_duplicate_geometries += 1
        else:
            seen.add(key)

    region_hits = {}
    for name, bbox in REGIONS.items():
        region_hits[name] = sum(1 for _ in reader.iterShapes(bbox=bbox))
    return {
        "feature_count": len(reader),
        "bbox_wgs84": reader.bbox,
        "vertex_count": vertices,
        "ring_count": rings,
        "invalid_feature_count": sum(invalid.values()),
        "invalid_reasons": dict(invalid),
        "empty_feature_count": empty,
        "zero_area_feature_count": zero_area,
        "exact_duplicate_geometry_count": exact_duplicate_geometries,
        "region_bbox_feature_hits": region_hits,
        "note": "bbox hits prove source geometry is present in the test window; they do not certify legal territory or historical accuracy",
    }


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    metrics = {
        "generated_at_utc": datetime.now(timezone.utc).isoformat(),
        "scope": "source audit only; no repairs, dissolves, simplification or canonical export",
        "sources": {name: audit_shapefile(path) for name, path in SOURCES.items()},
    }
    (OUT / "audit_metrics.json").write_text(
        json.dumps(metrics, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )

    hash_targets = sorted(
        p
        for p in (ROOT / "data/sources/candidates").rglob("*")
        if p.is_file() and ("/raw/" in p.as_posix() or "/license/" in p.as_posix())
    )
    lines = [f"{sha256(path)}  {path.relative_to(ROOT).as_posix()}" for path in hash_targets]
    (OUT / "SHA256SUMS.txt").write_text("\n".join(lines) + "\n", encoding="ascii")


if __name__ == "__main__":
    main()
