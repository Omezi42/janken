extends RefCounted
## HandShapeJudge と名前の表(GameDesign 2.2節・2.4節)。

const _FINGER_COUNT := 5
const _PATTERN_COUNT := 32

var _names: HandNameTable = load("res://data/hand_name_table.tres")
var _judge := HandShapeJudge.new(_names)


func run(assert_true: Callable) -> void:
	assert_true.call(_names.names.size() == _PATTERN_COUNT, "名前の表は32通り")
	var legal := {
		"●●●●●": HandTypes.Shape.ROCK,
		"●○○●●": HandTypes.Shape.SCISSORS,
		"○○○○○": HandTypes.Shape.PAPER,
	}
	for bits in _PATTERN_COUNT:
		var states := []
		for finger in _FINGER_COUNT:
			var curled := bits & (1 << finger)
			states.append(
				HandTypes.FingerState.CURLED if curled else HandTypes.FingerState.EXTENDED
			)
		var key := HandNameTable.key_of(states)
		var shape := HandShapeJudge.shape_of(states)
		var name := _judge.hand_name(states)
		var expected_shape: HandTypes.Shape = legal.get(key, HandTypes.Shape.NAMED)
		assert_true.call(
			shape == expected_shape and name == _names.names.get(key, "<none>"),
			"形と名前: %s → %s" % [key, name]
		)
