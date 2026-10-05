extends Node2D
# Кухня, как в Overcooked: вид сверху, повар бегает между столами.
# Размер кухни 960x540 (горизонтальный экран).

const KITCHEN_SIZE := Vector2(960, 540)
# Как близко к месту должен подойти повар (от края повара)
const REACH := Chef.RADIUS + 16.0

var chef: Chef
var joystick: ScreenJoystick
var stations: Array[Station] = []

var _focus: Station
var _hint_label: Label
var _action_button: ActionButton


func _ready() -> void:
	_build_floor_and_walls()
	_build_stations()

	# Повар
	chef = Chef.new()
	chef.position = Vector2(480, 400)
	chef.z_index = 10
	add_child(chef)

	_build_interface()


func _process(_delta: float) -> void:
	# Ищем ближайшее место, с которым можно что-то сделать, и подсвечиваем его
	var target := find_station()
	if target != _focus:
		if _focus != null:
			_focus.focused = false
		_focus = target
		if _focus != null:
			_focus.focused = true

	if _focus != null:
		var verb := _focus.verb(chef)
		_action_button.label_text = verb
		_hint_label.text = "%s: %s" % [verb, _focus.target_name(chef)]
	else:
		_action_button.label_text = ""
		_hint_label.text = ""


# Пробел или Enter на клавиатуре — то же, что кнопка действия
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		do_action()


# Выполнить действие с ближайшим подходящим местом
func do_action() -> void:
	var target := find_station()
	if target != null:
		target.interact(chef)


# Ближайшее место, где у повара есть доступное действие (или null)
func find_station() -> Station:
	var best: Station = null
	var best_distance := REACH
	for station in stations:
		if station.verb(chef) == "":
			continue
		var distance := station.distance_to(chef.position)
		if distance <= best_distance:
			best_distance = distance
			best = station
	return best


# Пол, стены и столы. Всё, что рисуем как блок, ещё и не пускает повара.
func _build_floor_and_walls() -> void:
	# Огромный тёмный фон (виден, если экран шире кухни) и сам пол
	_add_floor(Rect2(-2000, -2000, 5000, 5000), Color("2b2018"))
	_add_floor(Rect2(Vector2.ZERO, KITCHEN_SIZE), Color("e9dcc0"))

	var wall_color := Color("5b3a1e")
	var counter_color := Color("b08a5a")
	_add_block(Rect2(0, 0, 960, 70), counter_color)   # длинный стол у верхней стены
	_add_block(Rect2(0, 520, 960, 20), wall_color)    # нижняя стена
	_add_block(Rect2(0, 0, 20, 540), wall_color)      # левая стена
	_add_block(Rect2(940, 0, 20, 540), wall_color)    # правая стена


func _add_floor(rect: Rect2, color: Color) -> void:
	var floor_rect := ColorRect.new()
	floor_rect.position = rect.position
	floor_rect.size = rect.size
	floor_rect.color = color
	add_child(floor_rect)


# Простой твёрдый блок (стена)
func _add_block(rect: Rect2, color: Color) -> void:
	var block := Station.new()
	block.setup(rect, color, "")
	add_child(block)


# Ящики по рецепту, столы и мусорка
func _build_stations() -> void:
	var ingredients := RecipeLoader.load_ingredients()
	var ids: Array = GameState.current_recipe.get("ingredients", [])
	if ids.is_empty():
		ids = ["onion", "butter", "beef_broth"]

	# Ящики в ряд вдоль верхнего стола, по центру
	var cell := 110.0
	var start := 40.0 + (880.0 - ids.size() * cell) / 2.0
	for i in ids.size():
		var crate := Crate.new()
		crate.setup_crate(ids[i], ingredients.get(ids[i], {}), Rect2(start + i * cell + 7, 8, 96, 56))
		_add_station(crate)

	# Два стола и мусорка
	var island := Table.new()
	island.setup(Rect2(400, 240, 160, 70), Color("b08a5a"), "Стол")
	_add_station(island)

	var side_table := Table.new()
	side_table.setup(Rect2(60, 400, 150, 70), Color("b08a5a"), "Стол")
	_add_station(side_table)

	var bin := TrashBin.new()
	bin.setup(Rect2(850, 420, 90, 90), Color("6b7280"), "Мусорка")
	_add_station(bin)


func _add_station(station: Station) -> void:
	add_child(station)
	stations.append(station)


# Экранный слой: заголовок, подсказка, кнопка «Меню», джойстик, кнопка действия
func _build_interface() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	var title := Label.new()
	title.text = "Кухня: %s" % GameState.current_recipe.get("name", "свободная игра")
	title.position = Vector2(30, 76)
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color("3b2a1a"))
	layer.add_child(title)

	# Подсказка: что произойдёт по кнопке действия
	_hint_label = Label.new()
	_hint_label.position = Vector2(30, 102)
	_hint_label.add_theme_font_size_override("font_size", 22)
	_hint_label.add_theme_color_override("font_color", Color("8a3b00"))
	layer.add_child(_hint_label)

	var menu_button := Button.new()
	menu_button.text = "Меню"
	menu_button.custom_minimum_size = Vector2(110, 44)
	menu_button.anchor_left = 1.0
	menu_button.anchor_right = 1.0
	menu_button.offset_left = -130
	menu_button.offset_right = -20
	menu_button.offset_top = 90
	menu_button.pressed.connect(_on_menu_pressed)
	layer.add_child(menu_button)

	joystick = ScreenJoystick.new()
	layer.add_child(joystick)
	chef.joystick = joystick

	_action_button = ActionButton.new()
	_action_button.pressed.connect(do_action)
	layer.add_child(_action_button)


func _on_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
