class_name MatchConfig
extends Resource
## 試合の数値(GameDesign 5章)。

@export var wins_to_finish: int
## 掛け声の各区間(さいしょは・手の名前・じゃん・けん・ぽん)の秒数。
@export var call_segment_seconds: Array[float] = []
## 掛け声の各区間に表示する文字。call_segment_seconds と同じ並び。
@export var call_words: Array[String] = []
## 両者の手の名前を呼ぶ区間の番号。判定はしない。
@export var hand_call_segment: int
## 判定のあと結果を表示しておく秒数。
@export var result_display_seconds: float


func call_total_seconds() -> float:
	var total := 0.0
	for seconds in call_segment_seconds:
		total += seconds
	return total


## 掛け声の開始から seconds 秒の時点の区間。掛け声が終わっていれば区間の数を返す。
func call_segment_at(seconds: float) -> int:
	var end := 0.0
	for i in call_segment_seconds.size():
		end += call_segment_seconds[i]
		if seconds < end:
			return i
	return call_segment_seconds.size()
