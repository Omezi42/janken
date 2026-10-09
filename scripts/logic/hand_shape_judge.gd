class_name HandShapeJudge
extends RefCounted
## 曲がり具合 → 指の状態・手の形・系統・名前・勝ち条件の文(GameDesign 2.1〜2.4節)。
## 指の状態は親指から小指の順の HandTypes.FingerState の Array、曲がり具合は HandModel.curls と同じ並び。

const _CURLED := HandTypes.FingerState.CURLED
const _EXTENDED := HandTypes.FingerState.EXTENDED
const _HALF := HandTypes.FingerState.HALF
const _SCISSORS_STATES := [_CURLED, _EXTENDED, _EXTENDED, _CURLED, _CURLED]
## 反則の名前を付けるとき、中途半端な指をこの曲がり具合(0.0〜1.0)以上なら曲がりへ寄せる。
const _FOUL_NAME_SPLIT := 0.5

var rules: HandRuleTable
var _names: HandNameTable


func _init(names: HandNameTable, rule_table: HandRuleTable) -> void:
	_names = names
	rules = rule_table


func state_of(curl: int) -> HandTypes.FingerState:
	var ratio := float(curl) / HandModel.CURL_MAX
	if ratio < rules.extended_below:
		return _EXTENDED
	if ratio > rules.curled_above:
		return _CURLED
	return _HALF


func states_of(curls: PackedInt32Array) -> Array:
	var states := []
	for curl in curls:
		states.append(state_of(curl))
	return states


static func shape_of(states: Array) -> HandTypes.Shape:
	if _HALF in states:
		return HandTypes.Shape.FOUL
	if states.count(_CURLED) == states.size():
		return HandTypes.Shape.ROCK
	if states.count(_EXTENDED) == states.size():
		return HandTypes.Shape.PAPER
	if states == _SCISSORS_STATES:
		return HandTypes.Shape.SCISSORS
	return HandTypes.Shape.NAMED


static func is_original(shape: HandTypes.Shape) -> bool:
	return shape in [HandTypes.Shape.ROCK, HandTypes.Shape.SCISSORS, HandTypes.Shape.PAPER]


## states は反則でない手の指の状態。
func series_of(states: Array) -> HandTypes.Series:
	var extended := states.count(_EXTENDED)
	if extended >= rules.paper_min_extended:
		return HandTypes.Series.PAPER
	if extended >= rules.scissors_min_extended:
		return HandTypes.Series.SCISSORS
	return HandTypes.Series.ROCK


func hand_name(curls: PackedInt32Array) -> String:
	var states := states_of(curls)
	if not _HALF in states:
		return _names.name_of(states)
	if states.count(_HALF) == states.size():
		return _names.all_half_name
	var snapped := []
	for curl in curls:
		var curled := float(curl) / HandModel.CURL_MAX >= _FOUL_NAME_SPLIT
		snapped.append(_CURLED if curled else _EXTENDED)
	var format := _names.foul_named_format
	if is_original(shape_of(snapped)):
		format = _names.foul_original_format
	return format.format({"name": _names.name_of(snapped)})


## states は反則でない手の指の状態。手のそばに出す勝ち条件の文(GameDesign 2.3節・5章)。
func condition_text(states: Array) -> String:
	var condition := rules.condition_of(states)
	return rules.no_condition_text if condition == null else condition.text
