class_name UiStyle
## 画面で共通のボタン・文字・配置(Architecture 6章)。

const BUTTON_COLOR := Color("ffd84a")
const BUTTON_HOVER_COLOR := Color("ffe680")
const BUTTON_DISABLED_COLOR := Color("8a8f99")
const BUTTON_TEXT_COLOR := Color("3b2416")
const BUTTON_CORNER := 24
const BUTTON_BORDER := 6
const BUTTON_PRESSED_DARKEN := 0.15
const TEXT_COLOR := Color.WHITE
const OUTLINE_COLOR := Color("101820")
const LABEL_OUTLINE := 12


static func make_button(text: String, font_size: int, on_pressed: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_size_override("font_size", font_size)
	for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(color_name, BUTTON_TEXT_COLOR)
	button.add_theme_color_override("font_disabled_color", BUTTON_TEXT_COLOR)
	button.add_theme_stylebox_override("normal", box(BUTTON_COLOR))
	button.add_theme_stylebox_override("hover", box(BUTTON_HOVER_COLOR))
	button.add_theme_stylebox_override("pressed", box(BUTTON_COLOR.darkened(BUTTON_PRESSED_DARKEN)))
	button.add_theme_stylebox_override("disabled", box(BUTTON_DISABLED_COLOR))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.pressed.connect(on_pressed)
	return button


static func box(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = OUTLINE_COLOR
	style.set_border_width_all(BUTTON_BORDER)
	style.set_corner_radius_all(BUTTON_CORNER)
	style.anti_aliasing = true
	return style


static func make_label(text: String, font_size: int, color := TEXT_COLOR) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", OUTLINE_COLOR)
	label.add_theme_constant_override("outline_size", LABEL_OUTLINE)
	return label


## rect は親に対する比(位置と大きさ)。set_anchors_preset() は生成直後に使えないため anchor へ直接入れる。
static func place(parent: Control, control: Control, rect: Rect2) -> void:
	control.anchor_left = rect.position.x
	control.anchor_top = rect.position.y
	control.anchor_right = rect.end.x
	control.anchor_bottom = rect.end.y
	parent.add_child(control)
