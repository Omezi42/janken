class_name CensorTape
extends Control
## 名前の上に貼る規制テープ(GameDesign 2.5節)。斜めの黄色い帯に黒い縁と「自主規制」の文字。

const TEXT := "自主規制"
const TILT_DEGREES := -4.0
## 帯の大きさ(このノードに対する比)。
const BAND_SIZE_RATIO := Vector2(0.75, 0.95)
## 縁の太さ(帯の高さに対する比)。
const EDGE_RATIO := 0.12
## 文字の大きさ(帯の高さに対する比)。
const FONT_RATIO := 0.6
const BAND_COLOR := Color("f5d020")
const INK_COLOR := Color("141414")


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE


func _draw() -> void:
	var band := size * BAND_SIZE_RATIO
	var edge := band.y * EDGE_RATIO
	draw_set_transform(size / 2.0, deg_to_rad(TILT_DEGREES))
	draw_rect(Rect2(-band / 2.0, band), BAND_COLOR)
	draw_rect(Rect2(-band / 2.0, Vector2(band.x, edge)), INK_COLOR)
	draw_rect(
		Rect2(Vector2(-band.x, band.y) / 2.0 - Vector2(0.0, edge), Vector2(band.x, edge)), INK_COLOR
	)
	var font := get_theme_default_font()
	var font_size := int(band.y * FONT_RATIO)
	var text_size := font.get_string_size(TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var baseline := Vector2(-text_size.x / 2.0, font.get_ascent(font_size) - text_size.y / 2.0)
	draw_string(font, baseline, TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, INK_COLOR)
