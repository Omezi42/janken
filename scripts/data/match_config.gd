class_name MatchConfig
extends Resource
## 試合の数値(GameDesign 5章)。

@export var wins_to_finish: int
## 掛け声の各区間(じゃん・けん・ぽん)の秒数。
@export var call_segment_seconds: Array[float] = []


func call_total_seconds() -> float:
	var total := 0.0
	for seconds in call_segment_seconds:
		total += seconds
	return total
