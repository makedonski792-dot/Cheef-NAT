extends Control
# Главное меню: название игры, счётчик монет и кнопка «Готовить».
# Интерфейс собираем кодом, так проще читать и менять.


func _ready() -> void:
	# Фон цвета тёплого кремового
	var background := ColorRect.new()
	background.color = Color("f5ecd9")
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	# Колонка по центру экрана, в неё складываем элементы сверху вниз
	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_CENTER)
	column.grow_horizontal = Control.GROW_DIRECTION_BOTH
	column.grow_vertical = Control.GROW_DIRECTION_BOTH
	column.add_theme_constant_override("separation", 24)
	add_child(column)

	var title := Label.new()
	title.text = "Французский шеф"
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", Color("3b2a1a"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)

	var coins_label := Label.new()
	coins_label.text = "Монеты: %d" % GameState.coins
	coins_label.add_theme_font_size_override("font_size", 28)
	coins_label.add_theme_color_override("font_color", Color("8a5a00"))
	coins_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(coins_label)

	var cook_button := Button.new()
	cook_button.text = "Готовить"
	cook_button.custom_minimum_size = Vector2(320, 80)
	cook_button.add_theme_font_size_override("font_size", 32)
	cook_button.pressed.connect(_on_cook_pressed)
	column.add_child(cook_button)


# Вызывается при нажатии на кнопку «Готовить»: открываем выбор рецепта
func _on_cook_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/recipe_select.tscn")
