class_name HandView
extends Control
## HandModel を仮の図形で描き、interactive なら指のドラッグを HandModel へ渡す(Architecture 6章)。
## 手首の回転 0° で指先が画面の上を向く。寸法はすべて手のひらの半径に対する比。

## 手のひらの半径(このノードの短辺に対する比)。
const PALM_RADIUS_RATIO := 0.16
## 指の付け根の位置(手のひらの中心からの距離)。
const FINGER_BASE_RATIO := 0.6
## 伸びきった指の長さ。親指から小指の順。
const FINGER_LENGTH_RATIOS := [1.1, 1.5, 1.65, 1.5, 1.2]
const FINGER_WIDTH_RATIO := 0.34
## 指の向き(度。上を 0 として時計回り)。親指から小指の順。
const FINGER_ANGLES := [-75.0, -27.0, -9.0, 9.0, 27.0]
## 曲がりきった指の見える長さ(伸びきりに対する比)。
const CURLED_LENGTH_RATIO := 0.25
## 指を掴める範囲(指の太さに対する比)。
const GRAB_WIDTH_RATIO := 1.2

const SKIN_COLOR := Color("f2c9a0")
const CURLED_SKIN_COLOR := Color("b9845a")
const PALM_COLOR := Color("e8b98c")
const NAIL_COLOR := Color("fbe8dc")

const NO_FINGER := -1

var interactive := false
var _model: HandModel
var _dragging := NO_FINGER


func bind(model: HandModel) -> void:
	_model = model
	queue_redraw()


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if _model == null:
		return
	var radius := _palm_radius()
	draw_set_transform(size / 2.0, deg_to_rad(_model.wrist_rotation_degrees))
	for i in _model.curls.size():
		var curl := _model.curls[i]
		var direction := _finger_direction(i)
		var base := direction * radius * FINGER_BASE_RATIO
		var visible_length := _finger_length(i) * lerpf(1.0, CURLED_LENGTH_RATIO, curl)
		var tip := base + direction * visible_length
		var width := radius * FINGER_WIDTH_RATIO
		var color := SKIN_COLOR.lerp(CURLED_SKIN_COLOR, curl)
		draw_line(base, tip, color, width)
		draw_circle(tip, width / 2.0, color)
		draw_circle(tip, width / 2.0 * (1.0 - curl), NAIL_COLOR)
	draw_circle(Vector2.ZERO, radius, PALM_COLOR)


func _gui_input(event: InputEvent) -> void:
	if not interactive or _model == null:
		_dragging = NO_FINGER
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = _finger_at(event.position) if event.pressed else NO_FINGER
		accept_event()
	elif event is InputEventMouseMotion and _dragging != NO_FINGER:
		var local_motion: Vector2 = event.relative.rotated(-_wrist_radians())
		var toward_tip := local_motion.dot(_finger_direction(_dragging))
		_model.drag(_dragging as HandTypes.Finger, -toward_tip / _finger_length(_dragging))
		accept_event()


func _finger_at(position: Vector2) -> int:
	var radius := _palm_radius()
	var local := (position - size / 2.0).rotated(-_wrist_radians())
	var nearest := NO_FINGER
	var nearest_distance := radius * FINGER_WIDTH_RATIO * GRAB_WIDTH_RATIO
	for i in _model.curls.size():
		var base := _finger_direction(i) * radius * FINGER_BASE_RATIO
		var tip := base + _finger_direction(i) * _finger_length(i)
		var distance := local.distance_to(Geometry2D.get_closest_point_to_segment(local, base, tip))
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = i
	return nearest


func _palm_radius() -> float:
	return minf(size.x, size.y) * PALM_RADIUS_RATIO


func _finger_length(finger: int) -> float:
	return _palm_radius() * FINGER_LENGTH_RATIOS[finger]


func _finger_direction(finger: int) -> Vector2:
	return Vector2.UP.rotated(deg_to_rad(FINGER_ANGLES[finger]))


func _wrist_radians() -> float:
	return deg_to_rad(_model.wrist_rotation_degrees)
