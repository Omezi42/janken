extends RefCounted
## HandShapeJudge と初期値の .tres(GameDesign 2.1節・2.2節・2.4節)。

const _FINGER_COUNT := 5
const _PATTERN_COUNT := 32
const _STRAIGHT := 0.0
const _BENT := 1.0
const _LINKAGE_PAIR_COUNT := 4

var _config: HandConfig = load("res://data/hand_config.tres")
var _names: FoulNameTable = load("res://data/foul_name_table.tres")
var _judge := HandShapeJudge.new(_config, _names)


func run(assert_true: Callable) -> void:
	_test_data(assert_true)
	_test_all_crisp_patterns(assert_true)
	_test_thresholds(assert_true)
	_test_prefixed_names(assert_true)


func _test_data(assert_true: Callable) -> void:
	assert_true.call(_names.names.size() == _PATTERN_COUNT, "反則名の表は32通り")
	assert_true.call(_config.linkage_strengths.size() == _LINKAGE_PAIR_COUNT, "連動の強さは隣接4組分")


func _test_all_crisp_patterns(assert_true: Callable) -> void:
	var legal := {
		"●●●●●": HandTypes.Shape.ROCK,
		"●○○●●": HandTypes.Shape.SCISSORS,
		"○○○○○": HandTypes.Shape.PAPER,
	}
	for bits in _PATTERN_COUNT:
		var curls := PackedFloat64Array()
		for finger in _FINGER_COUNT:
			curls.append(_BENT if bits & (1 << finger) else _STRAIGHT)
		var key := FoulNameTable.key_of(_judge.states_of(curls))
		var shape := _judge.shape_of(curls)
		var name := _judge.foul_name(curls)
		if legal.has(key):
			assert_true.call(shape == legal[key] and name == "", "合法な形: " + key)
		else:
			assert_true.call(
				shape == HandTypes.Shape.FOUL and name == _names.names.get(key, "<none>"),
				"反則の名前: %s → %s" % [key, name]
			)


func _test_thresholds(assert_true: Callable) -> void:
	var states := _judge.states_of(PackedFloat64Array([0.29, 0.3, 0.5, 0.7, 0.71]))
	var expected := [
		HandTypes.FingerState.EXTENDED,
		HandTypes.FingerState.HALF,
		HandTypes.FingerState.HALF,
		HandTypes.FingerState.HALF,
		HandTypes.FingerState.CURLED,
	]
	assert_true.call(states == expected, "しきい値: 0.3未満は伸び、0.7超は曲がり %s" % [states])


func _test_prefixed_names(assert_true: Callable) -> void:
	var cases := [
		[[1.0, 1.0, 1.0, 1.0, 0.6], "ほぼグー"],
		[[0.0, 0.0, 0.0, 0.0, 0.4], "ほぼパー"],
		[[0.8, 0.2, 0.45, 0.9, 1.0], "ほぼチョキ"],
		[[0.0, 0.0, 1.0, 1.0, 0.6], "ゆるいピストル"],
		[[0.0, 0.0, 1.0, 1.0, 0.4], "ゆるいアイラブユー"],
		[[0.5, 0.0, 1.0, 1.0, 1.0], "ゆるい指さし"],
		[[0.49, 1.0, 1.0, 1.0, 1.0], "ゆるいグッド"],
		[[0.5, 0.5, 0.5, 0.5, 0.5], "グニャグニャ"],
		[[0.3, 0.7, 0.4, 0.6, 0.5], "グニャグニャ"],
	]
	for case in cases:
		var name := _judge.foul_name(PackedFloat64Array(case[0]))
		assert_true.call(name == case[1], "%s → %s(期待 %s)" % [case[0], name, case[1]])
	assert_true.call(
		_judge.shape_of(PackedFloat64Array([1.0, 1.0, 1.0, 1.0, 0.6])) == HandTypes.Shape.FOUL,
		"中途半端な指が1本でもあれば反則"
	)
