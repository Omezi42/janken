class_name PasscodeScreen
extends Control
## 合言葉の入力(GameDesign 4章)。枠に数字を埋め、そろうまで「決定」は押せない。テンキーだけで入れる。

signal entered(passcode: String)
signal back_requested

const CAPTION_TEXT := "合言葉を入れてね"
const DELETE_TEXT := "消す"
const ENTER_TEXT := "決定"
const BACK_TEXT := "戻る"
## テンキーの並び(上の段から)。
const KEY_ROWS := [
	["1", "2", "3"], ["4", "5", "6"], ["7", "8", "9"], [DELETE_TEXT, "0", ENTER_TEXT]
]
const CAPTION_FONT_SIZE := 48
const DIGIT_FONT_SIZE := 96
const KEY_FONT_SIZE := 56
const SMALL_KEY_FONT_SIZE := 40
const BACK_FONT_SIZE := 40
const SLOT_COLOR := Color("fff6e0")
const DIGIT_COLOR := Color("3b2416")

const CAPTION_RECT := Rect2(0.0, 0.08, 1.0, 0.06)
## 数字の枠を並べる範囲と、枠どうしの隙間(幅に対する比)。
const SLOTS_RECT := Rect2(0.12, 0.17, 0.76, 0.11)
const SLOT_GAP := 0.04
## テンキーを並べる範囲と、キーどうしの隙間(幅・高さに対する比)。
const KEYS_RECT := Rect2(0.12, 0.34, 0.76, 0.48)
const KEY_GAP := 0.03
const BACK_RECT := Rect2(0.3, 0.87, 0.4, 0.07)
const FULL_RECT := Rect2(0.0, 0.0, 1.0, 1.0)

## 追加する前に入れる。
var config: OnlineConfig
var _digits := ""
var _slots: Array[Label] = []
var _enter_button: Button


func _ready() -> void:
	UiStyle.place(self, BattleBackdrop.new(), FULL_RECT)
	UiStyle.place(self, UiStyle.make_label(CAPTION_TEXT, CAPTION_FONT_SIZE), CAPTION_RECT)
	_build_slots()
	_build_keys()
	UiStyle.place(
		self, UiStyle.make_button(BACK_TEXT, BACK_FONT_SIZE, back_requested.emit), BACK_RECT
	)
	_refresh()


func _build_slots() -> void:
	var count := config.passcode_length
	var width := (SLOTS_RECT.size.x - SLOT_GAP * (count - 1)) / count
	for i in count:
		var slot := UiStyle.make_label("", DIGIT_FONT_SIZE, DIGIT_COLOR)
		slot.add_theme_constant_override("outline_size", 0)
		var panel := Panel.new()
		panel.mouse_filter = MOUSE_FILTER_IGNORE
		panel.add_theme_stylebox_override("panel", UiStyle.box(SLOT_COLOR))
		var x := SLOTS_RECT.position.x + (width + SLOT_GAP) * i
		var rect := Rect2(x, SLOTS_RECT.position.y, width, SLOTS_RECT.size.y)
		UiStyle.place(self, panel, rect)
		UiStyle.place(self, slot, rect)
		_slots.append(slot)


func _build_keys() -> void:
	var rows := KEY_ROWS.size()
	var columns: int = KEY_ROWS[0].size()
	var width := (KEYS_RECT.size.x - KEY_GAP * (columns - 1)) / columns
	var height := (KEYS_RECT.size.y - KEY_GAP * (rows - 1)) / rows
	for row in rows:
		for column in columns:
			var key: String = KEY_ROWS[row][column]
			var x := KEYS_RECT.position.x + (width + KEY_GAP) * column
			var y := KEYS_RECT.position.y + (height + KEY_GAP) * row
			var button := _make_key(key)
			UiStyle.place(self, button, Rect2(x, y, width, height))
			if key == ENTER_TEXT:
				_enter_button = button


func _make_key(key: String) -> Button:
	match key:
		DELETE_TEXT:
			return UiStyle.make_button(key, SMALL_KEY_FONT_SIZE, _delete)
		ENTER_TEXT:
			return UiStyle.make_button(key, SMALL_KEY_FONT_SIZE, _enter)
	return UiStyle.make_button(key, KEY_FONT_SIZE, _type.bind(key))


func _type(digit: String) -> void:
	if _digits.length() < config.passcode_length:
		_digits += digit
		_refresh()


func _delete() -> void:
	_digits = _digits.left(-1)
	_refresh()


func _enter() -> void:
	if _digits.length() == config.passcode_length:
		entered.emit(_digits)


func _refresh() -> void:
	for i in _slots.size():
		_slots[i].text = _digits[i] if i < _digits.length() else ""
	_enter_button.disabled = _digits.length() < config.passcode_length
