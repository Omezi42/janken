class_name RoundRules
## 2つの手の形から勝敗を決める(GameDesign 2.3節)。

const _BEATS := {
	HandTypes.Shape.ROCK: HandTypes.Shape.SCISSORS,
	HandTypes.Shape.SCISSORS: HandTypes.Shape.PAPER,
	HandTypes.Shape.PAPER: HandTypes.Shape.ROCK,
}
const _NAMED_RANK := 1
const _FOUL_RANK := 0
const _JANKEN_RANK := 2


## mine から見た勝敗。強さ(グーチョキパー > 名前付き > 反則)が違えば強い側の勝ち。
static func outcome(mine: HandTypes.Shape, theirs: HandTypes.Shape) -> HandTypes.Outcome:
	var my_rank := _rank(mine)
	var their_rank := _rank(theirs)
	if my_rank != their_rank:
		return HandTypes.Outcome.WIN if my_rank > their_rank else HandTypes.Outcome.LOSE
	if mine == theirs or my_rank != _JANKEN_RANK:
		return HandTypes.Outcome.DRAW
	if _BEATS[mine] == theirs:
		return HandTypes.Outcome.WIN
	return HandTypes.Outcome.LOSE


static func _rank(shape: HandTypes.Shape) -> int:
	match shape:
		HandTypes.Shape.FOUL:
			return _FOUL_RANK
		HandTypes.Shape.NAMED:
			return _NAMED_RANK
	return _JANKEN_RANK
