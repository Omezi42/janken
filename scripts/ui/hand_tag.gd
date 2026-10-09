class_name HandTag
extends Control
## 手の指先のそばに出す、いまの手の名前(小)と勝ち条件の1行(GameDesign 5章・8.5節)。
## 当たっている勝ち条件は黄色にして光った瞬間に弾ませる。反則の間は直前の手を中途半端な指と同じ色で残す。
## 幅に収まらない文字は小さくする。

const NAME_FONT_SIZE := 24
const CONDITION_FONT_SIZE := 36
## 名前と勝ち条件の間(ピクセル)。
const GAP := 14.0
## 文字が使ってよい幅(このノードの幅に対する比)。
const FIT_RATIO := 0.94
const OUTLINE_SIZE := 12
const OUTLINE_COLOR := StampLabel.OUTLINE_COLOR
const TEXT_COLOR := Color.WHITE
const LIT_COLOR := Color("ffd84a")
const FOUL_COLOR := HandView.HALF_SKIN_COLOR
## 光った瞬間に勝ち条件を弾ませる大きさと秒。
const LIT_POP_SCALE := 1.3
const LIT_POP_SECONDS := 0.25

var condition_scale := 1.0:
	set(value):
		condition_scale = value
		queue_redraw()
var _hand_name := ""
var _condition := ""
var _lit := false
var _foul := false
var _tween: Tween


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE


## 反則でない手を出す。lit は勝ち条件が当たっているか。
func put(hand_name: String, condition: String, lit: bool) -> void:
	if lit and not _lit:
		_pop()
	_set_content(hand_name, condition, lit, false)


## 反則の間、直前に出した手を残す。
func put_foul() -> void:
	_set_content(_hand_name, _condition, false, true)


## 隠す。次に光ったときも弾むように光りを消す。
func clear() -> void:
	visible = false
	_lit = false


func _set_content(hand_name: String, condition: String, lit: bool, foul: bool) -> void:
	if [hand_name, condition, lit, foul] == [_hand_name, _condition, _lit, _foul]:
		return
	_hand_name = hand_name
	_condition = condition
	_lit = lit
	_foul = foul
	queue_redraw()


func _pop() -> void:
	if _tween != null:
		_tween.kill()
	condition_scale = LIT_POP_SCALE
	_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "condition_scale", 1.0, LIT_POP_SECONDS)


func _draw() -> void:
	var font := get_theme_default_font()
	var full_width := (
		_width(font, _hand_name, NAME_FONT_SIZE)
		+ GAP
		+ _width(font, _condition, CONDITION_FONT_SIZE)
	)
	var fit := minf(1.0, size.x * FIT_RATIO / full_width) if full_width > 0.0 else 1.0
	var name_size := floori(NAME_FONT_SIZE * fit)
	var condition_size := floori(CONDITION_FONT_SIZE * fit)
	var name_width := _width(font, _hand_name, name_size)
	var condition_width := _width(font, _condition, condition_size)
	var left := (size.x - name_width - GAP * fit - condition_width) / 2.0
	var ascent := font.get_ascent(condition_size)
	var baseline := (size.y + ascent - font.get_descent(condition_size)) / 2.0
	var color := FOUL_COLOR if _foul else TEXT_COLOR
	_draw_text(font, Vector2(left, baseline), _hand_name, name_size, color)
	var condition_left := left + name_width + GAP * fit
	var center := Vector2(condition_left + condition_width / 2.0, size.y / 2.0)
	draw_set_transform(center * (1.0 - condition_scale), 0.0, Vector2.ONE * condition_scale)
	var condition_color := LIT_COLOR if _lit else color
	_draw_text(font, Vector2(condition_left, baseline), _condition, condition_size, condition_color)
	draw_set_transform(Vector2.ZERO)


func _width(font: Font, text: String, font_size: int) -> float:
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x


func _draw_text(font: Font, at: Vector2, text: String, font_size: int, color: Color) -> void:
	draw_string_outline(
		font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, OUTLINE_SIZE, OUTLINE_COLOR
	)
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
