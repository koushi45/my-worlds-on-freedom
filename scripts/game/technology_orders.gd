extends Node
## Finite, targeted uses of the house's accumulated administrative capacity.
const DEFINITIONS := {
	"integration": {"name":"新領地の統治整備", "field":"governance", "points":120, "money":60, "food":0, "prepare":0, "duration":90, "hint":"90日間、安定化速度+50%。"},
	"patrol": {"name":"郡の巡察", "field":"governance", "points":60, "money":20, "food":0, "prepare":30, "duration":90, "hint":"30日巡察後、90日間治安+15。重税の治安低下は継続。"},
	"development": {"name":"開発事業の集中管理", "field":"governance", "points":120, "money":80, "food":0, "prepare":0, "duration":90, "hint":"90日間、農業・商業の開発進行+50%。担当未配置の分野は大名の政治能力で進行。"},
	"recovery": {"name":"災害復旧の指揮", "field":"governance", "points":90, "money":60, "food":100, "prepare":0, "duration":90, "hint":"90日間、3日ごとに荒廃度-2。生産低下を段階的に回復。"},
	"negotiation": {"name":"国衆・在地勢力との折衝", "field":"diplomacy", "points":120, "money":100, "food":0, "prepare":30, "duration":180, "hint":"30日後に安定度+20・自治度-20。既存権益を安堵し、以後180日間は税率30%以下を約束。"},
	"defense": {"name":"防衛準備", "field":"military", "points":100, "money":80, "food":100, "prepare":30, "duration":90, "hint":"30日準備後、90日間攻城防御+25%・奉行所の制圧速度-20%。守備兵100人以上が必要。野戦には無効。"}
}
var main: Node
var districts: Dictionary = {}
var drills: Dictionary = {}

func point_cost(house: String, base: int) -> int:
	return roundi(base*0.95) if main.technology_tree.completed(house, "城下町制度") else base

func today() -> int: return int(main.game_clock.elapsed_days)

func valid_job(id: String, include_expired := false) -> bool:
	if not districts.has(id) or not main.governance_registry.districts.has(id): return false
	var j: Dictionary = districts[id]
	var r: Dictionary = main.governance_registry.districts[id]
	if r.house_id != j.house or (not include_expired and today() >= int(j.end)): return false
	return true

func active(id: String, kind: String) -> bool:
	return valid_job(id) and districts[id].kind == kind and today() >= int(districts[id].ready)

func garrison_count(id: String) -> int:
	var r: Dictionary = main.governance_registry.districts[id]
	var count := int(r.sortie_troops)
	for site_id in r.get("site_ids", []):
		if main.governance_registry.sites.has(site_id) and main.governance_registry.sites[site_id].house_id == r.house_id:
			count += int(main.army_campaign.garrisons.get(site_id, 0))
	return count

func reason(id: String, kind: String, house: String) -> String:
	if kind not in DEFINITIONS or not main.governance_registry.districts.has(id): return "対象が不正です"
	var r: Dictionary = main.governance_registry.districts[id]
	if house.is_empty() or r.house_id != house: return "自家の郡を選択してください"
	if valid_job(id): return "この郡は命令実行中です"
	if main.army_campaign.office_enemy_present(id): return "敵部隊が奉行所に駐留しています"
	if kind == "integration":
		if float(r.occupation_stability) >= 100: return "既に統治が安定しています"
	if kind == "patrol" and main.technology_tree.security_for(r) >= 100: return "治安は上限です"
	if kind == "development":
		if int(r.agriculture_development) >= 30 and int(r.commerce_development) >= 30: return "農業・商業の開発は上限です"
	if kind == "recovery" and int(r.devastation) <= 0: return "復旧する荒廃がありません"
	if kind == "negotiation" and float(r.occupation_stability) >= 100 and int(r.autonomy) <= 0: return "統治が安定し、自治度も解消済みです"
	if kind == "defense" and garrison_count(id) < 100: return "守備兵100人以上が必要です"
	var d: Dictionary = DEFINITIONS[kind]
	var resources: Dictionary = main.district_economy.house_resources[house]
	if float(main.retainer_management.technology[house][d.field]) < point_cost(house, int(d.points)): return "技術力が不足しています"
	if float(resources.money) < int(d.money): return "金銭が不足しています"
	if int(resources.provisions) < int(d.food): return "兵糧が不足しています"
	return ""

func start(id: String, kind: String, house: String) -> Error:
	if not reason(id, kind, house).is_empty(): return ERR_UNAVAILABLE
	if districts.has(id): finish(id)
	var d: Dictionary = DEFINITIONS[kind]
	main.retainer_management.technology[house][d.field] -= point_cost(house, int(d.points))
	main.district_economy.house_resources[house].money -= int(d.money)
	main.district_economy.house_resources[house].provisions -= int(d.food)
	districts[id] = {"kind":kind, "house":house, "start":today(), "ready":today()+int(d.prepare), "end":today()+int(d.prepare)+int(d.duration), "last":today(), "applied":false, "previous_tax":int(main.governance_registry.districts[id].tax_rate)}
	notify(id)
	return OK

func finish(id: String) -> void:
	var j: Dictionary = districts[id]
	var r: Dictionary = main.governance_registry.districts[id]
	if j.kind == "negotiation" and j.applied and r.house_id == j.house and int(r.tax_rate) == mini(30, int(j.previous_tax)):
		r.tax_rate = int(j.previous_tax)
	districts.erase(id)
	notify(id)

func advance() -> void:
	for id in districts.keys():
		if not valid_job(id, true):
			finish(id)
			continue
		var j: Dictionary = districts[id]
		var r: Dictionary = main.governance_registry.districts[id]
		if today() < int(j.ready): continue
		if j.kind == "negotiation" and not j.applied:
			r.occupation_stability = minf(100, float(r.occupation_stability)+20)
			r.autonomy = maxi(0, int(r.autonomy)-20)
			r.tax_rate = mini(30, int(r.tax_rate))
			j.applied = true
		if j.kind == "recovery":
			var steps := (mini(today(), int(j.end))-int(j.last))/3
			if steps > 0:
				r.devastation = maxi(0, int(r.devastation)-steps*2)
				j.last += steps*3
		if today() >= int(j.end):
			finish(id)
		else:
			notify(id)
	for id in drills.keys():
		if not main.army_campaign.units.has(id) or today() >= int(drills[id].end):
			drills.erase(id)
			continue
		if training(id):
			var u: Dictionary = main.army_campaign.units[id]
			var district_id: String = main.army_campaign.district_id_for_node(u.origin)
			if district_id.is_empty() or main.governance_registry.districts[district_id].house_id != u.house_id or main.army_campaign.office_enemy_present(district_id) or main.army_campaign.melee_engagements().has(id): drills.erase(id)

func notify(id: String) -> void:
	main.district_actions.changed.emit(id)
	main.house_status_hud.invalidate()

func summary(id: String) -> String:
	if not valid_job(id): return "技術力命令なし"
	var j: Dictionary = districts[id]
	var name_text: String = DEFINITIONS[j.kind].name
	return "%s\n%s あと%d日" % [name_text, "準備" if today() < int(j.ready) else "効果", maxi(0, int(j.ready if today() < int(j.ready) else j.end)-today())]

func security_bonus(id: String) -> int: return 15 if active(id, "patrol") else 0
func development_multiplier(id: String) -> float: return 1.5 if active(id, "development") else 1.0
func stability_multiplier(id: String) -> float: return 1.5 if active(id, "integration") else 1.0
func defense_multiplier(id: String) -> float: return 1.25 if active(id, "defense") and garrison_count(id) >= 100 else 1.0
func tax_limit(id: String) -> int: return 30 if active(id, "negotiation") and districts[id].applied else 60

func training(id: String) -> bool:
	return drills.has(id) and today() < int(drills[id].ready) and today() < int(drills[id].end)

func drill_reason(id: String, house: String) -> String:
	if not main.army_campaign.units.has(id) or house.is_empty() or main.army_campaign.units[id].house_id != house: return "自家の部隊を選択してください"
	var u: Dictionary = main.army_campaign.units[id]
	if drills.has(id) and today() < int(drills[id].end): return "調練中または効果継続中です"
	if u.site_id != u.origin or not u.next_site.is_empty() or not u.orders.is_empty() or u.automatic != null: return "帰郡先で移動・自動命令を解除してください"
	var district_id: String = main.army_campaign.district_id_for_node(u.origin)
	if district_id.is_empty() or main.governance_registry.districts[district_id].house_id != house or main.army_campaign.office_enemy_present(district_id) or main.army_campaign.melee_engagements().has(id): return "安全な自領の帰郡先で準備してください"
	if float(u.supply_days) <= 14: return "準備に必要な腰兵糧14日分がありません"
	if float(main.retainer_management.technology[house].military) < point_cost(house, 100): return "軍事技術力%dが必要です" % point_cost(house, 100)
	if int(main.district_economy.house_resources[house].provisions) < ceili(int(u.soldiers)*0.1): return "調練用の兵糧が不足しています"
	return ""

func start_drill(id: String, house: String) -> Error:
	if not drill_reason(id, house).is_empty(): return ERR_UNAVAILABLE
	var u: Dictionary = main.army_campaign.units[id]
	main.retainer_management.technology[house].military -= point_cost(house, 100)
	main.district_economy.house_resources[house].provisions -= ceili(int(u.soldiers)*0.1)
	drills[id] = {"ready":today()+14, "end":today()+104, "soldiers":int(u.soldiers)}
	main.army_campaign.changed.emit()
	main.house_status_hud.invalidate()
	return OK

func reduce_trained(id: String, survivors: int, previous: int) -> void:
	if drills.has(id): drills[id].soldiers = maxi(1, floori(float(drills[id].soldiers)*survivors/maxi(1, previous)))

func combat_multiplier(u: Dictionary) -> float:
	var id: String = u.id
	if not drills.has(id) or today() < int(drills[id].ready) or today() >= int(drills[id].end): return 1.0
	return 1.0+0.15*minf(1.0, float(drills[id].soldiers)/maxi(1,int(u.soldiers)))

func merge_drills(id: String, other: String) -> void:
	var trained := 0
	var deadline := 2147483647
	for key in [id, other]:
		if drills.has(key) and today() >= int(drills[key].ready) and today() < int(drills[key].end):
			trained += mini(int(drills[key].soldiers), int(main.army_campaign.units[key].soldiers))
			deadline = mini(deadline, int(drills[key].end))
	drills.erase(id)
	drills.erase(other)
	if trained > 0: drills[id] = {"ready":today(), "end":deadline, "soldiers":trained}

func save_state() -> Dictionary:
	var saved_drills := {}
	for id in drills:
		if main.army_campaign.units.has(id): saved_drills[id] = drills[id].duplicate(true)
	return {"districts":districts.duplicate(true), "drills":saved_drills}

func development_progress(id: String, progress: float) -> float:
	if not active(id, "development"): return progress
	if progress <= 0.0:
		var house: String = main.governance_registry.districts[id].house_id
		progress = main.district_economy.politics_for(main.retainer_management.ruler_id(house))
	return progress * development_multiplier(id)
