extends Node2D
# Кухня, как в Overcooked: вид сверху, повар бегает между станциями.
# Здесь идёт смена: поток заказов от гостей, сборка блюд на тарелке и подача.
# Размер кухни 960x540 (горизонтальный экран).

const KITCHEN_SIZE := Vector2(960, 540)
# Как близко к месту должен подойти повар (от края повара)
const REACH := Chef.RADIUS + 22.0
const TICKET_GAP := 8.0

var chef: Chef
var joystick: ScreenJoystick
var stations: Array[Station] = []
var assembly: AssemblyStation
var serve_window: ServeWindow

# Смена и заказы
var shift: Dictionary
var menu: Array = []          # рецепты смены
var orders: OrderBoard
var served := 0               # сколько блюд подано
var failed := 0               # сколько заказов потеряно
var earned := 0               # сколько монет заработано за смену
var ended := false

var _tickets := {}            # Order -> OrderTicket
var _focus: Station
var _hint_label: Label
var _guide_label: Label
var _ingredients := {}
var _action_button: ActionButton
var _shift_label: Label
var _detail_title: Label
var _detail_label: Label
var _ticket_row: Control
var _sound_button: Button


func _ready() -> void:
	shift = GameState.current_shift
	if shift.is_empty():
		shift = GameState.make_shift()
	menu = RecipeLoader.recipes_for_shift(shift)
	_ingredients = RecipeLoader.load_ingredients()
	orders = OrderBoard.new(shift, menu)
	orders.order_added.connect(_on_order_added)
	orders.order_expired.connect(_on_order_expired)
	orders.order_removed.connect(_on_order_removed)

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
	_refresh_detail()


# Уходя с кухни, выключаем все зацикленные звуки
func _exit_tree() -> void:
	Sound.stop_loops()


func _process(delta: float) -> void:
	if ended:
		return

	# Время смены идёт: заказы теряют терпение, приходят новые гости
	orders.update(delta)
	if orders.is_finished():
		_end()
		return
	_update_hud()

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
	_guide_label.text = _guide_text()


# Пробел или Enter на клавиатуре — то же, что кнопка действия
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") and not ended:
		do_action()


# Если повар стоит у «Сборки» или «Раздачи» с предметом, который сейчас нельзя
# добавить или подать, объясняем почему (иначе кажется, что ничего не работает)
func _rejection_hint() -> String:
	if chef.held == null:
		return ""
	# Доска и плита объясняют, почему не принимают предмет
	for station in stations:
		if station is WorkStation and station.slot == null and station.distance_to(chef.position) <= REACH:
			var work_reason: String = station.reject_reason(chef.held)
			if work_reason != "":
				return "%s: %s" % [station._label, work_reason]
	if assembly.distance_to(chef.position) <= REACH:
		var reason := assembly.reject_reason(chef.held)
		if reason != "":
			return "Сборка: %s" % reason
	if serve_window.distance_to(chef.position) <= REACH:
		var reason := serve_window.reject_reason(chef)
		if reason != "":
			return "Раздача: %s" % reason
	return ""


# Совет: что делать с предметом в руках (пока предмет в руках, текст виден всегда)
func _guide_text() -> String:
	var item := chef.held
	if item == null:
		return ""
	if item.is_dish:
		return "Совет: неси блюдо на Раздачу"
	if item.state == "burnt":
		return "Совет: сгорело! Выбрось в мусорку"

	var needs := _needed_states(item.id)
	if needs.is_empty():
		var reason := "для текущих заказов" if not orders.orders.is_empty() else "в этой смене"
		return "Совет: %s не нужен %s, выбрось" % [item.name, reason]

	var chopped: bool = "chopped" in needs
	var cooked: bool = "cooked" in needs
	var raw: bool = "raw" in needs
	match item.state:
		"raw":
			if raw:
				return "Совет: неси на Сборку"
			if chopped and cooked:
				return "Совет: на Доску (нарезать), потом на Сборку или на Плиту"
			if chopped:
				return "Совет: на Доску, нарезать"
			if cooked:
				return "Совет: сначала на Доску (нарезать), потом на Плиту" if item.can("chop") else "Совет: неси на Плиту"
		"chopped":
			if chopped and cooked:
				return "Совет: на Сборку или на Плиту"
			if chopped:
				return "Совет: нарезано! Неси на Сборку"
			if cooked:
				return "Совет: неси на Плиту"
		"cooked":
			if cooked:
				return "Совет: готово! Неси на Сборку"
	return "Совет: в таком виде это сейчас не подойдёт"


# В каком виде нужен продукт. Если у гостей есть заказы, смотрим только продукты
# заказанных вариантов блюд; пока заказов нет, смотрим всё меню.
func _needed_states(ingredient_id: String) -> Array[String]:
	var result: Array[String] = []
	if orders.orders.is_empty():
		for recipe_data in menu:
			for step in recipe_data["steps"]:
				_add_state(result, step, ingredient_id)
		return result
	for order in orders.orders:
		for step in order.recipe["steps"]:
			if step["id"] in order.variant.get("needs", []):
				_add_state(result, step, ingredient_id)
	return result


func _add_state(result: Array[String], step: Dictionary, ingredient_id: String) -> void:
	if step["item"]["id"] == ingredient_id and not (step["item"]["state"] in result):
		result.append(step["item"]["state"])


# Выполнить действие с ближайшим подходящим местом
func do_action() -> void:
	var target := find_station()
	if target != null:
		target.interact(chef)
		_refresh_detail()
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


# ---------- Заказы ----------

func _on_order_added(order: Order) -> void:
	var ticket := OrderTicket.new(order)
	_ticket_row.add_child(ticket)
	_tickets[order] = ticket
	_layout_tickets()
	_refresh_detail()
	Sound.play("done", -4.0, 1.25)


func _on_order_removed(order: Order) -> void:
	var ticket: OrderTicket = _tickets.get(order)
	if ticket != null:
		ticket.queue_free()
	_tickets.erase(order)
	_layout_tickets()
	_refresh_detail()


# Гость ушёл, не дождавшись
func _on_order_expired(order: Order) -> void:
	failed += 1
	Sound.play("burnt", -2.0)
	_float_text("Гость ушёл: %s" % order.recipe["name"], Vector2(330, 160), Color("e53935"))


# Блюдо подано гостю
func _on_served(dish: FoodItem) -> void:
	var order := orders.find_for(dish.dish_recipe_id, dish.dish_variant_id)
	if order == null or ended:
		return
	# Оценка: звёзды зависят от того, как быстро блюдо подано после прихода заказа
	var result := dish.dish_logic.grade(order.elapsed)
	var reward := int(round(result["reward"] * float(shift.get("reward_scale", 1.0))))
	GameState.add_coins(reward)
	earned += reward
	served += 1
	orders.complete(order)
	_float_text("+%d монет" % reward, Vector2(740, 150), Color("2e7d32"))


# Билеты в ряд: самый старый заказ слева
func _layout_tickets() -> void:
	var index := 0
	for order in orders.orders:
		var ticket: OrderTicket = _tickets.get(order)
		if ticket != null:
			ticket.position = Vector2(index * (OrderTicket.TICKET_SIZE.x + TICKET_GAP), 0)
			index += 1


# Всплывающая надпись («+40 монет», «Гость ушёл»): поднимается и тает
func _float_text(text: String, position_: Vector2, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.position = position_
	label.z_index = 40
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.WHITE)
	label.add_theme_constant_override("outline_size", 6)
	add_child(label)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(label, "position:y", position_.y - 50.0, 1.4)
	tween.tween_property(label, "modulate:a", 0.0, 1.4)
	tween.chain().tween_callback(label.queue_free)


# ---------- Интерфейс: обновление ----------

# Таймер смены, счёт и состояние билетов
func _update_hud() -> void:
	var left := maxf(0.0, orders.duration() - orders.elapsed)
	_shift_label.text = "Смена: %d:%02d\nПодано: %d  (+%d)" % [int(left) / 60, int(left) % 60, served, earned]
	_shift_label.add_theme_color_override("font_color", Color("c0392b") if left < 30.0 else Color("3b2a1a"))
	for order in _tickets:
		var ticket: OrderTicket = _tickets[order]
		ticket.highlighted = assembly.is_building(order.recipe["id"])
		ticket.queue_redraw()


# Заказ, под который сейчас собирается блюдо на тарелке (или null).
# Если гости заказали разные варианты, берём тот, с которым ещё сходится содержимое тарелки.
func _order_for_plate(cooking: CookingLogic) -> Order:
	var fallback: Order = null
	for order in orders.orders:
		if order.recipe["id"] != cooking.recipe["id"]:
			continue
		if fallback == null:
			fallback = order
		var fits := true
		for step_id in cooking.done:
			if not (step_id in order.variant.get("needs", [])):
				fits = false
				break
		if fits:
			return order
	return fallback


# Подсказка слева: что собирается на тарелке сейчас или заказ самого старого гостя.
# Если у заказа есть конкретный вариант, показываем продукты именно для него.
func _refresh_detail() -> void:
	var cooking := assembly.best_candidate()
	var recipe: Dictionary
	var order: Order = null
	if cooking != null:
		recipe = cooking.recipe
		order = _order_for_plate(cooking)
	elif not orders.orders.is_empty():
		order = orders.orders[0]
		recipe = order.recipe
	else:
		_detail_title.text = "Ждём гостей…"
		_detail_label.text = ""
		return

	var header := "Нужно:"
	if cooking != null:
		header = "Готово! Неси на раздачу" if assembly.finished_candidate() == cooking else "Собираем:"

	var lines: Array[String] = []
	var intro := ""
	if order != null:
		# Только продукты заказанного варианта
		var needs: Array = order.variant.get("needs", [])
		intro = "Заказ: %s\n" % order.variant_name()
		for step in recipe["steps"]:
			if step["id"] in needs:
				var mark := "[x]" if cooking != null and step["id"] in cooking.done else "[  ]"
				lines.append("%s %s %s" % [mark, step["text"], _prep_tag(step)])
		# Лишнее на тарелке (не из заказанного варианта)
		if cooking != null:
			for step in recipe["steps"]:
				if step["id"] in cooking.done and not (step["id"] in needs):
					lines.append("[!] %s — лишнее, очисти тарелку" % step["text"])
	else:
		# Заказа на это блюдо нет: показываем все шаги, необязательные со звёздочкой
		var required := _required_steps(recipe)
		header += " (* — на выбор)"
		for step in recipe["steps"]:
			var mark := "[x]" if cooking != null and step["id"] in cooking.done else "[  ]"
			var optional := "" if required.has(step["id"]) else " *"
			lines.append("%s %s%s %s" % [mark, step["text"], optional, _prep_tag(step)])

	_detail_title.text = recipe["name"]
	_detail_label.text = intro + header + "\nД = доска, П = плита\n" + "\n".join(lines)
	_detail_label.add_theme_font_size_override("font_size", 12 if lines.size() <= 8 else 10)


# Короткая пометка, как приготовить продукт: [Д] резать на доске, [П] жарить на плите
func _prep_tag(step: Dictionary) -> String:
	var info: Dictionary = _ingredients.get(step["item"]["id"], {})
	match step["item"]["state"]:
		"chopped":
			return "[Д]"
		"cooked":
			return "[Д→П]" if info.get("chop", false) else "[П]"
	return ""


# Шаги, которые входят во все варианты блюда (остальные — «на выбор»)
func _required_steps(recipe: Dictionary) -> Dictionary:
	var required := {}
	for step in recipe["steps"]:
		var in_all := true
		for variant in recipe["variants"]:
			if not (step["id"] in variant["needs"]):
				in_all = false
				break
		if in_all:
			required[step["id"]] = true
	return required


# ---------- Конец смены ----------

# Смена закончилась: время вышло или гостей больше не будет и все обслужены
func _end() -> void:
	ended = true
	failed += orders.orders.size()   # кого не успели обслужить
	var day := GameState.day
	GameState.finish_shift()
	get_tree().paused = true
	Sound.stop_loops()
	Sound.play("success" if served > 0 and served >= failed else "fail")
	_show_overlay(day)


func _show_overlay(day: int) -> void:
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
	box.add_theme_constant_override("separation", 14)
	layer.add_child(box)

	var text := Label.new()
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.add_theme_font_size_override("font_size", 28)
	text.text = "День %d закончен!\n%s · %s\nПодано блюд: %d\nПотеряно заказов: %d\nЗаработано: +%d монет" % [
		day, shift["name"], Difficulty.level_name(shift.get("difficulty", "normal")), served, failed, earned
	]
	box.add_child(text)

	var next := Button.new()
	next.text = "Следующая смена"
	next.custom_minimum_size = Vector2(280, 58)
	next.add_theme_font_size_override("font_size", 24)
	next.pressed.connect(_on_next_shift_pressed)
	box.add_child(next)

	var menu_button := Button.new()
	menu_button.text = "В меню"
	menu_button.custom_minimum_size = Vector2(280, 58)
	menu_button.add_theme_font_size_override("font_size", 24)
	menu_button.pressed.connect(_on_menu_pressed)
	box.add_child(menu_button)


func _on_next_shift_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/shift_intro.tscn")


func _on_menu_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _on_sound_pressed() -> void:
	Sound.set_enabled(not GameState.sound_enabled)
	_update_sound_button()


func _update_sound_button() -> void:
	_sound_button.text = "Звук: вкл" if GameState.sound_enabled else "Звук: выкл"


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


# Ящики для всех блюд смены, столы, станции, сборка и раздача
func _build_stations() -> void:
	var ingredients := RecipeLoader.load_ingredients()
	var ids := RecipeLoader.ingredients_for(menu)

	# Ящики в ряд вдоль верхнего стола, по центру. Если их много, делаем уже.
	var cell := minf(110.0, 880.0 / maxf(1.0, ids.size()))
	var crate_width := minf(96.0, cell - 8.0)
	var start := 40.0 + (880.0 - ids.size() * cell) / 2.0
	for i in ids.size():
		var crate := Crate.new()
		crate.setup_crate(ids[i], ingredients.get(ids[i], {}),
				Rect2(start + i * cell + (cell - crate_width) / 2.0, 4, crate_width, 62))
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

	# Сборка блюд (снизу по центру) и раздача (на правой стене)
	assembly = AssemblyStation.new()
	assembly.setup(Rect2(400, 430, 160, 70), Color("f3e9d2"), "Сборка")
	assembly.set_art(Icons.kitchen("assembly"))
	assembly.orders = orders
	assembly.setup_menu(menu)
	_add_station(assembly)

	serve_window = ServeWindow.new()
	serve_window.setup(Rect2(870, 120, 70, 160), Color("fbbf24"), "Раздача")
	serve_window.set_art(Icons.kitchen("serve"))
	serve_window.label_y = 24.0
	serve_window.orders = orders
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


# Экранный слой: билеты заказов, подсказки, кнопки, джойстик
func _build_interface() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	# Ряд билетов заказов под верхним столом
	_ticket_row = Control.new()
	_ticket_row.position = Vector2(24, 76)
	_ticket_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_ticket_row)

	# Карточка-подсказка слева: что нужно для блюда
	var card := ColorRect.new()
	card.color = Color(1, 1, 1, 0.82)
	card.position = Vector2(24, 148)
	card.size = Vector2(192, 250)
	layer.add_child(card)

	_detail_title = Label.new()
	_detail_title.position = Vector2(8, 4)
	_detail_title.size = Vector2(178, 24)
	_detail_title.clip_text = true
	_detail_title.add_theme_font_size_override("font_size", 15)
	_detail_title.add_theme_color_override("font_color", Color("3b2a1a"))
	card.add_child(_detail_title)

	_detail_label = Label.new()
	_detail_label.position = Vector2(8, 28)
	_detail_label.size = Vector2(178, 216)
	_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_label.add_theme_font_size_override("font_size", 13)
	_detail_label.add_theme_color_override("font_color", Color("3b2a1a"))
	card.add_child(_detail_label)

	# Время смены и счёт
	_shift_label = Label.new()
	_shift_label.position = Vector2(700, 124)
	_shift_label.add_theme_font_size_override("font_size", 18)
	_shift_label.add_theme_color_override("font_color", Color("3b2a1a"))
	layer.add_child(_shift_label)

	# Подсказка: что произойдёт по кнопке действия
	_hint_label = Label.new()
	_hint_label.position = Vector2(232, 150)
	_hint_label.size = Vector2(450, 50)
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint_label.add_theme_font_size_override("font_size", 19)
	_hint_label.add_theme_color_override("font_color", Color("8a3b00"))
	layer.add_child(_hint_label)

	# Совет: что делать с предметом в руках
	_guide_label = Label.new()
	_guide_label.position = Vector2(232, 200)
	_guide_label.size = Vector2(460, 44)
	_guide_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_guide_label.add_theme_font_size_override("font_size", 17)
	_guide_label.add_theme_color_override("font_color", Color("1b5e20"))
	_guide_label.add_theme_color_override("font_outline_color", Color.WHITE)
	_guide_label.add_theme_constant_override("outline_size", 5)
	layer.add_child(_guide_label)

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
