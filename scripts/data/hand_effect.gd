class_name HandEffect
extends Resource
## 名前付きの手1つの効果(GameDesign 2.5節)。

@export var kind: HandTypes.EffectKind
## 効果が続くラウンド数。
@export var rounds: int
## 結果表示の文。{target} は効果が掛かる側の呼び名に置き換える。
@export var text: String
