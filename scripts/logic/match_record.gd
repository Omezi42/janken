class_name MatchRecord
extends RefCounted
## 1試合を再現するための記録(Architecture 4.1節)。seed と、tick ごとに反転した指(slot)を持つ。
## to_text() / from_text() でクリップボードに載せられる1行の文字列と相互に変換する。

## 記録の形式が変わったら上げる(古い文字列は読み込みを拒む)。
const FORMAT_VERSION := 4
const TEXT_PREFIX := "JK%d." % FORMAT_VERSION
## 展開後の大きさの上限(壊れた文字列で大きなメモリを確保しないため)。
const MAX_DECOMPRESSED_BYTES := 1 << 22

var seed := 0
var ticks := PackedInt32Array()
var slots := PackedByteArray()


func append(tick: int, slot: int) -> void:
	ticks.append(tick)
	slots.append(slot)


func size() -> int:
	return ticks.size()


func to_text() -> String:
	var data := {"seed": seed, "ticks": ticks, "slots": slots}
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
	return record


static func _is_valid(data: Variant) -> bool:
	if not data is Dictionary:
		return false
	if not (data.get("seed") is int and data.get("ticks") is PackedInt32Array):
		return false
	if not data.get("slots") is PackedByteArray:
		return false
	return data["slots"].size() == data["ticks"].size()
