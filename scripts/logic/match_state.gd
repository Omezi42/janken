class_name MatchState
extends RefCounted
## 試合の勝利数と終了判定(GameDesign 5章)。プレイヤーは 0 と 1。

const NO_WINNER := -1

var wins: Array[int] = [0, 0]
var _config: MatchConfig


func _init(config: MatchConfig) -> void:
	_config = config


## outcome はプレイヤー0から見た勝敗。試合終了後の記録は無視する。
func record(outcome: HandTypes.Outcome) -> void:
	if is_over():
		return
	match outcome:
		HandTypes.Outcome.WIN:
			wins[0] += 1
		HandTypes.Outcome.LOSE:
			wins[1] += 1


func is_over() -> bool:
	return winner() != NO_WINNER


func winner() -> int:
	for player in wins.size():
		if wins[player] >= _config.wins_to_finish:
			return player
	return NO_WINNER
