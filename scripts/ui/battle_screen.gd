class_name BattleScreen
extends Control
## ボット相手にローカルで遊ぶ対戦画面(GameDesign 3章・5章・8章)。奥に相手、手前に自分の手。
## 進行は LocalMatch が持ち、この画面は実時間を固定 tick へ刻んで回し、シグナルを受けて表示と演出を変えるだけ。
## 開発用の起動引数(`-- --replay=<記録の文字列>` / `-- --bot-vs-bot`)は Architecture 6章。

const MATCH_CONFIG: MatchConfig = preload("res://data/match_config.tres")
const HAND_NAMES: HandNameTable = preload("res://data/hand_name_table.tres")
const HAND_EFFECTS: HandEffectTable = preload("res://data/hand_effect_table.tres")

const OUTCOME_TEXTS := {
	HandTypes.Outcome.WIN: "かち!",
	HandTypes.Outcome.LOSE: "まけ…",
	HandTypes.Outcome.DRAW: "あいこ",
}
const OUTCOME_COLORS := {
	HandTypes.Outcome.WIN: Color("ffd84a"),
	HandTypes.Outcome.LOSE: Color("9cc2ff"),
	HandTypes.Outcome.DRAW: Color.WHITE,
}
## 相手から見た勝敗。
const FLIPPED_OUTCOMES := {
	HandTypes.Outcome.WIN: HandTypes.Outcome.LOSE,
	HandTypes.Outcome.LOSE: HandTypes.Outcome.WIN,
	HandTypes.Outcome.DRAW: HandTypes.Outcome.DRAW,
}
const MATCH_WON_TEXT := "あなたの勝ち!"
const MATCH_LOST_TEXT := "あなたの負け…"
const RETRY_TEXT := "もう一度"
## 星の横の呼び名と、効果の文の {target} に入れる呼び名。
const MY_CALL_NAME := "あなた"
const THEIR_CALL_NAME := "あいて"

const TEXT_COLOR := Color.WHITE
const NAMED_COLOR := Color("ffd84a")
const MY_SLEEVE_COLOR := Color("ff8a3d")
const THEIR_SLEEVE_COLOR := Color("3d8bff")
const CALL_FONT_SIZE := 104
const NAME_FONT_SIZE := 60
const EFFECT_FONT_SIZE := 30
const RETRY_FONT_SIZE := 44
const RETRY_COLOR := Color("ffd84a")
const RETRY_HOVER_COLOR := Color("ffe680")
const RETRY_TEXT_COLOR := Color("3b2416")
const RETRY_CORNER := 24
const RETRY_BORDER := 6
## 判定の瞬間の画面の揺れ(ピクセル・秒)。
const SHAKE_STRENGTH := 18.0
const SHAKE_SECONDS := 0.3

## 配置(画面に対する比。位置と大きさ)。
const THEIR_HAND_RECT := Rect2(0.0, 0.02, 1.0, 0.44)
const MY_HAND_RECT := Rect2(0.0, 0.54, 1.0, 0.44)
const THEIR_STARS_RECT := Rect2(0.04, 0.008, 0.92, 0.035)
const MY_STARS_RECT := Rect2(0.04, 0.957, 0.92, 0.035)
const THEIR_EFFECT_RECT := Rect2(0.0, 0.392, 1.0, 0.035)
const THEIR_NAME_RECT := Rect2(0.0, 0.425, 1.0, 0.05)
const CALL_RECT := Rect2(0.0, 0.468, 1.0, 0.07)
const LAMPS_RECT := Rect2(0.3, 0.537, 0.4, 0.016)
const MY_NAME_RECT := Rect2(0.0, 0.556, 1.0, 0.05)
const MY_EFFECT_RECT := Rect2(0.0, 0.604, 1.0, 0.035)
const RETRY_RECT := Rect2(0.28, 0.66, 0.44, 0.075)
const FULL_RECT := Rect2(0.0, 0.0, 1.0, 1.0)

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
var _fx_rng := RandomNumberGenerator.new()
var _unprocessed_seconds := 0.0
var _shake_left := 0.0
var _backdrop: BattleBackdrop
var _stage: Control
var _flash: ScreenFlash
var _my_view: HandView
var _their_view: HandView
var _call_label: StampLabel
var _lamps: BeatLamps
var _my_name_label: StampLabel
var _their_name_label: StampLabel
var _my_effect_label: StampLabel
var _their_effect_label: StampLabel
var _their_tape: CensorTape
var _my_stars: WinStars
var _their_stars: WinStars
var _retry_button: Button


func _ready() -> void:
	_seed_rng.randomize()
	_fx_rng.randomize()
	_match = LocalMatch.new(MATCH_CONFIG, HAND_NAMES, HAND_EFFECTS)
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
	_shake(delta)


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


func _shake(delta: float) -> void:
	if _shake_left <= 0.0:
		return
	_shake_left = maxf(_shake_left - delta, 0.0)
	var strength := SHAKE_STRENGTH * _shake_left / SHAKE_SECONDS
	_stage.position = (
		Vector2(_fx_rng.randf_range(-1.0, 1.0), _fx_rng.randf_range(-1.0, 1.0)) * strength
	)


func _build() -> void:
	_backdrop = BattleBackdrop.new()
	_place(self, _backdrop, FULL_RECT)
	_stage = Control.new()
	_stage.mouse_filter = MOUSE_FILTER_IGNORE
	_place(self, _stage, FULL_RECT)
	_their_view = _add_hand_view(_match.hands[THEIR_PLAYER], THEIR_HAND_RECT, THEIR_SLEEVE_COLOR)
	_their_view.facing_down = true
	_their_view.mouse_filter = MOUSE_FILTER_IGNORE
	_my_view = _add_hand_view(_match.hands[MY_PLAYER], MY_HAND_RECT, MY_SLEEVE_COLOR)
	_my_view.finger_flipped.connect(_on_my_finger_flipped)
	_their_effect_label = _add_label(THEIR_EFFECT_RECT, EFFECT_FONT_SIZE)
	_their_name_label = _add_label(THEIR_NAME_RECT, NAME_FONT_SIZE)
	_their_tape = CensorTape.new()
	_place(_stage, _their_tape, THEIR_NAME_RECT)
	_call_label = _add_label(CALL_RECT, CALL_FONT_SIZE)
	_lamps = BeatLamps.new()
	_lamps.count = MATCH_CONFIG.call_words.size()
	_place(_stage, _lamps, LAMPS_RECT)
	_my_name_label = _add_label(MY_NAME_RECT, NAME_FONT_SIZE)
	_my_effect_label = _add_label(MY_EFFECT_RECT, EFFECT_FONT_SIZE)
	_their_stars = _add_stars(THEIR_STARS_RECT, THEIR_CALL_NAME)
	_my_stars = _add_stars(MY_STARS_RECT, MY_CALL_NAME)
	_retry_button = _make_retry_button()
	_place(_stage, _retry_button, RETRY_RECT)
	_flash = ScreenFlash.new()
	_place(self, _flash, FULL_RECT)


func _add_hand_view(model: HandModel, rect: Rect2, sleeve: Color) -> HandView:
	var view := HandView.new()
	view.bind(model)
	view.sleeve_color = sleeve
	_place(_stage, view, rect)
	return view


func _add_label(rect: Rect2, font_size: int) -> StampLabel:
	var label := StampLabel.new()
	_place(_stage, label, rect)
	label.setup(font_size)
	return label


func _add_stars(rect: Rect2, caption: String) -> WinStars:
	var stars := WinStars.new()
	stars.caption = caption
	stars.total = MATCH_CONFIG.wins_to_finish
	_place(self, stars, rect)
	return stars


func _make_retry_button() -> Button:
	var button := Button.new()
	button.text = RETRY_TEXT
	button.add_theme_font_size_override("font_size", RETRY_FONT_SIZE)
	for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(color_name, RETRY_TEXT_COLOR)
	button.add_theme_stylebox_override("normal", _button_box(RETRY_COLOR))
	button.add_theme_stylebox_override("hover", _button_box(RETRY_HOVER_COLOR))
	button.add_theme_stylebox_override("pressed", _button_box(RETRY_COLOR.darkened(0.15)))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.pressed.connect(_start_match)
	return button


func _button_box(color: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = StampLabel.OUTLINE_COLOR
	box.set_border_width_all(RETRY_BORDER)
	box.set_corner_radius_all(RETRY_CORNER)
	box.anti_aliasing = true
	return box


## rect は画面に対する比(位置と大きさ)。
func _place(parent: Control, control: Control, rect: Rect2) -> void:
	control.anchor_left = rect.position.x
	control.anchor_top = rect.position.y
	control.anchor_right = rect.end.x
	control.anchor_bottom = rect.end.y
	parent.add_child(control)


func _start_match() -> void:
	_retry_button.visible = false
	if _replay != null:
		_replay.start()
	else:
		_match.start(_seed_rng.randi())


func _on_my_finger_flipped(finger: HandTypes.Finger) -> void:
	_match.flip(MY_PLAYER, finger)


func _on_round_started() -> void:
	_update_wins()
	_my_effect_label.clear()
	_their_effect_label.clear()
	_their_view.censored = _match.effects.is_censored(THEIR_PLAYER)
	_my_view.reset_pose()
	_their_view.reset_pose()


func _on_call_segment_changed(index: int) -> void:
	var word := MATCH_CONFIG.call_words[index]
	if word.is_empty():
		_call_label.clear()
	else:
		_call_label.pop(word, TEXT_COLOR)
	_my_name_label.clear()
	_their_name_label.clear()
	_their_tape.visible = false
	_lamps.lit = index + 1
	_my_view.beat()
	_their_view.beat()


func _on_hands_called(call: LocalMatch.RoundResult) -> void:
	_stamp_name(_my_name_label, call.my_name, call.my_shape)
	_their_tape.visible = _match.effects.is_censored(THEIR_PLAYER)
	if not _their_tape.visible:
		_stamp_name(_their_name_label, call.their_name, call.their_shape)


func _on_round_judged(result: LocalMatch.RoundResult) -> void:
	_flash.flash()
	_backdrop.burst()
	_shake_left = SHAKE_SECONDS
	_call_label.stamp(OUTCOME_TEXTS[result.outcome], OUTCOME_COLORS[result.outcome])
	_stamp_name(_my_name_label, result.my_name, result.my_shape)
	_stamp_name(_their_name_label, result.their_name, result.their_shape)
	_their_tape.visible = false
	_their_view.censored = false
	_show_effect(_my_effect_label, result.my_effect, THEIR_CALL_NAME)
	_show_effect(_their_effect_label, result.their_effect, MY_CALL_NAME)
	_my_view.show_result(result.outcome)
	_their_view.show_result(FLIPPED_OUTCOMES[result.outcome])
	_update_wins()


func _on_match_finished(winner: int) -> void:
	var won := winner == MY_PLAYER
	var outcome := HandTypes.Outcome.WIN if won else HandTypes.Outcome.LOSE
	_call_label.stamp(MATCH_WON_TEXT if won else MATCH_LOST_TEXT, OUTCOME_COLORS[outcome])
	_retry_button.visible = true
	print("replay: ", _match.record.to_text())


func _stamp_name(label: StampLabel, hand_name: String, shape: HandTypes.Shape) -> void:
	label.stamp(hand_name, NAMED_COLOR if shape == HandTypes.Shape.NAMED else TEXT_COLOR)


func _show_effect(label: StampLabel, effect: HandEffect, target_name: String) -> void:
	if effect == null:
		label.clear()
	else:
		label.pop(effect.text.format({"target": target_name}), NAMED_COLOR)


func _update_wins() -> void:
	_my_stars.won = _match.state.wins[MY_PLAYER]
	_their_stars.won = _match.state.wins[THEIR_PLAYER]
