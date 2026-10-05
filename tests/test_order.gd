extends SceneTree
# Проверка заказа целиком: «проходим» луковый суп от ящиков до раздачи.
#   Godot --headless --path . --script tests/test_order.gd

var failures := 0
var kitchen: Node2D
var chef: Chef


func check(condition: bool, message: String) -> void:
	if condition:
		print("  ок: ", message)
	else:
		failures += 1
		print("  ОШИБКА: ", message)


# Найти станцию нужного типа
func find(type) -> Station:
	return kitchen.stations.filter(func(s): return is_instance_of(s, type))[0]


# Поставить повара рядом со станцией
func go(pos: Vector2) -> void:
	chef.position = pos
	await physics_frame


# Взять ингредиент из ящика
func take_from_crate(ingredient_id: String) -> void:
	for s in kitchen.stations:
		if s is Crate and s.ingredient_id == ingredient_id:
			await go(Vector2(s.reach_rect.get_center().x, 95))
			kitchen.do_action()
			return


# Нарезать то, что в руках
func chop() -> void:
	await go(Vector2(280, 335))
	kitchen.do_action()
	find(CuttingBoard).tick(3.1)
	kitchen.do_action()


# Приготовить то, что в руках, на плите
func cook() -> void:
	await go(Vector2(680, 335))
	kitchen.do_action()
	find(Stove).tick(4.1)
	kitchen.do_action()


# Положить то, что в руках, на сборку
func add_to_dish() -> void:
	await go(Vector2(480, 405))
	kitchen.do_action()


func start_kitchen(game_state) -> void:
	for recipe in RecipeLoader.load_recipes():
		if recipe["id"] == "onion_soup":
			game_state.current_recipe = recipe
	kitchen = load("res://scenes/kitchen.tscn").instantiate()
	root.add_child(kitchen)
	await physics_frame
	await physics_frame
	chef = kitchen.chef


func _init() -> void:
	await process_frame
	var game_state = root.get_node("GameState")
	game_state.save_path = "user://test_save.json"
	game_state.coins = 0

	await start_kitchen(game_state)

	print("Сборка блюда")
	await take_from_crate("onion")
	await go(Vector2(480, 405))
	check(kitchen.find_station() != find(AssemblyStation), "сырой лук на сборку не принимается")
	await chop()
	await cook()
	check(chef.held.state == "cooked", "лук нарезан и обжарен")
	await add_to_dish()
	check(chef.held == null and kitchen.logic.done.size() == 1, "обжаренный лук добавлен в блюдо")

	await take_from_crate("onion")
	await chop()
	await cook()
	await go(Vector2(480, 405))
	check(kitchen.find_station() != find(AssemblyStation), "второй лук не принимается")
	chef.drop()

	await take_from_crate("beef_broth")
	await cook()
	await add_to_dish()
	check(kitchen.logic.done.has("broth"), "бульон добавлен после лука")

	await take_from_crate("white_wine")
	await cook()
	await go(Vector2(480, 405))
	check(kitchen.find_station() != find(AssemblyStation), "вино после бульона не принимается")
	chef.drop()

	await take_from_crate("butter")
	await cook()
	await add_to_dish()
	await take_from_crate("baguette")
	await chop()
	await cook()
	await add_to_dish()
	await take_from_crate("gruyere")
	await chop()
	await add_to_dish()
	check(kitchen.logic.is_finished(), "все продукты собраны: блюдо готово")

	print("Подача")
	await go(Vector2(480, 405))
	check(kitchen.find_station() is AssemblyStation, "готовое блюдо можно взять")
	kitchen.do_action()
	check(chef.held != null and chef.held.is_dish, "блюдо в руках: " + chef.held.name)

	await go(Vector2(830, 460))
	check(kitchen.find_station() == null, "готовое блюдо в мусорку выбросить нельзя")
	await go(Vector2(840, 200))
	check(kitchen.find_station() is ServeWindow, "возле раздачи можно подать")
	kitchen.do_action()
	check(kitchen.ended, "заказ завершён")
	check(kitchen.last_result["stars"] == 3 and kitchen.last_result["reward"] == 40, "3 звезды, 40 монет")
	check(game_state.coins == 40, "монеты начислены: %d" % game_state.coins)

	print("Время вышло")
	paused = false
	kitchen.queue_free()
	await process_frame
	await start_kitchen(game_state)
	kitchen.elapsed = 9999.0
	kitchen._process(0.0)
	check(kitchen.ended and kitchen.last_result.is_empty(), "по таймеру заказ провален, награды нет")
	check(game_state.coins == 40, "монеты не изменились")

	paused = false
	DirAccess.remove_absolute("user://test_save.json")
	print("")
	print("ВСЕ ТЕСТЫ ПРОШЛИ" if failures == 0 else "ПРОВАЛЕНО ТЕСТОВ: %d" % failures)
	quit(failures)
