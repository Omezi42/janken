class_name BattleScreen
extends Control
## ボット相手にローカルで遊ぶ対戦画面(GameDesign 3章・5章)。奥に相手、手前に自分の手。
## 進行は LocalMatch が持ち、この画面はシグナルを受けて表示を変えるだけ。

const HAND_CONFIG: HandConfig = preload("res://data/hand_config.tres")
const MATCH_CONFIG: MatchConfig = preload("res://data/match_config.tres")
const FOUL_NAMES: FoulNameTable = preload("res://data/foul_name_table.tres")

const OUTCOME_TEXTS := {
	HandTypes.Outcome.WIN: "かち!",
	HandTypes.Outcome.LOSE: "まけ…",
	HandTypes.Outcome.DRAW: "あいこ",
}
const MATCH_WON_TEXT := "あなたの勝ち!"
const MATCH_LOST_TEXT := "あなたの負け…"
const RETRY_TEXT := "もう一度"
const MY_WINS_FORMAT := "あなた %d勝"
const THEIR_WINS_FORMAT := "あいて %d勝"

const BACKGROUND_COLOR := Color("2b3a4a")
const TEXT_COLOR := Color.WHITE
const FOUL_COLOR := Color("ff6b5b")
const OUTLINE_COLOR := Color("101820")
const OUTLINE_SIZE := 12
const CALL_FONT_SIZE := 96
const NAME_FONT_SIZE := 56
const WINS_FONT_SIZE := 36
const RETRY_FONT_SIZE := 44

var _match: LocalMatch
var _my_view: HandView
var _their_view: HandView
var _call_label: Label
var _my_name_label: Label
var _their_name_label: Label
var _my_wins_label: Label
var _their_wins_label: Label
var _retry_button: Button


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	_match = LocalMatch.new(HAND_CONFIG, MATCH_CONFIG, FOUL_NAMES, rng)
	_build()
	_match.round_started.connect(_on_round_started)
	_match.call_segment_changed.connect(_on_call_segment_changed)
	_match.round_judged.connect(_on_round_judged)
	_match.match_finished.connect(_on_match_finished)
	_start_match()


func _process(delta: float) -> void:
	_match.advance(delta)
	_my_view.interactive = _match.can_operate()


func _build() -> void:
	var background := ColorRect.new()
	background.color = BACKGROUND_COLOR
	_place(background, Rect2(0.0, 0.0, 1.0, 1.0))
	_their_view = _add_hand_view(_match.their_hand, Rect2(0.0, 0.05, 1.0, 0.4))
	_my_view = _add_hand_view(_match.my_hand, Rect2(0.0, 0.55, 1.0, 0.4))
	_their_wins_label = _add_label(Rect2(0.04, 0.01, 0.92, 0.04), WINS_FONT_SIZE)
	_my_wins_label = _add_label(Rect2(0.04, 0.95, 0.92, 0.04), WINS_FONT_SIZE)
	_their_name_label = _add_label(Rect2(0.0, 0.4, 1.0, 0.06), NAME_FONT_SIZE)
	_call_label = _add_label(Rect2(0.0, 0.46, 1.0, 0.08), CALL_FONT_SIZE)
	_my_name_label = _add_label(Rect2(0.0, 0.54, 1.0, 0.06), NAME_FONT_SIZE)
	_retry_button = Button.new()
	_retry_button.text = RETRY_TEXT
	_retry_button.add_theme_font_size_override("font_size", RETRY_FONT_SIZE)
	_retry_button.pressed.connect(_start_match)
	_place(_retry_button, Rect2(0.3, 0.62, 0.4, 0.07))


func _add_hand_view(model: HandModel, rect: Rect2) -> HandView:
	var view := HandView.new()
	view.bind(model)
	_place(view, rect)
	return view


func _add_label(rect: Rect2, font_size: int) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_outline_color", OUTLINE_COLOR)
	label.add_theme_constant_override("outline_size", OUTLINE_SIZE)
	_place(label, rect)
	return label


## rect は画面に対する比(位置と大きさ)。
func _place(control: Control, rect: Rect2) -> void:
	control.anchor_left = rect.position.x
	control.anchor_top = rect.position.y
	control.anchor_right = rect.end.x
	control.anchor_bottom = rect.end.y
	add_child(control)


func _start_match() -> void:
	_retry_button.visible = false
	_match.start()


func _on_round_started() -> void:
	_my_name_label.text = ""
	_their_name_label.text = ""
	_update_wins()


func _on_call_segment_changed(index: int) -> void:
	_call_label.text = MATCH_CONFIG.call_words[index]


func _on_round_judged(result: LocalMatch.RoundResult) -> void:
	_call_label.text = OUTCOME_TEXTS[result.outcome]
	_show_name(_my_name_label, result.my_name, result.my_shape)
	_show_name(_their_name_label, result.their_name, result.their_shape)
	_update_wins()


func _on_match_finished(winner: int) -> void:
	_call_label.text = MATCH_WON_TEXT if winner == 0 else MATCH_LOST_TEXT
	_retry_button.visible = true


func _show_name(label: Label, hand_name: String, shape: HandTypes.Shape) -> void:
	label.text = hand_name
	var color := FOUL_COLOR if shape == HandTypes.Shape.FOUL else TEXT_COLOR
	label.add_theme_color_override("font_color", color)


func _update_wins() -> void:
	_my_wins_label.text = MY_WINS_FORMAT % _match.state.wins[0]
	_their_wins_label.text = THEIR_WINS_FORMAT % _match.state.wins[1]
