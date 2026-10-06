extends RefCounted
## RoundRules と MatchState(GameDesign 2.3節・5章)。

const ROCK := HandTypes.Shape.ROCK
const SCISSORS := HandTypes.Shape.SCISSORS
const PAPER := HandTypes.Shape.PAPER
const NAMED := HandTypes.Shape.NAMED
const WIN := HandTypes.Outcome.WIN
const LOSE := HandTypes.Outcome.LOSE
const DRAW := HandTypes.Outcome.DRAW

var _match_config: MatchConfig = load("res://data/match_config.tres")


func run(assert_true: Callable) -> void:
	_test_round_rules(assert_true)
	_test_match_state(assert_true)
	assert_true.call(is_equal_approx(_match_config.call_total_seconds(), 5.0), "掛け声は合計5秒")


func _test_round_rules(assert_true: Callable) -> void:
	# [自分, 相手, 自分から見た結果]
	var cases := [
		[ROCK, SCISSORS, WIN],
		[SCISSORS, PAPER, WIN],
		[PAPER, ROCK, WIN],
		[SCISSORS, ROCK, LOSE],
		[PAPER, SCISSORS, LOSE],
		[ROCK, PAPER, LOSE],
		[ROCK, ROCK, DRAW],
		[SCISSORS, SCISSORS, DRAW],
		[PAPER, PAPER, DRAW],
		[NAMED, ROCK, LOSE],
		[SCISSORS, NAMED, WIN],
		[NAMED, NAMED, DRAW],
	]
	for case in cases:
		var outcome := RoundRules.outcome(case[0], case[1])
		assert_true.call(outcome == case[2], "勝敗 %s vs %s → %s" % [case[0], case[1], outcome])


func _test_match_state(assert_true: Callable) -> void:
	var state := MatchState.new(_match_config)
	for outcome in [WIN, DRAW, LOSE, WIN, DRAW]:
		state.record(outcome)
	assert_true.call(state.wins == [2, 1] and not state.is_over(), "あいこは勝利数を変えない")
	state.record(WIN)
	assert_true.call(state.is_over() and state.winner() == 0, "3勝で試合終了")
	state.record(LOSE)
	assert_true.call(state.wins == [3, 1], "試合終了後の結果は記録しない")
