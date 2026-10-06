class_name HandShapeJudge
extends RefCounted
## 5本の曲がり具合 → 手の形と名前(GameDesign 2.2節・2.4節)。
## 曲がり具合は親指から小指の順の PackedFloat64Array。

const _CURLED := HandTypes.FingerState.CURLED
const _EXTENDED := HandTypes.FingerState.EXTENDED
const _HALF := HandTypes.FingerState.HALF
const _SCISSORS_STATES := [_CURLED, _EXTENDED, _EXTENDED, _CURLED, _CURLED]

var _config: HandConfig
var _names: HandNameTable


func _init(config: HandConfig, names: HandNameTable) -> void:
	_config = config
	_names = names


func shape_of(curls: PackedFloat64Array) -> HandTypes.Shape:
	return _shape_of_states(states_of(curls))


## 反則でなければ空文字。
func foul_name(curls: PackedFloat64Array) -> String:
	var states := states_of(curls)
	if _shape_of_states(states) != HandTypes.Shape.FOUL:
		return ""
	if states.count(_HALF) == states.size():
		return _names.all_half_name
	var snapped := _snap_states(curls, states)
	var base_name := _names.name_of(snapped)
	if _shape_of_states(snapped) == HandTypes.Shape.NAMED:
		return _names.loose_prefix + base_name
	return _names.almost_prefix + base_name


## 反則でない手は表の名前(グー・チョキ・パー・名前付きの手)、反則なら反則の名前。
func hand_name(curls: PackedFloat64Array) -> String:
	var states := states_of(curls)
	if _shape_of_states(states) == HandTypes.Shape.FOUL:
		return foul_name(curls)
	return _names.name_of(states)


func states_of(curls: PackedFloat64Array) -> Array:
	var states := []
	for curl in curls:
		states.append(state_of(_config, curl))
	return states


static func state_of(config: HandConfig, curl: float) -> HandTypes.FingerState:
	if curl < config.extended_below:
		return _EXTENDED
	if curl > config.curled_above:
		return _CURLED
	return _HALF


func _snap_states(curls: PackedFloat64Array, states: Array) -> Array:
	var snapped := []
	for i in states.size():
		if states[i] != _HALF:
			snapped.append(states[i])
		elif curls[i] >= _config.name_snap_border:
			snapped.append(_CURLED)
		else:
			snapped.append(_EXTENDED)
	return snapped


static func _shape_of_states(states: Array) -> HandTypes.Shape:
	if _HALF in states:
		return HandTypes.Shape.FOUL
	if states.count(_CURLED) == states.size():
		return HandTypes.Shape.ROCK
	if states.count(_EXTENDED) == states.size():
		return HandTypes.Shape.PAPER
	if states == _SCISSORS_STATES:
		return HandTypes.Shape.SCISSORS
	return HandTypes.Shape.NAMED
