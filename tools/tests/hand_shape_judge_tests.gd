extends RefCounted
## HandShapeJudge と名前の表(GameDesign 2.1節・2.2節・2.4節)。

const _FINGER_COUNT := 5
const _PATTERN_COUNT := 32
const MAX := HandModel.CURL_MAX
const E := HandTypes.FingerState.EXTENDED
const C := HandTypes.FingerState.CURLED
const H := HandTypes.FingerState.HALF

var _names: HandNameTable = load("res://data/hand_name_table.tres")
var _rules: HandRuleTable = load("res://data/hand_rule_table.tres")
var _judge := HandShapeJudge.new(_names, _rules)


func run(assert_true: Callable) -> void:
	_test_patterns(assert_true)
	_test_finger_states(assert_true)
	_test_series(assert_true)
	_test_foul_names(assert_true)


func _test_patterns(assert_true: Callable) -> void:
	assert_true.call(_names.names.size() == _PATTERN_COUNT, "名前の表は32通り")
	var legal := {
		"●●●●●": HandTypes.Shape.ROCK,
		"●○○●●": HandTypes.Shape.SCISSORS,
		"○○○○○": HandTypes.Shape.PAPER,
	}
	for bits in _PATTERN_COUNT:
		var states := []
		for finger in _FINGER_COUNT:
			states.append(C if bits & (1 << finger) else E)
		var key := HandNameTable.key_of(states)
		var shape := HandShapeJudge.shape_of(states)
		var name := _judge.hand_name(HandModel.pose_of(states))
		var expected_shape: HandTypes.Shape = legal.get(key, HandTypes.Shape.NAMED)
		assert_true.call(
			shape == expected_shape and name == _names.names.get(key, "<none>"),
			"形と名前: %s → %s" % [key, name]
		)


func _test_finger_states(assert_true: Callable) -> void:
	# [曲がり具合, 状態]。伸び 0.2 未満・曲がり 0.8 超・それ以外は中途半端。
	var cases := [[0, E], [19, E], [20, H], [50, H], [80, H], [81, C], [MAX, C]]
	for case in cases:
		var state := _judge.state_of(case[0])
		assert_true.call(state == case[1], "曲がり具合 %d → %s" % [case[0], state])
	var foul := _judge.states_of(PackedInt32Array([MAX, MAX, 50, MAX, MAX]))
	assert_true.call(HandShapeJudge.shape_of(foul) == HandTypes.Shape.FOUL, "中途半端が1本でもあれば反則")


func _test_series(assert_true: Callable) -> void:
	# [指の状態, 系統]。伸びた指 0〜1本 グー系・2〜3本 チョキ系・4〜5本 パー系。
	var cases := [
		[[C, C, C, C, C], HandTypes.Series.ROCK],
		[[C, E, C, C, C], HandTypes.Series.ROCK],
		[[E, E, C, C, C], HandTypes.Series.SCISSORS],
		[[C, E, E, E, C], HandTypes.Series.SCISSORS],
		[[E, E, E, E, C], HandTypes.Series.PAPER],
		[[E, E, E, E, E], HandTypes.Series.PAPER],
	]
	for case in cases:
		var series := _judge.series_of(case[0])
		assert_true.call(series == case[1], "系統 %s → %s" % [case[0], series])


func _test_foul_names(assert_true: Callable) -> void:
	# 中途半端な指は 0.5 以上で曲がり、未満で伸びへ寄せて名前を付ける。
	var cases := [
		[[MAX, MAX, MAX, MAX, 60], "ほぼグー"],
		[[0, 0, 60, MAX, MAX], "ゆるいピストル"],
		[[30, 40, 50, 60, 70], "グニャグニャ"],
	]
	for case in cases:
		var name := _judge.hand_name(PackedInt32Array(case[0]))
		assert_true.call(name == case[1], "反則の名前 %s → %s" % [case[0], name])
