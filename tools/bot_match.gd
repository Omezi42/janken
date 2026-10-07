extends SceneTree
## 画面なしでゲームロジックだけを回す(Architecture 4.1節)。
##   ボット同士: godot --headless --path . --script res://tools/bot_match.gd -- --matches=10 --seed=1
##   リプレイ:   godot --headless --path . --script res://tools/bot_match.gd -- --replay=<記録の文字列>
## 各試合のラウンドごとの手と、試合を再現する記録の文字列を出す。

const DEFAULT_MATCHES := 1
const DEFAULT_SEED := 1
## 1試合の tick の上限(あいこが続いても止まるように)。
const MAX_TICKS := LocalMatch.TICKS_PER_SECOND * 600
const OUTCOME_LABELS := {
	HandTypes.Outcome.WIN: "P0勝ち",
	HandTypes.Outcome.LOSE: "P1勝ち",
	HandTypes.Outcome.DRAW: "あいこ",
}

var _match_config: MatchConfig = load("res://data/match_config.tres")
var _names: HandNameTable = load("res://data/hand_name_table.tres")
var _effects: HandEffectTable = load("res://data/hand_effect_table.tres")
var _rules: HandRuleTable = load("res://data/hand_rule_table.tres")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var options := _parse_options(OS.get_cmdline_user_args())
	if options.has("replay"):
		var record := MatchRecord.from_text(options["replay"])
		if record == null:
			printerr("リプレイの文字列を読めない")
			quit(1)
			return
		_play_replay(record)
	else:
		var first_seed := int(options.get("seed", DEFAULT_SEED))
		for i in int(options.get("matches", DEFAULT_MATCHES)):
			_play_bots(first_seed + i)
	quit(0)


func _play_bots(match_seed: int) -> void:
	var game := _new_match()
	var bots: Array[HandBot] = []
	for player in LocalMatch.PLAYER_COUNT:
		bots.append(HandBot.new(game, player, match_seed * LocalMatch.PLAYER_COUNT + player))
	print("== seed %d" % match_seed)
	game.start(match_seed)
	while game.phase != LocalMatch.Phase.OVER and game.tick_count < MAX_TICKS:
		for bot in bots:
			bot.think()
		game.tick()
	_print_summary(game)


func _play_replay(record: MatchRecord) -> void:
	var game := _new_match()
	var replay := MatchReplay.new(game, record)
	print("== replay seed %d" % record.seed)
	replay.start()
	while not replay.is_finished() and game.tick_count < MAX_TICKS:
		replay.tick()
	_print_summary(game)


func _new_match() -> LocalMatch:
	var game := LocalMatch.new(_match_config, _names, _effects, _rules)
	game.round_judged.connect(_print_round)
	return game


func _print_round(result: LocalMatch.RoundResult) -> void:
	print("  %s / %s → %s" % [result.my_name, result.their_name, OUTCOME_LABELS[result.outcome]])


func _print_summary(game: LocalMatch) -> void:
	print(
		(
			"  勝者 P%d  %d-%d  %d tick"
			% [game.state.winner(), game.state.wins[0], game.state.wins[1], game.tick_count]
		)
	)
	print("  record: ", game.record.to_text())


## "--key=value" を {key: value}、"--flag" を {flag: ""} にする。
func _parse_options(args: PackedStringArray) -> Dictionary:
	var options := {}
	for arg in args:
		var pair := arg.trim_prefix("--").split("=", true, 1)
		options[pair[0]] = pair[1] if pair.size() > 1 else ""
	return options
