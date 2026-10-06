extends SceneTree
# Проверка управления и подсказок: плавающий джойстик, «совет» по предмету в руках,
# объяснение отказов доски и плиты, пометки в чеклисте.
#   Godot --headless --path . --script tests/test_hints.gd

var failures := 0


func check(condition: bool, message: String) -> void:
	if condition:
		print("  ок: ", message)
	else:
		failures += 1
		print("  ОШИБКА: ", message)


func touch(index: int, pos: Vector2, pressed: bool) -> InputEventScreenTouch:
	var e := InputEventScreenTouch.new()
	e.index = index
	e.position = pos
	e.pressed = pressed
	return e


func drag(index: int, pos: Vector2) -> InputEventScreenDrag:
	var e := InputEventScreenDrag.new()
	e.index = index
	e.position = pos
	return e


func _init() -> void:
	await process_frame
	var game_state = root.get_node("GameState")
	game_state.save_path = "user://test_save.json"
	for shift in RecipeLoader.load_shifts():
		if shift["id"] == "breakfast":
			game_state.current_shift = shift

	var kitchen: Node2D = load("res://scenes/kitchen.tscn").instantiate()
	root.add_child(kitchen)
	await physics_frame
	await physics_frame
	kitchen.orders.auto_spawn = false
	var chef: Chef = kitchen.chef
	var joystick: ScreenJoystick = kitchen.joystick
	var ingredients := RecipeLoader.load_ingredients()
	var screen := joystick.get_viewport_rect().size

	print("Джойстик")
	check(chef.BASE_SPEED >= 320.0, "повар бегает быстрее (скорость %d)" % chef.BASE_SPEED)
	joystick._input(touch(0, Vector2(700, 300), true))
	check(joystick.value == Vector2.ZERO, "касание в правой половине экрана джойстик не включает")
	joystick._input(touch(0, Vector2(700, 300), false))
	joystick._input(touch(1, Vector2(300, 50), true))
	check(joystick.value == Vector2.ZERO, "касание над зоной (у билетов) тоже не включает")
	joystick._input(touch(1, Vector2(300, 50), false))

	joystick._input(touch(2, Vector2(300, 380), true))
	joystick._input(drag(2, Vector2(340, 380)))
	check(joystick.value.x > 0.5 and absf(joystick.value.y) < 0.1, "джойстик появился там, где коснулись, и ведёт вправо: %s" % joystick.value)
	joystick._input(drag(2, Vector2(500, 380)))
	check(joystick.value.length() <= 1.001 and joystick.value.x > 0.95, "далеко оттянул: скорость не больше максимума")
	joystick._input(drag(2, Vector2(300, 380)))
	check(joystick.value.x < -0.5, "круг поехал за пальцем, не нужно возвращаться в центр: %s" % joystick.value)
	joystick._input(touch(2, Vector2(300, 380), false))
	check(joystick.value == Vector2.ZERO, "палец отпущен: стоим")

	print("Совет по предмету")
	chef.hold(FoodItem.new("bread", ingredients["bread"]))
	check(kitchen._guide_text().contains("Доск") and kitchen._guide_text().contains("Плит"), "хлеб (крок): " + kitchen._guide_text())
	var bread := chef.held
	bread.state = "chopped"
	check(kitchen._guide_text().contains("Плит"), "нарезанный хлеб: " + kitchen._guide_text())
	bread.state = "cooked"
	check(kitchen._guide_text().contains("Сборк"), "поджаренный хлеб: " + kitchen._guide_text())
	bread.state = "burnt"
	check(kitchen._guide_text().contains("мусор"), "сгоревший: " + kitchen._guide_text())
	chef.drop()
	chef.hold(FoodItem.new("flour", ingredients["flour"]))
	check(kitchen._guide_text().contains("Сборк"), "мука (идёт сырой): " + kitchen._guide_text())
	chef.drop()
	chef.hold(FoodItem.new("fish", ingredients["fish"]))
	check(kitchen._guide_text().contains("не нужен"), "лишний продукт: " + kitchen._guide_text())
	chef.drop()
	check(kitchen._guide_text() == "", "руки пусты: совета нет")

	print("Отказ доски и плиты")
	var board: CuttingBoard = kitchen.stations.filter(func(s): return s is CuttingBoard)[0]
	var stove: Stove = kitchen.stations.filter(func(s): return s is Stove)[0]
	var butter := FoodItem.new("butter", ingredients["butter"])
	check(board.reject_reason(butter).contains("нельзя нарезать"), "масло на доске: " + board.reject_reason(butter))
	var raw_bread := FoodItem.new("bread", ingredients["bread"])
	check(stove.reject_reason(raw_bread).begins_with("сначала нарежь"), "сырой хлеб на плите: " + stove.reject_reason(raw_bread))
	check(board.reject_reason(raw_bread) == "", "хлеб на доску можно")
	var egg_item := FoodItem.new("egg", ingredients["egg"])
	check(board.reject_reason(egg_item).contains("нельзя нарезать"), "яйцо на доске: " + board.reject_reason(egg_item))

	chef.position = Vector2(680, 335)
	chef.hold(FoodItem.new("bread", ingredients["bread"]))
	await physics_frame
	await process_frame
	await process_frame
	check(kitchen._hint_label.text.begins_with("Плита: сначала нарежь"), "на экране: " + kitchen._hint_label.text)
	chef.drop()

	print("Чеклист")
	var bread_step := {"item": {"id": "bread", "state": "cooked"}}
	check(kitchen._prep_tag(bread_step) == "[Д→П]", "хлеб: сначала доска, потом плита")
	check(kitchen._prep_tag({"item": {"id": "butter", "state": "cooked"}}) == "[П]", "масло: только плита")
	check(kitchen._prep_tag({"item": {"id": "gruyere", "state": "chopped"}}) == "[Д]", "сыр: только доска")
	check(kitchen._prep_tag({"item": {"id": "flour", "state": "raw"}}) == "", "мука: сразу на тарелку")
	kitchen.orders.add_order(kitchen.menu[0])
	check(kitchen._detail_label.text.contains("[Д→П]") and kitchen._detail_label.text.contains("Д = доска"), "в карточке заказа есть пометки и пояснение")

	print("Обучение")
	game_state.tutorial_seen = false
	var intro: Control = load("res://scenes/shift_intro.tscn").instantiate()
	root.add_child(intro)
	await process_frame
	await process_frame
	check(intro.get_child_count() > 2, "при первом запуске показано обучение")
	game_state.tutorial_seen = true
	intro.queue_free()

	DirAccess.remove_absolute("user://test_save.json")
	print("")
	print("ВСЕ ТЕСТЫ ПРОШЛИ" if failures == 0 else "ПРОВАЛЕНО ТЕСТОВ: %d" % failures)
	quit(failures)
