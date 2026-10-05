extends Control
# Главное меню: название игры, счётчик монет и кнопка «Готовить».
# Интерфейс собираем кодом, так проще читать и менять.

# Пока монеты просто число. В шаге 5 они будут сохраняться между запусками.
var coins: int = 0

var _info_label: Label


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
	coins_label.text = "Монеты: %d" % coins
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

	# Строка для сообщений игроку (пока там заглушка)
	_info_label = Label.new()
	_info_label.add_theme_color_override("font_color", Color("3b2a1a"))
	_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_info_label)


# Вызывается при нажатии на кнопку «Готовить»
func _on_cook_pressed() -> void:
	# Временная проверка шага 2: показываем, какие рецепты загрузились
	var recipes := RecipeLoader.load_recipes()
	var lines: Array[String] = []
	for recipe in recipes:
		lines.append("%s: шагов %d, вариантов %d, награда %d" % [
			recipe["name"], recipe["steps"].size(), recipe["variants"].size(), recipe["base_reward"]
		])
	_info_label.text = "Загружено рецептов: %d\n%s" % [recipes.size(), "\n".join(lines)]
