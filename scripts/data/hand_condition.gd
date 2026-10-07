class_name HandCondition
extends Resource
## 1つの手の勝ち条件「相手が〇〇なら勝ち」(GameDesign 2.3節)。判定は RoundRules。

@export var kind: HandTypes.ConditionKind
## SERIES: HandTypes.Series / FINGER_CURLED・FINGER_EXTENDED: HandTypes.Finger /
## FEWER_EXTENDED: 本数。ほかは使わない。
@export var value: int
## 表示の文(例: 指2〜3本に勝つ)。
@export var text: String
