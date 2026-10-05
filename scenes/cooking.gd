extends Control
# Экран готовки: заказ гостя, таймер, сделанные шаги и кнопки доступных шагов.

const TEXT_COLOR := Color("3b2a1a")

var _recipe: Dictionary
var _cooking: CookingLogic
var _ingredients: Dictionary

var _elapsed := 0.0
var _running := true

var _timer_label: Label
var _done_label: Label
var _steps_title: Label
var _steps_box: VBoxContainer
var _result_label: Label
var _bottom_box: HBoxContainer


func _ready() -> void:
	_recipe = GameState.current_recipe
	_cooking = CookingLogic.new(_recipe)
	_ingredients = RecipeLoader.load_ingredients()
	_build_ui()
	_refresh()


# Таймер идёт, пока блюдо готовится
func _process(delta: float) -> void:
	if not _running:
		return
	_elapsed += delta
	_timer_label.text = "Время: %d с (эталон %d с)" % [int(_elapsed), int(_cooking.par_time())]


# ---------- Построение интерфейса ----------

func _label(font_size: int, color := TEXT_COLOR) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color("f5ecd9")
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)

	var title := _label(34)
	title.text = _recipe["name"]
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)

	var order := _label(18)
	order.text = _recipe.get("description", "")
	column.add_child(order)

	# Ингредиенты с эмодзи одной строкой
	var parts: Array[String] = []
	for id in _recipe.get("ingredients", []):
		var ing: Dictionary = _ingredients.get(id, {})
		parts.append("%s %s" % [ing.get("emoji", ""), ing.get("name", id)])
	var ingredients := _label(18, Color("6b4a2a"))
	ingredients.text = "Ингредиенты: " + ", ".join(parts)
	column.add_child(ingredients)

	_timer_label = _label(20, Color("8a5a00"))
	column.add_child(_timer_label)

	column.add_child(HSeparator.new())

	_done_label = _label(18, Color("2f6b2f"))
	column.add_child(_done_label)

	_steps_title = _label(22)
	_steps_title.text = "Что делаем дальше?"
	column.add_child(_steps_title)

	# Список кнопок с шагами (прокручивается)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)

	_steps_box = VBoxContainer.new()
	_steps_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_steps_box.add_theme_constant_override("separation", 8)
	scroll.add_child(_steps_box)

	# Итог блюда (виден в конце)
	_result_label = _label(24)
	_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_label.visible = false
	column.add_child(_result_label)

	# Нижние кнопки
	_bottom_box = HBoxContainer.new()
	_bottom_box.add_theme_constant_override("separation", 10)
	column.add_child(_bottom_box)
	_add_bottom_button("К рецептам", _on_back_to_recipes)


func _add_bottom_button(text: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 64)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 22)
	button.pressed.connect(callback)
	_bottom_box.add_child(button)


# ---------- Игровой процесс ----------

# Игрок нажал на шаг (так же вызываем его из автотеста)
func choose_step(step_id: String) -> void:
	if _cooking.do_step(step_id):
		_refresh()


# Обновить экран по текущему состоянию блюда
func _refresh() -> void:
	# Список сделанных шагов
	var lines: Array[String] = []
	for i in _cooking.done.size():
		lines.append("%d. %s" % [i + 1, _cooking.get_step(_cooking.done[i])["text"]])
	_done_label.text = "Сделано:\n" + "\n".join(lines) if not lines.is_empty() else "Пока ничего не сделано."

	# Старые кнопки убираем
	for child in _steps_box.get_children():
		child.queue_free()

	if _cooking.is_finished():
		_finish_dish()
	elif _cooking.is_ruined():
		_spoil_dish()
	else:
		for step in _cooking.available_steps():
			var button := Button.new()
			button.text = step["text"]
			button.custom_minimum_size = Vector2(0, 64)
			button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			button.add_theme_font_size_override("font_size", 20)
			button.pressed.connect(choose_step.bind(step["id"]))
			_steps_box.add_child(button)


# Блюдо приготовлено: оцениваем, платим монеты
func _finish_dish() -> void:
	_running = false
	_steps_title.visible = false
	var result := _cooking.grade(_elapsed)
	GameState.add_coins(result["reward"])
	var stars: int = result["stars"]
	_result_label.text = "Готово! %s\nВариант: %s\n%s\nНаграда: +%d монет" % [
		_recipe["name"], result["variant"], "★".repeat(stars) + "☆".repeat(3 - stars), result["reward"]
	]
	_result_label.visible = true


# Блюдо испорчено: награды нет
func _spoil_dish() -> void:
	_running = false
	_steps_title.visible = false
	_result_label.text = "Блюдо испорчено: шаги из разных способов приготовления смешались. Попробуй ещё раз!"
	_result_label.visible = true
	_add_bottom_button("Заново", _on_retry)


func _on_retry() -> void:
	get_tree().reload_current_scene()


func _on_back_to_recipes() -> void:
	get_tree().change_scene_to_file("res://scenes/recipe_select.tscn")
