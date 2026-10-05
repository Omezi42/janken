class_name HandEffectTable
extends Resource
## 名前付きの手 → 効果(GameDesign 2.5節)。キーは HandNameTable.key_of() と同じ。

@export var effects: Dictionary[String, HandEffect] = {}
## 寝坊した指の動きの倍率。
@export_range(0.0, 1.0) var oversleep_drag_scale: float


## states は伸び・曲がりだけからなる指の状態。効果が無ければ null。
func effect_of(states: Array) -> HandEffect:
	return effects.get(HandNameTable.key_of(states))
