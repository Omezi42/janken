class_name RoundRules
## 2つの手の指の状態から勝敗を決める(GameDesign 2.3節)。


## mine から見た勝敗。反則は反則でない手すべてに負ける。
## 反則でなければ、片方だけが勝ち条件を満たせばその側の勝ち。両方・どちらも満たさなければあいこ。
static func outcome(mine: Array, theirs: Array, judge: HandShapeJudge) -> HandTypes.Outcome:
	var my_foul := HandShapeJudge.shape_of(mine) == HandTypes.Shape.FOUL
	var their_foul := HandShapeJudge.shape_of(theirs) == HandTypes.Shape.FOUL
	if my_foul or their_foul:
		if my_foul == their_foul:
			return HandTypes.Outcome.DRAW
		return HandTypes.Outcome.LOSE if my_foul else HandTypes.Outcome.WIN
	var i_win := beats(mine, theirs, judge)
	var they_win := beats(theirs, mine, judge)
	if i_win == they_win:
		return HandTypes.Outcome.DRAW
	return HandTypes.Outcome.WIN if i_win else HandTypes.Outcome.LOSE


## 反則でない手 mine の勝ち条件を、反則でない相手の手 theirs が満たすか。
static func beats(mine: Array, theirs: Array, judge: HandShapeJudge) -> bool:
	var condition := judge.rules.condition_of(mine)
	if condition == null:
		return false
	var their_shape := HandShapeJudge.shape_of(theirs)
	match condition.kind:
		HandTypes.ConditionKind.SERIES:
			return judge.series_of(theirs) == condition.value
		HandTypes.ConditionKind.ORIGINAL:
			return HandShapeJudge.is_original(their_shape)
		HandTypes.ConditionKind.NAMED:
			return their_shape == HandTypes.Shape.NAMED
		HandTypes.ConditionKind.FINGER_CURLED:
			return theirs[condition.value] == HandTypes.FingerState.CURLED
		HandTypes.ConditionKind.FINGER_EXTENDED:
			return theirs[condition.value] == HandTypes.FingerState.EXTENDED
		HandTypes.ConditionKind.FEWER_EXTENDED:
			return theirs.count(HandTypes.FingerState.EXTENDED) < condition.value
	return false
