"""Verify the immutable Phase P0 political-reference source package."""

from __future__ import annotations

import hashlib
import json
import os
import stat
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SOURCE_DIR = ROOT / "data" / "sources" / "political_reference"
IMAGE = SOURCE_DIR / "ryoseikoku_1280.png"
MANIFEST = SOURCE_DIR / "source_manifest.json"
ATTRIBUTION = SOURCE_DIR / "ATTRIBUTION.md"
LICENSE = SOURCE_DIR / "LICENSE-CC-BY-SA-4.0.txt"


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest().upper()


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"P0 verification failed: {message}")


def main() -> None:
    for path in (IMAGE, MANIFEST, ATTRIBUTION, LICENSE):
        require(path.is_file(), f"missing {path.relative_to(ROOT)}")

    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    asset = manifest["asset"]
    license_info = manifest["license"]

    require(asset["sha256"] == sha256(IMAGE), "image SHA-256 mismatch")
    require(asset["http"]["content_length"] == IMAGE.stat().st_size, "image size mismatch")
    with Image.open(IMAGE) as image:
        require(image.format == asset["format"], "image format mismatch")
        require(list(image.size) == [asset["width_px"], asset["height_px"]], "image dimensions mismatch")
        require(image.mode == asset["color_mode"], "image color mode mismatch")
        require(list(image.getbands()) == asset["channels"], "image channel mismatch")

    require(license_info["legal_code_sha256"] == sha256(LICENSE), "license SHA-256 mismatch")
    license_text = LICENSE.read_text(encoding="utf-8")
    require("Attribution-ShareAlike 4.0 International" in license_text, "wrong license legal code")

    attribution = ATTRIBUTION.read_text(encoding="utf-8")
    for marker in ("## 日本語", "## English", "Artanisen", "まいまいようお", "CC BY-SA"):
        require(marker in attribution, f"attribution marker missing: {marker}")

    if os.name == "nt":
        attributes = IMAGE.stat().st_file_attributes
        require(bool(attributes & stat.FILE_ATTRIBUTE_READONLY), "reference image is not read-only")

    require(manifest["gate_p0"]["status"] == "passed", "P0 gate is not passed")
    require(manifest["gate_p0"]["game_inclusion_allowed"] is False, "unapproved source marked for game inclusion")
    print("Phase P0 political reference verification passed")


if __name__ == "__main__":
    main()
