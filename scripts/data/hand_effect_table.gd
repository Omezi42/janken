class_name HandEffectTable
extends Resource
## 名前付きの手 → 効果(GameDesign 2.5節)。キーは HandNameTable.key_of() と同じ。

@export var effects: Dictionary[String, HandEffect] = {}
## 寝坊した指が反転するまでの遅れ(秒)。
@export var oversleep_delay_seconds: float


## states は伸び・曲がりだけからなる指の状態。効果が無ければ null。
func effect_of(states: Array) -> HandEffect:
	return effects.get(HandNameTable.key_of(states))
