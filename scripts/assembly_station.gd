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
		var missing := _missing_requirements(step["id"])
		if not missing.is_empty():
			return "сначала добавь: %s" % ", ".join(missing)
		for blocker in step.get("blocked_by", []):
			if blocker in logic.done:
				return "уже поздно, добавлено: %s" % _step_text(blocker)
		if not logic.can_do_safely(step["id"]):
			return "не сочетается с уже добавленным"
		return ""

	# Продукт нужен, но в другом виде (может быть несколько подходящих видов)
	var options: Array[String] = []
	for step in same_ingredient:
		options.append(item.name + FoodItem.state_suffix(step["item"]["state"]))
	return "нужно: %s" % " или ".join(options)


# Что ещё нужно добавить до этого шага, включая цепочку (масло → лук → баклажан).
# Возвращает названия шагов по порядку, без повторов.
func _missing_requirements(step_id: String) -> Array[String]:
	var result: Array[String] = []
	for step in logic.recipe["steps"]:
		if step["id"] != step_id:
			continue
		for dep in step.get("requires", []):
			if dep in logic.done:
				continue
			for deeper in _missing_requirements(dep):
				if not (deeper in result):
					result.append(deeper)
			var text := _step_text(dep)
			if not (text in result):
				result.append(text)
	return result


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
			Sound.play("add")
			Fx.burst(self, Vector2(_visual_size.x / 2.0, 37.0), Color("ffe08a"), 8, 80.0, 0.5, 120.0)
			if logic.is_finished():
				Sound.play("done")
				Fx.burst(self, Vector2(_visual_size.x / 2.0, 37.0), Color("fbbf24"), 18, 120.0, 0.7, 180.0)
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
		"icon": logic.recipe.get("dish_icon", ""),
	})
	item.is_dish = true
	return item


# Пока блюдо готово и ждёт, золотая рамка пульсирует
func _process(delta: float) -> void:
	super._process(delta)
	if logic != null and logic.is_finished() and not dish_taken:
		queue_redraw()


# На тарелке рисуем добавленные продукты (мелкие картинки в ряд),
# а когда блюдо готово — золотую рамку и надпись
func _draw_extra() -> void:
	var count := delivered.size()
	var step := minf(26.0, 100.0 / maxf(1.0, count))
	for i in count:
		var center := Vector2(_visual_size.x / 2.0 + (i - (count - 1) / 2.0) * step, 40.0)
		var texture := Icons.for_item(delivered[i])
		if texture != null:
			draw_texture_rect(texture, Rect2(center - Vector2(13, 13), Vector2(26, 26)), false)
		else:
			draw_circle(center, 8.0, delivered[i].color)

	if logic != null and logic.is_finished() and not dish_taken:
		var glow := 0.7 + 0.3 * sin(Time.get_ticks_msec() / 140.0)
		draw_rect(Rect2(Vector2.ZERO, _visual_size).grow(2), Color(0.98, 0.75, 0.14, glow), false, 4.0)
		var font := ThemeDB.fallback_font
		draw_string_outline(font, Vector2(0, 64), "ГОТОВО!", HORIZONTAL_ALIGNMENT_CENTER,
				_visual_size.x, 16, 5, Color("2b2018"))
		draw_string(font, Vector2(0, 64), "ГОТОВО!", HORIZONTAL_ALIGNMENT_CENTER,
				_visual_size.x, 16, Color("fbbf24"))
