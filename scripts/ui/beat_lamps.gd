class_name BeatLamps
extends Control
## 掛け声の区間の数だけ並べたランプ。いまの区間まで点け、最後(ぽん)は色を変える(GameDesign 8.2節)。

## ランプの半径・間隔・縁の太さ(このノードの高さに対する比)。
const RADIUS_RATIO := 0.4
const SPACING_RATIO := 1.4
const OUTLINE_RATIO := 0.12
const OFF_COLOR := Color(0.0, 0.0, 0.0, 0.35)
const ON_COLOR := Color("ffd84a")
const LAST_ON_COLOR := Color("ff5a4e")
const OUTLINE_COLOR := Color("101820")

var count := 0:
	set(value):
		count = value
		queue_redraw()
## 点いているランプの数。
var lit := 0:
	set(value):
		lit = value
		queue_redraw()


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE


func _draw() -> void:
	var radius := size.y * RADIUS_RATIO
	var spacing := size.y * SPACING_RATIO
	var left := size.x / 2.0 - spacing * (count - 1) / 2.0
	for i in count:
		var center := Vector2(left + spacing * i, size.y / 2.0)
		var color := OFF_COLOR
		if i < lit:
			color = LAST_ON_COLOR if i == count - 1 else ON_COLOR
		draw_circle(center, radius + size.y * OUTLINE_RATIO, OUTLINE_COLOR, true, -1.0, true)
		draw_circle(center, radius, color, true, -1.0, true)
