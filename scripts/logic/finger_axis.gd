class_name FingerAxis
extends RefCounted
## 5本の指の1つの量(曲がり具合か向き)の値・目標・速度(GameDesign 6.2節)。並びは親指から小指の順。
## 掴んだ指は move() で値ごと直接動き、隣の指は目標だけが連動で動いて step() のばねで追いかける。

var values := PackedFloat64Array()
var targets := PackedFloat64Array()
var min_value: float
var max_value: float
var _velocities := PackedFloat64Array()
## 隣接する指の連動の強さ。[親−人, 人−中, 中−薬, 薬−小] の順。負なら逆向きに動く。
var _linkage: Array[float]
var _stiffness: float
var _damping: float


func _init(
	lowest: float, highest: float, linkage: Array[float], stiffness: float, damping: float
) -> void:
	min_value = lowest
	max_value = highest
	_linkage = linkage
	_stiffness = stiffness
	_damping = damping
	var finger_count := HandTypes.Finger.size()
	values.resize(finger_count)
	targets.resize(finger_count)
	_velocities.resize(finger_count)


func set_all(pose: PackedFloat64Array) -> void:
	values = pose.duplicate()
	targets = pose.duplicate()
	_velocities.fill(0.0)


func set_one(finger: int, value: float) -> void:
	values[finger] = value
	targets[finger] = value
	_velocities[finger] = 0.0


## 掴んだ指を amount 動かし、隣の指の目標へ連動を掛け算で伝える。scales は指ごとの動きの倍率。
func move(finger: int, amount: float, scales: PackedFloat64Array) -> void:
	var before := values[finger]
	values[finger] = clampf(before + amount * scales[finger], min_value, max_value)
	targets[finger] = values[finger]
	_velocities[finger] = 0.0
	var applied := values[finger] - before
	var factor := 1.0
	for i in range(finger - 1, -1, -1):
		factor *= _linkage[i]
		_move_target(i, applied * factor, scales)
	factor = 1.0
	for i in range(finger + 1, values.size()):
		factor *= _linkage[i - 1]
		_move_target(i, applied * factor, scales)


func step(delta: float) -> void:
	for i in values.size():
		var pull := _stiffness * (targets[i] - values[i])
		_velocities[i] += (pull - _damping * _velocities[i]) * delta
		values[i] += _velocities[i] * delta
		if values[i] < min_value or values[i] > max_value:
			values[i] = clampf(values[i], min_value, max_value)
			_velocities[i] = 0.0


func _move_target(finger: int, amount: float, scales: PackedFloat64Array) -> void:
	targets[finger] = clampf(targets[finger] + amount * scales[finger], min_value, max_value)
