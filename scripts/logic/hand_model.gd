class_name HandModel
extends RefCounted
## 1つの手の状態(GameDesign 2.1節・6章)。5本の指それぞれの曲がり具合(0 伸びきり 〜 CURL_MAX 曲がりきり)。並びは親指から小指の順。
## 記録・通信・リプレイで値が一致するよう整数で持つ。
## move() で指を動かす。寝坊した指(delay_ticks が正)は予約だけして、step() でその tick 数が経ってから動かす。

const CURL_MAX := 100

var curls := PackedInt32Array()
## 指ごとの動きの遅れ(tick。寝坊。GameDesign 2.5節)。
var delay_ticks := PackedInt32Array()
## 遅れて動かす予約(届いた順)。
var _scheduled_fingers := PackedInt32Array()
var _scheduled_curls := PackedInt32Array()
var _scheduled_ticks := PackedInt32Array()


func _init() -> void:
	var finger_count := HandTypes.Finger.size()
	curls.resize(finger_count)
	delay_ticks.resize(finger_count)


## 伸び・曲がりだけからなる指の状態 → 伸びきり・曲がりきりの曲がり具合。
static func pose_of(states: Array) -> PackedInt32Array:
	var pose := PackedInt32Array()
	for state in states:
		pose.append(CURL_MAX if state == HandTypes.FingerState.CURLED else 0)
	return pose


## ラウンド開始時の初期配置(GameDesign 6.3節)。各指を半々の確率で伸びきり・曲がりきりにする。
func randomize_pose(rng: RandomNumberGenerator) -> void:
	var pose := PackedInt32Array()
	for i in HandTypes.Finger.size():
		pose.append(CURL_MAX if rng.randi_range(0, 1) == 1 else 0)
	set_pose(pose)


func set_pose(pose: PackedInt32Array) -> void:
	curls = pose.duplicate()
	_scheduled_fingers.clear()
	_scheduled_curls.clear()
	_scheduled_ticks.clear()


## 遅れなしで1本だけ置き換える(ピストル。GameDesign 2.5節)。
func set_curl(finger: HandTypes.Finger, curl: int) -> void:
	curls[finger] = clampi(curl, 0, CURL_MAX)


func move(finger: HandTypes.Finger, curl: int) -> void:
	if delay_ticks[finger] <= 0:
		set_curl(finger, curl)
		return
	_scheduled_fingers.append(finger)
	_scheduled_curls.append(curl)
	_scheduled_ticks.append(delay_ticks[finger])


## 1tick 進め、遅れが経った予約を動かす。
func step() -> void:
	var i := 0
	while i < _scheduled_ticks.size():
		_scheduled_ticks[i] -= 1
		if _scheduled_ticks[i] <= 0:
			set_curl(_scheduled_fingers[i] as HandTypes.Finger, _scheduled_curls[i])
			_scheduled_fingers.remove_at(i)
			_scheduled_curls.remove_at(i)
			_scheduled_ticks.remove_at(i)
		else:
			i += 1


## 予約がすべて済んだ後の曲がり具合。
func settled_curl(finger: HandTypes.Finger) -> int:
	for i in range(_scheduled_fingers.size() - 1, -1, -1):
		if _scheduled_fingers[i] == finger:
			return clampi(_scheduled_curls[i], 0, CURL_MAX)
	return curls[finger]
