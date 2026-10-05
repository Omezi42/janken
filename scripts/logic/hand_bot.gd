class_name HandBot
extends RefCounted
## 開発用の仮の相手。ラウンドごとにグー・チョキ・パーから1つ選び、
## 人と同じ drag() で目標から最も遠い指を1本ずつ寄せる(連動・慣性も受ける)。

const GOALS := [
	[1.0, 1.0, 1.0, 1.0, 1.0],
	[1.0, 0.0, 0.0, 1.0, 1.0],
	[0.0, 0.0, 0.0, 0.0, 0.0],
]
## 1秒あたりに動かす曲がり具合(人が指1本をドラッグする速さの目安)。
const DRAG_SPEED := 2.0
## 目標との差がこれ以下の指は動かさない。
const ARRIVED := 0.05

var _hand: HandModel
var _rng: RandomNumberGenerator
var _goal: Array = GOALS[0]


func _init(hand: HandModel, rng: RandomNumberGenerator) -> void:
	_hand = hand
	_rng = rng


func start_round() -> void:
	_goal = GOALS[_rng.randi_range(0, GOALS.size() - 1)]


func step(delta: float) -> void:
	var finger := -1
	var farthest := ARRIVED
	for i in _goal.size():
		var gap := absf(_goal[i] - _hand.targets[i])
		if gap > farthest:
			farthest = gap
			finger = i
	if finger < 0:
		return
	var max_move := DRAG_SPEED * delta
	var amount := clampf(_goal[finger] - _hand.targets[finger], -max_move, max_move)
	_hand.drag(finger as HandTypes.Finger, amount)
