extends Node
## Relations are symmetric treaties; opinion is directional, like EU4's country opinion.

signal changed
signal war_started(attacker: String, defender: String)
signal assistance_requested(defender: String, attacker: String, ally: String)

const ENVOY_GAIN := 5
const GIFT_COST := 100
const TRUCE_MONTHS := 12
const ACTION_DELAY_DAYS := 30

var main: Node
var opinions: Dictionary = {}
var envoys: Dictionary = {}
var truces: Dictionary = {}
var last_actions: Dictionary = {}
var last_message := ""
var wars: Dictionary = {}
var next_war_id := 1

func setup(game_main: Node) -> void:
	main = game_main
	opinions.clear()
	envoys.clear()
	truces.clear()
	last_actions.clear()
	wars.clear()
	next_war_id = 1
	for key in GameSession.relations:
		var ids: PackedStringArray = str(key).split("|")
		var value := 80 if GameSession.relations[key] == "ally" else (-80 if GameSession.relations[key] == "enemy" else 0)
		opinions[ids[0] + ">" + ids[1]] = value
		opinions[ids[1] + ">" + ids[0]] = value
		# Scenario hostility has no known aggressor; only new wars assign sides.

func opinion(from_house: String, about_house: String) -> int:
	return int(opinions.get(from_house + ">" + about_house, 0))

func change_opinion(from_house: String, about_house: String, amount: int) -> void:
	var key := from_house + ">" + about_house
	opinions[key] = clampi(opinion(from_house, about_house) + amount, -100, 100)
	changed.emit()

func envoy_target(house_id: String) -> String:
	return str(envoys.get(house_id, ""))

func truce_remaining(a: String, b: String) -> int:
	return maxi(0, int(truces.get(GameSession.pair(a, b), 0)) - int(main.game_clock.elapsed_days))

func reason(action: String, actor: String, target: String) -> String:
	if actor == target or not main.governance_registry.houses.has(actor) or not main.governance_registry.houses.has(target): return "対象の家を選んでください"
	var status := GameSession.relation(actor, target)
	var key := actor + ">" + target
	if action not in ["envoy", "recall", "call_allies", "join_war", "decline_war"] and int(main.game_clock.elapsed_days) - int(last_actions.get(key, -ACTION_DELAY_DAYS)) < ACTION_DELAY_DAYS:
		return "この家への外交行動は30日後に再開できます"
	match action:
		"envoy":
			if envoy_target(actor) == target: return "使節はすでに派遣されています"
			if opinion(target, actor) >= 100: return "相手の友好度は上限です"
		"recall":
			if envoy_target(actor) != target: return "この家へ使節を派遣していません"
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

func act(action: String, actor: String, target: String) -> Error:
	last_message = reason(action, actor, target)
	if not last_message.is_empty(): return ERR_UNAVAILABLE
	match action:
		"envoy":
			envoys[actor] = target
			last_message = "使節を派遣しました。毎月、相手の友好度が5上がります"
		"recall":
			envoys.erase(actor)
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
			main.house_prestige.on_unjustified_war_started(actor)
			last_message = "宣戦しました。威信が10下がりました"
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
	GameSession.relations[GameSession.pair(a, b)] = status
	main.army_campaign.route_obstacles.erase(a)
	main.army_campaign.route_obstacles.erase(b)
	if is_instance_valid(main.cpu_controller): main.cpu_controller.invalidate_routes(a, b)
	if is_instance_valid(main.territory_borders): main.territory_borders.refresh_relations()

func on_hostile_attack(actor: String, target: String) -> void:
	var relation := GameSession.relation(actor, target)
	if relation in ["ally", "self"] or truce_remaining(actor, target) > 0: return
	if relation == "neutral":
		_set_relation(actor, target, "enemy")
		change_opinion(target, actor, -50)
		main.house_prestige.on_unjustified_war_started(actor)
	if not _war_supports(actor, target): start_war(actor, target)
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
	for id in wars.keys():
		var war: Dictionary = wars[id]
		if GameSession.relation(war.attacker, war.defender) != "enemy":
			finish_peace(war.attacker, war.defender)
			continue
		for ally in war.requests.keys():
			if ally != GameSession.player_house and war.requests[ally] == "pending": join_war(id, ally)
	if day != 1: return
	for actor in envoys.keys():
		var target: String = str(envoys[actor])
		if not main.governance_registry.houses.has(actor) or not main.governance_registry.houses.has(target):
			envoys.erase(actor)
			continue
		change_opinion(target, actor, ENVOY_GAIN)
		if opinion(target, actor) >= 100: envoys.erase(actor)
	changed.emit()

func save_state() -> Dictionary:
	return {"opinions":opinions.duplicate(true), "envoys":envoys.duplicate(true), "truces":truces.duplicate(true), "last_actions":last_actions.duplicate(true), "wars":wars.duplicate(true), "next_war_id":next_war_id}

func restore_state(state: Dictionary) -> void:
	opinions = state.opinions.duplicate(true)
	envoys = state.envoys.duplicate(true)
	truces = state.truces.duplicate(true)
	last_actions = state.last_actions.duplicate(true)
	wars = state.wars.duplicate(true)
	next_war_id = int(state.next_war_id)
	for key in opinions: opinions[key] = int(opinions[key])
	for key in truces: truces[key] = int(truces[key])
	for key in last_actions: last_actions[key] = int(last_actions[key])
	for war in wars.values(): war.started = int(war.started)
	changed.emit()
