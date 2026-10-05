class_name HandConfig
extends Resource
## 指の状態のしきい値と操作しづらさの数値(GameDesign 2.1節・2.4節・6.2節)。

## 曲がり具合がこれ未満なら伸びている。
@export_range(0.0, 1.0) var extended_below: float
## 曲がり具合がこれを超えたら曲がっている。
@export_range(0.0, 1.0) var curled_above: float
## 反則の名前を引くとき、中途半端な指をこれ以上なら曲がり・未満なら伸びへ寄せる。
@export_range(0.0, 1.0) var name_snap_border: float
## 隣接する指の連動の強さ。[親−人, 人−中, 中−薬, 薬−小] の順。
@export var linkage_strengths: Array[float] = []
## 指が目標の曲がり具合へ戻るばねの強さ。
@export var spring_stiffness: float
## 指の速度を弱める強さ。
@export var spring_damping: float
