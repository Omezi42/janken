class_name WaitingScreen
extends Control
## 相手を待つ(GameDesign 4章・9.3節)。Matchmaker を毎フレーム回し、「やめる」でタイトルへ。

signal cancelled

const SEARCHING_TEXT := "さがしています"
const PASSCODE_FORMAT := "合言葉 {passcode}"
const CANCEL_TEXT := "やめる"
## 「さがしています」の後ろで増えていく点の数と、1つ増える秒数。
const DOT := "."
const DOT_COUNT := 3
const DOT_SECONDS := 0.4
const SEARCHING_FONT_SIZE := 64
const PASSCODE_FONT_SIZE := 44
const CANCEL_FONT_SIZE := 48

const SEARCHING_RECT := Rect2(0.0, 0.4, 1.0, 0.08)
const PASSCODE_RECT := Rect2(0.0, 0.3, 1.0, 0.06)
const CANCEL_RECT := Rect2(0.28, 0.62, 0.44, 0.08)
const FULL_RECT := Rect2(0.0, 0.0, 1.0, 1.0)

## 追加する前に入れる。合言葉で待つときだけ passcode を入れる。
var matchmaker: Matchmaker
var passcode := ""
var _label: Label
var _seconds := 0.0


func _ready() -> void:
	UiStyle.place(self, BattleBackdrop.new(), FULL_RECT)
	if not passcode.is_empty():
		var text := PASSCODE_FORMAT.format({"passcode": passcode})
		UiStyle.place(self, UiStyle.make_label(text, PASSCODE_FONT_SIZE), PASSCODE_RECT)
	_label = UiStyle.make_label(SEARCHING_TEXT, SEARCHING_FONT_SIZE)
	UiStyle.place(self, _label, SEARCHING_RECT)
	UiStyle.place(self, UiStyle.make_button(CANCEL_TEXT, CANCEL_FONT_SIZE, _cancel), CANCEL_RECT)


func _process(delta: float) -> void:
	_seconds += delta
	_label.text = SEARCHING_TEXT + DOT.repeat(int(_seconds / DOT_SECONDS) % (DOT_COUNT + 1))
	matchmaker.poll()


func _cancel() -> void:
	matchmaker.cancel()
	cancelled.emit()
