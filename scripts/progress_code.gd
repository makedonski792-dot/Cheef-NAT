class_name ProgressCode
extends RefCounted
# «Код прогресса»: сохранение игры в виде короткого текста, который можно скопировать
# и вставить обратно (после переустановки игры или на другом телефоне).
# Формат: FSH1-<размер>-<контрольная сумма>-<сжатые данные>. Контрольная сумма
# защищает от случайных опечаток и обрезанного текста.

const PREFIX := "FSH1"
const MAX_SIZE := 100000


# Данные сохранения -> текст кода
static func encode(data: Dictionary) -> String:
	var raw := JSON.stringify(data).to_utf8_buffer()
	var body := Marshalls.raw_to_base64(raw.compress(FileAccess.COMPRESSION_DEFLATE))
	return "%s-%d-%s-%s" % [PREFIX, raw.size(), _checksum(body, raw.size()), body]


# Текст кода -> {"ok": bool, "data": Dictionary, "error": String}
static func decode(code: String) -> Dictionary:
	# Убираем пробелы и переносы строк (при копировании текст часто разбивается)
	var clean := code.strip_edges()
	for blank in [" ", "\n", "\r", "\t"]:
		clean = clean.replace(blank, "")
	if clean == "":
		return _fail("Код пустой. Вставь код, который ты копировал раньше.")

	var parts := clean.split("-", true, 3)
	if parts.size() != 4 or parts[0] != PREFIX:
		return _fail("Это не код прогресса этой игры. Он должен начинаться с «%s-»." % PREFIX)
	if not parts[1].is_valid_int():
		return _fail("Код повреждён.")
	var size := int(parts[1])
	if size <= 0 or size > MAX_SIZE:
		return _fail("Код повреждён.")
	if _checksum(parts[3], size) != parts[2]:
		return _fail("Код скопирован не полностью или с ошибкой. Скопируй его ещё раз целиком.")

	var packed := Marshalls.base64_to_raw(parts[3])
	var raw := packed.decompress(size, FileAccess.COMPRESSION_DEFLATE)
	if raw.size() != size:
		return _fail("Код повреждён.")
	var parsed = JSON.parse_string(raw.get_string_from_utf8())
	if not (parsed is Dictionary):
		return _fail("Код повреждён.")
	return {"ok": true, "data": parsed, "error": ""}


# Краткое описание прогресса из кода для подтверждения
static func summary(data: Dictionary) -> String:
	var xp := maxi(0, int(data.get("xp", 0)))
	return "День %d · монет: %d · повар: уровень %d · предметов куплено: %d" % [
		maxi(1, int(data.get("day", 1))), maxi(0, int(data.get("coins", 0))),
		Skills.level_for_xp(xp), (data["owned"] as Array).size() if data.get("owned") is Array else 0
	]


static func _checksum(body: String, size: int) -> String:
	return ("%s|%d" % [body, size]).md5_text().substr(0, 6)


static func _fail(message: String) -> Dictionary:
	return {"ok": false, "data": {}, "error": message}
