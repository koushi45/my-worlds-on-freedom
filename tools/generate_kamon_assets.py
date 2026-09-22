"""Build local kamon SVG assets and an attribution index from Wikimedia Commons.

Only files exposed as SVG on a clan's Japanese Wikipedia page are adopted.
Explicitly reviewed crest identifications may supplement the automatic matches.
Branches share their root family's crest.  Unverified houses, temples, leagues,
and regional placeholders receive a deliberately neutral 'unknown crest' mark.
"""
from __future__ import annotations

import html
import hashlib
import json
import re
import time
import urllib.parse
import urllib.request
from pathlib import Path

import cv2
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
GOVERNANCE = ROOT / "data/derived/governance/governance_1546.json"
OUTPUT = ROOT / "assets/kamon"
UNKNOWN_REPORT = ROOT / "docs/governance/UNKNOWN_KAMON_HOUSES.md"
UA = "my-worlds-on-freedom-kamon/1.0 (local historical game assets)"
NON_FAMILY = {"local", "jingu", "negoro", "saika", "iga", "suwa", "kii"}
ROOT_OVERRIDES = {
    "ashikaga": "足利",
    "oda_nobuhide": "織田", "oda_iwakura": "織田", "oda_hitachi": "織田",
    "uesugi_echigo": "上杉", "uesugi_ogigayatsu": "上杉", "uesugi_yamanouchi": "上杉",
    "hatakeyama_noto": "畠山", "hatakeyama_kawachi": "畠山",
    "hosokawa_awa": "細川", "hosokawa_izumi": "細川",
    "yamana_inaba": "山名", "ashikaga_hirashima": "足利",
    "shimazu_hoshu": "島津", "shimazu_sasshu": "島津",
    "takeda_wakasa": "武田", "osaki_yoshinobu": "大崎",
    "shiba_shiwa": "斯波", "bessho_honganji": "別所",
    "kikkawa_ogasawara": "吉川", "ito_hyuga_tsuchimochi": "伊東",
}
HAKKO_REFERENCE = "https://hakko-daiodo.com/kamon-ichiran-sengoku-busho.html"
MANUAL_MATCHES = {
    "ouchi": ("大内", "大内菱", "大内家", "File:Japanese Crest Oouchi Hisi.svg"),
    "aso": ("阿蘇", "違い鷹の羽", "阿蘇家", "File:Japanese crest chigai Takanoha.svg"),
    "azai": ("浅井", "三つ盛り亀甲に花菱", "浅井家", "File:Japanese Crest mitumori Kikkou ni Hanabishi.svg"),
    "murakami_shinano": ("村上", "丸に上文字", "信濃村上家", "File:Murakami (No background and Black color drawing).svg"),
    "murakami_noshima": ("村上", "能島上文字（丸に上文字系）", "村上武吉", "File:Murakami (No background and Black color drawing).svg"),
    "arima": ("有馬", "有馬唐花", "有馬晴信", "File:Japanese Crest Karahana.svg"),
    "hatano": ("波多野", "丸に抜け十字", "波多野秀治", "File:Maru ni Tanba Hatano Nuke jūji (No background and Black color drawing).svg"),
    "honjo_echigo": ("本庄", "五七桐", "本庄繁長", "File:Goshichi no kiri.svg"),
    "kiso": ("木曾", "笹竜胆", "木曽義昌", "File:Sasa Rindo.svg"),
    "ota": ("太田", "太田桔梗", "太田道灌", "File:Oota Kikyou (No background and Black color drawing).svg"),
    "takayama_settsu": ("高山", "七曜", "高山右近", "File:Shichiyoumon (No background and Black color drawing).svg"),
    "ikeda_settsu": ("池田", "揚羽蝶", "池田恒興", "File:Ageha-cho.svg"),
    "miki": ("三木（姉小路）", "丸に剣花菱", "姉小路良頼", "File:丸に剣花菱 Maruni-ken-hanabishi.gif"),
    "suwa_shrine": ("諏訪", "諏訪梶の葉", "諏訪頼重", "File:Japanese crest Suwa Kajinoha(White background).svg"),
    # User-directed identification: the Saika power is represented by its
    # Suzuki leadership and the Yatagarasu emblem.
    "saika": ("鈴木（雑賀）", "八咫烏", "雑賀衆・鈴木家", "File:Yatagarasu.svg"),
    "aki_tosa": ("安芸（土佐）", "花橘", "安芸元泰・安芸氏", "File:Hikone Tachibana (No background and black color drawing).svg"),
    "daihoji": ("大宝寺", "六つ目結", "大宝寺晴時", "File:六つ目結紋.png"),
    "kagawa": ("香川（讃岐）", "九曜巴", "香川之景", "File:Kuyo Tomoe (inverted).svg"),
    "kii": ("城井（宇都宮）", "左三つ巴", "城井長房", "File:Hidari mitsudomoe.svg"),
    "kitashirakawa": ("長野（伊勢）", "三つ引両", "長野稙藤", "File:Japanese crest Marunouchi ni mitu Hiki.svg"),
    "miura_mimasaka": ("三浦（美作）", "三浦三つ引", "三浦貞久", "File:Marunimitsuhikiryo.svg"),
    "nagao": ("長尾（越後）", "九曜巴", "長尾晴景", "File:Kuyo Tomoe (inverted).svg"),
    "ogino_kuroi": ("荻野（黒井）", "二つ引両", "荻野秋清", "File:Futatsuhikiryo.svg"),
    "shiina": ("椎名", "蔦", "椎名康胤", "File:Japanese crest Tuta.svg"),
    "tarao_shigaraki": ("多羅尾", "大割牡丹", "多羅尾氏", "File:Japanese crest Oowari Botann.svg"),
}

# Identification source for reviewed matches.  The source identifies the
# historical house/crest; MANUAL_MATCHES deliberately takes the packaged art
# from Commons where a reusable rendering exists.
IDENTIFICATION_SOURCES = {
    "aki_tosa": "https://www.pref.kochi.lg.jp/doc/2017061200094/file_contents/file_2021913212316_1.pdf",
    "daihoji": "https://dtjytyk.blogspot.com/2019/03/blog-post_703.html?m=1",
    "kagawa": "https://folklore2017.com/20000/2980144.htm",
    "kii": "https://irohakamon.com/sengoku/",
    "kitashirakawa": "https://ja.wikisource.org/wiki/伊勢国司伝記",
    "miura_mimasaka": "https://irohakamon.com/kamon/hikiryou/miuramitsuhiki.html",
    "nagao": "https://kamon-db.net/portfolio/kuyotomoe",
    "ogino_kuroi": "https://tanba.jp/2021/02/尊氏から家紋賜る荻野氏　後に光秀と激戦繰り広げ/",
    "shiina": "https://chibasi.net/ichizoku5.htm",
    "tarao_shigaraki": "https://www.e-shigaraki.org/taraodaikanjinyaato.html",
}

# These traditional emblems do not have a suitable reusable Commons drawing.
# The listed page image is used as a shape reference and converted to a local,
# monochrome path-only SVG by vectorize_thumbnail().
RESEARCH_MATCHES = {
    "kedo": ("祁答院", "重ね扇", "祁答院重武", "https://www.digistats.net/history/familytree.php?page=1763", "https://irohakamon.com/img/symbol.php?id=kasaneougi"),
    "munakata": ("宗像", "楢の葉", "宗像大宮司", "https://munakata-taisha.or.jp/cms/wp-content/themes/munakata-taisha/pdf/517.pdf", "https://livedoor.sp.blogimg.jp/river_kingfisher/imgs/5/d/5d2de8b8.jpg"),
    "nikaido": ("二階堂", "三つ立砂", "二階堂氏", "https://www.city.sukagawa.fukushima.jp/bunka_sports/bunka_geijyutsu/1013435/bunkazai/1-1/1008769.html", "https://aizufudoki.sakura.ne.jp/zakki/kamon2/49.jpg"),
    "onodera": ("小野寺", "一文字に六葉木瓜", "小野寺稙道・小野寺氏", "http://www2.harimaya.com/sengoku/bukemon/bk_onode.html", "http://www2.harimaya.com/sengoku/buke/1_6mokk.jpg"),
}


def api(host: str, params: dict) -> dict:
    query = urllib.parse.urlencode({**params, "format": "json", "formatversion": "2"})
    req = urllib.request.Request(f"https://{host}/w/api.php?{query}", headers={"User-Agent": UA})
    for attempt in range(5):
        try:
            with urllib.request.urlopen(req, timeout=45) as response:
                return json.load(response)
        except Exception:
            if attempt == 4:
                raise
            time.sleep(2 ** attempt)
    raise RuntimeError("unreachable")


def download(url: str, target: Path) -> None:
    if target.is_file() and target.stat().st_size > 0:
        return
    for attempt in range(2):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": UA})
            with urllib.request.urlopen(req, timeout=45) as response:
                target.write_bytes(response.read())
            return
        except Exception:
            if attempt == 1:
                raise
            time.sleep(min(30, 2 ** attempt))


def vectorize_thumbnail(source: Path, target: Path) -> None:
    image = cv2.imread(str(source), cv2.IMREAD_UNCHANGED)
    if image is None:
        raise RuntimeError(f"Cannot read {source}")
    if len(image.shape) == 2:
        gray = image
        _, dark = cv2.threshold(gray, 0, 255, cv2.THRESH_BINARY_INV + cv2.THRESH_OTSU)
        _, light = cv2.threshold(gray, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)
        mask = (dark if np.count_nonzero(dark) <= np.count_nonzero(light) else light) > 0
    elif image.shape[2] == 4 and np.count_nonzero(image[:, :, 3] < 250) > image[:, :, 3].size * 0.05:
        mask = image[:, :, 3] > 32
    else:
        gray = cv2.cvtColor(image[:, :, :3], cv2.COLOR_BGR2GRAY)
        _, dark = cv2.threshold(gray, 0, 255, cv2.THRESH_BINARY_INV + cv2.THRESH_OTSU)
        _, light = cv2.threshold(gray, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)
        corners = ((0, 0), (0, -1), (-1, 0), (-1, -1))
        dark_corners = sum(bool(dark[y, x]) for y, x in corners)
        light_corners = sum(bool(light[y, x]) for y, x in corners)
        if dark_corners != light_corners:
            mask = (dark if dark_corners < light_corners else light) > 0
        else:
            mask = (dark if np.count_nonzero(dark) <= np.count_nonzero(light) else light) > 0
    binary = mask.astype(np.uint8) * 255
    contours, _ = cv2.findContours(binary, cv2.RETR_TREE, cv2.CHAIN_APPROX_SIMPLE)
    paths = []
    for contour in contours:
        contour = cv2.approxPolyDP(contour, 0.6, True)
        points = contour.reshape(-1, 2)
        if len(points) < 3 or abs(cv2.contourArea(contour)) < 3:
            continue
        paths.append("M" + " ".join(f"{x},{y}" for x, y in points) + "Z")
    height, width = binary.shape
    path_data = " ".join(paths)
    target.write_text(
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {width} {height}">\n'
        f'<path d="{path_data}" fill="#000" fill-rule="evenodd"/>\n</svg>\n',
        encoding="utf-8",
    )
    remove_full_frame(target)


def remove_full_frame(target: Path) -> None:
    """Drop opaque raster backgrounds while preserving edge-touching round crests."""
    svg = target.read_text(encoding="utf-8")
    viewbox = re.search(r'viewBox="0 0 ([0-9.]+) ([0-9.]+)"', svg)
    path = re.search(r'<path d="([^"]*)"', svg)
    if not viewbox or not path:
        return
    width, height = map(float, viewbox.groups())
    kept = []
    for subpath in re.findall(r"M[^Z]+Z", path.group(1)):
        points = [tuple(map(float, pair)) for pair in re.findall(r"(-?[0-9.]+),(-?[0-9.]+)", subpath)]
        area = 0.0
        for index, point in enumerate(points):
            following = points[(index + 1) % len(points)]
            area += point[0] * following[1] - following[0] * point[1]
        if abs(area) * 0.5 <= width * height * 0.9:
            kept.append(subpath)
    svg = svg[:path.start(1)] + " ".join(kept) + svg[path.end(1):]
    target.write_text(svg, encoding="utf-8")


def has_visible_path(target: Path) -> bool:
    path = re.search(r'<path d="([^"]*)"', target.read_text(encoding="utf-8"))
    return bool(path and path.group(1).strip())


def plain(value: str) -> str:
    return re.sub(r"<[^>]+>", "", html.unescape(value or "")).strip()


def family_name(house_id: str, display_name: str) -> str | None:
    if house_id in ROOT_OVERRIDES:
        return ROOT_OVERRIDES[house_id]
    if house_id.split("_")[0] in NON_FAMILY:
        return None
    name = re.split(r"[（(]", display_name)[0]
    name = re.sub(r"(家|勢|衆|一族|国人)$", "", name)
    return name or None


def unknown_svg() -> str:
    return """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
<circle cx="50" cy="50" r="43" fill="none" stroke="#000" stroke-width="8"/>
<path d="M50 20v38M50 76v2" fill="none" stroke="#000" stroke-width="10" stroke-linecap="round"/>
</svg>\n"""


def main() -> None:
    data = json.loads(GOVERNANCE.read_text(encoding="utf-8"))
    used = {v["house_id"] for v in data["districts"].values() if v.get("house_id")}
    families: dict[str, str | None] = {}
    for house_id in sorted(used):
        house = data["houses"][house_id]
        families[house_id] = family_name(house_id, house["display_name"])

    # Ask Wikipedia for each clan page's lead image. On Japanese clan pages
    # this is the crest selected for the infobox, which is safer than choosing
    # alphabetically from every image used by the article.
    family_images: dict[str, str] = {}
    names = sorted({name for name in families.values() if name})
    for offset in range(0, len(names), 40):
        page_for = {name + "氏": name for name in names[offset:offset + 40]}
        result = api("ja.wikipedia.org", {
            "action": "query", "titles": "|".join(page_for), "prop": "pageimages",
            "piprop": "name|original", "redirects": "1",
        })
        normalized = {x["to"]: x["from"] for x in result.get("query", {}).get("redirects", [])}
        for page in result.get("query", {}).get("pages", []):
            requested = normalized.get(page.get("title", ""), page.get("title", ""))
            family = page_for.get(requested)
            if not family:
                continue
            title = page.get("pageimage", "")
            if title.lower().endswith((".svg", ".png", ".jpg", ".jpeg")):
                family_images[family] = "File:" + title

    # Query Commons metadata and canonical download URLs in batches.
    metadata: dict[str, dict] = {}
    titles = sorted(set(family_images.values()))
    for offset in range(0, len(titles), 40):
        result = api("commons.wikimedia.org", {
            "action": "query", "titles": "|".join(titles[offset:offset + 40]),
            "prop": "imageinfo", "iiprop": "url|extmetadata", "iiurlwidth": 512,
        })
        for page in result.get("query", {}).get("pages", []):
            if page.get("imageinfo"):
                metadata[page["title"].replace(" ", "_")] = page["imageinfo"][0]

    OUTPUT.mkdir(parents=True, exist_ok=True)
    (OUTPUT / "unknown.svg").write_text(unknown_svg(), encoding="utf-8")
    assets: dict[str, dict] = {
        "unknown": {
            "asset": "res://assets/kamon/unknown.svg", "status": "unverified",
            "note": "史料上の家紋をこのデータセットで確認できない勢力用の中立表示",
        }
    }
    downloaded: dict[str, str] = {}
    for family, title in sorted(family_images.items()):
        info = metadata.get(title.replace(" ", "_"))
        if not info:
            continue
        key = re.sub(r"[^a-z0-9]+", "_", title.lower()).strip("_")
        filename = key + ".svg"
        if title not in downloaded:
            target = OUTPUT / filename
            if not target.is_file():
                thumbnail = OUTPUT / (key + ".png.tmp")
                try:
                    download(info.get("thumburl", info["url"]), thumbnail)
                    vectorize_thumbnail(thumbnail, target)
                    thumbnail.unlink()
                except Exception as error:
                    print(f"skip {title}: {error}")
                    if thumbnail.exists(): thumbnail.unlink()
                    continue
            if not has_visible_path(target):
                continue
            downloaded[title] = filename
        ext = info.get("extmetadata", {})
        assets[family] = {
            "asset": "res://assets/kamon/" + downloaded[title],
            "status": "wikimedia_commons",
            "file_page": info.get("descriptionurl", ""),
            "author": plain(ext.get("Artist", {}).get("value", "")),
            "license": plain(ext.get("LicenseShortName", {}).get("value", "")),
            "license_url": ext.get("LicenseUrl", {}).get("value", ""),
        }

    # The requested reference page identifies several crests that are absent
    # from, or ambiguous on, a clan article's lead image. Use that page only
    # for identification, and package a separately licensed Commons rendering.
    manual_titles = sorted({match[3] for match in MANUAL_MATCHES.values()})
    manual_metadata: dict[str, dict] = {}
    for offset in range(0, len(manual_titles), 40):
        result = api("commons.wikimedia.org", {
            "action": "query", "titles": "|".join(manual_titles[offset:offset + 40]),
            "prop": "imageinfo", "iiprop": "url|extmetadata", "iiurlwidth": 512,
        })
        for page in result.get("query", {}).get("pages", []):
            if page.get("imageinfo"):
                manual_metadata[page["title"].replace(" ", "_")] = page["imageinfo"][0]

    manual_assets: dict[str, dict] = {}
    for title in manual_titles:
        info = manual_metadata.get(title.replace(" ", "_"))
        if not info:
            raise RuntimeError(f"Commons asset is missing: {title}")
        filename = "verified_" + hashlib.sha256(title.encode("utf-8")).hexdigest()[:16] + ".svg"
        target = OUTPUT / filename
        thumbnail = OUTPUT / (filename + ".tmp.png")
        download(info.get("thumburl", info["url"]), thumbnail)
        vectorize_thumbnail(thumbnail, target)
        thumbnail.unlink()
        if not has_visible_path(target):
            raise RuntimeError(f"Commons asset produced an empty crest: {title}")
        ext = info.get("extmetadata", {})
        manual_assets[title] = {
            "asset": "res://assets/kamon/" + filename,
            "status": "wikimedia_commons",
            "file_page": info.get("descriptionurl", ""),
            "author": plain(ext.get("Artist", {}).get("value", "")),
            "license": plain(ext.get("LicenseShortName", {}).get("value", "")),
            "license_url": ext.get("LicenseUrl", {}).get("value", ""),
        }
        assets["verified:" + title] = manual_assets[title]

    houses = {}
    for house_id, family in families.items():
        crest = assets.get(family or "", assets["unknown"])
        houses[house_id] = {"family": family or "", "asset": crest["asset"], "status": crest["status"]}
    for house_id, (family, crest_name, reference_name, title) in MANUAL_MATCHES.items():
        crest = manual_assets[title]
        houses[house_id] = {
            "family": family,
            "crest_name": crest_name,
            "asset": crest["asset"],
            "status": crest["status"],
            "identification_source": IDENTIFICATION_SOURCES.get(house_id, HAKKO_REFERENCE),
            "identification_match": reference_name,
        }

    for house_id, (family, crest_name, reference_name, source_page, image_url) in RESEARCH_MATCHES.items():
        filename = "researched_" + hashlib.sha256(image_url.encode("utf-8")).hexdigest()[:16] + ".svg"
        target = OUTPUT / filename
        thumbnail = OUTPUT / (filename + ".tmp")
        if thumbnail.exists():
            thumbnail.unlink()
        download(image_url, thumbnail)
        vectorize_thumbnail(thumbnail, target)
        thumbnail.unlink()
        if not has_visible_path(target):
            raise RuntimeError(f"Researched asset produced an empty crest: {image_url}")
        asset_key = "researched:" + house_id
        assets[asset_key] = {
            "asset": "res://assets/kamon/" + filename,
            "status": "researched_svg",
            "identification_source": source_page,
            "shape_reference": image_url,
            "note": "閲覧した家紋図を単色の輪郭パスへ再構成",
        }
        houses[house_id] = {
            "family": family,
            "crest_name": crest_name,
            "asset": assets[asset_key]["asset"],
            "status": assets[asset_key]["status"],
            "identification_source": source_page,
            "identification_match": reference_name,
            "shape_reference": image_url,
        }
    index = {
        "schema_version": 1,
        "policy": "Japanese Wikipedia clan pages, reviewed crest references, and locally vectorized traditional emblems; Commons-backed art retains its license metadata; unverified powers use a neutral mark",
        "houses": houses,
        "assets": assets,
    }
    (OUTPUT / "index.json").write_text(json.dumps(index, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    unknown_ids = sorted(house_id for house_id, entry in houses.items() if entry["status"] == "unverified")
    report = [
        "# 家紋未確認の領有勢力",
        "",
        f"`assets/kamon/index.json` で `status: unverified` とされ、`unknown.svg` の代替紋を使用している全{len(unknown_ids)}勢力。大名家だけでなく、国人衆・寺社勢力・帰属未詳の在地領主を含む。",
        "",
        "| # | 表示名 | 当主・代表者 | house_id |",
        "|---:|---|---|---|",
    ]
    for number, house_id in enumerate(unknown_ids, 1):
        house = data["houses"][house_id]
        report.append(
            f"| {number} | {house['display_name']} | {house.get('head_reference') or '—'} | `{house_id}` |"
        )
    report.extend([
        "",
        "抽出元：`assets/kamon/index.json`、表示名・当主情報：`data/derived/governance/governance_1546.json`。",
        "",
    ])
    UNKNOWN_REPORT.write_text("\n".join(report), encoding="utf-8")
    print(
        f"houses={len(houses)} sourced_families={len(assets)-1} "
        f"downloaded_svg={len(downloaded)} verified_overrides={len(MANUAL_MATCHES)} researched={len(RESEARCH_MATCHES)}"
    )


if __name__ == "__main__":
    main()
