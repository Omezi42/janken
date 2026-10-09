class_name HandBot
extends RefCounted
## 開発用の仮の相手。人と同じ MatchSession.move() で、人が指をつかんで引くように1本ずつ動かす(GameDesign 6.1節・6.2節)。
## - ラウンドの初めに勝ち条件を持つ手(本家を含む)から1つ選び、食い違う指を1本ずつ、引く時間を掛けて伸びきり・曲がりきりへ動かす。
## - ときどき引き足りずに途中で離す(中途半端な指が残る)。
## - 「ぽん」の区間に入ったら、ときどき相手の手を見て、それに勝つ手のうち直す指が一番少ない手へ組み替える(見てから動くまで反応の秒数が掛かる)。
## 乱数は試合と別に持つ(リプレイはボットを動かさず記録だけで再現するため)。

## ラウンド開始・相手の手を見たときから動き出すまでの秒数。
const REACTION_SECONDS := 0.5
## 1本つかんで引くまでの秒数(下限・上限)。
const PULL_SECONDS := Vector2(0.15, 0.3)
## 引き足りずに途中で離す確率と、そのとき目標まで動かす割合(下限・上限)。
const MISS_CHANCE := 0.12
const MISS_REACH := Vector2(0.3, 0.7)
## 掛け声の最後の区間(ぽん)に入ったとき、相手の手を見て組み替える確率。
const READ_CHANCE := 0.6

var _match: MatchSession
var _player: int
var _rng := RandomNumberGenerator.new()
## 勝ち条件を持つ手の指の状態(伸び・曲がり)。
var _candidates := []
var _goal := []
var _wait_ticks := 0


func _init(session: MatchSession, player: int, bot_seed: int) -> void:
	_match = session
	_player = player
	_rng.seed = bot_seed
	var keys := _match.judge.rules.conditions.keys()
	keys.sort()
	for key in keys:
		_candidates.append(HandNameTable.states_of(key))
	_goal = _candidates[0]
	_match.round_started.connect(_on_round_started)
	_match.call_segment_changed.connect(_on_call_segment_changed)


## MatchSession.tick() の直前に毎回呼ぶ。1本動かしたら(引き足りなくても)、引く時間だけ次を待つ。
func think() -> void:
	if not _match.can_operate():
		return
	if _wait_ticks > 0:
		_wait_ticks -= 1
		return
	var wrong := _wrong_fingers(_goal)
	if wrong.is_empty():
		return
	var finger: int = wrong[_rng.randi_range(0, wrong.size() - 1)]
	var target: int = HandModel.CURL_MAX if _goal[finger] == HandTypes.FingerState.CURLED else 0
	if _rng.randf() < MISS_CHANCE:
		var from := _match.hands[_player].settled_curl(finger as HandTypes.Finger)
		target = roundi(lerpf(from, target, _rng.randf_range(MISS_REACH.x, MISS_REACH.y)))
	_match.move(_player, finger as HandTypes.Finger, target)
	_wait_ticks = _ticks(_rng.randf_range(PULL_SECONDS.x, PULL_SECONDS.y))


## goal と状態が食い違う指(予約を済ませた後で比べる)。
func _wrong_fingers(goal: Array) -> Array:
	var hand := _match.hands[_player]
	var wrong := []
	for finger in goal.size():
		var state := _match.judge.state_of(hand.settled_curl(finger as HandTypes.Finger))
		if state != goal[finger]:
			wrong.append(finger)
	return wrong


func _on_round_started() -> void:
	_goal = _candidates[_rng.randi_range(0, _candidates.size() - 1)]
	_wait_ticks = _ticks(REACTION_SECONDS)


func _on_call_segment_changed(index: int) -> void:
	var last_segment := _match.match_config.call_segment_seconds.size() - 1
	if index != last_segment or _rng.randf() >= READ_CHANCE:
		return
	var opponent := ActiveEffects.opponent_of(_player)
	if _match.effects.is_censored(opponent):
		return
	var theirs := _match.judge.states_of(_match.hands[opponent].curls)
	if HandShapeJudge.shape_of(theirs) == HandTypes.Shape.FOUL:
		return
	if RoundRules.outcome(_goal, theirs, _match.judge) == HandTypes.Outcome.WIN:
		return
	var best := []
	var best_cost := HandTypes.Finger.size() + 1
	for candidate in _candidates:
		if RoundRules.outcome(candidate, theirs, _match.judge) != HandTypes.Outcome.WIN:
			continue
		var cost := _wrong_fingers(candidate).size()
		if cost < best_cost:
			best = candidate
			best_cost = cost
	if not best.is_empty():
		_goal = best
		_wait_ticks = maxi(_wait_ticks, _ticks(REACTION_SECONDS))


static func _ticks(seconds: float) -> int:
	return roundi(seconds * MatchSession.TICKS_PER_SECOND)
