extends Control
# Начало смены: день, меню на сегодня и кнопка «Начать смену».
# Смены идут по кругу, по одной в день, выбирать рецепт не нужно:
# гости сами закажут любое блюдо из меню.

var _shift: Dictionary


func _ready() -> void:
	_shift = GameState.pick_shift()
	var menu := RecipeLoader.recipes_for_shift(_shift)

	var background := ColorRect.new()
	background.color = Color("f5ecd9")
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_CENTER)
	column.grow_horizontal = Control.GROW_DIRECTION_BOTH
	column.grow_vertical = Control.GROW_DIRECTION_BOTH
	column.add_theme_constant_override("separation", 12)
	add_child(column)

	column.add_child(_label("День %d" % GameState.day, 40, Color("3b2a1a")))
	column.add_child(_label(_shift.get("name", ""), 30, Color("8a5a00")))
	column.add_child(_label(_shift.get("description", ""), 18, Color("5b4a3a")))
	column.add_child(_label("Меню на сегодня:", 22, Color("3b2a1a")))

	# Блюда меню с картинками
	var dishes := HBoxContainer.new()
	dishes.alignment = BoxContainer.ALIGNMENT_CENTER
	dishes.add_theme_constant_override("separation", 40)
	column.add_child(dishes)
	for recipe in menu:
		var dish := VBoxContainer.new()
		dish.add_theme_constant_override("separation", 2)
		var icon := TextureRect.new()
		icon.texture = Icons.food(recipe.get("dish_icon", ""))
		icon.custom_minimum_size = Vector2(72, 72)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		dish.add_child(icon)
		dish.add_child(_label(recipe["name"], 20, Color("3b2a1a")))
		dish.add_child(_label("от %d монет" % recipe["base_reward"], 15, Color("5b4a3a")))
		dishes.add_child(dish)

	var minutes := int(_shift.get("duration", 420)) / 60
	column.add_child(_label("Смена длится %d минут. Гости приходят по очереди, у каждого свой таймер." % minutes, 16, Color("5b4a3a")))

	var start := Button.new()
	start.text = "Начать смену"
	start.custom_minimum_size = Vector2(300, 64)
	start.add_theme_font_size_override("font_size", 28)
	start.pressed.connect(_on_start_pressed)
	column.add_child(start)

	var help := Button.new()
	help.text = "Как играть"
	help.custom_minimum_size = Vector2(300, 48)
	help.add_theme_font_size_override("font_size", 20)
	help.pressed.connect(_show_tutorial)
	column.add_child(help)

	var back := Button.new()
	back.text = "Назад в меню"
	back.custom_minimum_size = Vector2(300, 48)
	back.add_theme_font_size_override("font_size", 20)
	back.pressed.connect(_on_back_pressed)
	column.add_child(back)

	# Первый раз показываем обучение сразу
	if not GameState.tutorial_seen:
		_show_tutorial()


# Короткая инструкция «Как играть» поверх экрана
func _show_tutorial() -> void:
	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.65)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)

	# Окно по центру экрана: CenterContainer сам ставит панель ровно посередине
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("fff8e8")
	style.set_corner_radius_all(14)
	style.set_content_margin_all(22)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(720, 0)
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)

	box.add_child(_label("Как играть", 30, Color("3b2a1a")))
	var steps := [
		"1. Веди повара пальцем в левой половине экрана (круг появится там, где коснёшься).",
		"2. Подойди к ящику с продуктом и нажми оранжевую кнопку справа: продукт у тебя в руках.",
		"3. Над кухней подсказка «Совет» скажет, что делать дальше с этим продуктом.",
		"4. ДОСКА: положи продукт и стой рядом, пока не нарежется. Нарезать надо всё, что режется: хлеб, лук, багет, сыр, овощи.",
		"5. ПЛИТА: положи нарезанный (или не режущийся) продукт, он приготовится сам. Не передержи, сгорит!",
		"6. СБОРКА: неси готовые продукты на тарелку. Блюдо определяется само. В списке слева: [Д] доска, [П] плита, [Д→П] сначала доска, потом плита.",
		"7. Блюдо готово? Возьми его и отнеси на РАЗДАЧУ, пока гость не ушёл. Выбросить лишнее можно в мусорку.",
	]
	for line in steps:
		var label := _label(line, 16, Color("3b2a1a"))
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size = Vector2(700, 0)
		box.add_child(label)

	var close := Button.new()
	close.text = "Понятно!"
	close.custom_minimum_size = Vector2(260, 52)
	close.add_theme_font_size_override("font_size", 22)
	close.pressed.connect(func():
		GameState.tutorial_seen = true
		GameState.save_game()
		overlay.queue_free())
	box.add_child(close)


func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


func _on_start_pressed() -> void:
	GameState.current_shift = _shift
	get_tree().change_scene_to_file("res://scenes/kitchen.tscn")


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
