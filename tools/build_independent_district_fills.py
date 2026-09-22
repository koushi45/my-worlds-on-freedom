import hashlib
import json
import struct
from pathlib import Path

from shapely import constrained_delaunay_triangles, get_parts
from shapely.geometry import Polygon


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "data/derived/scenarios/independent_districts_1546.json"
DEST = ROOT / "data/derived/scenarios/independent_district_fills"
MANIFEST = ROOT / "data/derived/scenarios/independent_district_fill_meshes.json"


def main() -> None:
    source_bytes = SOURCE.read_bytes()
    regions = json.loads(source_bytes)["regions"]
    DEST.mkdir(parents=True, exist_ok=True)
    expected_files: set[str] = set()
    meshes: dict[str, dict] = {}

    for district_id, region in sorted(regions.items()):
        vertices: list[tuple[float, float]] = []
        source_area = 0.0
        triangle_area = 0.0
        for raw_polygon in region["polygons"]:
            polygon = Polygon(raw_polygon[0], raw_polygon[1:])
            if not polygon.is_valid or polygon.area <= 0:
                raise ValueError(f"invalid district polygon: {district_id}")
            source_area += polygon.area
            for triangle in get_parts(constrained_delaunay_triangles(polygon)):
                coords = list(triangle.exterior.coords)[:3]
                vertices.extend((float(x), float(y)) for x, y in coords)
                triangle_area += triangle.area

        if abs(triangle_area - source_area) > max(1e-5, source_area * 1e-9):
            raise ValueError(
                f"triangulation area mismatch: {district_id} "
                f"{triangle_area} != {source_area}"
            )
        filename = hashlib.sha256(district_id.encode("utf-8")).hexdigest()[:24] + ".bin"
        expected_files.add(filename)
        (DEST / filename).write_bytes(
            b"".join(struct.pack("<ff", x, y) for x, y in vertices)
        )
        meshes[district_id] = {
            "file": f"res://data/derived/scenarios/independent_district_fills/{filename}",
            "map_area": source_area,
            "triangle_count": len(vertices) // 3,
        }

    for old in DEST.glob("*.bin"):
        if old.name not in expected_files:
            old.unlink()

    manifest = {
        "format": "float32_xy_triangles_v1",
        "source": "res://data/derived/scenarios/independent_districts_1546.json",
        "source_sha256": hashlib.sha256(source_bytes).hexdigest(),
        "district_count": len(meshes),
        "meshes": meshes,
    }
    MANIFEST.write_text(
        json.dumps(manifest, ensure_ascii=False, separators=(",", ":")) + "\n",
        encoding="utf-8",
    )
    print(
        f"Independent district fills: {len(meshes)} meshes, "
        f"{sum(m['triangle_count'] for m in meshes.values())} triangles"
    )


if __name__ == "__main__":
    main()
