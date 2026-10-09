class_name TitleScreen
extends Control
## タイトル(GameDesign 9.1節・9.2節)。名前の入力と、ランダムマッチ・合言葉・一人で練習。

## entered_name は入力された名前(空のこともある)。
signal chosen(choice: Choice, entered_name: String)

enum Choice { RANDOM, PASSCODE, PRACTICE }

const TITLE_TEXT := "じゃんけん"
const NAME_CAPTION := "名前"
const CHOICE_TEXTS := {
	Choice.RANDOM: "ランダムマッチ",
	Choice.PASSCODE: "合言葉",
	Choice.PRACTICE: "一人で練習",
}
const TITLE_FONT_SIZE := 120
const CAPTION_FONT_SIZE := 36
const NAME_FONT_SIZE := 48
const BUTTON_FONT_SIZE := 52
const NOTICE_FONT_SIZE := 34
const NOTICE_COLOR := Color("ffd84a")
const NAME_BOX_COLOR := Color("fff6e0")
const NAME_TEXT_COLOR := Color("3b2416")
const NAME_PLACEHOLDER_COLOR := Color("a08a70")
const NAME_PADDING := 16

const TITLE_RECT := Rect2(0.0, 0.1, 1.0, 0.12)
const NOTICE_RECT := Rect2(0.0, 0.26, 1.0, 0.05)
const CAPTION_RECT := Rect2(0.15, 0.33, 0.7, 0.04)
const NAME_RECT := Rect2(0.15, 0.375, 0.7, 0.065)
const FIRST_BUTTON_RECT := Rect2(0.18, 0.52, 0.64, 0.08)
## ボタンどうしの縦の間隔(画面に対する比)。
const BUTTON_STEP := 0.11
const FULL_RECT := Rect2(0.0, 0.0, 1.0, 1.0)

## 追加する前に入れる。
var config: OnlineConfig
var saved_name := ""
## 名前が空のときに使う名前。入力欄の薄い字にも出す。
var default_name := ""
## タイトルへ戻った理由(つながらない等)。空なら出さない。
var notice := ""
var _name_edit: LineEdit


func _ready() -> void:
	UiStyle.place(self, BattleBackdrop.new(), FULL_RECT)
	UiStyle.place(self, UiStyle.make_label(TITLE_TEXT, TITLE_FONT_SIZE), TITLE_RECT)
	if not notice.is_empty():
		UiStyle.place(self, UiStyle.make_label(notice, NOTICE_FONT_SIZE, NOTICE_COLOR), NOTICE_RECT)
	UiStyle.place(self, UiStyle.make_label(NAME_CAPTION, CAPTION_FONT_SIZE), CAPTION_RECT)
	_name_edit = _make_name_edit()
	UiStyle.place(self, _name_edit, NAME_RECT)
	var rect := FIRST_BUTTON_RECT
	for choice: Choice in CHOICE_TEXTS:
		UiStyle.place(
			self,
			UiStyle.make_button(CHOICE_TEXTS[choice], BUTTON_FONT_SIZE, _choose.bind(choice)),
			rect
		)
		rect.position.y += BUTTON_STEP


func _make_name_edit() -> LineEdit:
	var edit := LineEdit.new()
	edit.max_length = config.name_max_length
	edit.text = saved_name
	edit.placeholder_text = default_name
	edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	edit.add_theme_font_size_override("font_size", NAME_FONT_SIZE)
	edit.add_theme_color_override("font_color", NAME_TEXT_COLOR)
	edit.add_theme_color_override("font_placeholder_color", NAME_PLACEHOLDER_COLOR)
	edit.add_theme_color_override("caret_color", NAME_TEXT_COLOR)
	for style_name in ["normal", "focus", "read_only"]:
		var style := UiStyle.box(NAME_BOX_COLOR)
		style.set_content_margin_all(NAME_PADDING)
		edit.add_theme_stylebox_override(style_name, style)
	return edit


func _choose(choice: Choice) -> void:
	chosen.emit(choice, PlayerProfile.clean_name(_name_edit.text, config))
