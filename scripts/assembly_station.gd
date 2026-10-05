class_name AssemblyStation
extends Station
# Станция «Сборка»: сюда кладут подготовленные продукты, из которых собирается блюдо.
# Принимает только то, что подходит по рецепту (и не портит блюдо).
# Когда блюдо собрано, его можно взять и отнести на раздачу.

var logic: CookingLogic          # состояние заказа (его подключает кухня)
var delivered: Array[FoodItem] = []
var dish_taken := false


# Id шага рецепта, которому подходит этот предмет (пустая строка — не подходит)
func matching_step(item: FoodItem) -> String:
	if logic == null or item.is_dish:
		return ""
	for step in logic.recipe["steps"]:
		var need: Dictionary = step["item"]
		if need["id"] == item.id and need["state"] == item.state and logic.can_do_safely(step["id"]):
			return step["id"]
	return ""


# Почему предмет сейчас нельзя добавить (подсказка игроку). Пусто, если можно.
func reject_reason(item: FoodItem) -> String:
	if logic == null or item.is_dish:
		return ""
	var same_ingredient: Array = logic.recipe["steps"].filter(func(s): return s["item"]["id"] == item.id)
	if same_ingredient.is_empty():
		return "%s не нужен для этого блюда" % item.name

	for step in same_ingredient:
		if step["item"]["state"] != item.state:
			continue
		if step["id"] in logic.done:
			return "%s уже добавлено" % item.name
		for dep in step.get("requires", []):
			if not (dep in logic.done):
				return "сначала добавь: %s" % _step_text(dep)
		for blocker in step.get("blocked_by", []):
			if blocker in logic.done:
				return "уже поздно, добавлено: %s" % _step_text(blocker)
		if not logic.can_do_safely(step["id"]):
			return "не сочетается с уже добавленным"
		return ""

	# Продукт нужен, но в другом виде
	var need: Dictionary = same_ingredient[0]["item"]
	return "нужно: %s%s" % [item.name, FoodItem.state_suffix(need["state"])]


func _step_text(step_id: String) -> String:
	for step in logic.recipe["steps"]:
		if step["id"] == step_id:
			return step["text"].to_lower()
	return step_id


func verb(chef: Chef) -> String:
	if logic == null:
		return ""
	if chef.held != null:
		return "Добавить" if matching_step(chef.held) != "" else ""
	if logic.is_finished() and not dish_taken:
		return "Взять блюдо"
	return ""


func target_name(chef: Chef) -> String:
	if chef.held != null:
		return chef.held.display_name()
	if logic != null and logic.is_finished():
		return logic.recipe["name"]
	return _label


func interact(chef: Chef) -> void:
	if chef.held != null:
		var step_id := matching_step(chef.held)
		if step_id != "":
			logic.do_step(step_id)
			delivered.append(chef.drop())
	elif logic != null and logic.is_finished() and not dish_taken:
		dish_taken = true
		delivered.clear()
		chef.hold(_make_dish())
	queue_redraw()


# Предмет «готовое блюдо», которое повар несёт на раздачу
func _make_dish() -> FoodItem:
	var variant := logic.finished_variant()
	var item := FoodItem.new("dish", {
		"name": "%s (%s)" % [logic.recipe["name"], variant["name"]],
		"color": "#f2c94c",
	})
	item.is_dish = true
	return item


# Внутри станции рисуем кружки добавленных продуктов, а когда готово — золотую рамку
func _draw_extra() -> void:
	for i in delivered.size():
		var center := Vector2(14 + i * 18, _visual_size.y - 14)
		draw_circle(center, 8.0, delivered[i].color)
		draw_arc(center, 8.0, 0.0, TAU, 16, Color("3b2a1a"), 1.5)
	if logic != null and logic.is_finished() and not dish_taken:
		draw_rect(Rect2(Vector2.ZERO, _visual_size).grow(2), Color("fbbf24"), false, 4.0)
		draw_string(ThemeDB.fallback_font, Vector2(0, 16), "ГОТОВО!",
				HORIZONTAL_ALIGNMENT_CENTER, _visual_size.x, 16, Color("fbbf24"))
