class_name MatchRecord
extends RefCounted
## 1試合を再現するための記録(Architecture 4.1節)。seed と、tick ごとに置いた指の目標(曲がり具合のステップ数)を持つ。
## to_text() / from_text() でクリップボードに載せられる1行の文字列と相互に変換する。

## 記録の形式が変わったら上げる(古い文字列は読み込みを拒む)。
const FORMAT_VERSION := 3
const TEXT_PREFIX := "JK%d." % FORMAT_VERSION
## 曲がり具合 1.0 あたりのステップ数。指の目標はこの単位へ丸めて記録・適用する。
const STEPS_PER_CURL := 10000
## 展開後の大きさの上限(壊れた文字列で大きなメモリを確保しないため)。
const MAX_DECOMPRESSED_BYTES := 1 << 22

var seed := 0
var ticks := PackedInt32Array()
var slots := PackedByteArray()
var steps := PackedInt32Array()


func append(tick: int, slot: int, step_count: int) -> void:
	ticks.append(tick)
	slots.append(slot)
	steps.append(step_count)


func size() -> int:
	return ticks.size()


func to_text() -> String:
	var data := {"seed": seed, "ticks": ticks, "slots": slots, "steps": steps}
	var bytes := var_to_bytes(data).compress(FileAccess.COMPRESSION_DEFLATE)
	return TEXT_PREFIX + Marshalls.raw_to_base64(bytes)


## 読めない文字列なら null を返す。
static func from_text(text: String) -> MatchRecord:
	text = text.strip_edges()
	if not text.begins_with(TEXT_PREFIX):
		return null
	var compressed := Marshalls.base64_to_raw(text.substr(TEXT_PREFIX.length()))
	if compressed.is_empty():
		return null
	var bytes := compressed.decompress_dynamic(
		MAX_DECOMPRESSED_BYTES, FileAccess.COMPRESSION_DEFLATE
	)
	var data: Variant = bytes_to_var(bytes)
	if not _is_valid(data):
		return null
	var record := MatchRecord.new()
	record.seed = data["seed"]
	record.ticks = data["ticks"]
	record.slots = data["slots"]
	record.steps = data["steps"]
	return record


static func _is_valid(data: Variant) -> bool:
	if not data is Dictionary:
		return false
	if not (data.get("seed") is int and data.get("ticks") is PackedInt32Array):
		return false
	if not (data.get("slots") is PackedByteArray and data.get("steps") is PackedInt32Array):
		return false
	var count: int = data["ticks"].size()
	return data["slots"].size() == count and data["steps"].size() == count
