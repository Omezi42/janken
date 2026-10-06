class_name HandNameTable
extends Resource
## 手の名前(GameDesign 2.4節)。
## キーは親・人・中・薬・小の順に、伸び=EXTENDED_MARK / 曲がり=CURLED_MARK を並べた文字列。

const EXTENDED_MARK := "○"
const CURLED_MARK := "●"

## 32通りすべての名前。グー・チョキ・パーも含む。
@export var names: Dictionary[String, String] = {}


## states は指の状態(HandTypes.FingerState)。
static func key_of(states: Array) -> String:
	var key := ""
	for state in states:
		key += CURLED_MARK if state == HandTypes.FingerState.CURLED else EXTENDED_MARK
	return key


func name_of(states: Array) -> String:
	return names.get(key_of(states), "")
