extends SceneTree
# Проверка доски и плиты без окна. Время «прокручиваем» вызовом tick().
#   Godot --headless --path . --script tests/test_workstations.gd

var failures := 0


func check(condition: bool, message: String) -> void:
	if condition:
		print("  ок: ", message)
	else:
		failures += 1
		print("  ОШИБКА: ", message)


func _init() -> void:
	await process_frame

	var game_state = root.get_node("GameState")
	for recipe in RecipeLoader.load_recipes():
		if recipe["id"] == "onion_soup":
			game_state.current_recipe = recipe

	var kitchen: Node2D = load("res://scenes/kitchen.tscn").instantiate()
	root.add_child(kitchen)
	await physics_frame
	await physics_frame
	var chef: Chef = kitchen.chef

	var board: CuttingBoard = kitchen.stations.filter(func(s): return s is CuttingBoard)[0]
	var stove: Stove = kitchen.stations.filter(func(s): return s is Stove)[0]
	var ingredients := RecipeLoader.load_ingredients()

	print("Доска")
	chef.hold(FoodItem.new("butter", ingredients["butter"]))
	chef.position = Vector2(280, 335)
	await physics_frame
	check(kitchen.find_station() != board, "масло на доску не кладётся (его нельзя резать)")

	chef.drop()
	chef.hold(FoodItem.new("onion", ingredients["onion"]))
	check(kitchen.find_station() == board, "лук на доску класть можно")
	kitchen.do_action()
	check(chef.held == null and board.slot != null, "лук лежит на доске")

	board.tick(1.0)
	check(board.slot.state == "raw", "через 1 с лук ещё не нарезан")

	chef.position = Vector2(280, 480)   # отошли далеко
	board.tick(10.0)
	check(board.slot.state == "raw", "пока повара нет рядом, нарезка стоит")

	chef.position = Vector2(280, 335)   # вернулись
	board.tick(3.1)
	check(board.slot.state == "chopped", "после 3 с рядом лук нарезан")
	check(board.slot.display_name() == "Лук (нарезка)", "название: " + board.slot.display_name())

	kitchen.do_action()
	check(chef.held != null and chef.held.state == "chopped", "нарезанный лук взят в руки")

	print("Плита")
	chef.position = Vector2(680, 335)
	await physics_frame
	check(kitchen.find_station() == stove, "нарезанный лук можно класть на плиту")
	kitchen.do_action()
	check(stove.slot != null, "лук на плите")

	stove.tick(4.1)
	check(stove.slot.state == "cooked", "через 4 с готово")
	stove.tick(5.1)
	check(stove.slot.state == "burnt", "ещё через 5 с сгорело")

	kitchen.do_action()
	check(chef.held.state == "burnt", "сгоревшее взято в руки")
	check(kitchen.find_station() == null, "сгоревшее нельзя снова положить на плиту")

	print("Правила плиты")
	chef.drop()
	chef.hold(FoodItem.new("onion", ingredients["onion"]))
	check(kitchen.find_station() != stove, "сырой лук на плиту нельзя (сначала надо нарезать)")
	chef.drop()
	chef.hold(FoodItem.new("butter", ingredients["butter"]))
	check(kitchen.find_station() == stove, "сырое масло на плиту можно (его не режут)")
	kitchen.do_action()
	stove.tick(2.0)
	kitchen.do_action()
	check(chef.held.state == "raw", "снятое раньше времени масло осталось сырым")

	print("")
	print("ВСЕ ТЕСТЫ ПРОШЛИ" if failures == 0 else "ПРОВАЛЕНО ТЕСТОВ: %d" % failures)
	quit(failures)
