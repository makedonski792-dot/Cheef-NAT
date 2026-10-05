class_name SaveGame
extends RefCounted
# Чтение и запись сохранения в JSON-файл.
# Путь user:// — это специальная папка Godot для данных игрока:
# на Mac и на Android она своя, и игра всегда имеет туда доступ.

const DEFAULT_PATH := "user://save.json"


# Записать словарь с данными в файл. Возвращает true при успехе.
static func write(data: Dictionary, path: String = DEFAULT_PATH) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Не удалось сохранить игру: " + path)
		return false
	file.store_string(JSON.stringify(data, "\t"))
	return true


# Прочитать сохранение. Если файла нет или он повреждён, вернёт пустой словарь
# (игра тогда просто начнётся с нуля, а не упадёт).
static func read(path: String = DEFAULT_PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		return parsed
	push_warning("Файл сохранения повреждён, начинаем с нуля: " + path)
	return {}
