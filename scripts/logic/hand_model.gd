class_name HandModel
extends RefCounted
## 1つの手の状態(GameDesign 6章)。ドラッグで目標の曲がり具合を連動込みで動かし、
## step() で各指をばねに従って目標へ近づける。曲がり具合は親指から小指の順。

const MIN_CURL := 0.0
const MAX_CURL := 1.0
const FULL_TURN_DEGREES := 360.0

var curls := PackedFloat64Array()
var targets := PackedFloat64Array()
var wrist_rotation_degrees := 0.0
var _velocities := PackedFloat64Array()
var _config: HandConfig


func _init(config: HandConfig) -> void:
	_config = config
	var finger_count := HandTypes.Finger.size()
	curls.resize(finger_count)
	targets.resize(finger_count)
	_velocities.resize(finger_count)


## ラウンド開始時の初期配置(GameDesign 6.3節)。
func randomize_pose(rng: RandomNumberGenerator) -> void:
	var pose := PackedFloat64Array()
	for i in curls.size():
		pose.append(rng.randf_range(MIN_CURL, MAX_CURL))
	set_pose(pose, rng.randf_range(0.0, FULL_TURN_DEGREES))


func set_pose(pose: PackedFloat64Array, rotation_degrees: float) -> void:
	curls = pose.duplicate()
	targets = pose.duplicate()
	_velocities.fill(0.0)
	wrist_rotation_degrees = rotation_degrees


## amount は曲がり具合の変化量(正で曲がる)。隣の指へ連動の強さを掛けながら伝える。
func drag(finger: HandTypes.Finger, amount: float) -> void:
	var applied := _move_target(finger, amount)
	var factor := 1.0
	for i in range(finger - 1, -1, -1):
		factor *= _config.linkage_strengths[i]
		_move_target(i, applied * factor)
	factor = 1.0
	for i in range(finger + 1, curls.size()):
		factor *= _config.linkage_strengths[i - 1]
		_move_target(i, applied * factor)


func step(delta: float) -> void:
	for i in curls.size():
		var pull := _config.spring_stiffness * (targets[i] - curls[i])
		_velocities[i] += (pull - _config.spring_damping * _velocities[i]) * delta
		curls[i] += _velocities[i] * delta
		if curls[i] < MIN_CURL or curls[i] > MAX_CURL:
			curls[i] = clampf(curls[i], MIN_CURL, MAX_CURL)
			_velocities[i] = 0.0


## 実際に動いた量を返す(端で止まった分は含まない)。
func _move_target(finger: int, amount: float) -> float:
	var before := targets[finger]
	targets[finger] = clampf(before + amount, MIN_CURL, MAX_CURL)
	return targets[finger] - before
