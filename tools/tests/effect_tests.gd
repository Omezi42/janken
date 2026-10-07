extends RefCounted
## 名前付きの手の効果: HandEffectTable・ActiveEffects・LocalMatch での発動と反映(GameDesign 2.5節)。

const SEED := 7
const PISTOL := "○○●●●"
const INDEX_OVERSLEEP := "○●○○○"
const STRONG_CENSOR := "○●○●●"
const EFFECT_COUNT := 8
const HALF_CURL := 50

var _match_config: MatchConfig = load("res://data/match_config.tres")
var _names: HandNameTable = load("res://data/hand_name_table.tres")
var _effects: HandEffectTable = load("res://data/hand_effect_table.tres")
var _rules: HandRuleTable = load("res://data/hand_rule_table.tres")


func run(assert_true: Callable) -> void:
	_test_table(assert_true)
	_test_censor_rounds(assert_true)
	_test_oversleep_target(assert_true)
	_test_match_applies_effects(assert_true)
	_test_foul_has_no_effect(assert_true)


func _test_table(assert_true: Callable) -> void:
	assert_true.call(_effects.effects.size() == EFFECT_COUNT, "効果を持つ手は8種類")
	for key in _effects.effects:
		var name: String = _names.names.get(key, "")
		assert_true.call(
			name != "" and key.contains(HandNameTable.CURLED_MARK), "効果の手は名前付き: " + key
		)
	assert_true.call(_effects.effect_of(_states_of("●●●●●")) == null, "グーに効果は無い")


func _test_censor_rounds(assert_true: Callable) -> void:
	var active := ActiveEffects.new()
	var states := _states_of(STRONG_CENSOR)
	active.trigger(0, _effects.effect_of(states), states)
	assert_true.call(active.is_censored(0) and not active.is_censored(1), "自主規制は出した側の手を隠す")
	active.end_round()
	active.trigger(0, _effects.effect_of(_states_of("●●○●●")), states)
	assert_true.call(active.is_censored(0), "残りラウンド数は長い方に揃える")
	active.end_round()
	assert_true.call(not active.is_censored(0), "足さずに揃えるので2ラウンドで切れる")


func _test_oversleep_target(assert_true: Callable) -> void:
	var active := ActiveEffects.new()
	var states := _states_of(INDEX_OVERSLEEP)
	active.trigger(1, _effects.effect_of(states), states)
	assert_true.call(active.is_oversleeping(0, HandTypes.Finger.INDEX), "寝坊は相手の同じ指に掛かる")
	assert_true.call(not active.is_oversleeping(1, HandTypes.Finger.INDEX), "出した側には掛からない")
	assert_true.call(not active.is_oversleeping(0, HandTypes.Finger.MIDDLE), "ほかの指には掛からない")


func _test_match_applies_effects(assert_true: Callable) -> void:
	var game := LocalMatch.new(_match_config, _names, _effects, _rules)
	var results := []
	game.round_judged.connect(func(result: LocalMatch.RoundResult) -> void: results.append(result))
	game.start(SEED)
	_play_round(game, [_states_of(PISTOL), _states_of(INDEX_OVERSLEEP)])
	if results.is_empty():
		assert_true.call(false, "1ラウンド目が判定されない")
		return
	var first: LocalMatch.RoundResult = results[0]
	assert_true.call(
		first.my_shape == HandTypes.Shape.NAMED and first.outcome == HandTypes.Outcome.DRAW,
		"勝ち条件の無い手どうしはあいこ"
	)
	assert_true.call(
		(
			first.my_effect.kind == HandTypes.EffectKind.PISTOL
			and first.their_effect.kind == HandTypes.EffectKind.OVERSLEEP
		),
		"両者の効果が同時に発動する"
	)
	while game.phase != LocalMatch.Phase.CALLING:
		game.tick()
	assert_true.call(HandModel.CURL_MAX in game.hands[1].curls, "撃たれた指は曲がりきりから始まる")
	var delays := game.hands[0].delay_ticks
	var delay := roundi(_effects.oversleep_delay_seconds * LocalMatch.TICKS_PER_SECOND)
	assert_true.call(
		delays[HandTypes.Finger.INDEX] == delay and delays[HandTypes.Finger.MIDDLE] == 0,
		"寝坊した指だけ動きが遅れる %s" % [delays]
	)
	_play_round(game, [_states_of("●●●●●"), _states_of("●●●●●")])
	while game.phase != LocalMatch.Phase.CALLING:
		game.tick()
	assert_true.call(game.hands[0].delay_ticks[HandTypes.Finger.INDEX] == 0, "効果は1ラウンドで切れる")


func _test_foul_has_no_effect(assert_true: Callable) -> void:
	var game := LocalMatch.new(_match_config, _names, _effects, _rules)
	var results := []
	game.round_judged.connect(func(result: LocalMatch.RoundResult) -> void: results.append(result))
	game.start(SEED)
	_play_round(game, [_states_of(PISTOL), _states_of(PISTOL)])
	if results.is_empty():
		assert_true.call(false, "反則の確認で1ラウンド目が判定されない")
		return
	assert_true.call(results[0].my_effect != null, "反則でないピストルは効果が発動する")
	while game.phase != LocalMatch.Phase.CALLING:
		game.tick()
	while game.phase == LocalMatch.Phase.CALLING:
		var pose := HandModel.pose_of(_states_of(PISTOL))
		pose[HandTypes.Finger.PINKY] = HALF_CURL
		for finger in HandTypes.Finger.size():
			if game.hands[0].settled_curl(finger as HandTypes.Finger) != pose[finger]:
				game.move(0, finger as HandTypes.Finger, pose[finger])
		game.tick()
	var foul: LocalMatch.RoundResult = results[1]
	assert_true.call(
		foul.my_shape == HandTypes.Shape.FOUL and foul.my_effect == null, "反則では効果が発動しない"
	)
	assert_true.call(foul.my_name == "ゆるいピストル", "反則の名前 %s" % foul.my_name)


## 掛け声の終わりまで、両者の手を goals へ動かし続ける。
func _play_round(game: LocalMatch, goals: Array) -> void:
	while game.phase == LocalMatch.Phase.CALLING:
		for player in LocalMatch.PLAYER_COUNT:
			var hand := game.hands[player]
			var pose := HandModel.pose_of(goals[player])
			for finger in HandTypes.Finger.size():
				if hand.settled_curl(finger as HandTypes.Finger) != pose[finger]:
					game.move(player, finger as HandTypes.Finger, pose[finger])
		game.tick()


func _states_of(key: String) -> Array:
	return HandNameTable.states_of(key)
