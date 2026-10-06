class_name StampLabel
extends Label
## 弾んで出る文字(pop)と、ハンコのように押される文字(stamp)(GameDesign 8.2節・8.3節)。
## 幅に収まらない文字は小さくする。

const POP_SCALE := 1.6
const POP_SECONDS := 0.3
const STAMP_SCALE := 2.6
const STAMP_SECONDS := 0.2
const STAMP_TILT_DEGREES := 7.0
## 文字が使ってよい幅(このノードの幅に対する比)。
const FIT_RATIO := 0.94
const OUTLINE_COLOR := Color("101820")
const OUTLINE_SIZE := 14

var base_font_size := 0
var _tween: Tween
var _rng := RandomNumberGenerator.new()


func setup(font_size: int) -> void:
	base_font_size = font_size
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mouse_filter = MOUSE_FILTER_IGNORE
	add_theme_color_override("font_outline_color", OUTLINE_COLOR)
	add_theme_constant_override("outline_size", OUTLINE_SIZE)
	add_theme_font_size_override("font_size", font_size)
	_rng.randomize()


func clear() -> void:
	_stop()
	text = ""


func pop(new_text: String, color: Color) -> void:
	_show(new_text, color)
	scale = Vector2.ONE * POP_SCALE
	_tween = create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "scale", Vector2.ONE, POP_SECONDS)


func stamp(new_text: String, color: Color) -> void:
	_show(new_text, color)
	scale = Vector2.ONE * STAMP_SCALE
	modulate.a = 0.0
	rotation = deg_to_rad(_rng.randf_range(-STAMP_TILT_DEGREES, STAMP_TILT_DEGREES))
	_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "scale", Vector2.ONE, STAMP_SECONDS)
	_tween.parallel().tween_property(self, "modulate:a", 1.0, STAMP_SECONDS / 2.0)


func _show(new_text: String, color: Color) -> void:
	_stop()
	text = new_text
	add_theme_color_override("font_color", color)
	_fit_font()
	pivot_offset = size / 2.0


func _stop() -> void:
	if _tween != null:
		_tween.kill()
	scale = Vector2.ONE
	rotation = 0.0
	modulate.a = 1.0


func _fit_font() -> void:
	var font := get_theme_font("font")
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, base_font_size).x
	var available := size.x * FIT_RATIO
	var font_size := base_font_size
	if width > available:
		font_size = floori(base_font_size * available / width)
	add_theme_font_size_override("font_size", font_size)
