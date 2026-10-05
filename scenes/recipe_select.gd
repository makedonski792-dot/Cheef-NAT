extends Control
# Экран выбора рецепта: список блюд из папки data/recipes/.


func _ready() -> void:
	var background := ColorRect.new()
	background.color = Color("f5ecd9")
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	# Отступы от краёв экрана
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	margin.add_child(column)

	var title := Label.new()
	title.text = "Что приготовим?"
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color("3b2a1a"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)

	# Прокручиваемый список, чтобы влезло много рецептов
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 12)
	scroll.add_child(list)

	for recipe in RecipeLoader.load_recipes():
		var button := Button.new()
		button.text = "%s\n(награда от %d монет)" % [recipe["name"], recipe["base_reward"]]
		button.custom_minimum_size = Vector2(0, 90)
		button.add_theme_font_size_override("font_size", 24)
		button.pressed.connect(_on_recipe_pressed.bind(recipe))
		list.add_child(button)

	var back_button := Button.new()
	back_button.text = "Назад в меню"
	back_button.custom_minimum_size = Vector2(0, 64)
	back_button.add_theme_font_size_override("font_size", 24)
	back_button.pressed.connect(_on_back_pressed)
	column.add_child(back_button)


# Игрок выбрал рецепт: запоминаем и идём готовить
func _on_recipe_pressed(recipe: Dictionary) -> void:
	GameState.current_recipe = recipe
	get_tree().change_scene_to_file("res://scenes/kitchen.tscn")


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
