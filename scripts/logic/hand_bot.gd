class_name HandBot
extends RefCounted
## 開発用の仮の相手。ラウンドごとにグー・チョキ・パーから1つ選び、人と同じ LocalMatch.reach() で
## 目標から最も遠い指を、人がなぞる程度の間隔で1本ずつ触る(連動・ばねも受ける)。
## 乱数は試合と別に持つ(リプレイはボットを動かさず記録だけで再現するため)。

const GOALS := [
	[1.0, 1.0, 1.0, 1.0, 1.0],
	[1.0, 0.0, 0.0, 1.0, 1.0],
	[0.0, 0.0, 0.0, 0.0, 0.0],
]
## 1本触ってから次の指を触るまでの秒数(人が手の上をなぞって指を渡る速さの目安)。
const TOUCH_SECONDS := 0.08
## 目標との差がこれ以下の指は触らない。
const ARRIVED := 0.05

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


## LocalMatch.tick() の直前に毎回呼ぶ。
func think() -> void:
	if not _match.can_operate():
		return
	if _wait_ticks > 0:
		_wait_ticks -= 1
		return
	var hand := _match.hands[_player]
	var finger := -1
	var farthest := ARRIVED
	for i in _goal.size():
		var gap := absf(_goal[i] - hand.targets[i])
		if gap > farthest:
			farthest = gap
			finger = i
	if finger < 0:
		return
	_match.reach(_player, finger as HandTypes.Finger, _goal[finger])
	_wait_ticks = roundi(TOUCH_SECONDS * LocalMatch.TICKS_PER_SECOND)


func _on_round_started() -> void:
	_goal = GOALS[_rng.randi_range(0, GOALS.size() - 1)]
	_wait_ticks = 0
