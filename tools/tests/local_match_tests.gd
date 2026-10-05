extends RefCounted
## MatchConfig の掛け声の区間・HandBot・LocalMatch(GameDesign 5章)。

const STEP := 1.0 / 60.0
const SEED := 42
## 1試合にかかる時間の上限(あいこが続いても終わることを確かめる)。
const MAX_MATCH_SECONDS := 600.0
const BOT_SETTLE_SECONDS := 3.0

var _hand_config: HandConfig = load("res://data/hand_config.tres")
var _match_config: MatchConfig = load("res://data/match_config.tres")
var _names: FoulNameTable = load("res://data/foul_name_table.tres")


func run(assert_true: Callable) -> void:
	_test_call_segments(assert_true)
	_test_bot_makes_shape(assert_true)
	_test_full_match(assert_true)


func _test_call_segments(assert_true: Callable) -> void:
	var segments := [0.0, 0.99, 1.0, 2.5, 3.0]
	var expected := [0, 0, 1, 2, 3]
	for i in segments.size():
		var actual := _match_config.call_segment_at(segments[i])
		assert_true.call(
			actual == expected[i], "%s秒は区間%d (%d)" % [segments[i], expected[i], actual]
		)
	assert_true.call(
		_match_config.call_words.size() == _match_config.call_segment_seconds.size(),
		"掛け声の文字と区間の数が揃っている"
	)


func _test_bot_makes_shape(assert_true: Callable) -> void:
	var judge := HandShapeJudge.new(_hand_config, _names)
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var hand := HandModel.new(_hand_config)
	hand.randomize_pose(rng)
	var bot := HandBot.new(hand, rng)
	bot.start_round()
	for i in int(BOT_SETTLE_SECONDS / STEP):
		bot.step(STEP)
		hand.step(STEP)
	var shape := judge.shape_of(hand.curls)
	assert_true.call(shape != HandTypes.Shape.FOUL, "ボットは時間があれば形を作れる %s" % [hand.curls])


func _test_full_match(assert_true: Callable) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var game := LocalMatch.new(_hand_config, _match_config, _names, rng)
	var log := {"rounds": 0, "segments": [], "winner": MatchState.NO_WINNER}
	game.round_started.connect(func() -> void: log["rounds"] += 1)
	game.call_segment_changed.connect(func(index: int) -> void: log["segments"].append(index))
	game.match_finished.connect(func(winner: int) -> void: log["winner"] = winner)
	game.start()
	assert_true.call(game.can_operate(), "掛け声の間は操作できる")
	var call_seconds := _match_config.call_total_seconds()
	var elapsed := 0.0
	while elapsed + STEP < call_seconds:
		game.advance(STEP)
		elapsed += STEP
	assert_true.call(game.phase == LocalMatch.Phase.CALLING, "掛け声が終わるまでは判定しない")
	game.advance(STEP)
	elapsed += STEP
	assert_true.call(game.phase == LocalMatch.Phase.RESULT, "掛け声の終わりで判定する")
	while game.phase != LocalMatch.Phase.OVER and elapsed < MAX_MATCH_SECONDS:
		game.advance(STEP)
		elapsed += STEP
	assert_true.call(game.phase == LocalMatch.Phase.OVER, "1試合が終わる")
	assert_true.call(log["winner"] == game.state.winner(), "勝者が通知される")
	assert_true.call(game.state.wins.max() == _match_config.wins_to_finish, "3勝で終わる")
	assert_true.call(not game.can_operate(), "試合終了後は操作できない")
	assert_true.call(log["segments"].slice(0, 3) == [0, 1, 2], "じゃん・けん・ぽんの順に進む")
	var rounds_played: int = log["rounds"]
	game.start()
	assert_true.call(
		game.state.wins == [0, 0] and log["rounds"] == rounds_played + 1, "もう一度で0勝から始まる"
	)
