class_name HandModel
extends RefCounted
## 1つの手の状態(GameDesign 6章)。曲がり具合と向きを FingerAxis で1つずつ持つ。並びは親指から小指の順。
## 向きは自然な方向からの角度(度。正で時計回り)。手首は動かない。

const MIN_CURL := 0.0
const MAX_CURL := 1.0

## 指ごとに動きへ掛ける倍率(寝坊。GameDesign 2.5節)。曲がり具合と向きの両方に掛ける。
var drag_scales := PackedFloat64Array()
var curl_axis: FingerAxis
var swing_axis: FingerAxis
var curls: PackedFloat64Array:
	get:
		return curl_axis.values
var targets: PackedFloat64Array:
	get:
		return curl_axis.targets
var swings: PackedFloat64Array:
	get:
		return swing_axis.values


func _init(config: HandConfig) -> void:
	curl_axis = FingerAxis.new(
		MIN_CURL, MAX_CURL, config.linkage_strengths, config.spring_stiffness, config.spring_damping
	)
	swing_axis = FingerAxis.new(
		-config.swing_range_degrees,
		config.swing_range_degrees,
		config.swing_linkage_strengths,
		config.swing_spring_stiffness,
		config.swing_spring_damping
	)
	drag_scales.resize(HandTypes.Finger.size())
	drag_scales.fill(1.0)


func axis(kind: HandTypes.Axis) -> FingerAxis:
	return curl_axis if kind == HandTypes.Axis.CURL else swing_axis


## ラウンド開始時の初期配置(GameDesign 6.3節)。
func randomize_pose(rng: RandomNumberGenerator) -> void:
	var curl_pose := PackedFloat64Array()
	var swing_pose := PackedFloat64Array()
	for i in HandTypes.Finger.size():
		curl_pose.append(rng.randf_range(MIN_CURL, MAX_CURL))
		swing_pose.append(rng.randf_range(swing_axis.min_value, swing_axis.max_value))
	set_pose(curl_pose, swing_pose)


## swing_pose を省くと向きはすべて自然な方向になる。
func set_pose(curl_pose: PackedFloat64Array, swing_pose := PackedFloat64Array()) -> void:
	if swing_pose.is_empty():
		swing_pose.resize(HandTypes.Finger.size())
	curl_axis.set_all(curl_pose)
	swing_axis.set_all(swing_pose)


## 1本だけ曲がり具合を置き換える(ピストル。GameDesign 2.5節)。
func set_curl(finger: HandTypes.Finger, curl: float) -> void:
	curl_axis.set_one(finger, curl)


## amount は曲がり具合の変化量(正で曲がる)。
func drag(finger: HandTypes.Finger, amount: float) -> void:
	curl_axis.move(finger, amount, drag_scales)


## degrees は向きの変化量(正で時計回り)。
func swing(finger: HandTypes.Finger, degrees: float) -> void:
	swing_axis.move(finger, degrees, drag_scales)


func move(kind: HandTypes.Axis, finger: HandTypes.Finger, amount: float) -> void:
	axis(kind).move(finger, amount, drag_scales)


func step(delta: float) -> void:
	curl_axis.step(delta)
	swing_axis.step(delta)
