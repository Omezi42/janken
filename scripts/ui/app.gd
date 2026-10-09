class_name App
extends Control
## 画面の流れ(GameDesign 9章、Architecture 6章)。画面を1つずつ子に置いて差し替える。
## 開発用の起動引数(`-- --replay=<記録の文字列>` / `-- --bot-vs-bot`)があればタイトルを飛ばしてひとりで練習を始める。
## `-- --server=<URL>` でつなぐサーバーを替える。

const MATCH_CONFIG: MatchConfig = preload("res://data/match_config.tres")
const HAND_NAMES: HandNameTable = preload("res://data/hand_name_table.tres")
const HAND_EFFECTS: HandEffectTable = preload("res://data/hand_effect_table.tres")
const HAND_RULES: HandRuleTable = preload("res://data/hand_rule_table.tres")
const ONLINE_CONFIG: OnlineConfig = preload("res://data/online_config.tres")

const SERVER_ARG := "--server="
const REPLAY_ARG := "--replay="
const BOT_VS_BOT_ARG := "--bot-vs-bot"
const NOTICE_TEXTS := {
	Matchmaker.Reason.UNREACHABLE: "サーバーにつながりません",
	Matchmaker.Reason.FULL: "その合言葉はいま使われています",
}
const MY_PLAYER := 0
const THEIR_PLAYER := 1
const FULL_RECT := Rect2(0.0, 0.0, 1.0, 1.0)

var _screen: Control
var _choice := TitleScreen.Choice.PRACTICE
var _passcode := ""
var _player_name := ""
## 名前が空のときに使う名前(起動ごとに1つ決める)。
var _default_name := ""
var _server_url := ONLINE_CONFIG.server_url
var _dev_args := PackedStringArray()
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_default_name = PlayerProfile.random_name(ONLINE_CONFIG, _rng)
	_player_name = _default_name
	var args := OS.get_cmdline_user_args()
	for arg in args:
		if arg.begins_with(SERVER_ARG):
			_server_url = arg.substr(SERVER_ARG.length())
		elif arg.begins_with(REPLAY_ARG) or arg == BOT_VS_BOT_ARG:
			_dev_args.append(arg)
	if _dev_args.is_empty():
		_show_title("")
	else:
		_start_practice()


func _show(screen: Control) -> void:
	if _screen != null:
		_screen.queue_free()
	_screen = screen
	UiStyle.place(self, screen, FULL_RECT)


func _show_title(notice: String) -> void:
	var title := TitleScreen.new()
	title.config = ONLINE_CONFIG
	title.saved_name = PlayerProfile.load_name()
	title.default_name = _default_name
	title.notice = notice
	title.chosen.connect(_on_title_chosen)
	_show(title)


func _on_title_chosen(choice: TitleScreen.Choice, entered_name: String) -> void:
	PlayerProfile.save_name(entered_name)
	_player_name = _default_name if entered_name.is_empty() else entered_name
	_choice = choice
	match choice:
		TitleScreen.Choice.RANDOM:
			_show_waiting()
		TitleScreen.Choice.PASSCODE:
			_show_passcode()
		TitleScreen.Choice.PRACTICE:
			_start_practice()


func _show_passcode() -> void:
	var screen := PasscodeScreen.new()
	screen.config = ONLINE_CONFIG
	screen.entered.connect(_on_passcode_entered)
	screen.back_requested.connect(_show_title.bind(""))
	_show(screen)


func _on_passcode_entered(passcode: String) -> void:
	_passcode = passcode
	_show_waiting()


## 同じ探し方でもう一度待つ(GameDesign 9.4節)。
func _show_waiting() -> void:
	var matchmaker := Matchmaker.new(_server_url, _player_name, ONLINE_CONFIG)
	matchmaker.matched.connect(_start_online)
	matchmaker.failed.connect(
		func(reason: Matchmaker.Reason) -> void: _show_title(NOTICE_TEXTS[reason])
	)
	var screen := WaitingScreen.new()
	screen.matchmaker = matchmaker
	screen.cancelled.connect(_show_title.bind(""))
	if _choice == TitleScreen.Choice.PASSCODE:
		screen.passcode = _passcode
		matchmaker.join_passcode(_passcode)
	else:
		matchmaker.find_random()
	_show(screen)


func _start_online(net: NetClient, opponent: String) -> void:
	var game := OnlineMatch.new(net, MATCH_CONFIG, HAND_NAMES, HAND_RULES, _player_name, opponent)
	var bots: Array[HandBot] = []
	_show_battle(game, bots, null)


func _start_practice() -> void:
	var game := LocalMatch.new(MATCH_CONFIG, HAND_NAMES, HAND_EFFECTS, HAND_RULES)
	game.player_names = PackedStringArray([_player_name, ONLINE_CONFIG.bot_name])
	var bots: Array[HandBot] = []
	for arg in _dev_args:
		if arg.begins_with(REPLAY_ARG):
			var record := MatchRecord.from_text(arg.substr(REPLAY_ARG.length()))
			if record == null:
				push_error("リプレイの文字列を読めない")
			else:
				_show_battle(game, bots, MatchReplay.new(game, record))
				return
	if BOT_VS_BOT_ARG in _dev_args:
		bots.append(HandBot.new(game, MY_PLAYER, _rng.randi()))
	bots.append(HandBot.new(game, THEIR_PLAYER, _rng.randi()))
	_show_battle(game, bots, null)


func _show_battle(game: MatchSession, bots: Array[HandBot], replay: MatchReplay) -> void:
	var battle := BattleScreen.new()
	battle.setup(game, bots, replay)
	battle.retry_requested.connect(_on_retry)
	battle.title_requested.connect(_on_back_to_title.bind(game))
	_show(battle)


func _on_retry() -> void:
	if _choice == TitleScreen.Choice.PRACTICE:
		_start_practice()
	else:
		_show_waiting()


func _on_back_to_title(game: MatchSession) -> void:
	if game is OnlineMatch:
		(game as OnlineMatch).close()
	_show_title("")
