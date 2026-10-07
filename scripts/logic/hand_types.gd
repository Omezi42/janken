class_name HandTypes
## 手の判定で共有する列挙。指の並びは親指から小指の順。
## .tres に整数で保存されるため、値は末尾へ足す。

enum Finger { THUMB, INDEX, MIDDLE, RING, PINKY }
enum FingerState { EXTENDED, CURLED, HALF }
enum Shape { ROCK, SCISSORS, PAPER, NAMED, FOUL }
enum Outcome { WIN, LOSE, DRAW }
## 名前付きの手の効果(GameDesign 2.5節)。
enum EffectKind { CENSOR, OVERSLEEP, PISTOL }
## 伸びた指の本数で分ける系統(GameDesign 2.2節)。
enum Series { ROCK, SCISSORS, PAPER }
## 勝ち条件の種類(GameDesign 2.3節)。値の意味は HandCondition.value に書く。
enum ConditionKind { SERIES, ORIGINAL, NAMED, FINGER_CURLED, FINGER_EXTENDED, FEWER_EXTENDED }
