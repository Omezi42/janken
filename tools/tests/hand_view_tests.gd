extends RefCounted
## HandView のなぞり操作(GameDesign 6.1節)。押した瞬間は何もせず、帯へ入るたびに反転を知らせる。

const VIEW_SIZE := Vector2(720.0, 563.0)
const Y := 100.0

var _view: HandView
var _flipped := []


func run(assert_true: Callable) -> void:
	_view = HandView.new()
	_view.size = VIEW_SIZE
	_view.bind(HandModel.new())
	_view.finger_flipped.connect(func(finger: HandTypes.Finger) -> void: _flipped.append(finger))
	_test_press_does_nothing(assert_true)
	_test_margin(assert_true)
	_test_sweep(assert_true)
	_view.free()


func _test_press_does_nothing(assert_true: Callable) -> void:
	_press(_band_center(2))
	assert_true.call(_flipped.is_empty(), "押した瞬間は反転しない")
	_drag(_band_center(3))
	assert_true.call(_flipped == [HandTypes.Finger.MIDDLE], "隣の帯へ入ったらその指を反転 %s" % [_flipped])
	_drag(_band_center(2))
	assert_true.call(
		_flipped == [HandTypes.Finger.MIDDLE, HandTypes.Finger.INDEX],
		"戻って入った帯の指も反転 %s" % [_flipped]
	)
	_release()


func _test_margin(assert_true: Callable) -> void:
	_flipped.clear()
	_press(_band_center(1))
	var margin := HandView.BAND_MARGIN / _view._unit()
	_drag(_view._borders[1] + margin / 2.0)
	assert_true.call(_flipped.is_empty(), "境目を越えた距離が余白より短ければ反転しない")
	_drag(_view._borders[1] + margin * 2.0)
	assert_true.call(_flipped == [HandTypes.Finger.INDEX], "余白を越えたら反転")
	_drag(_view._borders[1] - margin / 2.0)
	assert_true.call(_flipped.size() == 1, "境目のそばで戻っても余白の内なら反転しない")
	_release()


func _test_sweep(assert_true: Callable) -> void:
	_flipped.clear()
	_press(_band_center(0))
	_drag(_band_center(6))
	assert_true.call(_flipped == [0, 1, 2, 3, 4], "一度に端から端へ動いても通った帯はすべて反転 %s" % [_flipped])
	_release()


## 帯の中央(手の大きさに対する比)。両端の何も起きない帯は外側の境目から少し外。
func _band_center(band: int) -> float:
	var borders := _view._borders
	if band == 0:
		return borders[0] - 0.2
	if band == borders.size():
		return borders[borders.size() - 1] + 0.2
	return (borders[band - 1] + borders[band]) / 2.0


func _at(x: float) -> Vector2:
	return _view._rest_transform() * Vector2(x * _view._unit(), Y)


func _press(x: float) -> void:
	_view._press(HandView.MOUSE_POINTER, _at(x), true)


func _drag(x: float) -> void:
	_view._drag(HandView.MOUSE_POINTER, _at(x))


func _release() -> void:
	_view._press(HandView.MOUSE_POINTER, Vector2.ZERO, false)
