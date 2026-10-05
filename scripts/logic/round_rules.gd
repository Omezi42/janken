class_name RoundRules
## 2つの手の形から勝敗を決める(GameDesign 2.3節)。

const _BEATS := {
	HandTypes.Shape.ROCK: HandTypes.Shape.SCISSORS,
	HandTypes.Shape.SCISSORS: HandTypes.Shape.PAPER,
	HandTypes.Shape.PAPER: HandTypes.Shape.ROCK,
}


## mine から見た勝敗。両方反則はあいこ、片方だけ反則なら反則した側の負け。
static func outcome(mine: HandTypes.Shape, theirs: HandTypes.Shape) -> HandTypes.Outcome:
	if mine == theirs:
		return HandTypes.Outcome.DRAW
	if mine == HandTypes.Shape.FOUL:
		return HandTypes.Outcome.LOSE
	if theirs == HandTypes.Shape.FOUL:
		return HandTypes.Outcome.WIN
	if _BEATS[mine] == theirs:
		return HandTypes.Outcome.WIN
	return HandTypes.Outcome.LOSE
