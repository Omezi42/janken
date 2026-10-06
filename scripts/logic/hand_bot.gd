class_name HandBot
extends RefCounted
## 開発用の仮の相手。ラウンドごとにグー・チョキ・パーから1つ選び、人と同じ LocalMatch.flip() で
## 目標と食い違う指を、人がなぞる程度の間隔で1本ずつ反転する。
## 乱数は試合と別に持つ(リプレイはボットを動かさず記録だけで再現するため)。

const _E := HandTypes.FingerState.EXTENDED
const _C := HandTypes.FingerState.CURLED
const GOALS := [
	[_C, _C, _C, _C, _C],
	[_C, _E, _E, _C, _C],
	[_E, _E, _E, _E, _E],
]
## 1本反転してから次の指を反転するまでの秒数(人がなぞって帯を1つ越える速さの目安)。
const TOUCH_SECONDS := 0.15

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
	for finger in _goal.size():
		if hand.settled_state(finger) != _goal[finger]:
			_match.flip(_player, finger as HandTypes.Finger)
			_wait_ticks = roundi(TOUCH_SECONDS * LocalMatch.TICKS_PER_SECOND)
			return


func _on_round_started() -> void:
	_goal = GOALS[_rng.randi_range(0, GOALS.size() - 1)]
	_wait_ticks = 0
