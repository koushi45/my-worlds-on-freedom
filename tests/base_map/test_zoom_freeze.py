"""Bounded regression tests: an infinite GDScript loop must fail, not hang CI."""
import shutil
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
GODOT = shutil.which("godot_console") or shutil.which("godot") or shutil.which("godot4")


@unittest.skipUnless(GODOT, "Godot is required")
class ZoomFreezeTests(unittest.TestCase):
    def run_script(self, name, marker):
        result = subprocess.run(
            [GODOT, "--headless", "--path", str(ROOT), "--script",
             f"res://tests/base_map/godot/{name}.gd"],
            capture_output=True, text=True, encoding="utf-8", timeout=30,
        )
        output = result.stdout + result.stderr
        self.assertEqual(result.returncode, 0, output)
        self.assertIn(marker, output)
        self.assertNotIn("SCRIPT ERROR", output)

    def test_dash_remainder_terminates(self):
        self.run_script("test_dash_progress", "DASH PROGRESS: PASS")

    def test_watchdog_and_log_rotation(self):
        self.run_script("test_map_diagnostics", "MAP DIAGNOSTICS: PASS;")
