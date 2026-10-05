class_name RecipeLoader
extends RefCounted
# Загрузчик данных: читает ингредиенты и рецепты из JSON-файлов.
# Чтобы добавить рецепт, достаточно положить новый .json в папку data/recipes/.

const INGREDIENTS_PATH := "res://data/ingredients.json"
const RECIPES_DIR := "res://data/recipes"


# Возвращает словарь ингредиентов: id -> {name, emoji}
static func load_ingredients() -> Dictionary:
	var data = _read_json(INGREDIENTS_PATH)
	if data is Dictionary:
		return data
	return {}


# Возвращает массив рецептов (каждый рецепт — словарь из JSON)
static func load_recipes() -> Array:
	var recipes: Array = []
	var dir := DirAccess.open(RECIPES_DIR)
	if dir == null:
		push_error("Не удалось открыть папку с рецептами: " + RECIPES_DIR)
		return recipes

	for file_name in dir.get_files():
		if not file_name.ends_with(".json"):
			continue
		var recipe = _read_json(RECIPES_DIR + "/" + file_name)
		if recipe is Dictionary and _is_valid(recipe, file_name):
			recipes.append(recipe)

	# Сортируем по названию, чтобы порядок в меню был одинаковым
	recipes.sort_custom(func(a, b): return a["name"] < b["name"])
	return recipes


# Читает JSON-файл. Если файл сломан, пишет понятную ошибку и возвращает null
static func _read_json(path: String):
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Не удалось открыть файл: " + path)
		return null
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed == null:
		push_error("Файл содержит ошибку в JSON: " + path)
	return parsed


# Проверяет, что в рецепте есть все нужные поля и ссылки на шаги верные
static func _is_valid(recipe: Dictionary, file_name: String) -> bool:
	for key in ["id", "name", "base_reward", "steps", "variants"]:
		if not recipe.has(key):
			push_error("В %s нет поля '%s'" % [file_name, key])
			return false

	var step_ids := {}
	for step in recipe["steps"]:
		step_ids[step["id"]] = true

	for step in recipe["steps"]:
		for dep in step.get("requires", []) + step.get("blocked_by", []):
			if not step_ids.has(dep):
				push_error("В %s шаг '%s' ссылается на неизвестный шаг '%s'" % [file_name, step["id"], dep])
				return false

	for variant in recipe["variants"]:
		for needed in variant["needs"]:
			if not step_ids.has(needed):
				push_error("В %s вариант '%s' требует неизвестный шаг '%s'" % [file_name, variant["id"], needed])
				return false
	return true
