class_name HandBot
extends RefCounted
## 開発用の仮の相手。人と同じ LocalMatch.flip() で、人が指をつかんで引くように1本ずつ反転する(GameDesign 6.1節・6.2節)。
## - ラウンドの初めにグー・チョキ・パーから1つ選び、食い違う指を1本ずつ、引く時間を掛けて反転する。
## - ときどき引き足りずに失敗する(時間だけ使って反転しない)。
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
## 1本つかんで引くまでの秒数(下限・上限)。
const PULL_SECONDS := Vector2(0.15, 0.3)
## 引き足りずに反転しない確率。
const MISS_CHANCE := 0.12
## 相手の手を見て組み替える区間(ぽん)と、組み替える確率。
const READ_SEGMENT := 4
const READ_CHANCE := 0.6

var _match: LocalMatch
var _player: int
var _rng := RandomNumberGenerator.new()
var _goal: Array = GOALS[0]
var _wait_ticks := 0


func _init(local_match: LocalMatch, player: int, bot_seed: int) -> void:
	_match = local_match
	_player = player
	_rng.seed = bot_seed
	_match.round_started.connect(_on_round_started)
	_match.call_segment_changed.connect(_on_call_segment_changed)


## LocalMatch.tick() の直前に毎回呼ぶ。1本反転したら(失敗しても)、引く時間だけ次を待つ。
func think() -> void:
	if not _match.can_operate():
		return
	if _wait_ticks > 0:
		_wait_ticks -= 1
		return
	var hand := _match.hands[_player]
	var wrong := []
	for finger in _goal.size():
		if hand.settled_state(finger) != _goal[finger]:
			wrong.append(finger)
	if wrong.is_empty():
		return
	if _rng.randf() >= MISS_CHANCE:
		var finger: int = wrong[_rng.randi_range(0, wrong.size() - 1)]
		_match.flip(_player, finger as HandTypes.Finger)
	_wait_ticks = _ticks(_rng.randf_range(PULL_SECONDS.x, PULL_SECONDS.y))


func _on_round_started() -> void:
	_goal = GOALS[_rng.randi_range(0, GOALS.size() - 1)]
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
		_wait_ticks = maxi(_wait_ticks, _ticks(REACTION_SECONDS))


static func _ticks(seconds: float) -> int:
	return roundi(seconds * LocalMatch.TICKS_PER_SECOND)
