class_name BattleScreen
extends Control
## ボット相手にローカルで遊ぶ対戦画面(GameDesign 3章・5章)。奥に相手、手前に自分の手。
## 進行は LocalMatch が持ち、この画面は実時間を固定 tick へ刻んで回し、シグナルを受けて表示を変えるだけ。
## 開発用の起動引数(`-- --replay=<記録の文字列>` / `-- --bot-vs-bot`)は Architecture 6章。

const HAND_CONFIG: HandConfig = preload("res://data/hand_config.tres")
const MATCH_CONFIG: MatchConfig = preload("res://data/match_config.tres")
const HAND_NAMES: HandNameTable = preload("res://data/hand_name_table.tres")
const HAND_EFFECTS: HandEffectTable = preload("res://data/hand_effect_table.tres")

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
## 効果の文の {target} に入れる呼び名。
const MY_CALL_NAME := "あなた"
const THEIR_CALL_NAME := "あいて"

const BACKGROUND_COLOR := Color("2b3a4a")
const TEXT_COLOR := Color.WHITE
const FOUL_COLOR := Color("ff6b5b")
const NAMED_COLOR := Color("ffd84a")
const OUTLINE_COLOR := Color("101820")
const OUTLINE_SIZE := 12
const CALL_FONT_SIZE := 96
const NAME_FONT_SIZE := 56
const EFFECT_FONT_SIZE := 30
const WINS_FONT_SIZE := 36
const RETRY_FONT_SIZE := 44
## 処理落ちしたとき1フレームで追いつく tick 数の上限(それ以上は遅れを捨てる)。
const MAX_TICKS_PER_FRAME := 8
const REPLAY_ARG := "--replay="
const BOT_VS_BOT_ARG := "--bot-vs-bot"
const MY_PLAYER := 0
const THEIR_PLAYER := 1

var _match: LocalMatch
var _bots: Array[HandBot] = []
var _replay: MatchReplay
var _seed_rng := RandomNumberGenerator.new()
var _unprocessed_seconds := 0.0
var _my_view: HandView
var _their_view: HandView
var _call_label: Label
var _my_name_label: Label
var _their_name_label: Label
var _my_effect_label: Label
var _their_effect_label: Label
var _their_tape: CensorTape
var _my_wins_label: Label
var _their_wins_label: Label
var _retry_button: Button


func _ready() -> void:
	_seed_rng.randomize()
	_match = LocalMatch.new(HAND_CONFIG, MATCH_CONFIG, HAND_NAMES, HAND_EFFECTS)
	_build()
	_setup_players(OS.get_cmdline_user_args())
	_match.round_started.connect(_on_round_started)
	_match.call_segment_changed.connect(_on_call_segment_changed)
	_match.hands_called.connect(_on_hands_called)
	_match.round_judged.connect(_on_round_judged)
	_match.match_finished.connect(_on_match_finished)
	_start_match()


func _process(delta: float) -> void:
	var max_seconds := LocalMatch.TICK_SECONDS * MAX_TICKS_PER_FRAME
	_unprocessed_seconds = minf(_unprocessed_seconds + delta, max_seconds)
	while _unprocessed_seconds >= LocalMatch.TICK_SECONDS:
		_unprocessed_seconds -= LocalMatch.TICK_SECONDS
		_tick()
	_my_view.interactive = _is_human_playing() and _match.can_operate()


func _setup_players(args: PackedStringArray) -> void:
	for arg in args:
		if arg.begins_with(REPLAY_ARG):
			var record := MatchRecord.from_text(arg.substr(REPLAY_ARG.length()))
			if record == null:
				push_error("リプレイの文字列を読めない")
			else:
				_replay = MatchReplay.new(_match, record)
				return
	if BOT_VS_BOT_ARG in args:
		_bots.append(HandBot.new(_match, MY_PLAYER, _seed_rng.randi()))
	_bots.append(HandBot.new(_match, THEIR_PLAYER, _seed_rng.randi()))


func _is_human_playing() -> bool:
	return _replay == null and _bots.size() < LocalMatch.PLAYER_COUNT


func _tick() -> void:
	if _replay != null:
		_replay.tick()
		return
	for bot in _bots:
		bot.think()
	_match.tick()


func _build() -> void:
	var background := ColorRect.new()
	background.color = BACKGROUND_COLOR
	_place(background, Rect2(0.0, 0.0, 1.0, 1.0))
	_their_view = _add_hand_view(_match.hands[THEIR_PLAYER], Rect2(0.0, 0.05, 1.0, 0.4))
	_my_view = _add_hand_view(_match.hands[MY_PLAYER], Rect2(0.0, 0.55, 1.0, 0.4))
	_my_view.finger_dragged.connect(_on_my_finger_dragged)
	_their_wins_label = _add_label(Rect2(0.04, 0.01, 0.92, 0.04), WINS_FONT_SIZE)
	_my_wins_label = _add_label(Rect2(0.04, 0.95, 0.92, 0.04), WINS_FONT_SIZE)
	_their_effect_label = _add_label(Rect2(0.0, 0.36, 1.0, 0.04), EFFECT_FONT_SIZE)
	_their_name_label = _add_label(Rect2(0.0, 0.4, 1.0, 0.06), NAME_FONT_SIZE)
	_their_tape = CensorTape.new()
	_place(_their_tape, Rect2(0.0, 0.4, 1.0, 0.06))
	_call_label = _add_label(Rect2(0.0, 0.46, 1.0, 0.08), CALL_FONT_SIZE)
	_my_name_label = _add_label(Rect2(0.0, 0.54, 1.0, 0.06), NAME_FONT_SIZE)
	_my_effect_label = _add_label(Rect2(0.0, 0.6, 1.0, 0.04), EFFECT_FONT_SIZE)
	_retry_button = Button.new()
	_retry_button.text = RETRY_TEXT
	_retry_button.add_theme_font_size_override("font_size", RETRY_FONT_SIZE)
	_retry_button.pressed.connect(_start_match)
	_place(_retry_button, Rect2(0.3, 0.66, 0.4, 0.07))


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
	if _replay != null:
		_replay.start()
	else:
		_match.start(_seed_rng.randi())


func _on_my_finger_dragged(finger: HandTypes.Finger, amount: float) -> void:
	_match.drag(MY_PLAYER, finger, amount)


func _on_round_started() -> void:
	_update_wins()
	_my_effect_label.text = ""
	_their_effect_label.text = ""
	_their_view.censored = _match.effects.is_censored(THEIR_PLAYER)


func _on_call_segment_changed(index: int) -> void:
	_call_label.text = MATCH_CONFIG.call_words[index]
	_my_name_label.text = ""
	_their_name_label.text = ""
	_their_tape.visible = false


func _on_hands_called(call: LocalMatch.RoundResult) -> void:
	_show_name(_my_name_label, call.my_name, call.my_shape)
	_their_tape.visible = _match.effects.is_censored(THEIR_PLAYER)
	var their_name := "" if _their_tape.visible else call.their_name
	_show_name(_their_name_label, their_name, call.their_shape)


func _on_round_judged(result: LocalMatch.RoundResult) -> void:
	_call_label.text = OUTCOME_TEXTS[result.outcome]
	_show_name(_my_name_label, result.my_name, result.my_shape)
	_show_name(_their_name_label, result.their_name, result.their_shape)
	_their_tape.visible = false
	_their_view.censored = false
	_my_effect_label.text = _effect_text(result.my_effect, THEIR_CALL_NAME)
	_their_effect_label.text = _effect_text(result.their_effect, MY_CALL_NAME)
	_update_wins()


func _on_match_finished(winner: int) -> void:
	_call_label.text = MATCH_WON_TEXT if winner == MY_PLAYER else MATCH_LOST_TEXT
	_retry_button.visible = true
	print("replay: ", _match.record.to_text())


func _show_name(label: Label, hand_name: String, shape: HandTypes.Shape) -> void:
	label.text = hand_name
	var color := TEXT_COLOR
	if shape == HandTypes.Shape.FOUL:
		color = FOUL_COLOR
	elif shape == HandTypes.Shape.NAMED:
		color = NAMED_COLOR
	label.add_theme_color_override("font_color", color)


func _effect_text(effect: HandEffect, target_name: String) -> String:
	if effect == null:
		return ""
	return effect.text.format({"target": target_name})


func _update_wins() -> void:
	_my_wins_label.text = MY_WINS_FORMAT % _match.state.wins[MY_PLAYER]
	_their_wins_label.text = THEIR_WINS_FORMAT % _match.state.wins[THEIR_PLAYER]
