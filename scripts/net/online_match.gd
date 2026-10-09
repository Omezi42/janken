class_name OnlineMatch
extends MatchSession
## オンラインの1試合(GameDesign 7章、Architecture 3.2節・4.2節)。プレイヤー 0 が自分、1 が相手。
## 判定は部屋が行い、ここは届いた予定どおりに掛け声を進め、結果を知らせるだけ。
## judged は手元の掛け声が終わってから知らせる(時計のずれで表示の順が崩れないため)。

## 自分の接続が切れた(試合は終わり。結果は無い)。
signal connection_lost

const MY_PLAYER := 0
const THEIR_PLAYER := 1
const MS_PER_SECOND := 1000.0
const OUTCOMES := {
	"win": HandTypes.Outcome.WIN,
	"lose": HandTypes.Outcome.LOSE,
	"draw": HandTypes.Outcome.DRAW,
}

## 相手が切れて不戦勝になった。
var opponent_left := false
var _net: NetClient
## 掛け声の始まり(手元の時刻、ミリ秒)。
var _round_at := 0.0
var _segment := 0
var _result_started := 0
var _pending_round := {}
var _pending_judged := {}
var _final_judged := false


func _init(
	net: NetClient,
	config: MatchConfig,
	names: HandNameTable,
	rule_table: HandRuleTable,
	my_name: String,
	their_name: String
) -> void:
	super(names, rule_table, config)
	_net = net
	player_names = PackedStringArray([my_name, their_name])
	phase = Phase.WAITING
	_net.message.connect(_on_message)
	_net.closed.connect(_on_closed)


func move(player: int, finger: HandTypes.Finger, curl: int) -> void:
	if player != MY_PLAYER or not can_operate():
		return
	hands[MY_PLAYER].move(finger, curl)
	_net.send({"t": "move", "f": finger, "c": hands[MY_PLAYER].curls[finger]})


func close() -> void:
	phase = Phase.OVER
	_net.close()


func tick() -> void:
	_net.poll()
	var now := Time.get_ticks_msec()
	match phase:
		Phase.WAITING:
			_try_start_round(now)
		Phase.CALLING:
			_tick_call(now)
		Phase.JUDGING:
			_try_judge()
		Phase.RESULT:
			if state.is_over():
				if now - _result_started >= match_config.result_display_seconds * MS_PER_SECOND:
					phase = Phase.OVER
					match_finished.emit(state.winner())
			else:
				_try_start_round(now)


func _try_start_round(now: int) -> void:
	if _pending_round.is_empty():
		return
	var at := _net.to_local_msec(float(_pending_round["at"]))
	if now < at:
		return
	_round_at = at
	hands[MY_PLAYER].set_pose(_curls_of(_pending_round["mine"]))
	hands[THEIR_PLAYER].set_pose(_curls_of(_pending_round["theirs"]))
	_pending_round = {}
	phase = Phase.CALLING
	round_started.emit()
	_enter_segment(0)
	_tick_call(now)


func _tick_call(now: int) -> void:
	for hand in hands:
		hand.step()
	var segment := match_config.call_segment_at((now - _round_at) / MS_PER_SECOND)
	if segment >= match_config.call_segment_seconds.size():
		phase = Phase.JUDGING
		_try_judge()
		return
	if segment != _segment:
		_enter_segment(segment)


func _enter_segment(segment: int) -> void:
	_segment = segment
	call_segment_changed.emit(_segment)


func _try_judge() -> void:
	if _pending_judged.is_empty():
		return
	var judged := _pending_judged
	_pending_judged = {}
	hands[MY_PLAYER].set_pose(_curls_of(judged["mine"]))
	hands[THEIR_PLAYER].set_pose(_curls_of(judged["theirs"]))
	var result := name_hands(hands[MY_PLAYER].curls, hands[THEIR_PLAYER].curls)
	result.outcome = OUTCOMES.get(judged.get("outcome"), HandTypes.Outcome.DRAW)
	state.record(result.outcome)
	phase = Phase.RESULT
	_result_started = Time.get_ticks_msec()
	round_judged.emit(result)


func _on_message(data: Dictionary) -> void:
	if phase == Phase.OVER:
		return
	match data.get("t"):
		"round":
			_pending_round = data
		"judged":
			_pending_judged = data
			var wins: Array = data.get("wins", [])
			_final_judged = wins.any(
				func(w: Variant) -> bool: return int(w) >= match_config.wins_to_finish
			)
			if _final_judged:
				_net.close()
		"move":
			if phase == Phase.CALLING or phase == Phase.JUDGING:
				var finger := int(data.get("f", -1))
				if finger >= 0 and finger < HandTypes.Finger.size():
					hands[THEIR_PLAYER].move(finger as HandTypes.Finger, int(data.get("c", 0)))
		"left":
			if not _final_judged:
				opponent_left = true
				close()
				match_finished.emit(MY_PLAYER)


## 最後の判定の直後に部屋が接続を切るのは正常。
func _on_closed() -> void:
	if phase == Phase.OVER or _final_judged:
		return
	phase = Phase.OVER
	connection_lost.emit()


static func _curls_of(values: Variant) -> PackedInt32Array:
	var curls := PackedInt32Array()
	if values is Array:
		for value: Variant in values:
			curls.append(clampi(int(value), 0, HandModel.CURL_MAX))
	curls.resize(HandTypes.Finger.size())
	return curls
