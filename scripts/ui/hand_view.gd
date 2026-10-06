class_name HandView
extends Control
## HandModel をマンガ風のゴムホースの手で描き、interactive ならなぞりを finger_reached で知らせる
## (GameDesign 6.1節・8.1節)。HandModel を直接動かさない(入力は LocalMatch が tick に揃えて記録・適用するため)。
## 手のローカル座標は手のひらの中心が原点で、指先が上(-Y)。寸法はすべて手の大きさ(短辺 × UNIT_RATIO)に対する比。
## なぞり: 伸びきった指先のx座標の中点で縦の帯に分けて指を選び、ポインタの高さへ指先の高さを合わせる曲がり具合を知らせる。

## curl はポインタの高さに指先が来る曲がり具合(0.0〜1.0)。
signal finger_reached(finger: HandTypes.Finger, curl: float)


class Spark:
	var position: Vector2
	var velocity: Vector2
	var life: float


const UNIT_RATIO := 0.23
## 手のひらの中心(このノードの中心から手首の側へ)。
const PALM_CENTER := Vector2(0.0, 0.8)
const PALM_SIZE := Vector2(2.0, 1.7)
const PALM_CORNER := 0.6
const WRIST_WIDTH := 1.3
## 手首と袖を描く長さ(手のひらの中心から。画面の端より外まで伸ばす)。
const ARM_LENGTH := 4.0
const SLEEVE_START := 1.45
const SLEEVE_WIDTH := 1.75
const SLEEVE_STRIPE := Vector2(0.12, 0.14)
const OUTLINE_WIDTH := 0.06
## 指の付け根(手のひらの下に隠れる位置)・向き(度。上が0で時計回り)・伸びきりの長さ・太さ。親指から小指の順。
## 指先の間を広げ、なぞりの帯の幅をスマホで指先1つ分以上にする(GameDesign 6.1節)。
const FINGER_BASES := [
	Vector2(-0.85, 0.15),
	Vector2(-0.72, -0.6),
	Vector2(-0.24, -0.7),
	Vector2(0.24, -0.66),
	Vector2(0.7, -0.52),
]
const FINGER_ANGLES := [-50.0, -16.0, -3.0, 10.0, 22.0]
const FINGER_LENGTHS := [1.25, 1.5, 1.65, 1.55, 1.25]
const FINGER_WIDTHS := [0.44, 0.38, 0.39, 0.37, 0.33]
## 指先の太さ(付け根に対する比)。
const TIP_WIDTH_RATIO := 0.85
## 曲がりきった指の見える長さ(伸びきりに対する比)と、太る割合。
const CURLED_LENGTH_RATIO := 0.3
const CURLED_FATTEN := 0.15
## 速くなぞったとき、前回の位置から今の位置までを区切る間隔(帯を飛ばさないように)。
const SWEEP_SPACING := 0.1
## 触っている指がポインタの方へ傾く角度の上限(度)・追いつく速さ・付け根から測る距離の下限(伸びきりの長さに対する比)。
const LEAN_MAX := 12.0
const LEAN_SPEED := 18.0
const LEAN_MIN_REACH := 0.5
## 関節のしわの位置(付け根からの比)と長さ(太さに対する比)。
const CREASE_FRACTIONS := [0.5, 0.75]
const CREASE_LENGTH := 0.5
## 爪の大きさ(指先の太さに対する比)、指先から奥へずらす量(同)、見えなくなる曲がり具合。
const NAIL_SIZE := Vector2(0.3, 0.4)
const NAIL_INSET := 0.35
const NAIL_HIDDEN_CURL := 0.5
const NAIL_SEGMENTS := 16
## 止まっていてもうねる揺れ(指先の横ずれ・速さ・指ごとのずれ)。
const IDLE_SWAY := 0.07
const IDLE_SPEED := 2.3
const IDLE_PHASE := 1.3
## 中途半端な指の震え(指先の横ずれ・速さ)と赤みの割合。
const TREMBLE := 0.05
const TREMBLE_SPEED := 40.0
const HALF_TINT := 0.5
## 触っている指の光る縁の太さ。
const GLOW_WIDTH := 0.1
## 伸び・曲がりの範囲に入ったときの火花(数・速さ・寿命・大きさ)。
const SPARK_COUNT := 7
const SPARK_SPEED := 2.6
const SPARK_LIFE := 0.35
const SPARK_SIZE := 0.08
## 見た目の揺れを1フレームで進める時間の上限(処理落ちでばねが暴れないように)。
const MAX_VISUAL_DELTA := 1.0 / 30.0
## モザイクの1マスの大きさ、覆う範囲の中心と半径。
const MOSAIC_CELL := 0.4
const MOSAIC_CENTER := Vector2(0.0, -0.6)
const MOSAIC_REACH := 2.6
## マスの色を散らすための係数(互いに素な数ならよい)。
const MOSAIC_HASH := Vector2i(7, 13)

## 拍に合わせて弾む(前へ出る量・大きさ・秒)。
const BEAT_KICK := 0.12
const BEAT_SCALE := 1.05
const BEAT_SECONDS := 0.09
## ぽんで相手へ突き出す(量・大きさ・秒)。
const THRUST := 0.35
const THRUST_SCALE := 1.12
const THRUST_SECONDS := 0.12
## 勝ち: 跳ねる(高さ・秒・回数)。負け: しぼむ(大きさ・色・下がる量・秒)。あいこ: 揺れる(角度・秒・回数)。
const HOP_HEIGHT := 0.3
const HOP_SECONDS := 0.14
const HOP_COUNT := 3
const SLUMP_SCALE := 0.86
const SLUMP_COLOR := Color(0.5, 0.5, 0.58)
const SLUMP_DROP := 0.25
const SLUMP_SECONDS := 0.4
const WOBBLE_TILT := 0.12
const WOBBLE_SECONDS := 0.08
const WOBBLE_COUNT := 3

const SKIN_COLOR := Color("f7c59f")
const CREASE_COLOR := Color("cf8a62")
const OUTLINE_COLOR := Color("3b2416")
const NAIL_COLOR := Color("ffe6dc")
const HALF_COLOR := Color("ff4a3d")
const GLOW_COLOR := Color("fff27a")
const SPARK_COLOR := Color("fff7a8")
const SLEEVE_STRIPE_COLOR := Color(1.0, 1.0, 1.0, 0.45)
const MOSAIC_COLORS := [SKIN_COLOR, CREASE_COLOR, Color("e8a984")]

const NO_FINGER := -1
const MOUSE_POINTER := -1
const NO_POINTER := -2
const NO_STATE := -1

var interactive := false
## 自主規制(GameDesign 2.5節)で手をモザイクで覆う。
var censored := false
## 相手の手は上下を逆にして、指先を画面の下へ向ける。
var facing_down := false
var sleeve_color := Color.WHITE
## 演出用。pose_offset は手の大きさに対する比で、-Y が相手の方向。入力の対応には使わない。
var pose_offset := Vector2.ZERO
var pose_scale := 1.0
var pose_tilt := 0.0
var _model: HandModel
var _config: HandConfig
## なぞっているポインタ(マウスは MOUSE_POINTER、タッチは番号)。同時に1つだけ。
var _pointer := NO_POINTER
## なぞっているポインタの位置(演出を除いた手のローカル座標)と、その帯の指。
var _pointer_local := Vector2.ZERO
var _touched := NO_FINGER
## 見た目だけの傾き(度)。
var _leans := PackedFloat32Array()
var _softs: Array[SoftFinger] = []
var _curves: Array[PackedVector2Array] = []
var _states: Array[int] = []
var _sparks: Array[Spark] = []
var _time := 0.0
var _tween: Tween
var _palm_box := StyleBoxFlat.new()
var _wrist_box := StyleBoxFlat.new()
var _sleeve_box := StyleBoxFlat.new()
var _rng := RandomNumberGenerator.new()


func bind(model: HandModel, config: HandConfig) -> void:
	_model = model
	_config = config
	_softs.clear()
	_curves.clear()
	_states.clear()
	for i in HandTypes.Finger.size():
		_softs.append(SoftFinger.new())
		_curves.append(PackedVector2Array())
		_states.append(NO_STATE)
	_leans.resize(HandTypes.Finger.size())
	_rng.randomize()


## ラウンド開始時に演出と揺れを止め、手を初期配置のまま見せる。
func reset_pose() -> void:
	if _tween != null:
		_tween.kill()
	pose_offset = Vector2.ZERO
	pose_scale = 1.0
	pose_tilt = 0.0
	modulate = Color.WHITE
	_release()
	_leans.fill(0.0)
	_sparks.clear()
	for i in _softs.size():
		_softs[i].reset()
		_states[i] = NO_STATE


## 掛け声の拍に合わせて前へ弾む。
func beat() -> void:
	var tween := _restart_tween()
	tween.tween_property(self, "pose_offset", Vector2(0.0, -BEAT_KICK), BEAT_SECONDS)
	tween.parallel().tween_property(self, "pose_scale", BEAT_SCALE, BEAT_SECONDS)
	tween.tween_property(self, "pose_offset", Vector2.ZERO, BEAT_SECONDS)
	tween.parallel().tween_property(self, "pose_scale", 1.0, BEAT_SECONDS)


## ぽんで相手へ突き出し、outcome(この手から見た勝敗)に応じて跳ねる・しぼむ・揺れる。
func show_result(outcome: HandTypes.Outcome) -> void:
	var tween := _restart_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "pose_offset", Vector2(0.0, -THRUST), THRUST_SECONDS)
	tween.parallel().tween_property(self, "pose_scale", THRUST_SCALE, THRUST_SECONDS)
	tween.set_trans(Tween.TRANS_SINE)
	match outcome:
		HandTypes.Outcome.WIN:
			for i in HOP_COUNT:
				var top := Vector2(0.0, -THRUST - HOP_HEIGHT)
				tween.tween_property(self, "pose_offset", top, HOP_SECONDS)
				tween.tween_property(self, "pose_offset", Vector2(0.0, -THRUST), HOP_SECONDS)
		HandTypes.Outcome.LOSE:
			tween.tween_property(self, "pose_offset", Vector2(0.0, SLUMP_DROP), SLUMP_SECONDS)
			tween.parallel().tween_property(self, "pose_scale", SLUMP_SCALE, SLUMP_SECONDS)
			tween.parallel().tween_property(self, "modulate", SLUMP_COLOR, SLUMP_SECONDS)
		HandTypes.Outcome.DRAW:
			for i in WOBBLE_COUNT:
				tween.tween_property(self, "pose_tilt", WOBBLE_TILT, WOBBLE_SECONDS)
				tween.tween_property(self, "pose_tilt", -WOBBLE_TILT, WOBBLE_SECONDS)
			tween.tween_property(self, "pose_tilt", 0.0, WOBBLE_SECONDS)


func _restart_tween() -> Tween:
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	return _tween


func _process(delta: float) -> void:
	if _model == null:
		return
	if not interactive:
		_release()
	var step := minf(delta, MAX_VISUAL_DELTA)
	_time += step
	var unit := _unit()
	_update_leans(step)
	for i in HandTypes.Finger.size():
		var state := HandShapeJudge.state_of(_config, _model.curls[i])
		var base: Vector2 = FINGER_BASES[i] * unit
		var tip := base + _direction(i) * _visible_length(i, unit)
		if state != _states[i]:
			if _states[i] != NO_STATE and state != HandTypes.FingerState.HALF and not censored:
				_spawn_sparks(tip, unit)
			_states[i] = state
		var sway := sin(_time * IDLE_SPEED + i * IDLE_PHASE) * IDLE_SWAY * unit
		_softs[i].update(base, tip, sway, step)
		var shake := 0.0
		if state == HandTypes.FingerState.HALF:
			shake = sin(_time * TREMBLE_SPEED + i) * TREMBLE * unit
		_curves[i] = _softs[i].curve(shake)
	_update_sparks(step)
	queue_redraw()


func _draw() -> void:
	if _model == null or _curves.is_empty() or _curves[0].is_empty():
		return
	var unit := _unit()
	draw_set_transform_matrix(_hand_transform())
	_draw_arm(unit)
	for i in HandTypes.Finger.size():
		_draw_finger(i, unit, i == _touched)
	_draw_palm(unit)
	if censored:
		_draw_mosaic(unit)
	else:
		_draw_sparks(unit)


func _draw_arm(unit: float) -> void:
	var outline := int(OUTLINE_WIDTH * unit)
	_set_box(_wrist_box, SKIN_COLOR, outline, 0)
	draw_style_box(
		_wrist_box, Rect2(-WRIST_WIDTH / 2.0 * unit, 0.0, WRIST_WIDTH * unit, ARM_LENGTH * unit)
	)
	_set_box(_sleeve_box, sleeve_color, outline, int(OUTLINE_WIDTH * unit))
	var sleeve := Rect2(
		-SLEEVE_WIDTH / 2.0 * unit,
		SLEEVE_START * unit,
		SLEEVE_WIDTH * unit,
		(ARM_LENGTH - SLEEVE_START) * unit
	)
	draw_style_box(_sleeve_box, sleeve)
	var stripe := Rect2(
		sleeve.position + Vector2(outline, SLEEVE_STRIPE.x * unit),
		Vector2(sleeve.size.x - outline * 2, SLEEVE_STRIPE.y * unit)
	)
	draw_rect(stripe, SLEEVE_STRIPE_COLOR)


func _draw_palm(unit: float) -> void:
	_set_box(_palm_box, SKIN_COLOR, int(OUTLINE_WIDTH * unit), int(PALM_CORNER * unit))
	draw_style_box(_palm_box, Rect2(-PALM_SIZE / 2.0 * unit, PALM_SIZE * unit))


func _set_box(box: StyleBoxFlat, color: Color, border: int, corner: int) -> void:
	box.bg_color = color
	box.border_color = OUTLINE_COLOR
	box.set_border_width_all(border)
	box.set_corner_radius_all(corner)
	box.anti_aliasing = true


func _draw_finger(finger: int, unit: float, touched: bool) -> void:
	var curve := _curves[finger]
	var curl := _model.curls[finger]
	var width: float = FINGER_WIDTHS[finger] * unit * (1.0 + CURLED_FATTEN * curl)
	var tip_width := width * TIP_WIDTH_RATIO
	var outline := OUTLINE_WIDTH * unit
	if touched:
		_draw_tube(curve, width, tip_width, outline + GLOW_WIDTH * unit, GLOW_COLOR)
	_draw_tube(curve, width, tip_width, outline, OUTLINE_COLOR)
	var skin := SKIN_COLOR
	if _states[finger] == HandTypes.FingerState.HALF:
		skin = SKIN_COLOR.lerp(HALF_COLOR, HALF_TINT)
	_draw_tube(curve, width, tip_width, 0.0, skin)
	for fraction in CREASE_FRACTIONS:
		_draw_crease(curve, fraction, lerpf(width, tip_width, fraction), outline / 2.0)
	var nail_alpha := clampf(1.0 - curl / NAIL_HIDDEN_CURL, 0.0, 1.0)
	if nail_alpha > 0.0:
		_draw_nail(curve, tip_width, nail_alpha, outline / 2.0)


## 太さが付け根の width から指先の tip_width へ変わる管を、円を並べて描く。extra は太らせる量。
func _draw_tube(
	points: PackedVector2Array, width: float, tip_width: float, extra: float, color: Color
) -> void:
	var last := points.size() - 1
	for s in points.size():
		var radius := lerpf(width, tip_width, float(s) / last) / 2.0 + extra
		draw_circle(points[s], radius, color, true, -1.0, true)


func _draw_crease(
	points: PackedVector2Array, fraction: float, width: float, thickness: float
) -> void:
	var last := points.size() - 1
	var index := clampi(roundi(fraction * last), 1, last - 1)
	var along := (points[index + 1] - points[index - 1]).normalized()
	var half := along.orthogonal() * width * CREASE_LENGTH / 2.0
	draw_line(points[index] - half, points[index] + half, CREASE_COLOR, thickness, true)


func _draw_nail(
	points: PackedVector2Array, tip_width: float, alpha: float, thickness: float
) -> void:
	var last := points.size() - 1
	var along := (points[last] - points[last - 1]).normalized()
	var center := points[last] - along * tip_width * NAIL_INSET
	var radii := NAIL_SIZE * tip_width
	var outline := PackedVector2Array()
	for s in NAIL_SEGMENTS:
		var angle := TAU * s / NAIL_SEGMENTS
		var local := Vector2(cos(angle) * radii.x, sin(angle) * radii.y)
		outline.append(center + local.rotated(along.angle() + PI / 2.0))
	var nail := NAIL_COLOR
	nail.a = alpha
	draw_colored_polygon(outline, nail)
	outline.append(outline[0])
	var edge := CREASE_COLOR
	edge.a = alpha
	draw_polyline(outline, edge, thickness, true)


func _draw_mosaic(unit: float) -> void:
	var cell := MOSAIC_CELL * unit
	var center := MOSAIC_CENTER * unit
	var reach := MOSAIC_REACH * unit
	var cells := ceili(reach / cell)
	for x in range(-cells, cells):
		for y in range(-cells, cells):
			var corner := center + Vector2(x, y) * cell
			if (corner + Vector2.ONE * cell / 2.0 - center).length() > reach:
				continue
			var color_index := posmod(x * MOSAIC_HASH.x + y * MOSAIC_HASH.y, MOSAIC_COLORS.size())
			draw_rect(Rect2(corner, Vector2.ONE * cell), MOSAIC_COLORS[color_index])


func _spawn_sparks(at: Vector2, unit: float) -> void:
	for i in SPARK_COUNT:
		var spark := Spark.new()
		spark.position = at
		var angle := TAU * (i + _rng.randf()) / SPARK_COUNT
		spark.velocity = (
			Vector2.RIGHT.rotated(angle) * SPARK_SPEED * unit * _rng.randf_range(0.6, 1.0)
		)
		spark.life = SPARK_LIFE
		_sparks.append(spark)


func _update_sparks(delta: float) -> void:
	for spark in _sparks:
		spark.position += spark.velocity * delta
		spark.life -= delta
	_sparks.assign(_sparks.filter(func(spark: Spark) -> bool: return spark.life > 0.0))


func _draw_sparks(unit: float) -> void:
	for spark in _sparks:
		var reach := SPARK_SIZE * unit * spark.life / SPARK_LIFE
		var along := spark.velocity.normalized() * reach
		var across := along.orthogonal()
		draw_line(spark.position - along, spark.position + along, SPARK_COLOR, reach / 2.0, true)
		draw_line(spark.position - across, spark.position + across, SPARK_COLOR, reach / 2.0, true)


func _gui_input(event: InputEvent) -> void:
	if not interactive or _model == null:
		return
	if event is InputEventMouseButton:
		if (
			event.device == InputEvent.DEVICE_ID_EMULATION
			or event.button_index != MOUSE_BUTTON_LEFT
		):
			return
		_press(MOUSE_POINTER, event.position, event.pressed)
	elif event is InputEventMouseMotion:
		if event.device == InputEvent.DEVICE_ID_EMULATION:
			return
		_sweep(MOUSE_POINTER, event.position)
	elif event is InputEventScreenTouch:
		_press(event.index, event.position, event.pressed)
	elif event is InputEventScreenDrag:
		_sweep(event.index, event.position)
	else:
		return
	accept_event()


func _press(pointer: int, at: Vector2, pressed: bool) -> void:
	if not pressed:
		if pointer == _pointer:
			_release()
		return
	if _pointer != NO_POINTER:
		return
	_pointer = pointer
	_pointer_local = _rest_transform().affine_inverse() * at
	_reach_at(_pointer_local)


## 前回の位置から今の位置までを SWEEP_SPACING ごとに区切り、通った帯の指を順に知らせる。
func _sweep(pointer: int, at: Vector2) -> void:
	if pointer != _pointer:
		return
	var to := _rest_transform().affine_inverse() * at
	var count := maxi(ceili(_pointer_local.distance_to(to) / (SWEEP_SPACING * _unit())), 1)
	for i in range(1, count + 1):
		_reach_at(_pointer_local.lerp(to, float(i) / count))
	_pointer_local = to


func _reach_at(local: Vector2) -> void:
	var unit := _unit()
	_touched = _finger_at(local.x / unit)
	finger_reached.emit(_touched as HandTypes.Finger, _curl_at(_touched, local.y / unit))


func _release() -> void:
	_pointer = NO_POINTER
	_touched = NO_FINGER


## x は手の大きさに対する比。伸びきった指先のx座標の中点で分けた帯のうち、x が入る帯の指。
func _finger_at(x: float) -> int:
	var last := HandTypes.Finger.size() - 1
	for i in last:
		var border := (
			(_rest_tip(i, HandModel.MIN_CURL).x + _rest_tip(i + 1, HandModel.MIN_CURL).x) / 2.0
		)
		if x < border:
			return i
	return last


## y は手の大きさに対する比。指先の高さが y になる曲がり具合(範囲の外は端で止める)。
func _curl_at(finger: int, y: float) -> float:
	var extended := _rest_tip(finger, HandModel.MIN_CURL).y
	var curled := _rest_tip(finger, HandModel.MAX_CURL).y
	return clampf((y - extended) / (curled - extended), HandModel.MIN_CURL, HandModel.MAX_CURL)


## 傾いていない指の、曲がり具合 curl での指先の位置(手の大きさに対する比)。
func _rest_tip(finger: int, curl: float) -> Vector2:
	var direction := Vector2.UP.rotated(deg_to_rad(FINGER_ANGLES[finger]))
	var length: float = FINGER_LENGTHS[finger] * lerpf(1.0, CURLED_LENGTH_RATIO, curl)
	var base: Vector2 = FINGER_BASES[finger]
	return base + direction * length


## 触っている指をポインタの方へ傾け、離れた指を戻す(見た目だけ)。
func _update_leans(delta: float) -> void:
	var follow := 1.0 - exp(-LEAN_SPEED * delta)
	for i in _leans.size():
		var goal := 0.0
		if i == _touched:
			var direction := Vector2.UP.rotated(deg_to_rad(FINGER_ANGLES[i]))
			var offset: Vector2 = _pointer_local / _unit() - FINGER_BASES[i]
			var reach: float = maxf(offset.dot(direction), FINGER_LENGTHS[i] * LEAN_MIN_REACH)
			var side := offset.dot(direction.rotated(PI / 2.0))
			goal = clampf(rad_to_deg(atan2(side, reach)), -LEAN_MAX, LEAN_MAX)
		_leans[i] = lerpf(_leans[i], goal, follow)


## 演出(弾み・突き出し)を除いた手の位置。入力の対応に使う(拍で弾んでも同じ高さなら同じ曲がり具合にするため)。
func _rest_transform() -> Transform2D:
	var turn := PI if facing_down else 0.0
	return Transform2D(turn, size / 2.0) * Transform2D(0.0, PALM_CENTER * _unit())


func _hand_transform() -> Transform2D:
	var unit := _unit()
	var turn := PI if facing_down else 0.0
	var view := Transform2D(turn, size / 2.0)
	var hand := Transform2D(
		pose_tilt, Vector2.ONE * pose_scale, 0.0, (PALM_CENTER + pose_offset) * unit
	)
	return view * hand


func _unit() -> float:
	return minf(size.x, size.y) * UNIT_RATIO


func _direction(finger: int) -> Vector2:
	return Vector2.UP.rotated(deg_to_rad(FINGER_ANGLES[finger] + _leans[finger]))


func _visible_length(finger: int, unit: float) -> float:
	var curl := _model.curls[finger]
	return FINGER_LENGTHS[finger] * unit * lerpf(1.0, CURLED_LENGTH_RATIO, curl)
