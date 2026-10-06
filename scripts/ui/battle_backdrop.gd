class_name BattleBackdrop
extends Control
## 対戦画面の背景(GameDesign 8.4節)。上(相手側)を青系、下(自分側)を暖色系に塗り分けて斜めの縞を重ねる。
## burst() で判定の瞬間の集中線を出して消す(8.3節)。

## 上下それぞれの [端, 中央] の色。
const THEIR_COLORS := [Color("16305c"), Color("2f6fc4")]
const MY_COLORS := [Color("6e2412"), Color("d0602c")]
const STRIPE_COLOR := Color(1.0, 1.0, 1.0, 0.05)
## 縞の間隔・太さ(幅に対する比)と傾き(高さに対する横ずれの比)。
const STRIPE_SPACING := 0.09
const STRIPE_WIDTH := 0.035
const STRIPE_SLANT := 0.5
const DIVIDER_COLOR := Color(1.0, 1.0, 1.0, 0.3)
const DIVIDER_WIDTH := 0.008
## 集中線の本数・表示秒・内側の端(中心から、対角線の半分に対する比)・付け根の太さ(幅に対する比)。
const BURST_LINES := 44
const BURST_SECONDS := 0.6
const BURST_INNER := 0.3
const BURST_WIDTH := 0.03
const BURST_COLOR := Color(1.0, 1.0, 1.0, 0.8)

var _burst_left := 0.0
var _burst_angles := PackedFloat32Array()
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	clip_contents = true
	_rng.randomize()
	set_process(false)


func burst() -> void:
	_burst_angles.clear()
	for i in BURST_LINES:
		_burst_angles.append(TAU * (i + _rng.randf()) / BURST_LINES)
	_burst_left = BURST_SECONDS
	set_process(true)


func _process(delta: float) -> void:
	_burst_left -= delta
	if _burst_left <= 0.0:
		set_process(false)
	queue_redraw()


func _draw() -> void:
	var middle := size.y / 2.0
	_draw_gradient(0.0, middle, THEIR_COLORS[0], THEIR_COLORS[1])
	_draw_gradient(middle, size.y, MY_COLORS[1], MY_COLORS[0])
	_draw_stripes()
	var divider_width := size.x * DIVIDER_WIDTH
	draw_line(Vector2(0.0, middle), Vector2(size.x, middle), DIVIDER_COLOR, divider_width)
	if _burst_left > 0.0:
		_draw_burst()


func _draw_gradient(top: float, bottom: float, top_color: Color, bottom_color: Color) -> void:
	var corners := PackedVector2Array(
		[Vector2(0.0, top), Vector2(size.x, top), Vector2(size.x, bottom), Vector2(0.0, bottom)]
	)
	var colors := PackedColorArray([top_color, top_color, bottom_color, bottom_color])
	draw_polygon(corners, colors)


func _draw_stripes() -> void:
	var spacing := size.x * STRIPE_SPACING
	var width := size.x * STRIPE_WIDTH
	var slant := size.y * STRIPE_SLANT
	var left := -slant
	while left < size.x:
		var stripe := PackedVector2Array(
			[
				Vector2(left, 0.0),
				Vector2(left + width, 0.0),
				Vector2(left + width + slant, size.y),
				Vector2(left + slant, size.y),
			]
		)
		draw_colored_polygon(stripe, STRIPE_COLOR)
		left += spacing


func _draw_burst() -> void:
	var center := size / 2.0
	var outer := size.length()
	var inner := outer / 2.0 * BURST_INNER
	var half_width := size.x * BURST_WIDTH / 2.0
	var color := BURST_COLOR
	color.a *= _burst_left / BURST_SECONDS
	for angle in _burst_angles:
		var direction := Vector2.RIGHT.rotated(angle)
		var side := direction.orthogonal() * half_width
		var wedge := PackedVector2Array(
			[
				center + direction * inner,
				center + direction * outer + side,
				center + direction * outer - side,
			]
		)
		draw_colored_polygon(wedge, color)
