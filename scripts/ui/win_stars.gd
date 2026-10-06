class_name WinStars
extends Control
## 勝利数(GameDesign 8.4節)。呼び名の横に勝利に必要な数だけ星を並べ、取った分を点ける。

const STAR_TIPS := 5
## 星の外側の半径・間隔(このノードの高さに対する比)と、内側の半径・縁の太さ(外側の半径に対する比)。
const STAR_RADIUS_RATIO := 0.45
const STAR_SPACING_RATIO := 1.05
const STAR_INNER_RATIO := 0.45
const OUTLINE_RATIO := 0.16
## 呼び名の文字の大きさと、星との間(高さに対する比)。
const CAPTION_FONT_RATIO := 0.75
const CAPTION_GAP_RATIO := 0.35
const CAPTION_OUTLINE := 8
const ON_COLOR := Color("ffd84a")
const OFF_COLOR := Color(0.0, 0.0, 0.0, 0.35)
const OUTLINE_COLOR := Color("101820")
const CAPTION_COLOR := Color.WHITE

var caption := ""
var total := 0:
	set(value):
		total = value
		queue_redraw()
var won := 0:
	set(value):
		won = value
		queue_redraw()


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE


func _draw() -> void:
	var font := get_theme_default_font()
	var font_size := int(size.y * CAPTION_FONT_RATIO)
	var caption_width := font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var spacing := size.y * STAR_SPACING_RATIO
	var gap := size.y * CAPTION_GAP_RATIO
	var left := (size.x - caption_width - gap - spacing * total) / 2.0
	var ascent := font.get_ascent(font_size)
	var baseline := Vector2(left, (size.y + ascent - font.get_descent(font_size)) / 2.0)
	draw_string_outline(
		font,
		baseline,
		caption,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		font_size,
		CAPTION_OUTLINE,
		OUTLINE_COLOR
	)
	draw_string(font, baseline, caption, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, CAPTION_COLOR)
	var radius := size.y * STAR_RADIUS_RATIO
	for i in total:
		var center := Vector2(left + caption_width + gap + spacing * (i + 0.5), size.y / 2.0)
		_draw_star(center, radius, ON_COLOR if i < won else OFF_COLOR)


func _draw_star(center: Vector2, radius: float, color: Color) -> void:
	var points := PackedVector2Array()
	for i in STAR_TIPS * 2:
		var reach := radius if i % 2 == 0 else radius * STAR_INNER_RATIO
		points.append(center + Vector2.UP.rotated(PI * i / STAR_TIPS) * reach)
	draw_colored_polygon(points, color)
	points.append(points[0])
	draw_polyline(points, OUTLINE_COLOR, radius * OUTLINE_RATIO, true)
