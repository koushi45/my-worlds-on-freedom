extends Node
## One-time research nodes, ordered by prerequisite in each branch.

signal research_completed(house_id: String, branch: String, technology_id: String)

const BASE_COST := 1000
const BRANCHES := {
	"governance": ["分国法", "官僚機構制定", "人口台帳", "城下町制度", "楽市", "兵農分離", "武家諸法度"],
	"agriculture": ["二毛作", "鉄製農具配布", "近世式用水路", "共同管理法制定", "大名介入", "灌漑整備", "検地", "石高制制定", "新田開発"],
	"commerce": ["市場整備", "商人保護", "度量衡整備", "職人誘致", "問屋整備", "貨幣流通促進", "商工業振興", "商業奉行設置"]
}
const DESCRIPTIONS := {
	"分国法":"支配郡の基礎治安 +5", "官僚機構制定":"全配下武将の忠誠 +5", "人口台帳":"支配郡の人口 +10%（研究時）",
	"城下町制度":"以後の技術力消費 -5%", "楽市":"金銭収入 +5%", "兵農分離":"兵糧収入 +25%・常備兵 -15%・治安 +15",
	"武家諸法度":"全配下武将の忠誠 +20", "二毛作":"兵糧収入 +5%", "鉄製農具配布":"金銭収入 -10%・兵糧収入 +20%",
	"近世式用水路":"兵糧収入 +5%・渇水被害 -25%", "共同管理法制定":"農業施設建築費 -15",
	"大名介入":"金銭収入 -15%・人口増加率 +15%・治安 +10", "灌漑整備":"洪水・台風被害 -50%",
	"検地":"兵糧収入 +25%", "石高制制定":"常備兵 +20%", "新田開発":"金銭収入 -10%・兵糧収入 +50%",
	"市場整備":"市場の建築費 -15%（以後の着工）", "商人保護":"金銭収入 +5%",
	"度量衡整備":"担当武将による商業開発の月次進行 +15%",
	"職人誘致":"工房の建築費 -15%・建築期間 -2か月（以後の着工）",
	"問屋整備":"市場の金銭収入補正を +10% → +20% に強化",
	"貨幣流通促進":"金銭収入 +5%", "商工業振興":"担当武将による商業開発の月次進行 +15%（累計 +30%）",
	"商業奉行設置":"金銭収入 +10%"
}

var registry: RefCounted
var modifier_cache: Dictionary = {}
var retainers: Node
var technology_orders: Node
var district_buildings: Node
var researched: Dictionary = {}

func setup(governance_registry: RefCounted, retainer_management: Node) -> void:
	registry = governance_registry
	retainers = retainer_management
	researched.clear()
	for house_id in registry.houses:
		researched[house_id] = {"governance": [], "agriculture": [], "commerce": []}

func completed(house_id: String, technology_id: String) -> bool:
	if not researched.has(house_id): return false
	for branch in BRANCHES:
		if technology_id in researched[house_id][branch]: return true
	return false

func cost_for(house_id: String, technology_id: String) -> int:
	if not researched.has(house_id): return BASE_COST
	return 950 if technology_id != "城下町制度" and completed(house_id, "城下町制度") else BASE_COST

func next_technology(house_id: String, branch: String) -> String:
	if not researched.has(house_id) or not BRANCHES.has(branch): return ""
	var current: Array = researched[house_id][branch]
	return BRANCHES[branch][current.size()] if current.size() < BRANCHES[branch].size() else ""

func research(house_id: String, branch: String, technology_id: String) -> Error:
	if not BRANCHES.has(branch) or not researched.has(house_id) or next_technology(house_id, branch) != technology_id:
		return ERR_INVALID_PARAMETER
	var cost := cost_for(house_id, technology_id)
	if float(retainers.technology[house_id].governance) < cost: return ERR_UNAVAILABLE
	retainers.technology[house_id].governance -= cost
	researched[house_id][branch].append(technology_id)
	if technology_id == "分国法":
		for district in registry.districts.values():
			if district.house_id == house_id: district.security = mini(100, int(district.security) + 5)
	if technology_id == "人口台帳":
		for district in registry.districts.values():
			if district.house_id == house_id: district.population = mini(2000000000, roundi(int(district.population) * 1.1))
	research_completed.emit(house_id, branch, technology_id)
	return OK

func modifiers(house_id: String) -> Dictionary:
	# Compare the actual researched state, including in-place edits and loaded saves.
	var inputs: Dictionary = researched.get(house_id, {})
	if modifier_cache.has(house_id) and modifier_cache[house_id].inputs == inputs:
		return modifier_cache[house_id].value
	var result := {"money":1.0, "provisions":1.0, "security":0, "loyalty":0,
		"drought_damage":1.0, "flood_damage":1.0, "typhoon_damage":1.0,
		"agriculture_building_cost_reduction":0, "population_growth":1.0, "standing_troops":1.0,
		"commerce_development":1.0, "market_income_bonus":0.0,
		"market_cost_multiplier":1.0, "workshop_cost_multiplier":1.0, "workshop_months_reduction":0}
	if completed(house_id, "官僚機構制定"): result.loyalty += 5
	if completed(house_id, "楽市"): result.money += 0.05
	if completed(house_id, "兵農分離"):
		result.provisions += 0.25
		result.standing_troops -= 0.15
		result.security += 15
	if completed(house_id, "武家諸法度"): result.loyalty += 20
	if completed(house_id, "二毛作"): result.provisions += 0.05
	if completed(house_id, "鉄製農具配布"):
		result.money -= 0.10
		result.provisions += 0.20
	if completed(house_id, "近世式用水路"):
		result.provisions += 0.05
		result.drought_damage -= 0.25
	if completed(house_id, "共同管理法制定"): result.agriculture_building_cost_reduction = 15
	if completed(house_id, "大名介入"):
		result.money -= 0.15
		result.population_growth += 0.15
		result.security += 10
	if completed(house_id, "灌漑整備"):
		result.flood_damage -= 0.50
		result.typhoon_damage -= 0.50
	if completed(house_id, "検地"): result.provisions += 0.25
	if completed(house_id, "石高制制定"): result.standing_troops += 0.20
	if completed(house_id, "新田開発"):
		result.money -= 0.10
		result.provisions += 0.50
	if completed(house_id, "市場整備"): result.market_cost_multiplier = 0.85
	if completed(house_id, "商人保護"): result.money += 0.05
	if completed(house_id, "度量衡整備"): result.commerce_development += 0.15
	if completed(house_id, "職人誘致"):
		result.workshop_cost_multiplier = 0.85
		result.workshop_months_reduction = 2
	if completed(house_id, "問屋整備"): result.market_income_bonus = 0.10
	if completed(house_id, "貨幣流通促進"): result.money += 0.05
	if completed(house_id, "商工業振興"): result.commerce_development += 0.15
	if completed(house_id, "商業奉行設置"): result.money += 0.10
	result.make_read_only()
	if modifier_cache.size() >= 256 and not modifier_cache.has(house_id): modifier_cache.erase(modifier_cache.keys()[0])
	modifier_cache[house_id] = {"inputs":inputs.duplicate(true), "value":result}
	return result

func commerce_building_cost_for(house_id: String, building_id: String, base_cost: int) -> int:
	var field: String = {"market":"market_cost_multiplier", "workshop":"workshop_cost_multiplier"}.get(building_id, "")
	if field.is_empty(): return base_cost
	return maxi(0, roundi(base_cost * float(modifiers(house_id)[field])))

func building_months_for(house_id: String, building_id: String, base_months: int) -> int:
	return maxi(1, base_months - int(modifiers(house_id).workshop_months_reduction)) if building_id == "workshop" else base_months

func commerce_development_for(house_id: String, base_progress: float) -> float:
	return base_progress * float(modifiers(house_id).commerce_development)

func security_for(district: Dictionary) -> int:
	var building_bonus: int = district_buildings.security_bonus(district.id) if district_buildings != null else 0
	return clampi(int(district.get("security", 50)) + int(modifiers(district.house_id).security) + building_bonus + (technology_orders.security_bonus(district.id) if technology_orders != null else 0) - (int(district.get("tax_rate", 40)) - 40), 0, 100)

func population_growth_for(house_id: String, base_growth: float) -> float:
	return base_growth * float(modifiers(house_id).population_growth)

func standing_troops_for(house_id: String, base_troops: int) -> int:
	return maxi(0, roundi(base_troops * float(modifiers(house_id).standing_troops)))

func agriculture_building_cost_for(house_id: String, base_cost: int) -> int:
	return maxi(0, base_cost - int(modifiers(house_id).agriculture_building_cost_reduction))

func disaster_damage_for(house_id: String, kind: String, base_damage: int) -> int:
	var field: String = {"drought":"drought_damage", "flood":"flood_damage", "typhoon":"typhoon_damage"}.get(kind, "")
	if field.is_empty(): return maxi(0, base_damage)
	return maxi(0, roundi(base_damage * float(modifiers(house_id)[field])))
