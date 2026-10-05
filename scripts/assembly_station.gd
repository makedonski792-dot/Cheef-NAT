class_name AssemblyStation
extends Station
# Станция «Сборка»: сюда кладут подготовленные продукты, из которых собирается блюдо.
# Одна тарелка на все блюда смены: по тому, что кладёшь, станция сама понимает,
# какое блюдо собирается. Принимает только то, что подходит и не портит блюдо.
# Когда блюдо собрано, его можно взять и отнести на раздачу.

var menu: Array = []                       # рецепты смены
var candidates: Array[CookingLogic] = []   # блюда, к которым ещё подходит содержимое тарелки
var delivered: Array[FoodItem] = []        # что уже лежит на тарелке


# Задать меню смены и очистить тарелку
func setup_menu(recipes: Array) -> void:
	menu = recipes
	reset_plate()


func reset_plate() -> void:
	candidates.clear()
	for recipe in menu:
		candidates.append(CookingLogic.new(recipe))
	delivered.clear()
	queue_redraw()


func is_plate_empty() -> bool:
	return delivered.is_empty()


# Id шага рецепта, которому подходит этот предмет (пустая строка — не подходит)
static func step_for(cooking: CookingLogic, item: FoodItem) -> String:
	for step in cooking.recipe["steps"]:
		var need: Dictionary = step["item"]
		if need["id"] == item.id and need["state"] == item.state and cooking.can_do_safely(step["id"]):
			return step["id"]
	return ""


# Блюда, которым подходит этот предмет
func accepting(item: FoodItem) -> Array[CookingLogic]:
	var result: Array[CookingLogic] = []
	if item.is_dish:
		return result
	for cooking in candidates:
		if step_for(cooking, item) != "":
			result.append(cooking)
	return result


# Блюдо, которое уже собрано полностью (или null)
func finished_candidate() -> CookingLogic:
	if delivered.is_empty():
		return null
	for cooking in candidates:
		if cooking.is_finished():
			return cooking
	return null


# Блюдо, которое сейчас больше всего похоже на содержимое тарелки (или null, если тарелка пуста)
func best_candidate() -> CookingLogic:
	if delivered.is_empty():
		return null
	var best: CookingLogic = null
	for cooking in candidates:
		if best == null or cooking.done.size() > best.done.size():
			best = cooking
	return best


# Собирается ли сейчас это блюдо (для подсветки билета заказа)
func is_building(recipe_id: String) -> bool:
	if delivered.is_empty():
		return false
	for cooking in candidates:
		if cooking.recipe["id"] == recipe_id:
			return true
	return false


# Почему предмет сейчас нельзя добавить (подсказка игроку). Пусто, если можно.
func reject_reason(item: FoodItem) -> String:
	if item.is_dish or not accepting(item).is_empty():
		return ""
	for cooking in candidates:
		var uses: bool = cooking.recipe["steps"].any(func(s): return s["item"]["id"] == item.id)
		if not uses:
			continue
		var reason := _reason_for(cooking, item)
		if reason != "":
			return reason if candidates.size() == 1 else "%s: %s" % [cooking.recipe["name"], reason]
	if delivered.is_empty():
		return "%s не нужен ни для одного блюда смены" % item.name
	return "%s не подходит к тому, что уже на тарелке" % item.name


# Причина отказа для одного блюда
func _reason_for(cooking: CookingLogic, item: FoodItem) -> String:
	var same_ingredient: Array = cooking.recipe["steps"].filter(func(s): return s["item"]["id"] == item.id)
	for step in same_ingredient:
		if step["item"]["state"] != item.state:
			continue
		if step["id"] in cooking.done:
			return "%s уже добавлено" % item.name
		var missing := _missing_requirements(cooking, step["id"])
		if not missing.is_empty():
			return "сначала добавь: %s" % ", ".join(missing)
		for blocker in step.get("blocked_by", []):
			if blocker in cooking.done:
				return "уже поздно, добавлено: %s" % _step_text(cooking, blocker)
		if not cooking.can_do_safely(step["id"]):
			return "не сочетается с уже добавленным"
		return ""

	# Продукт нужен, но в другом виде (может быть несколько подходящих видов)
	var options: Array[String] = []
	for step in same_ingredient:
		options.append(item.name + FoodItem.state_suffix(step["item"]["state"]))
	return "нужно: %s" % " или ".join(options)


# Что ещё нужно добавить до этого шага, включая цепочку (масло → лук → баклажан).
# Возвращает названия шагов по порядку, без повторов.
func _missing_requirements(cooking: CookingLogic, step_id: String) -> Array[String]:
	var result: Array[String] = []
	for step in cooking.recipe["steps"]:
		if step["id"] != step_id:
			continue
		for dep in step.get("requires", []):
			if dep in cooking.done:
				continue
			for deeper in _missing_requirements(cooking, dep):
				if not (deeper in result):
					result.append(deeper)
			var text := _step_text(cooking, dep)
			if not (text in result):
				result.append(text)
	return result


func _step_text(cooking: CookingLogic, step_id: String) -> String:
	for step in cooking.recipe["steps"]:
		if step["id"] == step_id:
			return step["text"].to_lower()
	return step_id


func verb(chef: Chef) -> String:
	if chef.held != null:
		return "Добавить" if not accepting(chef.held).is_empty() else ""
	return "Взять блюдо" if finished_candidate() != null else ""


func target_name(chef: Chef) -> String:
	if chef.held != null:
		return chef.held.display_name()
	var finished := finished_candidate()
	if finished != null:
		return finished.recipe["name"]
	return _label


func interact(chef: Chef) -> void:
	if chef.held != null:
		var matching := accepting(chef.held)
		if matching.is_empty():
			return
		# Продукт кладётся во все подходящие блюда; остальные отпадают
		for cooking in matching:
			cooking.do_step(step_for(cooking, chef.held))
		candidates = matching
		delivered.append(chef.drop())
		Sound.play("add")
		Fx.burst(self, Vector2(_visual_size.x / 2.0, 37.0), Color("ffe08a"), 8, 80.0, 0.5, 120.0)
		if finished_candidate() != null:
			Sound.play("done")
			Fx.burst(self, Vector2(_visual_size.x / 2.0, 37.0), Color("fbbf24"), 18, 120.0, 0.7, 180.0)
	else:
		var finished := finished_candidate()
		if finished != null:
			chef.hold(_make_dish(finished))
			reset_plate()
	queue_redraw()


# Предмет «готовое блюдо», которое повар несёт на раздачу
func _make_dish(cooking: CookingLogic) -> FoodItem:
	var variant := cooking.finished_variant()
	var item := FoodItem.new("dish", {
		"name": "%s (%s)" % [cooking.recipe["name"], variant["name"]],
		"color": "#f2c94c",
		"icon": cooking.recipe.get("dish_icon", ""),
	})
	item.is_dish = true
	item.dish_recipe_id = cooking.recipe["id"]
	item.dish_logic = cooking
	return item


# Пока блюдо готово и ждёт, золотая рамка пульсирует
func _process(delta: float) -> void:
	super._process(delta)
	if finished_candidate() != null:
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

	if finished_candidate() != null:
		var glow := 0.7 + 0.3 * sin(Time.get_ticks_msec() / 140.0)
		draw_rect(Rect2(Vector2.ZERO, _visual_size).grow(2), Color(0.98, 0.75, 0.14, glow), false, 4.0)
		var font := ThemeDB.fallback_font
		draw_string_outline(font, Vector2(0, 64), "ГОТОВО!", HORIZONTAL_ALIGNMENT_CENTER,
				_visual_size.x, 16, 5, Color("2b2018"))
		draw_string(font, Vector2(0, 64), "ГОТОВО!", HORIZONTAL_ALIGNMENT_CENTER,
				_visual_size.x, 16, Color("fbbf24"))
