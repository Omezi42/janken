class_name HandModel
extends RefCounted
## 1つの手の状態(GameDesign 6章)。5本の指の曲がり具合・目標・速度。並びは親指から小指の順。
## reach() で指の目標を置くと隣の指の目標へ連動が伝わり、step() で全部の指がばねで目標を追う(触っている指も同じ)。

const MIN_CURL := 0.0
const MAX_CURL := 1.0

## 指ごとの動く速さの倍率(寝坊。GameDesign 2.5節)。ばねの時間に掛ける。
var speed_scales := PackedFloat64Array()
var curls := PackedFloat64Array()
var targets := PackedFloat64Array()
var _velocities := PackedFloat64Array()
## 隣接する指の連動の強さ。[親−人, 人−中, 中−薬, 薬−小] の順。負なら逆向きに動く。
var _linkage: Array[float]
var _stiffness: float
var _damping: float


func _init(config: HandConfig) -> void:
	_linkage = config.linkage_strengths
	_stiffness = config.spring_stiffness
	_damping = config.spring_damping
	var finger_count := HandTypes.Finger.size()
	curls.resize(finger_count)
	targets.resize(finger_count)
	_velocities.resize(finger_count)
	speed_scales.resize(finger_count)
	speed_scales.fill(1.0)


## ラウンド開始時の初期配置(GameDesign 6.3節)。
func randomize_pose(rng: RandomNumberGenerator) -> void:
	var pose := PackedFloat64Array()
	for i in HandTypes.Finger.size():
		pose.append(rng.randf_range(MIN_CURL, MAX_CURL))
	set_pose(pose)


func set_pose(pose: PackedFloat64Array) -> void:
	curls = pose.duplicate()
	targets = pose.duplicate()
	_velocities.fill(0.0)


## 1本だけ曲がり具合を置き換える(ピストル。GameDesign 2.5節)。
func set_curl(finger: HandTypes.Finger, curl: float) -> void:
	curls[finger] = curl
	targets[finger] = curl
	_velocities[finger] = 0.0


## 指の目標を curl にし、変わった分を隣の指の目標へ掛け算で伝える(GameDesign 6.2節)。
func reach(finger: HandTypes.Finger, curl: float) -> void:
	var before := targets[finger]
	targets[finger] = clampf(curl, MIN_CURL, MAX_CURL)
	var change := targets[finger] - before
	var factor := 1.0
	for i in range(finger - 1, -1, -1):
		factor *= _linkage[i]
		_shift_target(i, change * factor)
	factor = 1.0
	for i in range(finger + 1, targets.size()):
		factor *= _linkage[i - 1]
		_shift_target(i, change * factor)


func step(delta: float) -> void:
	for i in curls.size():
		var scaled := delta * speed_scales[i]
		var pull := _stiffness * (targets[i] - curls[i])
		_velocities[i] += (pull - _damping * _velocities[i]) * scaled
		curls[i] += _velocities[i] * scaled
		if curls[i] < MIN_CURL or curls[i] > MAX_CURL:
			curls[i] = clampf(curls[i], MIN_CURL, MAX_CURL)
			_velocities[i] = 0.0


func _shift_target(finger: int, amount: float) -> void:
	targets[finger] = clampf(targets[finger] + amount, MIN_CURL, MAX_CURL)
