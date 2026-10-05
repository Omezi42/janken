class_name HandBot
extends RefCounted
## 開発用の仮の相手。ラウンドごとにグー・チョキ・パーから1つ選び、
## 人と同じ LocalMatch.drag() で目標から最も遠い指を1本ずつ寄せる(連動・慣性も受ける)。
## 乱数は試合と別に持つ(リプレイはボットを動かさず記録だけで再現するため)。

const GOALS := [
	[1.0, 1.0, 1.0, 1.0, 1.0],
	[1.0, 0.0, 0.0, 1.0, 1.0],
	[0.0, 0.0, 0.0, 0.0, 0.0],
]
## 1秒あたりに動かす曲がり具合(人が指1本をドラッグする速さの目安)。
const DRAG_SPEED := 2.0
## 目標との差がこれ以下の指は動かさない。
const ARRIVED := 0.05

var _match: LocalMatch
var _player: int
var _rng := RandomNumberGenerator.new()
var _goal: Array = GOALS[0]


func _init(local_match: LocalMatch, player: int, bot_seed: int) -> void:
	_match = local_match
	_player = player
	_rng.seed = bot_seed
	_match.round_started.connect(_on_round_started)


## LocalMatch.tick() の直前に毎回呼ぶ。
func think() -> void:
	if not _match.can_operate():
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
	var max_move := DRAG_SPEED * LocalMatch.TICK_SECONDS
	var amount := clampf(_goal[finger] - hand.targets[finger], -max_move, max_move)
	_match.drag(_player, finger as HandTypes.Finger, amount)


func _on_round_started() -> void:
	_goal = GOALS[_rng.randi_range(0, GOALS.size() - 1)]
