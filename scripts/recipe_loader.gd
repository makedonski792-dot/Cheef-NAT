class_name RecipeLoader
extends RefCounted
# Загрузчик данных: читает ингредиенты и рецепты из JSON-файлов.
# Чтобы добавить рецепт, достаточно положить новый .json в папку data/recipes/.

const INGREDIENTS_PATH := "res://data/ingredients.json"
const RECIPES_DIR := "res://data/recipes"
const SHIFTS_DIR := "res://data/shifts"
# Сколько ящиков помещается вдоль верхнего стола
const MAX_CRATES := 11


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


# Возвращает смены по порядку (поле order). Смена — это меню из рецептов и
# настройки потока заказов.
static func load_shifts() -> Array:
	var shifts: Array = []
	var dir := DirAccess.open(SHIFTS_DIR)
	if dir == null:
		push_error("Не удалось открыть папку со сменами: " + SHIFTS_DIR)
		return shifts
	var all_recipes := load_recipes()
	for file_name in dir.get_files():
		if not file_name.ends_with(".json"):
			continue
		var shift = _read_json(SHIFTS_DIR + "/" + file_name)
		if shift is Dictionary and _is_valid_shift(shift, file_name, all_recipes):
			shifts.append(shift)
	shifts.sort_custom(func(a, b): return a.get("order", 0) < b.get("order", 0))
	return shifts


# Рецепты (словари) для данной смены, в порядке меню
static func recipes_for_shift(shift: Dictionary) -> Array:
	var result: Array = []
	var all_recipes := load_recipes()
	for id in shift.get("recipes", []):
		for recipe in all_recipes:
			if recipe["id"] == id:
				result.append(recipe)
	return result


# Все ингредиенты рецептов без повторов (по порядку): столько нужно ящиков
static func ingredients_for(recipes: Array) -> Array:
	var result: Array = []
	for recipe in recipes:
		for id in recipe.get("ingredients", []):
			if not (id in result):
				result.append(id)
	return result


static func _is_valid_shift(shift: Dictionary, file_name: String, all_recipes: Array) -> bool:
	for key in ["id", "name", "duration", "recipes"]:
		if not shift.has(key):
			push_error("В %s нет поля '%s'" % [file_name, key])
			return false
	var chosen: Array = []
	for id in shift["recipes"]:
		var found := false
		for recipe in all_recipes:
			if recipe["id"] == id:
				chosen.append(recipe)
				found = true
		if not found:
			push_error("В %s неизвестный рецепт '%s'" % [file_name, id])
			return false
	if ingredients_for(chosen).size() > MAX_CRATES:
		push_error("В %s слишком много ингредиентов (больше %d ящиков)" % [file_name, MAX_CRATES])
		return false
	return true


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
		# Каждый шаг — это подготовленный продукт, который кладут в блюдо
		if not step.has("item") or not step["item"].has("id") or not step["item"].has("state"):
			push_error("В %s у шага '%s' нет поля item {id, state}" % [file_name, step["id"]])
			return false

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
