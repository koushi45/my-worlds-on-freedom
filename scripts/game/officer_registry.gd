extends RefCounted
## Historical roster is independent of the map reference year and future service rules.

const SCENARIO_PATH := "res://data/derived/scenarios/default_scenario.json"
var scenario: Dictionary = {}
var data: Dictionary = {}
var lookup: Dictionary = {}
var last_error := ""

func load_data() -> Error:
	if not FileAccess.file_exists(SCENARIO_PATH):
		last_error = "開始設定が見つかりません"
		return ERR_FILE_NOT_FOUND
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SCENARIO_PATH))
	if not parsed is Dictionary or not parsed.has("officer_registry"):
		last_error = "開始設定の形式が不正です"
		return ERR_PARSE_ERROR
	scenario = parsed
	var path: String = scenario["officer_registry"]
	parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary or not parsed.get("officers") is Array:
		last_error = "武将台帳を読み込めません"
		return ERR_PARSE_ERROR
	data = parsed
	lookup.clear()
	for officer in data["officers"]:
		if not officer is Dictionary or not officer.has("id") or lookup.has(officer["id"]):
			last_error = "武将IDが不正または重複しています"
			lookup.clear()
			return ERR_INVALID_DATA
		lookup[officer["id"]] = officer
	return OK

func is_present_at_start(id: String) -> bool:
	return lookup.has(id) and lookup[id]["temporal_status"] == "alive"

func ability(id: String, key: String) -> Variant:
	# Unknown is null, not zero. Callers must handle missing assessments explicitly.
	if not lookup.has(id): return null
	return lookup[id]["assessment"]["scores"].get(key)

func search_ids(query: String, status: String = "all", assessed_only := false, cohort: String = "all") -> Array[String]:
	var result: Array[String] = []
	query = query.strip_edges().to_lower()
	for officer in data.get("officers", []):
		if cohort == "notable":
			if not officer.get("notable_registration", false): continue
		elif cohort != "all" and officer["assessment"].get("cohort", "") != cohort: continue
		if status == "child":
			if officer["life_stage"] != "child": continue
		elif status != "all" and officer["temporal_status"] != status:
			continue
		if assessed_only:
			var has_score := false
			for value in officer["assessment"]["scores"].values():
				if value != null: has_score = true
			if not has_score: continue
		var terms: String = str(officer["display_name"]) + " " + str(officer["aliases"]) + " " + str(officer["id"])
		var affiliation: Dictionary = officer.get("affiliation_1546", {})
		terms += " " + str(affiliation.get("house_display", "")) + " " + str(affiliation.get("role", "")) + " " + str(affiliation.get("district_display", ""))
		terms += " " + str(officer.get("lineage", {}).get("display_name", ""))
		if not query.is_empty() and not query in terms.to_lower(): continue
		result.append(officer["id"])
	return result
