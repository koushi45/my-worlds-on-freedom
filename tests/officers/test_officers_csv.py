import csv
import importlib.util
import json
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MODULE_PATH = ROOT / "tools" / "officers" / "export_officers_csv.py"
SPEC = importlib.util.spec_from_file_location("export_officers_csv", MODULE_PATH)
EXPORT = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(EXPORT)


class OfficerCsvExportTests(unittest.TestCase):
    def test_export_round_trips_every_flattened_value(self):
        source = ROOT / "data" / "derived" / "officers" / "officers_1546.json"
        registry = json.loads(source.read_text(encoding="utf-8"))
        expected_columns, expected_rows = EXPORT.build_rows(registry)

        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "officers.csv"
            report = EXPORT.export_csv(source, output)
            self.assertEqual(report["rows"], 1598)
            self.assertEqual(report["columns"], len(expected_columns))
            self.assertEqual(output.read_bytes()[:3], b"\xef\xbb\xbf")
            with output.open(encoding="utf-8-sig", newline="") as stream:
                reader = csv.DictReader(stream)
                actual_rows = list(reader)

        self.assertEqual(reader.fieldnames, expected_columns)
        self.assertEqual(len(actual_rows), len(expected_rows))
        self.assertEqual(len({row["id"] for row in actual_rows}), 1598)
        for actual, expected in zip(actual_rows, expected_rows, strict=True):
            for column in expected_columns:
                value = expected.get(column, "")
                self.assertEqual(actual[column], "" if value is None else str(value))


if __name__ == "__main__":
    unittest.main()
