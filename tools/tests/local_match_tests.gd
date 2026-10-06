extends RefCounted
## MatchConfig の掛け声の区間・HandBot・LocalMatch(GameDesign 5章)。

const SEED := 42
## 1試合の tick の上限(あいこが続いても終わることを確かめる)。
const MAX_MATCH_TICKS := LocalMatch.TICKS_PER_SECOND * 600
## 相手を見て組み替える区間(ぽん)より前。
const BOT_SETTLE_TICKS := roundi(LocalMatch.TICKS_PER_SECOND * 2.5)
## 名前を呼ぶ間も手を変え続ける間隔。
const FLIP_INTERVAL_TICKS := 7

var _match_config: MatchConfig = load("res://data/match_config.tres")
var _names: HandNameTable = load("res://data/hand_name_table.tres")
var _effects: HandEffectTable = load("res://data/hand_effect_table.tres")


func run(assert_true: Callable) -> void:
	_test_call_segments(assert_true)
	_test_bot_makes_shape(assert_true)
	_test_full_match(assert_true)
	_test_flip_is_applied_on_tick(assert_true)
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
	return LocalMatch.new(_match_config, _names, _effects)


func _test_bot_makes_shape(assert_true: Callable) -> void:
	var game := _new_match()
	var bot := HandBot.new(game, 1, SEED)
	game.start(SEED)
	var hand := game.hands[1]
	for i in BOT_SETTLE_TICKS:
		bot.think()
		game.tick()
	assert_true.call(game.phase == LocalMatch.Phase.CALLING, "確かめる間は掛け声の途中")
	var shape := HandShapeJudge.shape_of(hand.states)
	assert_true.call(shape != HandTypes.Shape.NAMED, "ボットは時間があれば形を作れる %s" % [hand.states])


func _test_full_match(assert_true: Callable) -> void:
	var game := _new_match()
	var bot := HandBot.new(game, 1, SEED)
	var log := {"rounds": 0, "segments": [], "winner": MatchState.NO_WINNER}
	game.round_started.connect(func() -> void: log["rounds"] += 1)
	game.call_segment_changed.connect(func(index: int) -> void: log["segments"].append(index))
	game.match_finished.connect(func(winner: int) -> void: log["winner"] = winner)
	game.start(SEED)
	assert_true.call(game.can_operate(), "掛け声の間は操作できる")
	var call_ticks := roundi(_match_config.call_total_seconds() * LocalMatch.TICKS_PER_SECOND)
	for i in call_ticks - 1:
		bot.think()
		game.tick()
	assert_true.call(game.phase == LocalMatch.Phase.CALLING, "掛け声が終わるまでは判定しない")
	game.tick()
	assert_true.call(game.phase == LocalMatch.Phase.RESULT, "掛け声の終わりで判定する")
	while game.phase != LocalMatch.Phase.OVER and game.tick_count < MAX_MATCH_TICKS:
		bot.think()
		game.tick()
	assert_true.call(game.phase == LocalMatch.Phase.OVER, "1試合が終わる")
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


func _test_flip_is_applied_on_tick(assert_true: Callable) -> void:
	var game := _new_match()
	game.start(SEED)
	var hand := game.hands[0]
	var before: int = hand.states[HandTypes.Finger.INDEX]
	game.flip(0, HandTypes.Finger.INDEX)
	assert_true.call(hand.states[HandTypes.Finger.INDEX] == before, "flip は tick まで適用しない")
	game.tick()
	assert_true.call(hand.states[HandTypes.Finger.INDEX] != before, "tick の頭で反転する")
	assert_true.call(
		(
			game.record.size() == 1
			and game.record.ticks[0] == 0
			and game.record.slots[0] == LocalMatch.slot_of(0, HandTypes.Finger.INDEX)
		),
		"適用した tick で反転を記録する"
	)
	var ring: int = hand.states[HandTypes.Finger.RING]
	game.flip(0, HandTypes.Finger.RING)
	game.flip(0, HandTypes.Finger.RING)
	game.tick()
	assert_true.call(game.record.size() == 3, "同じ指が続いてもすべて記録する")
	assert_true.call(hand.states[HandTypes.Finger.RING] == ring, "同じ tick に2回反転したら元に戻る")


func _test_hands_called(assert_true: Callable) -> void:
	var judge := HandShapeJudge.new(_names)
	var game := _new_match()
	var calls := []
	var called_names := []
	game.hands_called.connect(
		func(call: LocalMatch.RoundResult) -> void:
			calls.append(call)
			called_names.append(judge.hand_name(game.hands[1].states))
			assert_true.call(
				game.phase == LocalMatch.Phase.CALLING and game.state.wins == [0, 0], "呼ぶだけで判定しない"
			)
	)
	game.start(SEED)
	var call_ticks := roundi(_match_config.call_total_seconds() * LocalMatch.TICKS_PER_SECOND)
	for i in call_ticks:
		if i % FLIP_INTERVAL_TICKS == 0:
			game.flip(1, HandTypes.Finger.INDEX)
		game.tick()
	assert_true.call(calls.size() == 1, "手の名前は1ラウンドに1回だけ呼ぶ (%d)" % calls.size())
	if calls.is_empty():
		return
	var call: LocalMatch.RoundResult = calls[0]
	assert_true.call(call.their_name == called_names[0], "呼んだ瞬間の手の名前を出す")
