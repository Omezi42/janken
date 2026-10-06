class_name SoftFinger
extends RefCounted
## 1本の指の見た目だけの柔らかさ(GameDesign 8.1節)。付け根と指先を結ぶ直線上の内側の点が、
## 直線から横へずれた量をばねで持つ。指が横へ動くと内側が遅れてしなり、揺れが残る。ロジックには関わらない。

## 内側の点の位置(付け根 0 〜 指先 1)。
const FRACTIONS := [0.25, 0.5, 0.75]
## 内側の点のばね(指先側ほど柔らかい)。
const STIFFNESS := [300.0, 200.0, 140.0]
const DAMPING := 6.0
## 横へずれる量の上限(付け根から指先までの長さに対する比)。
const MAX_BEND_RATIO := 0.45
## 曲線を描くときの点の数。
const SAMPLES := 24
## これより短い指は向きを前のフレームから引き継ぐ(長さ0で向きが定まらないため)。
const MIN_LENGTH := 0.001

var _offsets := PackedFloat32Array()
var _velocities := PackedFloat32Array()
var _rest := PackedVector2Array()
var _side := Vector2.RIGHT
var _base := Vector2.ZERO
var _tip := Vector2.ZERO
var _started := false


func _init() -> void:
	_offsets.resize(FRACTIONS.size())
	_velocities.resize(FRACTIONS.size())
	_rest.resize(FRACTIONS.size())


## 次の update() で揺れを捨てて直線から始める(ラウンドの初期配置で手が飛ぶため)。
func reset() -> void:
	_started = false


## sway は指先の横ずれの目標(内側の点は付け根からの位置に比例して小さくする)。
func update(base: Vector2, tip: Vector2, sway: float, delta: float) -> void:
	var axis := tip - base
	var length := axis.length()
	var side := axis.normalized().orthogonal() if length > MIN_LENGTH else _side
	var limit := length * MAX_BEND_RATIO
	for i in FRACTIONS.size():
		var rest: Vector2 = base + axis * FRACTIONS[i]
		if _started:
			var previous := _rest[i] + _side * _offsets[i]
			_offsets[i] = (previous - rest).dot(side)
		else:
			_offsets[i] = 0.0
			_velocities[i] = 0.0
		var pull: float = STIFFNESS[i] * (sway * FRACTIONS[i] - _offsets[i])
		_velocities[i] += (pull - DAMPING * _velocities[i]) * delta
		_offsets[i] = clampf(_offsets[i] + _velocities[i] * delta, -limit, limit)
		_rest[i] = rest
	_side = side
	_base = base
	_tip = tip
	_started = true


## 付け根から指先までの曲線。
func curve() -> PackedVector2Array:
	var controls := PackedVector2Array([_base])
	for i in FRACTIONS.size():
		controls.append(_rest[i] + _side * _offsets[i])
	controls.append(_tip)
	var points := PackedVector2Array()
	var last := controls.size() - 1
	for s in SAMPLES + 1:
		var position := float(s) / SAMPLES * last
		var i := mini(int(position), last - 1)
		var before := controls[maxi(i - 1, 0)]
		var after := controls[mini(i + 2, last)]
		points.append(controls[i].cubic_interpolate(controls[i + 1], before, after, position - i))
	return points
