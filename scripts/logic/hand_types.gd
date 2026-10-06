class_name HandTypes
## 手の判定で共有する列挙。指の並びは親指から小指の順。
## .tres に整数で保存されるため、値は末尾へ足す。

enum Finger { THUMB, INDEX, MIDDLE, RING, PINKY }
enum FingerState { EXTENDED, HALF, CURLED }
enum Shape { ROCK, SCISSORS, PAPER, FOUL, NAMED }
enum Outcome { WIN, LOSE, DRAW }
## 名前付きの手の効果(GameDesign 2.5節)。
enum EffectKind { CENSOR, OVERSLEEP, PISTOL }
## 指の量(GameDesign 6.1節)。曲がり具合と向き。
enum Axis { CURL, SWING }
