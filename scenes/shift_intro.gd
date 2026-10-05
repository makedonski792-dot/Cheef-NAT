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

	var back := Button.new()
	back.text = "Назад в меню"
	back.custom_minimum_size = Vector2(300, 48)
	back.add_theme_font_size_override("font_size", 20)
	back.pressed.connect(_on_back_pressed)
	column.add_child(back)


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
