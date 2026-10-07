class_name HandNameTable
extends Resource
## 手の名前(GameDesign 2.4節)。
## キーは親・人・中・薬・小の順に、伸び=EXTENDED_MARK / 曲がり=CURLED_MARK を並べた文字列。

const EXTENDED_MARK := "○"
const CURLED_MARK := "●"

## 32通りすべての名前。グー・チョキ・パーも含む。
@export var names: Dictionary[String, String] = {}
## 反則の名前。{name} は中途半端な指を寄せた手の名前に置き換える。
@export var foul_original_format: String
@export var foul_named_format: String
## 5本とも中途半端な反則の名前。
@export var all_half_name: String


## states は伸び・曲がりだけからなる指の状態(HandTypes.FingerState)。
static func key_of(states: Array) -> String:
	var key := ""
	for state in states:
		key += CURLED_MARK if state == HandTypes.FingerState.CURLED else EXTENDED_MARK
	return key


static func states_of(key: String) -> Array:
	var states := []
	for mark in key:
		var curled := mark == CURLED_MARK
		states.append(HandTypes.FingerState.CURLED if curled else HandTypes.FingerState.EXTENDED)
	return states


func name_of(states: Array) -> String:
	return names.get(key_of(states), "")
