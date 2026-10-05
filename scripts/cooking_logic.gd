class_name CookingLogic
extends RefCounted
# Правила готовки одного блюда. Не знает ничего про экран, только про рецепт.
# Использование:
#   var cooking := CookingLogic.new(recipe)
#   cooking.available_steps()   -> что можно сделать прямо сейчас
#   cooking.do_step("slice_onion")
#   cooking.grade(секунды)      -> итог: блюдо, звёзды, монеты

# Множитель награды в зависимости от звёзд (0 звёзд = блюдо испорчено)
const STAR_MULTIPLIER := {0: 0.0, 1: 0.6, 2: 0.8, 3: 1.0}
# Сколько секунд «эталонного» времени даём на один шаг
const PAR_SECONDS_PER_STEP := 8.0

var recipe: Dictionary
# Выполненные шаги в том порядке, в котором их сделал игрок
var done: Array[String] = []


func _init(recipe_data: Dictionary) -> void:
	recipe = recipe_data


# Найти шаг рецепта по его id (пустой словарь, если такого нет)
func get_step(step_id: String) -> Dictionary:
	for step in recipe["steps"]:
		if step["id"] == step_id:
			return step
	return {}


# Можно ли сделать этот шаг прямо сейчас?
func can_do(step_id: String) -> bool:
	var step := get_step(step_id)
	if step.is_empty() or step_id in done:
		return false
	for dep in step.get("requires", []):
		if not (dep in done):
			return false
	# blocked_by: если уже сделан один из этих шагов, то делать этот поздно
	for blocker in step.get("blocked_by", []):
		if blocker in done:
			return false
	return true


# Все шаги, которые игрок может сделать сейчас
func available_steps() -> Array:
	var result: Array = []
	for step in recipe["steps"]:
		if can_do(step["id"]):
			result.append(step)
	return result


# Выполнить шаг. Возвращает true, если получилось.
func do_step(step_id: String) -> bool:
	if not can_do(step_id):
		return false
	done.append(step_id)
	return true


# Варианты блюда, к которым ещё можно прийти (всё сделанное в них входит)
func possible_variants() -> Array:
	var result: Array = []
	for variant in recipe["variants"]:
		var fits := true
		for step_id in done:
			if not (step_id in variant["needs"]):
				fits = false
				break
		if fits:
			result.append(variant)
	return result


# Блюдо испорчено: сделаны шаги, которые не складываются ни в один вариант
func is_ruined() -> bool:
	return possible_variants().is_empty()


# Готовый вариант блюда (пустой словарь, если блюдо ещё не готово)
func finished_variant() -> Dictionary:
	for variant in recipe["variants"]:
		if variant["needs"].size() == done.size() and possible_variants().has(variant):
			return variant
	return {}


# Блюдо готово, когда выполнены ровно все шаги одного из вариантов
func is_finished() -> bool:
	return not finished_variant().is_empty()


# Эталонное время приготовления в секундах
func par_time() -> float:
	return recipe["steps"].size() * PAR_SECONDS_PER_STEP


# Оценка блюда. elapsed_seconds — сколько секунд игрок готовил.
# Возвращает словарь: variant (название), stars (0–3), reward (монеты).
func grade(elapsed_seconds: float) -> Dictionary:
	var variant := finished_variant()
	if variant.is_empty():
		# Не доготовлено или испорчено: награды нет
		return {"variant": "", "stars": 0, "reward": 0}

	var stars := 1
	if elapsed_seconds <= par_time():
		stars = 3
	elif elapsed_seconds <= par_time() * 1.5:
		stars = 2

	var total: float = recipe["base_reward"] + variant["bonus"]
	return {
		"variant": variant["name"],
		"stars": stars,
		"reward": int(round(total * STAR_MULTIPLIER[stars])),
	}
