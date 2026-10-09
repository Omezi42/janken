class_name HandRuleTable
extends Resource
## 指の状態の閾値・系統・勝ち条件(GameDesign 2.1〜2.3節)。キーは HandNameTable.key_of() と同じ。

## 曲がり具合(0.0〜1.0)がこれ未満なら伸び、curled_above を超えたら曲がり、それ以外は中途半端。
@export var extended_below: float
@export var curled_above: float
## 伸びた指がこの本数以上ならチョキ系、paper_min_extended 以上ならパー系。それ未満はグー系。
@export var scissors_min_extended: int
@export var paper_min_extended: int
## 勝ち条件を持つ手(本家を含む)。表に無い手は勝ち条件なし。
@export var conditions: Dictionary[String, HandCondition] = {}


## states は伸び・曲がりだけからなる指の状態。勝ち条件が無ければ null。
func condition_of(states: Array) -> HandCondition:
	return conditions.get(HandNameTable.key_of(states))
