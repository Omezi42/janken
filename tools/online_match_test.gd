extends SceneTree
## ローカルのサーバーへ2クライアントをつなぎ、ボット同士で試合を通す(Architecture 3.4節)。
## godot --headless --path . --script res://tools/online_match_test.gd
##   -- --server=ws://127.0.0.1:8787

const MATCH_CONFIG: MatchConfig = preload("res://data/match_config.tres")
const HAND_NAMES: HandNameTable = preload("res://data/hand_name_table.tres")
const HAND_RULES: HandRuleTable = preload("res://data/hand_rule_table.tres")
const ONLINE_CONFIG: OnlineConfig = preload("res://data/online_config.tres")
const SERVER_ARG := "--server="
const MATCH_TIMEOUT_MSEC := 180000
const STEP_TIMEOUT_MSEC := 15000
const PASSCODE_DIGITS := 10000
const NO_REASON := -1
const FLIPPED := {
	HandTypes.Outcome.WIN: HandTypes.Outcome.LOSE,
	HandTypes.Outcome.LOSE: HandTypes.Outcome.WIN,
	HandTypes.Outcome.DRAW: HandTypes.Outcome.DRAW,
}


class Client:
	var player_name: String
	var maker: Matchmaker
	var game: OnlineMatch
	var bot: HandBot
	var bot_seed: int
	var results: Array[MatchSession.RoundResult] = []
	var winner := MatchState.NO_WINNER
	var failed_reason := NO_REASON
	var lost := false
	var _unprocessed := 0.0

	func _init(client_name: String, server_url: String, seed_value: int) -> void:
		player_name = client_name
		bot_seed = seed_value
		maker = Matchmaker.new(server_url, client_name, ONLINE_CONFIG)
		maker.matched.connect(_on_matched)
		maker.failed.connect(func(reason: Matchmaker.Reason) -> void: failed_reason = reason)

	func is_finished() -> bool:
		return winner != MatchState.NO_WINNER or lost

	func step(delta: float) -> void:
		maker.poll()
		if game == null:
			return
		_unprocessed += delta
		while _unprocessed >= MatchSession.TICK_SECONDS:
			_unprocessed -= MatchSession.TICK_SECONDS
			bot.think()
			game.tick()

	func _on_matched(net: NetClient, opponent: String) -> void:
		game = OnlineMatch.new(net, MATCH_CONFIG, HAND_NAMES, HAND_RULES, player_name, opponent)
		bot = HandBot.new(game, OnlineMatch.MY_PLAYER, bot_seed)
		game.round_judged.connect(
			func(result: MatchSession.RoundResult) -> void: results.append(result)
		)
		game.match_finished.connect(func(w: int) -> void: winner = w)
		game.connection_lost.connect(func() -> void: lost = true)


var _server_url := ONLINE_CONFIG.server_url
var _failures := 0
var _checks := 0
var _last_msec := 0


func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with(SERVER_ARG):
			_server_url = arg.substr(SERVER_ARG.length())
	call_deferred("_run")


func _run() -> void:
	await _random_match()
	await _passcode_full_and_leave()
	if _failures > 0:
		printerr("online tests FAILED: ", _failures, " / ", _checks)
		quit(1)
		return
	print("online tests passed: ", _checks)
	quit(0)


func _random_match() -> void:
	var a := Client.new("あいうえおかきくけこ", _server_url, 1)
	var b := Client.new("B", _server_url, 2)
	a.maker.find_random()
	b.maker.find_random()
	var ok := await _pump(
		[a, b], func() -> bool: return a.is_finished() and b.is_finished(), MATCH_TIMEOUT_MSEC
	)
	_check(ok, "ランダムマッチで1試合が終わる")
	if not ok:
		return
	_check(not a.lost and not b.lost, "接続が切れない")
	_check(a.game.player_names[1] == "B", "相手の名前が届く")
	_check(b.game.player_names[1].length() == ONLINE_CONFIG.name_max_length, "名前は最大文字数で切られる")
	_check(a.winner != b.winner, "勝者が両者で一致する")
	_check(a.game.state.wins == [b.game.state.wins[1], b.game.state.wins[0]], "勝利数が裏返しで一致する")
	_check(a.results.size() == b.results.size(), "ラウンド数が一致する")
	for i in mini(a.results.size(), b.results.size()):
		var mine := a.results[i]
		var theirs := b.results[i]
		_check(FLIPPED[mine.outcome] == theirs.outcome, "ラウンド%dの勝敗が裏返しで一致する" % i)
		_check(mine.my_name == theirs.their_name, "ラウンド%dの手の名前が一致する" % i)
		var local := RoundRules.outcome(mine.my_states, mine.their_states, a.game.judge)
		_check(local == mine.outcome, "ラウンド%dの部屋の判定が手元の判定と一致する" % i)
	print("random match: rounds=", a.results.size(), " wins=", a.game.state.wins)


func _passcode_full_and_leave() -> void:
	var passcode := "%04d" % (Time.get_ticks_usec() % PASSCODE_DIGITS)
	var a := Client.new("A", _server_url, 3)
	var b := Client.new("B", _server_url, 4)
	a.maker.join_passcode(passcode)
	var a_waiting := func() -> bool: return a.maker != null and a.game == null
	await _pump([a], a_waiting, STEP_TIMEOUT_MSEC)
	b.maker.join_passcode(passcode)
	var both := func() -> bool: return a.game != null and b.game != null
	_check(await _pump([a, b], both, STEP_TIMEOUT_MSEC), "同じ合言葉の2人が組まれる")
	if not both.call():
		return
	var c := Client.new("C", _server_url, 5)
	c.maker.join_passcode(passcode)
	var c_failed := func() -> bool: return c.failed_reason != NO_REASON
	_check(await _pump([a, b, c], c_failed, STEP_TIMEOUT_MSEC), "3人目は断られる")
	_check(c.failed_reason == Matchmaker.Reason.FULL, "3人目の理由はふさがっている")
	var calling := func() -> bool: return a.game.can_operate() and b.game.can_operate()
	_check(await _pump([a, b], calling, STEP_TIMEOUT_MSEC), "掛け声が始まる")
	a.game.close()
	_check(await _pump([a, b], b.is_finished, STEP_TIMEOUT_MSEC), "相手が切れたら試合が終わる")
	_check(b.game.opponent_left and b.winner == OnlineMatch.MY_PLAYER, "残った側の不戦勝")


## until が真になるまで(または timeout まで)クライアントを回す。
func _pump(clients: Array, until: Callable, timeout_msec: int) -> bool:
	var deadline := Time.get_ticks_msec() + timeout_msec
	_last_msec = Time.get_ticks_msec()
	while not until.call():
		if Time.get_ticks_msec() > deadline:
			return false
		await process_frame
		var now := Time.get_ticks_msec()
		var delta := (now - _last_msec) / 1000.0
		_last_msec = now
		for client: Client in clients:
			client.step(delta)
	return true


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		printerr("FAILED: ", label)
