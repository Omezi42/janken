extends RefCounted
## 名前付きの手の効果: HandEffectTable・ActiveEffects・LocalMatch での発動と反映(GameDesign 2.5節)。

const SEED := 7
const PISTOL := "○○●●●"
const INDEX_OVERSLEEP := "○●○○○"
const STRONG_CENSOR := "○●○●●"
const EFFECT_COUNT := 8

var _hand_config: HandConfig = load("res://data/hand_config.tres")
var _match_config: MatchConfig = load("res://data/match_config.tres")
var _names: HandNameTable = load("res://data/hand_name_table.tres")
var _effects: HandEffectTable = load("res://data/hand_effect_table.tres")


func run(assert_true: Callable) -> void:
	_test_table(assert_true)
	_test_censor_rounds(assert_true)
	_test_oversleep_target(assert_true)
	_test_match_applies_effects(assert_true)


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
	var game := LocalMatch.new(_hand_config, _match_config, _names, _effects)
	var results := []
	game.round_judged.connect(func(result: LocalMatch.RoundResult) -> void: results.append(result))
	game.start(SEED)
	_play_round(game, [_curls_of(PISTOL), _curls_of(INDEX_OVERSLEEP)])
	if results.is_empty():
		assert_true.call(false, "1ラウンド目が判定されない")
		return
	var first: LocalMatch.RoundResult = results[0]
	assert_true.call(
		first.my_shape == HandTypes.Shape.NAMED and first.outcome == HandTypes.Outcome.DRAW,
		"名前付きの手どうしはあいこ"
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
	assert_true.call(HandModel.MAX_CURL in game.hands[1].curls, "撃たれた指は曲がりきりから始まる")
	var scales := game.hands[0].drag_scales
	assert_true.call(
		(
			scales[HandTypes.Finger.INDEX] == _effects.oversleep_drag_scale
			and scales[HandTypes.Finger.MIDDLE] == 1.0
		),
		"寝坊した指だけ動きが遅い %s" % [scales]
	)
	_play_round(game, [_curls_of("●●●●●"), _curls_of("●●●●●")])
	while game.phase != LocalMatch.Phase.CALLING:
		game.tick()
	assert_true.call(game.hands[0].drag_scales[HandTypes.Finger.INDEX] == 1.0, "効果は1ラウンドで切れる")


## 掛け声の終わりまで、両者の目標を goals へ寄せ続ける。
func _play_round(game: LocalMatch, goals: Array) -> void:
	while game.phase == LocalMatch.Phase.CALLING:
		for player in LocalMatch.PLAYER_COUNT:
			var hand := game.hands[player]
			for finger in HandTypes.Finger.size():
				var gap: float = goals[player][finger] - hand.targets[finger]
				game.drag(player, finger as HandTypes.Finger, gap)
		game.tick()


func _curls_of(key: String) -> PackedFloat64Array:
	var curls := PackedFloat64Array()
	for mark in key:
		curls.append(
			HandModel.MAX_CURL if mark == HandNameTable.CURLED_MARK else HandModel.MIN_CURL
		)
	return curls


func _states_of(key: String) -> Array:
	var states := []
	for mark in key:
		var curled := mark == HandNameTable.CURLED_MARK
		states.append(HandTypes.FingerState.CURLED if curled else HandTypes.FingerState.EXTENDED)
	return states
