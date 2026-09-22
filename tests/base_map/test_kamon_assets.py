import json
import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


class KamonAssetsTest(unittest.TestCase):
    def test_every_controlling_house_has_an_svg(self):
        governance = json.loads((ROOT / "data/derived/governance/governance_1546.json").read_text(encoding="utf-8"))
        topology = json.loads((ROOT / "data/derived/scenarios/district_connectivity_1546.json").read_text(encoding="utf-8"))
        index = json.loads((ROOT / "assets/kamon/index.json").read_text(encoding="utf-8"))
        used = {record["house_id"] for record in governance["districts"].values() if record.get("house_id")}
        used.update(record["house_id"] for record in topology["extra_districts"].values())
        self.assertEqual(used, set(index["houses"]))
        for house_id, entry in index["houses"].items():
            self.assertTrue(entry["asset"].endswith(".svg"), house_id)
            self.assertTrue((ROOT / entry["asset"].removeprefix("res://")).is_file(), house_id)

    def test_reviewed_crest_matches(self):
        index = json.loads((ROOT / "assets/kamon/index.json").read_text(encoding="utf-8"))
        expected = {
            "ouchi": "大内菱", "aso": "違い鷹の羽", "azai": "三つ盛り亀甲に花菱",
            "murakami_shinano": "丸に上文字", "murakami_noshima": "能島上文字（丸に上文字系）",
            "arima": "有馬唐花", "hatano": "丸に抜け十字", "honjo_echigo": "五七桐",
            "kiso": "笹竜胆", "ota": "太田桔梗", "takayama_settsu": "七曜",
            "ikeda_settsu": "揚羽蝶", "miki": "丸に剣花菱", "suwa_shrine": "諏訪梶の葉",
            "saika": "八咫烏",
            "aki_tosa": "花橘", "daihoji": "六つ目結", "kagawa": "九曜巴",
            "kii": "左三つ巴", "kitashirakawa": "三つ引両", "miura_mimasaka": "三浦三つ引",
            "nagao": "九曜巴", "ogino_kuroi": "二つ引両", "shiina": "蔦",
            "tarao_shigaraki": "大割牡丹",
        }
        researched = {
            "kedo": "重ね扇", "munakata": "楢の葉", "nikaido": "三つ立砂",
            "onodera": "一文字に六葉木瓜",
        }
        self.assertEqual(15, sum(entry["status"] == "unverified" for entry in index["houses"].values()))
        for house_id, crest_name in expected.items():
            entry = index["houses"][house_id]
            self.assertEqual("wikimedia_commons", entry["status"], house_id)
            self.assertEqual(crest_name, entry["crest_name"], house_id)
            self.assertTrue(entry["identification_source"].startswith(("http://", "https://")), house_id)
        for house_id, crest_name in researched.items():
            entry = index["houses"][house_id]
            self.assertEqual("researched_svg", entry["status"], house_id)
            self.assertEqual(crest_name, entry["crest_name"], house_id)
            self.assertTrue(entry["shape_reference"].startswith(("http://", "https://")), house_id)

    def test_map_uses_kamon_instead_of_district_names(self):
        kamon = (ROOT / "scripts/map/kamon_layer.gd").read_text(encoding="utf-8")
        district = (ROOT / "scripts/map/district_layer.gd").read_text(encoding="utf-8")
        main = (ROOT / "scripts/main/main_map.gd").read_text(encoding="utf-8")
        self.assertIn("draw_texture_rect(kamon_textures[asset]", kamon)
        self.assertNotIn("draw_texture_rect(kamon_textures[asset]", district)
        self.assertIn('kamon_layer.name = "Kamon"', main)
        self.assertNotIn('var label: String = r["name"]', district)
        self.assertNotIn('warmup.labels.append({"text":record.name', main)

    def test_coloured_borders_match_district_width(self):
        borders = (ROOT / "scripts/game/territory_borders.gd").read_text(encoding="utf-8")
        band_shader = (ROOT / "scripts/game/territory_inner_band.gdshader").read_text(encoding="utf-8")
        political = (ROOT / "scripts/map/political_boundary_layer.gd").read_text(encoding="utf-8")
        district = (ROOT / "scripts/map/district_layer.gd").read_text(encoding="utf-8")
        self.assertIn("const DISTRICT_BORDER_WIDTH := 1.4", borders)
        self.assertIn("BORDER_COLOR,DISTRICT_BORDER_WIDTH/scale_value", borders)
        self.assertIn("_create_band_nodes(false,district_band_nodes)", borders)
        self.assertIn("_create_band_nodes(true,country_band_nodes)", borders)
        self.assertIn("_build_country_geometry()", borders)
        self.assertIn("inward_ratio", band_shader)
        self.assertNotIn("hint_screen_texture", band_shader)
        self.assertNotIn("VERTEX +=", band_shader)
        self.assertNotIn("8.0/scale_value", borders)
        self.assertIn("HOUSE_THEME_PATH", borders)
        self.assertIn("theme_color(r.house_id)", borders)
        self.assertIn("_band_style_for(house_id)", borders)
        self.assertIn("draw_mesh(mesh,null,Transform2D.IDENTITY,fill_color)", borders)
        self.assertIn("SELECTION_PULSE_SECONDS := 2.4", borders)
        self.assertIn("_draw_selection_pulse(active_projected)", borders)
        self.assertNotIn('Color("#ffd378")', borders)
        self.assertNotIn('Color("#f2b633")', political)
        self.assertNotIn("Color(1.0,0.73,0.28,0.30)", district)

    def test_house_theme_colours_are_complete_and_separated(self):
        governance = json.loads((ROOT / "data/derived/governance/governance_1546.json").read_text(encoding="utf-8"))
        themes = json.loads((ROOT / "data/derived/governance/house_theme_colors_1546.json").read_text(encoding="utf-8"))
        self.assertEqual(set(governance["houses"]), set(themes["themes"]))
        self.assertEqual(0, themes["stats"]["same_colour_adjacent_pairs"])
        self.assertEqual(0, themes["stats"]["near_colour_adjacent_pairs"])
        self.assertGreaterEqual(themes["stats"]["minimum_adjacent_colour_distance"], 0.12)
        self.assertEqual([], themes["same_colour_adjacent_pairs"])
        self.assertGreaterEqual(len({entry["color"] for entry in themes["themes"].values()}), 20)
        for house_id, entry in themes["themes"].items():
            self.assertRegex(entry["color"], re.compile(r"^#[0-9a-f]{6}$"), house_id)
        self.assertEqual("#cf3632", themes["themes"]["takeda"]["color"])
        self.assertEqual("#292d38", themes["themes"]["date"]["color"])

    def test_kamon_is_normalized_to_white(self):
        kamon = (ROOT / "scripts/map/kamon_layer.gd").read_text(encoding="utf-8")
        self.assertIn('ResourceLoader.load(asset, "Texture2D")', kamon)
        self.assertIn("Color(1.0,1.0,1.0,alpha)", kamon)

    def test_kamon_are_always_visible_and_area_scaled(self):
        kamon = (ROOT / "scripts/map/kamon_layer.gd").read_text(encoding="utf-8")
        self.assertNotIn("if view_zoom < 1.0: return", kamon)
        self.assertIn("for key in visible_keys", kamon)
        self.assertIn("KAMON_REFERENCE_AREA", kamon)
        self.assertIn("const KAMON_MIN_SCREEN_SIZE := 24.0", kamon)
        self.assertIn("maxf(KAMON_MIN_SCREEN_SIZE", kamon)
        self.assertIn("kamon_background_color(house_id)", kamon)
        self.assertIn("func kamon_screen_size", kamon)
        self.assertNotIn("if collides: continue", kamon)

    def test_vectorized_kamon_have_no_opaque_square_background(self):
        import re
        for asset in (ROOT / "assets/kamon").glob("*.svg"):
            if asset.name == "unknown.svg":
                continue
            svg = asset.read_text(encoding="utf-8")
            viewbox = re.search(r'viewBox="0 0 ([0-9.]+) ([0-9.]+)"', svg)
            if not viewbox:
                continue
            width, height = map(float, viewbox.groups())
            for subpath in re.findall(r"M[^Z]+Z", svg):
                points = [tuple(map(float, pair)) for pair in re.findall(r"(-?[0-9.]+),(-?[0-9.]+)", subpath)]
                area = sum(p[0] * points[(i + 1) % len(points)][1] - points[(i + 1) % len(points)][0] * p[1]
                           for i, p in enumerate(points)) * 0.5
                self.assertLessEqual(abs(area), width * height * 0.9, asset.name)


if __name__ == "__main__":
    unittest.main()
