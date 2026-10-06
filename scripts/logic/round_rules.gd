class_name RoundRules
## 2つの手の形から勝敗を決める(GameDesign 2.3節)。

const _BEATS := {
	HandTypes.Shape.ROCK: HandTypes.Shape.SCISSORS,
	HandTypes.Shape.SCISSORS: HandTypes.Shape.PAPER,
	HandTypes.Shape.PAPER: HandTypes.Shape.ROCK,
}


## mine から見た勝敗。グー・チョキ・パーは名前付きの手に勝つ。
static func outcome(mine: HandTypes.Shape, theirs: HandTypes.Shape) -> HandTypes.Outcome:
	var my_named := mine == HandTypes.Shape.NAMED
	var their_named := theirs == HandTypes.Shape.NAMED
	if my_named != their_named:
		return HandTypes.Outcome.LOSE if my_named else HandTypes.Outcome.WIN
	if mine == theirs:
		return HandTypes.Outcome.DRAW
	if _BEATS[mine] == theirs:
		return HandTypes.Outcome.WIN
	return HandTypes.Outcome.LOSE
