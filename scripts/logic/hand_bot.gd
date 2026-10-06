class_name HandBot
extends RefCounted
## 開発用の仮の相手。人と同じ LocalMatch.flip() で、人がなぞるように指を反転する(GameDesign 6.1節・6.2節)。
## - ラウンドの初めにグー・チョキ・パーから1つ選び、食い違う指が並んでいる所を1回のなぞりで続けて反転する。
## - なぞりの終わりで、ときどき隣の指まで行き過ぎる(後で直す)。
## - 「ぽん」の区間に入ったら、ときどき相手の手を見て、それに勝つ手へ組み替える(見てから動くまで反応の秒数が掛かる)。
## 乱数は試合と別に持つ(リプレイはボットを動かさず記録だけで再現するため)。

const _E := HandTypes.FingerState.EXTENDED
const _C := HandTypes.FingerState.CURLED
## HandTypes.Shape の ROCK, SCISSORS, PAPER の順。
const GOALS := [
	[_C, _C, _C, _C, _C],
	[_C, _E, _E, _C, _C],
	[_E, _E, _E, _E, _E],
]
## 相手の形 → それに勝つ形。
const COUNTERS := {
	HandTypes.Shape.ROCK: HandTypes.Shape.PAPER,
	HandTypes.Shape.SCISSORS: HandTypes.Shape.ROCK,
	HandTypes.Shape.PAPER: HandTypes.Shape.SCISSORS,
}
## ラウンド開始・相手の手を見たときから動き出すまでの秒数。
const REACTION_SECONDS := 0.5
## なぞりで帯を1つ越える秒数。
const BAND_SECONDS := 0.09
## なぞり終えてから次のなぞりを始めるまでの秒数(下限・上限)。
const REGRIP_SECONDS := Vector2(0.25, 0.5)
## なぞりの終わりで隣の指まで行き過ぎる確率。
const OVERSHOOT_CHANCE := 0.4
## 左(親指の側)からなぞる確率。
const FROM_LEFT_CHANCE := 0.5
## 相手の手を見て組み替える区間(ぽん)と、組み替える確率。
const READ_SEGMENT := 4
const READ_CHANCE := 0.6

var _match: LocalMatch
var _player: int
var _rng := RandomNumberGenerator.new()
var _goal: Array = GOALS[0]
var _wait_ticks := 0
## いまのなぞりで、これから反転する指(なぞる順)。
var _stroke := PackedInt32Array()


func _init(local_match: LocalMatch, player: int, bot_seed: int) -> void:
	_match = local_match
	_player = player
	_rng.seed = bot_seed
	_match.round_started.connect(_on_round_started)
	_match.call_segment_changed.connect(_on_call_segment_changed)


## LocalMatch.tick() の直前に毎回呼ぶ。
func think() -> void:
	if not _match.can_operate():
		return
	if _wait_ticks > 0:
		_wait_ticks -= 1
		return
	if _stroke.is_empty():
		_plan_stroke()
		if _stroke.is_empty():
			return
	_match.flip(_player, _stroke[0] as HandTypes.Finger)
	_stroke.remove_at(0)
	if _stroke.is_empty():
		_wait_ticks = _ticks(_rng.randf_range(REGRIP_SECONDS.x, REGRIP_SECONDS.y))
	else:
		_wait_ticks = _ticks(BAND_SECONDS)


## 食い違う指が並んでいる所を1つ選び、左右どちらかからなぞる順に並べる。
func _plan_stroke() -> void:
	var hand := _match.hands[_player]
	var wrong := []
	for finger in _goal.size():
		wrong.append(hand.settled_state(finger) != _goal[finger])
	var start := wrong.find(true)
	if start < 0:
		return
	var end := start
	while end + 1 < wrong.size() and wrong[end + 1]:
		end += 1
	var forward := _rng.randf() < FROM_LEFT_CHANCE
	for i in end - start + 1:
		_stroke.append(start + i if forward else end - i)
	var beyond := end + 1 if forward else start - 1
	if beyond >= 0 and beyond < wrong.size() and _rng.randf() < OVERSHOOT_CHANCE:
		_stroke.append(beyond)


func _on_round_started() -> void:
	_goal = GOALS[_rng.randi_range(0, GOALS.size() - 1)]
	_stroke.clear()
	_wait_ticks = _ticks(REACTION_SECONDS)


func _on_call_segment_changed(index: int) -> void:
	if index != READ_SEGMENT or _rng.randf() >= READ_CHANCE:
		return
	var opponent := ActiveEffects.opponent_of(_player)
	if _match.effects.is_censored(opponent):
		return
	var shape := HandShapeJudge.shape_of(_match.hands[opponent].states)
	if COUNTERS.has(shape) and GOALS[COUNTERS[shape]] != _goal:
		_goal = GOALS[COUNTERS[shape]]
		_stroke.clear()
		_wait_ticks = maxi(_wait_ticks, _ticks(REACTION_SECONDS))


static func _ticks(seconds: float) -> int:
	return roundi(seconds * LocalMatch.TICKS_PER_SECOND)
