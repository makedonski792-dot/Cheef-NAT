extends Control
# Начало смены: день, меню на сегодня и кнопка «Начать смену».
# Смены идут по кругу, по одной в день, выбирать рецепт не нужно:
# гости сами закажут любое блюдо из меню.

var _shift: Dictionary          # смена с настройками выбранной сложности
var _base_shift: Dictionary     # смена дня без учёта сложности
var _info_label: Label
var _level_buttons := {}


func _ready() -> void:
	_base_shift = GameState.pick_shift()
	_shift = GameState.make_shift()
	var menu := RecipeLoader.recipes_for_shift(_base_shift)

	var background := ColorRect.new()
	background.color = Color("f5ecd9")
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_CENTER)
	column.grow_horizontal = Control.GROW_DIRECTION_BOTH
	column.grow_vertical = Control.GROW_DIRECTION_BOTH
	column.add_theme_constant_override("separation", 8)
	add_child(column)

	column.add_child(_label("День %d: %s" % [GameState.day, _base_shift.get("name", "")], 34, Color("3b2a1a")))
	column.add_child(_label(_base_shift.get("description", ""), 17, Color("5b4a3a")))

	# Блюда меню с картинками
	var dishes := HBoxContainer.new()
	dishes.alignment = BoxContainer.ALIGNMENT_CENTER
	dishes.add_theme_constant_override("separation", 40)
	column.add_child(dishes)
	for recipe in menu:
		var dish := VBoxContainer.new()
		dish.add_theme_constant_override("separation", 0)
		var icon := TextureRect.new()
		icon.texture = Icons.food(recipe.get("dish_icon", ""))
		icon.custom_minimum_size = Vector2(60, 60)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		dish.add_child(icon)
		dish.add_child(_label(recipe["name"], 18, Color("3b2a1a")))
		dish.add_child(_label("от %d монет" % recipe["base_reward"], 14, Color("5b4a3a")))
		dishes.add_child(dish)

	# Выбор уровня сложности
	column.add_child(_label("Сложность:", 20, Color("3b2a1a")))
	var levels := HBoxContainer.new()
	levels.alignment = BoxContainer.ALIGNMENT_CENTER
	levels.add_theme_constant_override("separation", 12)
	column.add_child(levels)
	var group := ButtonGroup.new()
	for level_id in Difficulty.ORDER:
		var button := Button.new()
		button.text = Difficulty.level_name(level_id)
		button.toggle_mode = true
		button.button_group = group
		button.button_pressed = (level_id == GameState.difficulty)
		button.custom_minimum_size = Vector2(150, 46)
		button.add_theme_font_size_override("font_size", 20)
		# Выбранный уровень подсвечен оранжевым
		var selected := StyleBoxFlat.new()
		selected.bg_color = Color("e08a1e")
		selected.set_corner_radius_all(4)
		for style_name in ["pressed", "hover_pressed"]:
			button.add_theme_stylebox_override(style_name, selected)
		button.add_theme_color_override("font_pressed_color", Color.WHITE)
		button.add_theme_color_override("font_hover_pressed_color", Color.WHITE)
		button.pressed.connect(_on_level_pressed.bind(level_id))
		levels.add_child(button)
		_level_buttons[level_id] = button
	_info_label = _label("", 15, Color("5b4a3a"))
	column.add_child(_info_label)
	_update_info()

	var start := Button.new()
	start.text = "Начать смену"
	start.custom_minimum_size = Vector2(320, 60)
	start.add_theme_font_size_override("font_size", 28)
	start.pressed.connect(_on_start_pressed)
	column.add_child(start)

	# Внизу в ряд: «Как играть» и «Назад»
	var bottom := HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_theme_constant_override("separation", 12)
	column.add_child(bottom)

	var help := Button.new()
	help.text = "Как играть"
	help.custom_minimum_size = Vector2(154, 44)
	help.add_theme_font_size_override("font_size", 18)
	help.pressed.connect(_show_tutorial)
	bottom.add_child(help)

	var back := Button.new()
	back.text = "Назад в меню"
	back.custom_minimum_size = Vector2(154, 44)
	back.add_theme_font_size_override("font_size", 18)
	back.pressed.connect(_on_back_pressed)
	bottom.add_child(back)

	# Первый раз показываем обучение сразу
	if not GameState.tutorial_seen:
		_show_tutorial()


# Игрок выбрал уровень сложности: запоминаем и обновляем описание
func _on_level_pressed(level_id: String) -> void:
	GameState.difficulty = level_id
	GameState.save_game()
	_shift = GameState.make_shift()
	_update_info()


func _update_info() -> void:
	_info_label.text = Difficulty.describe(_shift)


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
