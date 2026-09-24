extends RefCounted
## Runtime ownership is independent from immutable officer biographies and map geometry.
const PATH := "res://data/derived/governance/governance_1546.json"
const POPULATION_PATH := "res://data/derived/population/district_population_1546.json"
var data: Dictionary = {}
var districts: Dictionary = {}
var sites: Dictionary = {}
var houses: Dictionary = {}
var technology_tree: Node
var district_economy: Node
var last_error := ""


func load_data() -> Error:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if not parsed is Dictionary or parsed.get("schema_version") != 1:
		last_error = "統治台帳を読み込めません"
		return ERR_PARSE_ERROR
	for field in ["districts", "sites", "houses"]:
		if not parsed.get(field) is Dictionary:
			last_error = "統治台帳の形式が不正です"
			return ERR_INVALID_DATA
	data = parsed
	districts = data.districts.duplicate(true)
	sites = data.sites.duplicate(true)
	houses = data.houses
	var topology_path := "res://data/derived/scenarios/district_connectivity_1546.json"
	if FileAccess.file_exists(topology_path):
		var topology: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(topology_path))
		for id in topology.extra_districts:
			var extra: Dictionary = topology.extra_districts[id]
			var r: Dictionary = districts[extra.source_id].duplicate(true)
			r.id = id
			r.name = extra.name
			r.province = extra.get("province", r.province)
			var house_id: String = extra.get("house_id", r.house_id)
			if house_id != r.house_id:
				r.house_id = house_id
				r.ruler = houses[house_id].ruler.duplicate(true)
				r.governor = r.ruler.duplicate(true)
				r.governor.appointment = "scenario_direct"
				r.governor.note = "島郡の統治担当として当主を置くゲーム設定です。"
				r.candidate_house_ids = [house_id]
			r.site_ids = []
			r.existing_officer_ids = []
			if r.governor is Dictionary:
				r.governor.appointment = "scenario_appointment"
				r.governor.note = "分割元の郡の統治担当を、新しい島の郡でも継続するゲーム設定です。"
			r.note = "採用対象の島郡。範囲はベース地図の島の海岸線と完全に一致します。"
			districts[id] = r
		if topology.has("active_district_ids"):
			for id in districts.keys():
				if id not in topology.active_district_ids: districts.erase(id)
		if topology.has("site_district_candidates"):
			for r in districts.values(): r.site_ids = []
			for id in topology.site_district_candidates:
				var candidates: Array = topology.site_district_candidates[id]
				sites[id].district_candidates = candidates
				sites[id].district_key = candidates[0] if candidates.size() == 1 else null
				sites[id].district_link_status = "candidate" if candidates.size()==1 else ("ambiguous" if candidates.size()>1 else "unresolved")
				for key in candidates: districts[key].site_ids.append(id)
	var population_error := apply_initial_population()
	if population_error != OK:
		return population_error
	recount_assignments()
	return OK


func apply_initial_population() -> Error:
	if not FileAccess.file_exists(POPULATION_PATH):
		last_error = "1546年郡人口台帳がありません"
		return ERR_FILE_NOT_FOUND
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(POPULATION_PATH))
	if not parsed is Dictionary or parsed.get("schema_version") != 1 or parsed.get("scenario_year") != 1546 or not parsed.get("districts") is Dictionary:
		last_error = "1546年郡人口台帳の形式が不正です"
		return ERR_PARSE_ERROR
	var population_districts: Dictionary = parsed.districts
	if population_districts.size() != districts.size():
		last_error = "1546年郡人口台帳の件数が統治台帳と一致しません"
		return ERR_INVALID_DATA
	for id in districts:
		if not population_districts.has(id):
			last_error = "1546年郡人口台帳に郡がありません: " + id
			return ERR_INVALID_DATA
		var population: Variant = population_districts[id].get("population_estimate")
		if not (population is int or population is float) or not is_finite(float(population)) or population < 0 or float(population) != floor(float(population)):
			last_error = "1546年郡人口台帳の人口値が不正です: " + id
			return ERR_INVALID_DATA
		districts[id].initial_population = int(population)
		districts[id].population = int(population)
		districts[id].security = 50
		districts[id].population_model_version = parsed.get("model_version", "unknown")
	apply_initial_development()
	return OK


func apply_initial_development() -> void:
	# The reference map expresses province-scale productive concentration.  The
	# population ledger was allocated from the same kokudaka signal, so district
	# population rank is its reproducible district-level proxy.  Keep 80% at 1.
	var ranked: Array = districts.keys()
	ranked.sort_custom(func(a, b):
		var difference: int = int(districts[a].population) - int(districts[b].population)
		return difference > 0 or (difference == 0 and str(a) < str(b)))
	var count := ranked.size()
	for index in count:
		var percentile := float(index) / float(count)
		var initial := 5 if percentile < 0.01 else (4 if percentile < 0.03 else (3 if percentile < 0.08 else (2 if percentile < 0.20 else 1)))
		var record: Dictionary = districts[ranked[index]]
		record.agriculture_development = initial
		record.commerce_development = initial
		record.agriculture_progress = float(initial - 1) * 5400.0 / 29.0
		record.commerce_progress = float(initial - 1) * 5400.0 / 29.0
		var governor: Variant = record.get("governor")
		var officer_id: Variant = governor.get("officer_id") if governor is Dictionary else null
		record.agriculture_developer_id = officer_id
		record.commerce_developer_id = officer_id

func recount_assignments() -> void:
	var counts := {}
	for r in districts.values()+sites.values():
		if r.governor is Dictionary and r.governor.get("officer_id") != null:
			var id: String = r.governor.officer_id
			counts[id] = counts.get(id,0)+1
	for r in districts.values()+sites.values():
		if r.governor is Dictionary: r.governor.assignment_count = counts.get(r.governor.get("officer_id"),0)


func house_name(record: Dictionary) -> String:
	return houses.get(record.get("house_id"), {}).get("display_name", "帰属未詳")


func ruler_name(record: Dictionary) -> String:
	var ruler: Variant = record.get("ruler")
	return str(ruler.name) if ruler is Dictionary else "当主未詳・合議"


func governor_name(record: Dictionary) -> String:
	var governor: Variant = record.get("governor")
	if governor is Dictionary: return str(governor.name)
	if record.get("temporal_status") == "not_yet_established": return "未任命（未築城・未開港）"
	if record.get("temporal_status") == "established_during_start_year": return "未任命（年内成立・月日未詳）"
	if houses.get(record.get("house_id"), {}).get("governance_type") == "collective": return "合議・自治運営"
	return "担当者未詳"


func search(kind: String, query: String) -> Array:
	var records: Dictionary = districts if kind == "district" else sites
	var found: Array = []
	query = query.strip_edges().to_lower()
	for r in records.values():
		var terms: String = str(r.id) + str(r.name) + str(r.province) + str(r.get("map_name", "")) + house_name(r) + ruler_name(r) + governor_name(r)
		if query.is_empty() or query in terms.to_lower(): found.append(r.id)
	found.sort_custom(func(a, b): return (str(records[a].province) + str(records[a].name)) < (str(records[b].province) + str(records[b].name)))
	return found


func describe(record: Dictionary) -> String:
	var is_site: bool = record.kind == "site"
	var title := "城主・統治担当" if is_site and "castle" in record.get("roles", []) else "統治担当"
	var result := "%s / %s\n\n支配家：%s\n大名・領主：%s\n%s：%s\n" % [record.province, record.name, house_name(record), ruler_name(record), title, governor_name(record)]
	if record.get("adoption_status") == "deferred": result += "拠点の採用状態：保留（地図掲載候補）\n"
	var governor: Variant = record.get("governor")
	if governor is Dictionary:
		var labels := {"existing_office":"既存の官職設定", "historical_office":"史料で確認", "scenario_direct":"ゲーム設定・直轄", "scenario_appointment":"ゲーム設定・任命", "reference_direct":"当主参考情報・直轄"}
		result += "任命根拠：%s\n" % labels.get(governor.appointment, "暫定")
		if int(governor.get("assignment_count", 0)) > 1:
			result += "ゲーム内兼任：郡・拠点あわせて%d件\n" % int(governor.assignment_count)
		if governor.get("officer_id") == null: result += "武将名簿未登録の参考人物\n"
		result += "\n" + str(governor.get("note", "")) + "\n"
	result += "\n【1546年開始時の設定】\n" + str(record.note) + "\n"
	if record.get("candidate_house_ids", []).size() > 1:
		var names: PackedStringArray = []
		for id in record.candidate_house_ids: names.append(houses[id].display_name)
		result += "\n競合・地域候補：" + " / ".join(names) + "\n"
	if is_site:
		var linked: PackedStringArray = []
		for key in record.get("district_candidates", []):
			if districts.has(key): linked.append(districts[key].province + "・" + districts[key].name)
		result += "\n所在郡候補：" + (" / ".join(linked) if not linked.is_empty() else "未確認（地図の対象郡外を含む）") + "\n"
		result += "座標上の包含・近傍候補であり、史料上の所属郡の確定ではありません。\n"
	else:
		var economy := preload("res://scripts/game/district_economy.gd")
		var agriculture_income: int = district_economy.income_for(record, "agriculture") if district_economy != null else roundi((economy.BASE_VALUE + int(record.agriculture_development)) * int(record.population) * economy.AGRICULTURE_POPULATION_FACTOR)
		var commerce_income: int = district_economy.income_for(record, "commerce") if district_economy != null else roundi((economy.BASE_VALUE + int(record.commerce_development)) * int(record.population) * economy.COMMERCE_POPULATION_FACTOR)
		var security_value: int = technology_tree.security_for(record) if technology_tree != null else int(record.get("security", 50))
		result += "\n【人口・開発】\n人口：%d人\n治安：%d / 100\n農業開発度：%d / %d（9月1日見込兵糧：%d）\n商工業開発度：%d / %d（毎月1日見込金銭：%d）\n" % [int(record.population), security_value, int(record.agriculture_development), economy.MAX_DEVELOPMENT, agriculture_income, int(record.commerce_development), economy.MAX_DEVELOPMENT, commerce_income]
		result += "\n【郡内の拠点候補】\n"
		for id in record.get("site_ids", []):
			if sites.has(id): result += "%s：%s / %s\n" % [sites[id].name, house_name(sites[id]), governor_name(sites[id])]
		if record.get("site_ids", []).is_empty(): result += "登録候補なし\n"
		result += "\n" + str(record.get("geometry_note", "")) + "\n"
	result += "\n【判断資料】\n"
	for url in record.get("source_urls", []): result += str(url) + "\n"
	if record.get("source_urls", []).is_empty(): result += "担当者・帰属の史料確認が残っています。\n"
	result += "\n領有は暫定のゲーム設定です。時間経過だけでは当主・担当者は自動交代しません。"
	return result
