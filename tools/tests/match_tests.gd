extends RefCounted
## RoundRules と MatchState(GameDesign 2.3節・5章)。

const ROCK := "●●●●●"
const SCISSORS := "●○○●●"
const PAPER := "○○○○○"
const PISTOL := "○○●●●"
const CENSOR := "●●○●●"
const POINTING := "●○●●●"
const THUMBS_UP := "○●●●●"
const PINKY_PROMISE := "●●●●○"
const ROCK_SIGN := "●○●●○"
const THREE := "●○○○●"
const ALOHA := "○●●●○"
## 中途半端な指を「半」で書く(反則)。
const FOUL := "●●●●半"
const HALF_MARK := "半"
const WIN := HandTypes.Outcome.WIN
const LOSE := HandTypes.Outcome.LOSE
const DRAW := HandTypes.Outcome.DRAW

var _match_config: MatchConfig = load("res://data/match_config.tres")
var _judge := HandShapeJudge.new(
	load("res://data/hand_name_table.tres"), load("res://data/hand_rule_table.tres")
)


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
		[PAPER, PAPER, DRAW],
		[ROCK, PISTOL, WIN],
		[PAPER, PISTOL, DRAW],
		[POINTING, ROCK, WIN],
		[POINTING, PAPER, DRAW],
		[ROCK_SIGN, PISTOL, WIN],
		[ROCK_SIGN, ROCK, LOSE],
		[THREE, SCISSORS, WIN],
		[THUMBS_UP, SCISSORS, WIN],
		[THUMBS_UP, PAPER, LOSE],
		[PINKY_PROMISE, ALOHA, WIN],
		[PISTOL, CENSOR, DRAW],
		[FOUL, ROCK, LOSE],
		[PISTOL, FOUL, WIN],
		[FOUL, FOUL, DRAW],
	]
	for case in cases:
		var outcome := RoundRules.outcome(_states_of(case[0]), _states_of(case[1]), _judge)
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


func _states_of(key: String) -> Array:
	var states := HandNameTable.states_of(key)
	for i in key.length():
		if key[i] == HALF_MARK:
			states[i] = HandTypes.FingerState.HALF
	return states
