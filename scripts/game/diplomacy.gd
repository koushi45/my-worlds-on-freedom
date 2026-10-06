extends Node
## Relations are symmetric treaties; opinion is directional, like EU4's country opinion.

signal changed
signal war_started(attacker: String, defender: String)
signal assistance_requested(defender: String, attacker: String, ally: String)

const DIPLOMAT_LIMIT := 3
const ENVOY_GAIN := 5
const GIFT_COST := 100
const TRUCE_MONTHS := 12
const ACTION_DELAY_DAYS := 30
const SPY_MONTHLY_GAIN := 5

var main: Node
var opinions: Dictionary = {}
var envoys: Dictionary = {}
var truces: Dictionary = {}
var last_actions: Dictionary = {}
var last_message := ""
var wars: Dictionary = {}
var next_war_id := 1
const SPY_COSTS := {"fabricate_claim":20, "sow_discontent":60, "sabotage_reputation":50, "sabotage_recruitment":50, "slander_merchants":70, "counterespionage":30}
const EFFECT_DAYS := 360
const CLAIM_DAYS := 1825
var spy_networks: Dictionary = {}
var spies: Dictionary = {}
var claims: Dictionary = {}
var spy_effects: Dictionary = {}

func setup(game_main: Node) -> void:
	main = game_main
	opinions.clear()
	envoys.clear()
	truces.clear()
	last_actions.clear()
	wars.clear()
	next_war_id = 1
	spy_networks.clear()
	spies.clear()
	claims.clear()
	spy_effects.clear()
	for key in GameSession.relations:
		var ids: PackedStringArray = str(key).split("|")
		var value := 80 if GameSession.relations[key] == "ally" else (-80 if GameSession.relations[key] == "enemy" else 0)
		opinions[ids[0] + ">" + ids[1]] = value
		opinions[ids[1] + ">" + ids[0]] = value
		# Scenario hostility has no known aggressor; only new wars assign sides.

func opinion(from_house: String, about_house: String) -> int:
	var penalty := 20 if from_house != about_house and effect_active("sabotage_reputation", about_house) else 0
	return clampi(int(opinions.get(from_house + ">" + about_house, 0)) - penalty, -100, 100)

func change_opinion(from_house: String, about_house: String, amount: int) -> void:
	var key := from_house + ">" + about_house
	opinions[key] = clampi(int(opinions.get(key, 0)) + amount, -100, 100)
	changed.emit()

func has_envoy(actor: String, target: String) -> bool:
	return target in envoys.get(actor, [])

func has_spy(actor: String, target: String) -> bool:
	return target in spies.get(actor, [])

func diplomats_used(actor: String) -> int:
	return envoys.get(actor, []).size() + spies.get(actor, []).size()

func _dispatch(assignments: Dictionary, actor: String, target: String) -> void:
	if not assignments.has(actor): assignments[actor] = []
	assignments[actor].append(target)

func _recall(assignments: Dictionary, actor: String, target: String) -> void:
	if not assignments.has(actor): return
	assignments[actor].erase(target)
	if assignments[actor].is_empty(): assignments.erase(actor)

func diplomat_reason(actor: String) -> String:
	return "外交官は%d人までです。派遣中の外交官を呼び戻してください" % DIPLOMAT_LIMIT if diplomats_used(actor) >= DIPLOMAT_LIMIT else ""

func truce_remaining(a: String, b: String) -> int:
	return maxi(0, int(truces.get(GameSession.pair(a, b), 0)) - int(main.game_clock.elapsed_days))

func reason(action: String, actor: String, target: String, district_id: String = "") -> String:
	if actor == target or not main.governance_registry.houses.has(actor) or not main.governance_registry.houses.has(target): return "対象の家を選んでください"
	if action in ["build_spy_network", "recall_spy"] or SPY_COSTS.has(action):
		return spy_reason(action, actor, target, district_id)
	var status := GameSession.relation(actor, target)
	var key := actor + ">" + target
	if action not in ["envoy", "recall", "call_allies", "join_war", "decline_war"] and int(main.game_clock.elapsed_days) - int(last_actions.get(key, -ACTION_DELAY_DAYS)) < ACTION_DELAY_DAYS:
		return "この家への外交行動は30日後に再開できます"
	match action:
		"envoy":
			if has_envoy(actor, target): return "使節はすでに派遣されています"
			if opinion(target, actor) >= 100: return "相手の友好度は上限です"
			if not diplomat_reason(actor).is_empty(): return diplomat_reason(actor)
		"recall":
			if not has_envoy(actor, target): return "この家へ使節を派遣していません"
		"gift":
			if float(main.district_economy.house_resources.get(actor, {}).get("money", 0)) < GIFT_COST: return "金銭が100不足しています"
			if opinion(target, actor) >= 100: return "相手の友好度は上限です"
		"ally":
			if status != "neutral": return "中立の家にのみ同盟を提案できます"
			if truce_remaining(actor, target) > 0: return "停戦期間中は同盟できません"
			if opinion(target, actor) < 40: return "相手の友好度が40以上必要です"
		"break_ally":
			if status != "ally": return "同盟を結んでいません"
		"insult":
			if status == "ally": return "同盟相手を侮辱できません"
		"war":
			if status != "neutral": return "中立の家にのみ宣戦できます"
			if truce_remaining(actor, target) > 0: return "停戦期間中は宣戦できません"
			if actor != GameSession.player_house and war_justification(actor, target).is_empty(): return "CPUの宣戦には有効な請求権が必要です"
		"peace":
			if status != "enemy": return "敵対していません"
			if opinion(target, actor) < -20: return "相手の友好度が-20以上必要です"
		"call_allies":
			if status != "enemy": return "敵対していません"
			if _war_supports(actor, target) and defense_war(actor, target).is_empty(): return "主たる防衛側の家から参戦を要請してください"
		"join_war", "decline_war":
			if pending_request(actor, target).is_empty(): return "この家からの参戦要請はありません"
			if action == "join_war":
				var war: Dictionary = wars[pending_request(actor, target)]
				if truce_remaining(actor, war.attacker) > 0: return "攻撃側との停戦期間中です"
		_:
			return "外交行動が不正です"
	return ""

func act(action: String, actor: String, target: String, district_id: String = "") -> Error:
	last_message = reason(action, actor, target, district_id)
	if not last_message.is_empty(): return ERR_UNAVAILABLE
	if action in ["build_spy_network", "recall_spy"] or SPY_COSTS.has(action):
		return spy_act(action, actor, target, district_id)
	match action:
		"envoy":
			_dispatch(envoys, actor, target)
			last_message = "使節を派遣しました。毎月、相手の友好度が5上がります"
		"recall":
			_recall(envoys, actor, target)
			last_message = "使節を呼び戻しました"
		"gift":
			main.district_economy.house_resources[actor].money -= GIFT_COST
			change_opinion(target, actor, 20)
			last_message = "贈物を届けました。相手の友好度が20上がりました"
		"ally":
			_set_relation(actor, target, "ally")
			change_opinion(target, actor, 15)
			change_opinion(actor, target, 15)
			last_message = "同盟を結びました"
		"break_ally":
			_set_relation(actor, target, "neutral")
			change_opinion(target, actor, -40)
			main.house_prestige.on_treaty_broken(actor)
			last_message = "同盟を破棄しました。威信が10下がりました"
		"insult":
			change_opinion(target, actor, -25)
			last_message = "侮辱を送りました。相手の友好度が25下がりました"
		"war":
			_set_relation(actor, target, "enemy")
			change_opinion(target, actor, -50)
			if has_claim_against(actor, target):
				last_message = "請求権を根拠に宣戦しました。威信の減少はありません"
			else:
				main.house_prestige.on_unjustified_war_started(actor)
				last_message = "正当な理由なく宣戦しました。威信が%d下がります（下限0）" % main.house_prestige.UNJUSTIFIED_WAR_LOSS
			start_war(actor, target)
		"peace":
			finish_peace(actor, target)
			last_message = "停戦しました。360日間は宣戦できません"
		"call_allies":
			var defense_id := defense_war(actor, target)
			if defense_id.is_empty(): defense_id = _record_war(target, actor)
			request_allies(defense_id)
			last_message = "同盟国へ防衛参戦を要請しました"
		"join_war":
			join_war(pending_request(actor, target), actor)
			last_message = "同盟国の防衛戦争に参戦しました"
		"decline_war":
			wars[pending_request(actor, target)].requests[actor] = "declined"
			last_message = "防衛参戦を辞退しました"
	if action not in ["envoy", "recall", "call_allies", "join_war", "decline_war"]: last_actions[actor + ">" + target] = int(main.game_clock.elapsed_days)
	changed.emit()
	return OK

func _set_relation(a: String, b: String, status: String) -> void:
	if GameSession.relation(a, b) == status: return
	GameSession.relations[GameSession.pair(a, b)] = status
	main.army_campaign.route_obstacles.erase(a)
	main.army_campaign.route_obstacles.erase(b)
	if is_instance_valid(main.cpu_controller): main.cpu_controller.invalidate_routes(a, b)
	if is_instance_valid(main.territory_borders): main.territory_borders.refresh_relations()

func on_hostile_attack(actor: String, target: String) -> void:
	if GameSession.relation(actor, target) != "enemy" or truce_remaining(actor, target) > 0: return
	if _war_supports(actor, target): return
	start_war(actor, target)
	changed.emit()

func _record_war(attacker: String, defender: String) -> String:
	for id in wars:
		if wars[id].attacker == attacker and defender in wars[id].defenders: return id
	var id := "war_%d" % next_war_id
	next_war_id += 1
	wars[id] = {"attacker":attacker, "defender":defender, "defenders":[defender], "requests":{}, "started":int(main.game_clock.elapsed_days), "called":false}
	return id

func start_war(attacker: String, defender: String) -> void:
	var id := _record_war(attacker, defender)
	request_allies(id)
	war_started.emit(attacker, defender)

func defense_war(defender: String, attacker: String) -> String:
	for id in wars:
		if wars[id].defender == defender and wars[id].attacker == attacker: return id
	return ""

func pending_request(ally: String, defender: String) -> String:
	for id in wars:
		if wars[id].defender == defender and wars[id].requests.get(ally) == "pending": return id
	return ""

func request_allies(id: String) -> void:
	if not wars.has(id): return
	var war: Dictionary = wars[id]
	war.called = true
	for ally in main.governance_registry.houses:
		if ally == war.attacker or ally in war.defenders or war.requests.has(ally): continue
		if GameSession.relation(war.defender, ally) != "ally": continue
		war.requests[ally] = "pending"
		assistance_requested.emit(war.defender, war.attacker, ally)
		if ally != GameSession.player_house: join_war(id, ally)
	changed.emit()

func join_war(id: String, ally: String) -> bool:
	if not wars.has(id): return false
	var war: Dictionary = wars[id]
	if war.requests.get(ally) != "pending" or GameSession.relation(ally, war.defender) != "ally": return false
	if truce_remaining(ally, war.attacker) > 0: return false
	if GameSession.relation(ally, war.attacker) == "ally":
		_set_relation(ally, war.attacker, "neutral")
		change_opinion(war.attacker, ally, -40)
		main.house_prestige.on_treaty_broken(ally)
	war.requests[ally] = "accepted"
	if ally not in war.defenders: war.defenders.append(ally)
	_set_relation(ally, war.attacker, "enemy")
	changed.emit()
	return true

func _war_supports(a: String, b: String) -> bool:
	for war in wars.values():
		if (war.attacker == a and b in war.defenders) or (war.attacker == b and a in war.defenders): return true
	return false

func finish_peace(actor: String, target: String) -> void:
	var pairs: Array = [[actor, target]]
	for id in wars.keys():
		var war: Dictionary = wars[id]
		if (war.attacker == actor and war.defender == target) or (war.attacker == target and war.defender == actor):
			for defender in war.defenders: pairs.append([war.attacker, defender])
			wars.erase(id)
		elif (war.attacker == actor and target in war.defenders) or (war.attacker == target and actor in war.defenders):
			var leaving: String = target if war.attacker == actor else actor
			war.defenders.erase(leaving)
			war.requests[leaving] = "declined"
	for pair in pairs:
		if _war_supports(pair[0], pair[1]): continue
		_set_relation(pair[0], pair[1], "neutral")
		truces[GameSession.pair(pair[0], pair[1])] = int(main.game_clock.elapsed_days) + TRUCE_MONTHS * 30

func on_day_advanced(_year: int, _month: int, day: int) -> void:
	for key in spy_effects.keys():
		if int(spy_effects[key]) <= int(main.game_clock.elapsed_days): spy_effects.erase(key)
	for actor in claims:
		for district_id in claims[actor].keys():
			if int(claims[actor][district_id]) <= int(main.game_clock.elapsed_days): claims[actor].erase(district_id)
	for id in wars.keys():
		var war: Dictionary = wars[id]
		if GameSession.relation(war.attacker, war.defender) != "enemy":
			finish_peace(war.attacker, war.defender)
			continue
		for ally in war.requests.keys():
			if ally != GameSession.player_house and war.requests[ally] == "pending": join_war(id, ally)
	if day != 1: return
	advance_spy_month()
	var owned := {}
	for record in main.governance_registry.districts.values(): owned[record.house_id] = true
	for actor in envoys.keys():
		for target in envoys[actor].duplicate():
			if not owned.has(actor) or not owned.has(target):
				_recall(envoys, actor, target)
				continue
			change_opinion(target, actor, ENVOY_GAIN)
			if opinion(target, actor) >= 100: _recall(envoys, actor, target)
	changed.emit()

func save_state() -> Dictionary:
	return {"opinions":opinions.duplicate(true), "envoys":envoys.duplicate(true), "truces":truces.duplicate(true), "last_actions":last_actions.duplicate(true), "wars":wars.duplicate(true), "next_war_id":next_war_id, "spy_networks":spy_networks.duplicate(true), "spies":spies.duplicate(true), "claims":claims.duplicate(true), "spy_effects":spy_effects.duplicate(true)}

func restore_state(state: Dictionary) -> void:
	opinions = state.opinions.duplicate(true)
	envoys = state.envoys.duplicate(true)
	truces = state.truces.duplicate(true)
	last_actions = state.last_actions.duplicate(true)
	wars = state.wars.duplicate(true)
	next_war_id = int(state.next_war_id)
	spy_networks = state.spy_networks.duplicate(true)
	spies = state.spies.duplicate(true)
	claims = state.claims.duplicate(true)
	spy_effects = state.spy_effects.duplicate(true)
	for key in opinions: opinions[key] = int(opinions[key])
	for key in truces: truces[key] = int(truces[key])
	for key in last_actions: last_actions[key] = int(last_actions[key])
	for war in wars.values(): war.started = int(war.started)
	changed.emit()

func spy_value(actor: String, target: String) -> int:
	return int(spy_networks.get(actor + ">" + target, 0))

func effect_remaining(action: String, target: String) -> int:
	return maxi(0, int(spy_effects.get(action + ">" + target, 0)) - int(main.game_clock.elapsed_days))

func effect_active(action: String, target: String) -> bool:
	return main != null and effect_remaining(action, target) > 0

func claim_remaining(actor: String, district_id: String) -> int:
	return maxi(0, int(claims.get(actor, {}).get(district_id, 0)) - int(main.game_clock.elapsed_days))

func has_claim_against(actor: String, target: String) -> bool:
	for district_id in claims.get(actor, {}):
		if claim_remaining(actor, district_id) > 0 and main.governance_registry.districts.has(district_id) and main.governance_registry.districts[district_id].house_id == target: return true
	return false

func war_justification(actor: String, target: String) -> String:
	return "請求権" if has_claim_against(actor, target) else ""

func claim_candidates(actor: String, target: String) -> Array[String]:
	var result: Array[String] = []
	for id in main.governance_registry.districts:
		if main.governance_registry.districts[id].house_id == target and claim_remaining(actor, id) == 0: result.append(id)
	result.sort()
	return result

func spy_reason(action: String, actor: String, target: String, district_id: String) -> String:
	var owns_land := false
	for record in main.governance_registry.districts.values():
		if record.house_id == target: owns_land = true; break
	if not owns_land: return "対象家は領地を所有していません"
	if action == "build_spy_network":
		if has_spy(actor, target): return "間者はすでに派遣されています"
		return diplomat_reason(actor)
	if action == "recall_spy":
		return "この家へ間者を派遣していません" if not has_spy(actor, target) else ""
	if action != "counterespionage" and GameSession.relation(actor, target) == "ally": return "同盟家に敵対工作はできません"
	if int(main.game_clock.elapsed_days) - int(last_actions.get(actor + ">" + target, -ACTION_DELAY_DAYS)) < ACTION_DELAY_DAYS: return "この家への外交行動は30日後に再開できます"
	if spy_value(actor, target) < int(SPY_COSTS[action]): return "諜報値が%d必要です（現在%d）" % [SPY_COSTS[action], spy_value(actor, target)]
	if action == "fabricate_claim":
		if district_id.is_empty():
			if claim_candidates(actor, target).is_empty(): return "捏造できる郡がありません"
		elif not main.governance_registry.districts.has(district_id) or main.governance_registry.districts[district_id].house_id != target: return "対象家が現在所有する郡を選んでください"
		elif claim_remaining(actor, district_id) > 0: return "この郡にはすでに請求権があります"
	elif action == "counterespionage":
		if spy_value(target, actor) == 0: return "対象家の自家に対する諜報網はありません"
	elif effect_active(action, target): return "この工作は効果中です（残り%d日）" % effect_remaining(action, target)
	return ""

func spy_act(action: String, actor: String, target: String, district_id: String) -> Error:
	if action == "fabricate_claim" and district_id.is_empty():
		last_message = "請求権を捏造する郡を選んでください"
		return ERR_UNAVAILABLE
	if action == "build_spy_network":
		_dispatch(spies, actor, target)
		spy_networks[actor + ">" + target] = spy_value(actor, target)
		last_message = "間者を派遣しました。月初に諜報値+%d（上限100）" % SPY_MONTHLY_GAIN
	elif action == "recall_spy":
		_recall(spies, actor, target)
		last_message = "間者を帰還させました。構築していない諜報網は月初に2減衰します"
	else:
		spy_networks[actor + ">" + target] = spy_value(actor, target) - int(SPY_COSTS[action])
		last_actions[actor + ">" + target] = int(main.game_clock.elapsed_days)
		if action == "fabricate_claim":
			if not claims.has(actor): claims[actor] = {}
			claims[actor][district_id] = int(main.game_clock.elapsed_days) + CLAIM_DAYS
			last_message = "請求権を捏造しました（1825日）。この郡の領主への宣戦を正当化できます"
		elif action == "counterespionage":
			spy_networks[target + ">" + actor] = maxi(0, spy_value(target, actor) - 30)
			last_message = "防諜を実行しました。相手の自家に対する諜報値を30減らしました"
		else:
			spy_effects[action + ">" + target] = int(main.game_clock.elapsed_days) + EFFECT_DAYS
			last_message = "工作が成功しました。効果は360日間続きます"
	changed.emit()
	return OK

func advance_spy_month() -> void:
	var owned := {}
	for record in main.governance_registry.districts.values(): owned[record.house_id] = true
	for actor in spies.keys():
		for target in spies[actor].duplicate():
			if not owned.has(actor) or not owned.has(target): _recall(spies, actor, target)
	for key in spy_networks:
		var ids: PackedStringArray = str(key).split(">")
		spy_networks[key] = clampi(int(spy_networks[key]) + (SPY_MONTHLY_GAIN if has_spy(ids[0], ids[1]) else -2), 0, 100)
	for record in main.governance_registry.districts.values():
		if effect_active("sow_discontent", record.house_id): record.security = maxi(0, int(record.security) - 3)
