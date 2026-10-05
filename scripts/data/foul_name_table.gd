class_name FoulNameTable
extends Resource
## 反則した手の名前(GameDesign 2.4節)。
## キーは親・人・中・薬・小の順に、伸び=EXTENDED_MARK / 曲がり=CURLED_MARK を並べた文字列。

const EXTENDED_MARK := "○"
const CURLED_MARK := "●"

## 32通りすべての名前。グー・チョキ・パーも含む(「ほぼ○○」に使う)。
@export var names: Dictionary[String, String] = {}
@export var almost_prefix: String
@export var loose_prefix: String
## 5本とも中途半端なときの名前。
@export var all_half_name: String


## states は伸び・曲がりだけからなる指の状態(HandTypes.FingerState)。
static func key_of(states: Array) -> String:
	var key := ""
	for state in states:
		key += CURLED_MARK if state == HandTypes.FingerState.CURLED else EXTENDED_MARK
	return key


func name_of(states: Array) -> String:
	return names.get(key_of(states), "")
