extends RefCounted
## HandView の引っぱる操作(GameDesign 6.1節)。押した位置に一番近い見えている指をつかみ、
## 反転の距離を越えたら反転・戻ったら元に戻す。

const E := HandTypes.FingerState.EXTENDED
const C := HandTypes.FingerState.CURLED
const VIEW_SIZE := Vector2(720.0, 563.0)

var _view: HandView
var _model := HandModel.new()
var _flipped := []
## 押した位置(手のローカル座標のピクセル)。
var _grab_at := Vector2.ZERO


func run(assert_true: Callable) -> void:
	_view = HandView.new()
	_view.size = VIEW_SIZE
	_view.bind(_model)
	_view.finger_flipped.connect(func(finger: HandTypes.Finger) -> void: _flipped.append(finger))
	_test_pull(assert_true)
	_test_push_up(assert_true)
	_test_one_finger_per_grab(assert_true)
	_test_grab_curled_fingers(assert_true)
	_view.free()


func _test_pull(assert_true: Callable) -> void:
	_pose([E, E, E, E, E])
	_press(HandTypes.Finger.MIDDLE)
	_drag(Vector2(0.0, HandView.FLIP_DISTANCE * 0.9))
	assert_true.call(_flipped.is_empty(), "反転の距離に届かなければ反転しない")
	_drag(Vector2(0.0, HandView.FLIP_DISTANCE * 1.1))
	assert_true.call(_flipped == [HandTypes.Finger.MIDDLE], "伸びた指を下へ引いて距離を越えたら反転 %s" % [_flipped])
	_drag(Vector2(0.0, HandView.FLIP_DISTANCE * 0.5))
	assert_true.call(_flipped.size() == 2, "距離の内へ戻したら元に戻す")
	_release()


func _test_push_up(assert_true: Callable) -> void:
	_pose([C, C, C, C, C])
	_press(HandTypes.Finger.INDEX)
	_drag(Vector2(0.0, HandView.FLIP_DISTANCE * 2.0))
	assert_true.call(_flipped.is_empty(), "曲がった指を下へ引いても反転しない")
	_drag(Vector2(0.0, -HandView.FLIP_DISTANCE * 1.1))
	assert_true.call(_flipped == [HandTypes.Finger.INDEX], "曲がった指は上へ押し上げて反転")
	_release()


func _test_one_finger_per_grab(assert_true: Callable) -> void:
	_pose([E, E, E, E, E])
	_press(HandTypes.Finger.INDEX)
	_drag(Vector2(VIEW_SIZE.x / 2.0, HandView.FLIP_DISTANCE * 1.1))
	assert_true.call(_flipped == [HandTypes.Finger.INDEX], "横へ動いてもつかんだ指だけ反転 %s" % [_flipped])
	_release()


func _test_grab_curled_fingers(assert_true: Callable) -> void:
	for pose in [[C, C, C, C, C], [C, E, E, E, C], [E, C, C, C, E]]:
		for finger in HandTypes.Finger.size():
			_pose(pose)
			_press(finger)
			_drag(Vector2(0.0, HandView.FLIP_DISTANCE * (-1.1 if pose[finger] == C else 1.1)))
			assert_true.call(
				_flipped == [finger], "見えている指を押せばその指をつかむ %s 指%d → %s" % [pose, finger, _flipped]
			)
			_release()


func _pose(pose: Array) -> void:
	_model.set_pose(pose)
	_view.reset_pose()
	_flipped.clear()


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
