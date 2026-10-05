extends Node2D
# Кухня, как в Overcooked: вид сверху, повар бегает между станциями.
# Здесь же идёт заказ: таймер, список «что нужно», сборка и подача блюда.
# Размер кухни 960x540 (горизонтальный экран).

const KITCHEN_SIZE := Vector2(960, 540)
# Как близко к месту должен подойти повар (от края повара)
const REACH := Chef.RADIUS + 16.0
const DEFAULT_TIME_LIMIT := 180.0

var chef: Chef
var joystick: ScreenJoystick
var stations: Array[Station] = []
var assembly: AssemblyStation
var serve_window: ServeWindow

# Заказ
var recipe: Dictionary
var logic: CookingLogic
var elapsed := 0.0
var time_limit := DEFAULT_TIME_LIMIT
var ended := false
var last_result: Dictionary = {}

var _required := {}   # id шагов, которые есть в любом варианте блюда
var _focus: Station
var _hint_label: Label
var _action_button: ActionButton
var _timer_label: Label
var _order_label: Label
var _sound_button: Button


func _ready() -> void:
	recipe = GameState.current_recipe
	if recipe.is_empty():
		recipe = RecipeLoader.load_recipes()[0]
	logic = CookingLogic.new(recipe)
	time_limit = float(recipe.get("time_limit", DEFAULT_TIME_LIMIT))
	_find_required_steps()

	_build_floor_and_walls()
	_build_stations()

	# Повар
	chef = Chef.new()
	chef.position = Vector2(480, 360)
	chef.z_index = 10
	add_child(chef)

	# Станциям с работой нужно знать, где повар (доска режет, только пока он рядом)
	for station in stations:
		if station is WorkStation:
			station.worker = chef

	_build_interface()
	_refresh_order()


# Уходя с кухни, выключаем все зацикленные звуки
func _exit_tree() -> void:
	Sound.stop_loops()


func _process(delta: float) -> void:
	if ended:
		return

	elapsed += delta
	var left := maxf(0.0, time_limit - elapsed)
	_timer_label.text = "Время: %d:%02d" % [int(left) / 60, int(left) % 60]
	_timer_label.add_theme_color_override("font_color", Color("c0392b") if left < 30.0 else Color("3b2a1a"))
	if left <= 0.0:
		_end(false)
		return

	# Звуки и анимация работы: шкворчание, пока что-то готовится; повар «рубит» у доски
	var cooking := false
	var chopping := false
	for station in stations:
		if station is Stove and station.is_working():
			cooking = true
		elif station is CuttingBoard and station.is_working():
			chopping = true
	chef.working = chopping
	Sound.set_loop("sizzle", cooking)

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
		_hint_label.text = _rejection_hint()


# Пробел или Enter на клавиатуре — то же, что кнопка действия
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") and not ended:
		do_action()


# Если повар стоит у «Сборки» с предметом, который сейчас нельзя добавить,
# объясняем почему (иначе игроку кажется, что ничего не работает)
func _rejection_hint() -> String:
	if chef.held == null or assembly.distance_to(chef.position) > REACH:
		return ""
	var reason := assembly.reject_reason(chef.held)
	return "Сборка: %s" % reason if reason != "" else ""


# Выполнить действие с ближайшим подходящим местом
func do_action() -> void:
	var target := find_station()
	if target != null:
		target.interact(chef)
		_refresh_order()
	else:
		# Делать нечего: тихий «нельзя»
		Sound.play("reject", -8.0)


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


# ---------- Заказ ----------

# Шаги, которые входят во все варианты блюда (остальные — «на выбор»)
func _find_required_steps() -> void:
	for step in recipe["steps"]:
		var in_all := true
		for variant in recipe["variants"]:
			if not (step["id"] in variant["needs"]):
				in_all = false
				break
		if in_all:
			_required[step["id"]] = true


# Обновить список «что нужно» в карточке заказа
func _refresh_order() -> void:
	var lines: Array[String] = []
	for step in recipe["steps"]:
		var mark := "[x]" if step["id"] in logic.done else "[  ]"
		var optional := "" if _required.has(step["id"]) else " *"
		lines.append("%s %s%s" % [mark, step["text"], optional])
	var title := "Нужно (* — на выбор):\n"
	if logic.is_finished():
		title = "Блюдо собрано! Неси на раздачу.\n"
	_order_label.text = title + "\n".join(lines)


# Блюдо подано гостю
func _on_served(_item: FoodItem) -> void:
	if ended:
		return
	last_result = logic.grade(elapsed)
	GameState.add_coins(last_result["reward"])
	_end(true)


# Заказ закончен: подан (success) или время вышло
func _end(success: bool) -> void:
	ended = true
	get_tree().paused = true
	Sound.stop_loops()
	Sound.play("success" if success else "fail")
	_show_overlay(success)


func _show_overlay(success: bool) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	# Пока игра на паузе, окно с кнопками должно работать
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(dim)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.add_theme_constant_override("separation", 16)
	layer.add_child(box)

	var text := Label.new()
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.add_theme_font_size_override("font_size", 30)
	if success:
		text.text = "Блюдо подано!\n%s\nЗвёзды: %d из 3\nВремя: %d с\nНаграда: +%d монет" % [
			recipe["name"], last_result["stars"], int(elapsed), last_result["reward"]
		]
	else:
		text.text = "Время вышло!\nГость ушёл голодным.\nНаграды нет."
	box.add_child(text)

	var again := Button.new()
	again.text = "Ещё раз"
	again.custom_minimum_size = Vector2(260, 60)
	again.add_theme_font_size_override("font_size", 24)
	again.pressed.connect(_on_again_pressed)
	box.add_child(again)

	var menu := Button.new()
	menu.text = "В меню"
	menu.custom_minimum_size = Vector2(260, 60)
	menu.add_theme_font_size_override("font_size", 24)
	menu.pressed.connect(_on_menu_pressed)
	box.add_child(menu)


func _on_sound_pressed() -> void:
	Sound.set_enabled(not GameState.sound_enabled)
	_update_sound_button()


func _update_sound_button() -> void:
	_sound_button.text = "Звук: вкл" if GameState.sound_enabled else "Звук: выкл"


func _on_again_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_menu_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


# ---------- Построение кухни ----------

# Пол, стены и столы. Всё, что рисуем как блок, ещё и не пускает повара.
func _build_floor_and_walls() -> void:
	# Пол (плитка) и тёмный фон за его пределами
	add_child(KitchenFloor.new())

	var wall_color := Color("5b3a1e")
	var counter_color := Color("b08a5a")
	_add_block(Rect2(0, 0, 960, 70), counter_color, "counter")   # длинный стол у верхней стены
	_add_block(Rect2(0, 520, 960, 20), wall_color, "wall_tile")  # нижняя стена
	_add_block(Rect2(0, 0, 20, 540), wall_color, "wall_tile")    # левая стена
	_add_block(Rect2(940, 0, 20, 540), wall_color, "wall_tile")  # правая стена


# Твёрдый блок (стена или стол) с картинкой, которая повторяется плиткой
func _add_block(rect: Rect2, color: Color, art_name: String) -> void:
	var block := Station.new()
	block.setup(rect, color, "")
	block.set_art(Icons.kitchen(art_name), true)
	add_child(block)


# Ящики по рецепту, столы, станции, сборка и раздача
func _build_stations() -> void:
	var ingredients := RecipeLoader.load_ingredients()
	var ids: Array = recipe.get("ingredients", [])

	# Ящики в ряд вдоль верхнего стола, по центру
	var cell := 110.0
	var start := 40.0 + (880.0 - ids.size() * cell) / 2.0
	for i in ids.size():
		var crate := Crate.new()
		crate.setup_crate(ids[i], ingredients.get(ids[i], {}), Rect2(start + i * cell + 7, 4, 96, 62))
		_add_station(crate)

	# Столы
	var island := Table.new()
	island.setup(Rect2(400, 240, 160, 70), Color("b08a5a"), "Стол")
	island.set_art(Icons.kitchen("counter"))
	_add_station(island)

	var side_table := Table.new()
	side_table.setup(Rect2(240, 400, 140, 70), Color("b08a5a"), "Стол")
	side_table.set_art(Icons.kitchen("counter"))
	_add_station(side_table)

	# Рабочие станции: доска слева от острова, плита справа
	var board := CuttingBoard.new()
	board.setup(Rect2(220, 240, 120, 70), Color("d8b98a"), "Доска")
	board.set_art(Icons.kitchen("board"))
	_add_station(board)

	var stove := Stove.new()
	stove.setup(Rect2(620, 240, 120, 70), Color("4b5563"), "Плита")
	stove.set_art(Icons.kitchen("stove"))
	_add_station(stove)

	# Сборка блюда (снизу по центру) и раздача (на правой стене)
	assembly = AssemblyStation.new()
	assembly.setup(Rect2(400, 430, 160, 70), Color("f3e9d2"), "Сборка")
	assembly.set_art(Icons.kitchen("assembly"))
	assembly.logic = logic
	_add_station(assembly)

	serve_window = ServeWindow.new()
	serve_window.setup(Rect2(870, 120, 70, 160), Color("fbbf24"), "Раздача")
	serve_window.set_art(Icons.kitchen("serve"))
	serve_window.label_y = 24.0
	serve_window.served.connect(_on_served)
	_add_station(serve_window)

	var bin := TrashBin.new()
	bin.setup(Rect2(850, 288, 90, 80), Color("6b7280"), "Мусорка")
	bin.set_art(Icons.kitchen("bin"))
	bin.label_y = 48.0
	_add_station(bin)


func _add_station(station: Station) -> void:
	add_child(station)
	stations.append(station)


# Экранный слой: карточка заказа, подсказка, кнопка «Меню», джойстик, кнопка действия
func _build_interface() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	# Карточка заказа слева
	var card := ColorRect.new()
	card.color = Color(1, 1, 1, 0.82)
	card.position = Vector2(24, 82)
	card.size = Vector2(180, 262)
	layer.add_child(card)

	var name_label := Label.new()
	name_label.text = recipe["name"]
	name_label.position = Vector2(8, 4)
	name_label.add_theme_font_size_override("font_size", 20)
	name_label.add_theme_color_override("font_color", Color("3b2a1a"))
	card.add_child(name_label)

	_timer_label = Label.new()
	_timer_label.position = Vector2(8, 30)
	_timer_label.add_theme_font_size_override("font_size", 18)
	card.add_child(_timer_label)

	_order_label = Label.new()
	_order_label.position = Vector2(8, 58)
	_order_label.size = Vector2(166, 194)
	_order_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Много шагов (рататуй): пишем мельче, чтобы список влез в карточку
	_order_label.add_theme_font_size_override("font_size", 13 if recipe["steps"].size() <= 8 else 11)
	_order_label.add_theme_color_override("font_color", Color("3b2a1a"))
	card.add_child(_order_label)

	# Подсказка: что произойдёт по кнопке действия
	_hint_label = Label.new()
	_hint_label.position = Vector2(230, 78)
	_hint_label.size = Vector2(450, 50)
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint_label.add_theme_font_size_override("font_size", 19)
	_hint_label.add_theme_color_override("font_color", Color("8a3b00"))
	layer.add_child(_hint_label)

	var menu_button := Button.new()
	menu_button.text = "Меню"
	menu_button.custom_minimum_size = Vector2(100, 36)
	menu_button.anchor_left = 1.0
	menu_button.anchor_right = 1.0
	menu_button.offset_left = -130
	menu_button.offset_right = -30
	menu_button.offset_top = 78
	menu_button.pressed.connect(_on_menu_pressed)
	layer.add_child(menu_button)

	# Кнопка включения и выключения звука
	_sound_button = Button.new()
	_sound_button.custom_minimum_size = Vector2(120, 36)
	_sound_button.anchor_left = 1.0
	_sound_button.anchor_right = 1.0
	_sound_button.offset_left = -260
	_sound_button.offset_right = -140
	_sound_button.offset_top = 78
	_sound_button.pressed.connect(_on_sound_pressed)
	layer.add_child(_sound_button)
	_update_sound_button()

	joystick = ScreenJoystick.new()
	layer.add_child(joystick)
	chef.joystick = joystick

	_action_button = ActionButton.new()
	_action_button.pressed.connect(do_action)
	layer.add_child(_action_button)
