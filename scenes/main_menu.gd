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
	column.add_theme_constant_override("separation", 14)
	add_child(column)

	var title := Label.new()
	title.text = "Французский шеф"
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", Color("3b2a1a"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)

	var day_label := Label.new()
	day_label.text = "День %d" % GameState.day
	day_label.add_theme_font_size_override("font_size", 26)
	day_label.add_theme_color_override("font_color", Color("3b2a1a"))
	day_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(day_label)

	var coins_label := Label.new()
	coins_label.text = "Монеты: %d" % GameState.coins
	coins_label.add_theme_font_size_override("font_size", 28)
	coins_label.add_theme_color_override("font_color", Color("8a5a00"))
	coins_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(coins_label)

	var level_label := Label.new()
	level_label.text = "Повар: уровень %d" % GameState.chef_level()
	level_label.add_theme_font_size_override("font_size", 20)
	level_label.add_theme_color_override("font_color", Color("1b5e20"))
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(level_label)

	var cook_button := Button.new()
	cook_button.text = "Начать смену"
	cook_button.custom_minimum_size = Vector2(320, 80)
	cook_button.add_theme_font_size_override("font_size", 32)
	cook_button.pressed.connect(_on_cook_pressed)
	column.add_child(cook_button)

	# Мастерская: интерьер, ножи, костюмы и навыки повара
	var shop_button := Button.new()
	shop_button.text = "Мастерская"
	shop_button.custom_minimum_size = Vector2(320, 64)
	shop_button.add_theme_font_size_override("font_size", 26)
	shop_button.pressed.connect(_on_shop_pressed)
	column.add_child(shop_button)


# Открываем Мастерскую
func _on_shop_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/shop.tscn")


# Вызывается при нажатии на кнопку: открываем экран начала смены
func _on_cook_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/shift_intro.tscn")
