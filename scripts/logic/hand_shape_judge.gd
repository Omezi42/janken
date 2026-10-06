class_name HandShapeJudge
extends RefCounted
## 5本の指の状態 → 手の形と名前(GameDesign 2.2節・2.4節)。
## 状態は親指から小指の順の HandTypes.FingerState の Array。

const _CURLED := HandTypes.FingerState.CURLED
const _EXTENDED := HandTypes.FingerState.EXTENDED
const _SCISSORS_STATES := [_CURLED, _EXTENDED, _EXTENDED, _CURLED, _CURLED]

var _names: HandNameTable


func _init(names: HandNameTable) -> void:
	_names = names


static func shape_of(states: Array) -> HandTypes.Shape:
	if states.count(_CURLED) == states.size():
		return HandTypes.Shape.ROCK
	if states.count(_EXTENDED) == states.size():
		return HandTypes.Shape.PAPER
	if states == _SCISSORS_STATES:
		return HandTypes.Shape.SCISSORS
	return HandTypes.Shape.NAMED


func hand_name(states: Array) -> String:
	return _names.name_of(states)
