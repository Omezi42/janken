extends RefCounted
## MatchConfig の掛け声の区間・HandBot・LocalMatch(GameDesign 5章)。

const SEED := 42
## 1試合の tick の上限(あいこが続いても終わることを確かめる)。
const MAX_MATCH_TICKS := MatchSession.TICKS_PER_SECOND * 600
## 相手を見て組み替える区間(ぽん)より前。
const BOT_SETTLE_TICKS := roundi(MatchSession.TICKS_PER_SECOND * 2.5)
## 名前を呼ぶ間も手を変え続ける間隔。
const MOVE_INTERVAL_TICKS := 7
const HALF_CURL := 50

var _match_config: MatchConfig = load("res://data/match_config.tres")
var _names: HandNameTable = load("res://data/hand_name_table.tres")
var _effects: HandEffectTable = load("res://data/hand_effect_table.tres")
var _rules: HandRuleTable = load("res://data/hand_rule_table.tres")


func run(assert_true: Callable) -> void:
	_test_call_segments(assert_true)
	_test_bot_makes_shape(assert_true)
	_test_full_match(assert_true)
	_test_move_is_applied_on_tick(assert_true)
	_test_hands_called(assert_true)


func _test_call_segments(assert_true: Callable) -> void:
	var segments := [0.0, 0.99, 1.0, 4.5, 5.0]
	var expected := [0, 0, 1, 4, 5]
	for i in segments.size():
		var actual := _match_config.call_segment_at(segments[i])
		assert_true.call(
			actual == expected[i], "%s秒は区間%d (%d)" % [segments[i], expected[i], actual]
		)
	assert_true.call(
		_match_config.call_words.size() == _match_config.call_segment_seconds.size(),
		"掛け声の文字と区間の数が揃っている"
	)


func _new_match() -> LocalMatch:
	return LocalMatch.new(_match_config, _names, _effects, _rules)


func _test_bot_makes_shape(assert_true: Callable) -> void:
	var game := _new_match()
	var bot := HandBot.new(game, 1, SEED)
	game.start(SEED)
	var hand := game.hands[1]
	for i in BOT_SETTLE_TICKS:
		bot.think()
		game.tick()
	assert_true.call(game.phase == MatchSession.Phase.CALLING, "確かめる間は掛け声の途中")
	var states := game.judge.states_of(hand.curls)
	assert_true.call(
		(
			game.judge.rules.condition_of(states) != null
			and HandShapeJudge.shape_of(states) != HandTypes.Shape.FOUL
		),
		"ボットは時間があれば勝ち条件を持つ手を作れる %s" % [hand.curls]
	)


func _test_full_match(assert_true: Callable) -> void:
	var game := _new_match()
	var bot := HandBot.new(game, 1, SEED)
	var log := {"rounds": 0, "segments": [], "winner": MatchState.NO_WINNER}
	game.round_started.connect(func() -> void: log["rounds"] += 1)
	game.call_segment_changed.connect(func(index: int) -> void: log["segments"].append(index))
	game.match_finished.connect(func(winner: int) -> void: log["winner"] = winner)
	game.start(SEED)
	assert_true.call(game.can_operate(), "掛け声の間は操作できる")
	var call_ticks := roundi(_match_config.call_total_seconds() * MatchSession.TICKS_PER_SECOND)
	for i in call_ticks - 1:
		bot.think()
		game.tick()
	assert_true.call(game.phase == MatchSession.Phase.CALLING, "掛け声が終わるまでは判定しない")
	game.tick()
	assert_true.call(game.phase == MatchSession.Phase.RESULT, "掛け声の終わりで判定する")
	while game.phase != MatchSession.Phase.OVER and game.tick_count < MAX_MATCH_TICKS:
		bot.think()
		game.tick()
	assert_true.call(game.phase == MatchSession.Phase.OVER, "1試合が終わる")
	assert_true.call(log["winner"] == game.state.winner(), "勝者が通知される")
	assert_true.call(game.state.wins.max() == _match_config.wins_to_finish, "3勝で終わる")
	assert_true.call(not game.can_operate(), "試合終了後は操作できない")
	assert_true.call(log["segments"].slice(0, 5) == [0, 1, 2, 3, 4], "さいしょは〜ぽんの順に進む")
	var rounds_played: int = log["rounds"]
	game.start(SEED)
	assert_true.call(
		game.state.wins == [0, 0] and log["rounds"] == rounds_played + 1, "もう一度で0勝から始まる"
	)
	assert_true.call(game.record.size() == 0, "もう一度で記録も新しくなる")


func _test_move_is_applied_on_tick(assert_true: Callable) -> void:
	var game := _new_match()
	game.start(SEED)
	var hand := game.hands[0]
	var before: int = hand.curls[HandTypes.Finger.INDEX]
	game.move(0, HandTypes.Finger.INDEX, HALF_CURL)
	assert_true.call(hand.curls[HandTypes.Finger.INDEX] == before, "move は tick まで適用しない")
	game.tick()
	assert_true.call(hand.curls[HandTypes.Finger.INDEX] == HALF_CURL, "tick の頭で動かす")
	assert_true.call(
		(
			game.record.size() == 1
			and game.record.ticks[0] == 0
			and game.record.slots[0] == LocalMatch.slot_of(0, HandTypes.Finger.INDEX)
			and game.record.curls[0] == HALF_CURL
		),
		"適用した tick で動きを記録する"
	)
	game.move(0, HandTypes.Finger.RING, HandModel.CURL_MAX)
	game.move(0, HandTypes.Finger.RING, 0)
	game.tick()
	assert_true.call(game.record.size() == 3, "同じ指が続いてもすべて記録する")
	assert_true.call(hand.curls[HandTypes.Finger.RING] == 0, "同じ tick では最後の動きが残る")


func _test_hands_called(assert_true: Callable) -> void:
	var game := _new_match()
	var calls := []
	var called_names := []
	game.hands_called.connect(
		func(call: MatchSession.RoundResult) -> void:
			calls.append(call)
			called_names.append(game.judge.hand_name(game.hands[1].curls))
			assert_true.call(
				game.phase == MatchSession.Phase.CALLING and game.state.wins == [0, 0], "呼ぶだけで判定しない"
			)
	)
	game.start(SEED)
	var call_ticks := roundi(_match_config.call_total_seconds() * MatchSession.TICKS_PER_SECOND)
	for i in call_ticks:
		if i % MOVE_INTERVAL_TICKS == 0:
			var curl := HandModel.CURL_MAX - game.hands[1].settled_curl(HandTypes.Finger.INDEX)
			game.move(1, HandTypes.Finger.INDEX, curl)
		game.tick()
	assert_true.call(calls.size() == 1, "手の名前は1ラウンドに1回だけ呼ぶ (%d)" % calls.size())
	if calls.is_empty():
		return
	var call: MatchSession.RoundResult = calls[0]
	assert_true.call(call.their_name == called_names[0], "呼んだ瞬間の手の名前を出す")
