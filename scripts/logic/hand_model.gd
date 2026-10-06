class_name HandModel
extends RefCounted
## 1つの手の状態(GameDesign 2.1節・6章)。5本の指それぞれが伸びか曲がり。並びは親指から小指の順。
## flip() で指を反転する。寝坊した指(delay_ticks が正)は予約だけして、step() でその tick 数が経ってから反転する。

const EXTENDED := HandTypes.FingerState.EXTENDED
const CURLED := HandTypes.FingerState.CURLED

## HandTypes.FingerState の並び。
var states := []
## 指ごとの反転の遅れ(tick。寝坊。GameDesign 2.5節)。
var delay_ticks := PackedInt32Array()
## 遅れて反転する予約(届いた順)。
var _scheduled_fingers := PackedInt32Array()
var _scheduled_ticks := PackedInt32Array()


func _init() -> void:
	var finger_count := HandTypes.Finger.size()
	states.resize(finger_count)
	states.fill(EXTENDED)
	delay_ticks.resize(finger_count)


## ラウンド開始時の初期配置(GameDesign 6.3節)。各指を半々の確率で伸び・曲がりにする。
func randomize_pose(rng: RandomNumberGenerator) -> void:
	var pose := []
	for i in HandTypes.Finger.size():
		pose.append(CURLED if rng.randi_range(0, 1) == 1 else EXTENDED)
	set_pose(pose)


func set_pose(pose: Array) -> void:
	states = pose.duplicate()
	_scheduled_fingers.clear()
	_scheduled_ticks.clear()


## 1本だけ状態を置き換える(ピストル。GameDesign 2.5節)。
func set_state(finger: HandTypes.Finger, state: HandTypes.FingerState) -> void:
	states[finger] = state


func is_curled(finger: HandTypes.Finger) -> bool:
	return states[finger] == CURLED


func flip(finger: HandTypes.Finger) -> void:
	if delay_ticks[finger] <= 0:
		_toggle(finger)
		return
	_scheduled_fingers.append(finger)
	_scheduled_ticks.append(delay_ticks[finger])


## 1tick 進め、遅れが経った予約を反転する。
func step() -> void:
	var i := 0
	while i < _scheduled_ticks.size():
		_scheduled_ticks[i] -= 1
		if _scheduled_ticks[i] <= 0:
			_toggle(_scheduled_fingers[i])
			_scheduled_fingers.remove_at(i)
			_scheduled_ticks.remove_at(i)
		else:
			i += 1


## 予約がすべて済んだ後の状態。
func settled_state(finger: HandTypes.Finger) -> HandTypes.FingerState:
	var pending := _scheduled_fingers.count(finger)
	if pending % 2 == 0:
		return states[finger]
	return _flipped(states[finger])


func _toggle(finger: int) -> void:
	states[finger] = _flipped(states[finger])


static func _flipped(state: HandTypes.FingerState) -> HandTypes.FingerState:
	return EXTENDED if state == CURLED else CURLED
