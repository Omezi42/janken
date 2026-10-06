extends RefCounted
## HandView の引っぱる操作(GameDesign 6.1節)。押した帯の指をつかみ、反転の距離を越えたら反転・戻ったら元に戻す。

const E := HandTypes.FingerState.EXTENDED
const C := HandTypes.FingerState.CURLED
const VIEW_SIZE := Vector2(720.0, 563.0)
const GRAB_Y := 0.0

var _view: HandView
var _model := HandModel.new()
var _flipped := []


func run(assert_true: Callable) -> void:
	_view = HandView.new()
	_view.size = VIEW_SIZE
	_view.bind(_model)
	_view.finger_flipped.connect(func(finger: HandTypes.Finger) -> void: _flipped.append(finger))
	_test_pull(assert_true)
	_test_push_up(assert_true)
	_test_one_finger_per_grab(assert_true)
	_view.free()


func _test_pull(assert_true: Callable) -> void:
	_model.set_pose([E, E, E, E, E])
	_flipped.clear()
	_press(_band_center(HandTypes.Finger.MIDDLE), GRAB_Y)
	_drag(_band_center(HandTypes.Finger.MIDDLE), GRAB_Y + HandView.FLIP_DISTANCE * 0.9)
	assert_true.call(_flipped.is_empty(), "反転の距離に届かなければ反転しない")
	_drag(_band_center(HandTypes.Finger.MIDDLE), GRAB_Y + HandView.FLIP_DISTANCE * 1.1)
	assert_true.call(_flipped == [HandTypes.Finger.MIDDLE], "伸びた指を下へ引いて距離を越えたら反転 %s" % [_flipped])
	_drag(_band_center(HandTypes.Finger.MIDDLE), GRAB_Y + HandView.FLIP_DISTANCE * 0.5)
	assert_true.call(_flipped.size() == 2, "距離の内へ戻したら元に戻す")
	_release()


func _test_push_up(assert_true: Callable) -> void:
	_model.set_pose([C, C, C, C, C])
	_flipped.clear()
	_press(_band_center(HandTypes.Finger.THUMB), GRAB_Y)
	_drag(_band_center(HandTypes.Finger.THUMB), GRAB_Y + HandView.FLIP_DISTANCE * 2.0)
	assert_true.call(_flipped.is_empty(), "曲がった指を下へ引いても反転しない")
	_drag(_band_center(HandTypes.Finger.THUMB), GRAB_Y - HandView.FLIP_DISTANCE * 1.1)
	assert_true.call(_flipped == [HandTypes.Finger.THUMB], "曲がった指は上へ押し上げて反転")
	_release()


func _test_one_finger_per_grab(assert_true: Callable) -> void:
	_model.set_pose([E, E, E, E, E])
	_flipped.clear()
	_press(_band_center(HandTypes.Finger.INDEX), GRAB_Y)
	_drag(_band_center(HandTypes.Finger.PINKY), GRAB_Y + HandView.FLIP_DISTANCE * 1.1)
	assert_true.call(_flipped == [HandTypes.Finger.INDEX], "横へ動いてもつかんだ指だけ反転 %s" % [_flipped])
	_release()


## 指の帯の中央(手の大きさに対する比)。両端の帯は外側の境目から少し外。
func _band_center(finger: int) -> float:
	var borders := _view._borders
	if finger == 0:
		return borders[0] - 0.2
	if finger == borders.size():
		return borders[borders.size() - 1] + 0.2
	return (borders[finger - 1] + borders[finger]) / 2.0


func _at(x: float, y: float) -> Vector2:
	return _view._rest_transform() * Vector2(x * _view._unit(), y)


func _press(x: float, y: float) -> void:
	_view._press(HandView.MOUSE_POINTER, _at(x, y), true)


func _drag(x: float, y: float) -> void:
	_view._drag(HandView.MOUSE_POINTER, _at(x, y))


func _release() -> void:
	_view._press(HandView.MOUSE_POINTER, Vector2.ZERO, false)
