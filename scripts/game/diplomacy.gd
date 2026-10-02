extends Node
## Relations are symmetric treaties; opinion is directional, like EU4's country opinion.

signal changed

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

func setup(game_main: Node) -> void:
	main = game_main
	opinions.clear()
	envoys.clear()
	truces.clear()
	last_actions.clear()
	for key in GameSession.relations:
		var ids: PackedStringArray = str(key).split("|")
		var value := 80 if GameSession.relations[key] == "ally" else (-80 if GameSession.relations[key] == "enemy" else 0)
		opinions[ids[0] + ">" + ids[1]] = value
		opinions[ids[1] + ">" + ids[0]] = value

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
	if action not in ["envoy", "recall"] and int(main.game_clock.elapsed_days) - int(last_actions.get(key, -ACTION_DELAY_DAYS)) < ACTION_DELAY_DAYS:
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
		"peace":
			_set_relation(actor, target, "neutral")
			truces[GameSession.pair(actor, target)] = int(main.game_clock.elapsed_days) + TRUCE_MONTHS * 30
			last_message = "停戦しました。360日間は宣戦できません"
	if action not in ["envoy", "recall"]: last_actions[actor + ">" + target] = int(main.game_clock.elapsed_days)
	changed.emit()
	return OK

func _set_relation(a: String, b: String, status: String) -> void:
	GameSession.relations[GameSession.pair(a, b)] = status
	if is_instance_valid(main.territory_borders): main.territory_borders.refresh_relations()

func on_hostile_attack(actor: String, target: String) -> void:
	if GameSession.relation(actor, target) != "neutral" or truce_remaining(actor, target) > 0: return
	_set_relation(actor, target, "enemy")
	change_opinion(target, actor, -50)
	main.house_prestige.on_unjustified_war_started(actor)
	changed.emit()

func on_day_advanced(_year: int, _month: int, day: int) -> void:
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
	return {"opinions":opinions.duplicate(true), "envoys":envoys.duplicate(true), "truces":truces.duplicate(true), "last_actions":last_actions.duplicate(true)}

func restore_state(state: Dictionary) -> void:
	opinions = state.opinions.duplicate(true)
	envoys = state.envoys.duplicate(true)
	truces = state.truces.duplicate(true)
	last_actions = state.last_actions.duplicate(true)
	changed.emit()
