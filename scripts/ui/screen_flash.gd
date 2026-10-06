class_name ScreenFlash
extends ColorRect
## 画面全体を白く光らせて消す(GameDesign 8.3節)。

const FLASH_ALPHA := 0.8
const FLASH_SECONDS := 0.25

var _tween: Tween


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	color = Color(1.0, 1.0, 1.0, 0.0)


func flash() -> void:
	if _tween != null:
		_tween.kill()
	color.a = FLASH_ALPHA
	_tween = create_tween()
	_tween.tween_property(self, "color:a", 0.0, FLASH_SECONDS)
