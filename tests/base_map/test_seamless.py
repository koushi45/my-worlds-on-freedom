"""Bounded regression for streaming failures and parallel map computation."""
import shutil
import subprocess
import unittest
from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]
GODOT = shutil.which('godot_console') or shutil.which('godot') or shutil.which('godot4')
@unittest.skipUnless(GODOT, 'Godot is required')
class SeamlessMapTests(unittest.TestCase):
    def test_streaming_faults_and_workers(self):
        (ROOT/'builds/seamless').mkdir(parents=True,exist_ok=True)
        result = subprocess.run([GODOT,'--headless','--path',str(ROOT),'--script','res://tests/base_map/godot/test_seamless_map.gd','--','--district-unconfirmed'],capture_output=True,text=True,encoding='utf-8',timeout=60)
        output = result.stdout+result.stderr
        self.assertEqual(result.returncode,0,output)
        self.assertIn('SEAMLESS QA:',output)
        self.assertNotIn('SCRIPT ERROR',output)
