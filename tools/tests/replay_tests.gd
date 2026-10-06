extends RefCounted
## 決定論とリプレイ(Architecture 4.1節)。同じ seed と記録から、ボット無しで同じ試合が再現されること。

const SEED := 7
const MAX_MATCH_TICKS := LocalMatch.TICKS_PER_SECOND * 600

var _match_config: MatchConfig = load("res://data/match_config.tres")
var _names: HandNameTable = load("res://data/hand_name_table.tres")
var _effects: HandEffectTable = load("res://data/hand_effect_table.tres")


func run(assert_true: Callable) -> void:
	var original := _play_bots(SEED)
	var again := _play_bots(SEED)
	assert_true.call(
		original["record"].to_text() == again["record"].to_text(), "同じ seed のボット戦は同じ記録になる"
	)
	assert_true.call(original["names"] == again["names"], "同じ seed のボット戦は同じ手になる")

	var text: String = original["record"].to_text()
	var parsed := MatchRecord.from_text(text)
	assert_true.call(parsed != null, "記録の文字列を読み戻せる (%d文字)" % text.length())
	if parsed == null:
		return
	var replayed := _play_replay(parsed)
	assert_true.call(replayed["names"] == original["names"], "リプレイは全ラウンドの手の名前が一致する")
	assert_true.call(replayed["wins"] == original["wins"], "リプレイは勝利数が一致する")
	assert_true.call(replayed["states"] == original["states"], "リプレイは最後の指の状態が一致する")
	assert_true.call(replayed["record"].to_text() == text, "リプレイを記録し直すと同じ文字列になる")

	assert_true.call(MatchRecord.from_text("") == null, "空文字は読まない")
	assert_true.call(MatchRecord.from_text(MatchRecord.TEXT_PREFIX + "!!!!") == null, "壊れた文字列は読まない")
	var old_prefix := "JK%d." % (MatchRecord.FORMAT_VERSION - 1)
	var old_text := old_prefix + text.substr(MatchRecord.TEXT_PREFIX.length())
	assert_true.call(MatchRecord.from_text(old_text) == null, "版の違う文字列は読まない")
	assert_true.call(MatchRecord.from_text(" %s\n" % text) != null, "前後の空白・改行は無視する")


func _new_match(log: Dictionary) -> LocalMatch:
	var game := LocalMatch.new(_match_config, _names, _effects)
	log["names"] = []
	game.round_judged.connect(
		func(result: LocalMatch.RoundResult) -> void:
			log["names"].append([result.my_name, result.their_name])
	)
	return game


func _play_bots(match_seed: int) -> Dictionary:
	var log := {}
	var game := _new_match(log)
	var bots: Array[HandBot] = []
	for player in LocalMatch.PLAYER_COUNT:
		bots.append(HandBot.new(game, player, match_seed + player))
	game.start(match_seed)
	while game.phase != LocalMatch.Phase.OVER and game.tick_count < MAX_MATCH_TICKS:
		for bot in bots:
			bot.think()
		game.tick()
	return _finish(log, game)


func _play_replay(record: MatchRecord) -> Dictionary:
	var log := {}
	var game := _new_match(log)
	var replay := MatchReplay.new(game, record)
	replay.start()
	while not replay.is_finished() and game.tick_count < MAX_MATCH_TICKS:
		replay.tick()
	return _finish(log, game)


func _finish(log: Dictionary, game: LocalMatch) -> Dictionary:
	log["wins"] = game.state.wins.duplicate()
	log["states"] = [game.hands[0].states.duplicate(), game.hands[1].states.duplicate()]
	log["record"] = game.record
	return log
