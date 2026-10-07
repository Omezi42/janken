extends RefCounted
## HandView の引っぱる操作(GameDesign 6.1節)。押した位置に一番近い見えている指をつかみ、
## つかんだときの曲がり具合に上下の移動を足して知らせる。

const E := HandTypes.FingerState.EXTENDED
const C := HandTypes.FingerState.CURLED
const MAX := HandModel.CURL_MAX
const HALF_CURL := 50
const BACK_RATIO := 0.3
const VIEW_SIZE := Vector2(720.0, 563.0)

var _view: HandView
var _model := HandModel.new()
var _judge := HandShapeJudge.new(
	load("res://data/hand_name_table.tres"), load("res://data/hand_rule_table.tres")
)
## 知らせた [指, 曲がり具合] の並び。
var _moves := []
## 押した位置(手のローカル座標のピクセル)。
var _grab_at := Vector2.ZERO


func run(assert_true: Callable) -> void:
	_view = HandView.new()
	_view.size = VIEW_SIZE
	_view.bind(_model, _judge)
	_view.finger_moved.connect(
		func(finger: HandTypes.Finger, curl: int) -> void: _moves.append([finger, curl])
	)
	_test_pull(assert_true)
	_test_push_up(assert_true)
	_test_one_finger_per_grab(assert_true)
	_test_grab_curled_fingers(assert_true)
	_view.free()


func _test_pull(assert_true: Callable) -> void:
	_pose([E, E, E, E, E])
	_press(HandTypes.Finger.MIDDLE)
	_drag(Vector2(0.0, HandView.PULL_DISTANCE * 0.5))
	assert_true.call(_last() == [HandTypes.Finger.MIDDLE, HALF_CURL], "引いた分だけ曲がる %s" % [_moves])
	_drag(Vector2(0.0, HandView.PULL_DISTANCE * 1.5))
	assert_true.call(_last() == [HandTypes.Finger.MIDDLE, MAX], "曲がりきりの先では止まる %s" % [_last()])
	_drag(Vector2(0.0, HandView.PULL_DISTANCE * BACK_RATIO))
	assert_true.call(
		_last() == [HandTypes.Finger.MIDDLE, roundi(MAX * BACK_RATIO)], "戻すと伸びる %s" % [_last()]
	)
	_release()


func _test_push_up(assert_true: Callable) -> void:
	_pose([C, C, C, C, C])
	_press(HandTypes.Finger.INDEX)
	_drag(Vector2(0.0, HandView.PULL_DISTANCE))
	assert_true.call(_moves.is_empty(), "曲がりきった指を下へ引いても変わらない")
	_drag(Vector2(0.0, -HandView.PULL_DISTANCE * 0.5))
	assert_true.call(_last() == [HandTypes.Finger.INDEX, HALF_CURL], "曲がった指は上へ押し上げて伸ばす")
	_release()


func _test_one_finger_per_grab(assert_true: Callable) -> void:
	_pose([E, E, E, E, E])
	_press(HandTypes.Finger.INDEX)
	_drag(Vector2(VIEW_SIZE.x / 2.0, HandView.PULL_DISTANCE))
	var fingers := _moves.map(func(move: Array) -> int: return move[0])
	assert_true.call(
		not fingers.is_empty() and fingers.count(HandTypes.Finger.INDEX) == fingers.size(),
		"横へ動いてもつかんだ指だけ動く %s" % [_moves]
	)
	_release()


func _test_grab_curled_fingers(assert_true: Callable) -> void:
	for pose in [[C, C, C, C, C], [C, E, E, E, C], [E, C, C, C, E]]:
		for finger in HandTypes.Finger.size():
			_pose(pose)
			_press(finger)
			var toward := -0.5 if pose[finger] == C else 0.5
			_drag(Vector2(0.0, HandView.PULL_DISTANCE * toward))
			assert_true.call(
				not _moves.is_empty() and _moves[0][0] == finger,
				"見えている指を押せばその指をつかむ %s 指%d → %s" % [pose, finger, _moves]
			)
			_release()


func _last() -> Array:
	return [] if _moves.is_empty() else _moves.back()


func _pose(pose: Array) -> void:
	_model.set_pose(HandModel.pose_of(pose))
	_view.reset_pose()
	_moves.clear()


## いま見えている指先の位置(手のローカル座標のピクセル)。
func _tip(finger: int) -> Vector2:
	var unit := _view._unit()
	var direction := Vector2.UP.rotated(deg_to_rad(HandView.FINGER_ANGLES[finger]))
	var base: Vector2 = HandView.FINGER_BASES[finger] * unit
	return base + direction * _view._visible_length(finger, unit)


func _press(finger: int) -> void:
	_grab_at = _tip(finger)
	_view._press(HandView.MOUSE_POINTER, _view._rest_transform() * _grab_at, true)


## offset は押した位置からのずれ(ピクセル)。
func _drag(offset: Vector2) -> void:
	_view._drag(HandView.MOUSE_POINTER, _view._rest_transform() * (_grab_at + offset))


func _release() -> void:
	_view._press(HandView.MOUSE_POINTER, Vector2.ZERO, false)
