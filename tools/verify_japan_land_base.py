"""Verify the Phase-B canonical Japan GeoPackage and manifest."""

from __future__ import annotations

import hashlib
import json
import sqlite3
from pathlib import Path

import geopandas as gpd
from shapely.geometry import MultiPolygon


ROOT = Path(__file__).resolve().parents[1]
GPKG = ROOT / "data/base/japan_land.gpkg"
GEOJSON = ROOT / "data/base/japan_land.geojson"
MANIFEST = ROOT / "data/base/japan_land_manifest.json"
SOURCE = ROOT / "data/sources/candidates/natural_earth_10m/extracted/ne_10m_land.shp"
REQUIRED_COLUMNS = {
    "feature_id",
    "part_class",
    "source_id",
    "source_version",
    "edit_status",
    "edit_note",
    "geometry",
}


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest().upper()


def main():
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    canonical = gpd.read_file(GPKG, layer="japan_land")
    mirror = gpd.read_file(GEOJSON)

    assert sha256(GPKG) == manifest["canonical"]["sha256"]
    assert canonical.crs.to_epsg() == 4326
    assert set(canonical.columns) == REQUIRED_COLUMNS
    assert len(canonical) == manifest["canonical"]["feature_count"] == 154
    assert canonical.feature_id.is_unique
    assert canonical.source_id.is_unique
    assert not canonical[list(REQUIRED_COLUMNS - {"geometry"})].isnull().any().any()
    assert set(canonical.geom_type) == {"MultiPolygon"}
    assert canonical.geometry.is_valid.all()
    assert set(canonical.part_class) <= {"mainland", "island"}
    assert set(canonical.edit_status) <= {"unchanged", "repaired", "manual"}

    source = gpd.read_file(SOURCE).explode(index_parts=True)
    source.index.names = ["source_feature", "source_part"]
    source = source.reset_index()
    source["source_id"] = source.apply(
        lambda row: f"ne_10m_land:{row.source_feature}:{row.source_part}", axis=1
    )
    source = source.set_index("source_id")
    for feature in canonical.itertuples(index=False):
        original = source.loc[feature.source_id].geometry
        expected = MultiPolygon([original]) if original.geom_type == "Polygon" else original
        assert feature.geometry.equals_exact(expected, 0.0), feature.source_id

    assert sha256(GEOJSON) == manifest["geojson_mirror"]["sha256"]
    assert len(mirror) == len(canonical)
    assert set(mirror.geom_type) == {"MultiPolygon"}
    assert mirror.geometry.is_valid.all()
    with sqlite3.connect(GPKG) as connection:
        assert connection.execute("PRAGMA integrity_check").fetchone()[0] == "ok"
        layers = {row[0] for row in connection.execute("SELECT table_name FROM gpkg_contents")}
        assert layers == {"japan_land"}
    print("Phase-B verification passed")


if __name__ == "__main__":
    main()
