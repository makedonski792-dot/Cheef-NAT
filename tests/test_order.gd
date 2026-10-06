extends SceneTree
# Проверка смены целиком: заказы приходят, блюдо собирается на общей тарелке,
# подаётся на раздачу, гости теряют терпение, смена заканчивается.
#   Godot --headless --path . --script tests/test_order.gd

var failures := 0
var kitchen: Node2D
var chef: Chef
var game_state: Node


func check(condition: bool, message: String) -> void:
	if condition:
		print("  ок: ", message)
	else:
		failures += 1
		print("  ОШИБКА: ", message)


# Найти станцию нужного типа
func find(type) -> Station:
	return kitchen.stations.filter(func(s): return is_instance_of(s, type))[0]


func recipe_by_id(id: String) -> Dictionary:
	for recipe in kitchen.menu:
		if recipe["id"] == id:
			return recipe
	return {}


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


# Приготовить ингредиент (нарезать и/или обжарить) и положить на тарелку
func prepare(ingredient_id: String, do_chop: bool, do_cook: bool) -> void:
	await take_from_crate(ingredient_id)
	if do_chop:
		await chop()
	if do_cook:
		await cook()
	await add_to_dish()


func start_kitchen() -> void:
	for shift in RecipeLoader.load_shifts():
		if shift["id"] == "classic":
			game_state.current_shift = shift
	kitchen = load("res://scenes/kitchen.tscn").instantiate()
	root.add_child(kitchen)
	await physics_frame
	await physics_frame
	chef = kitchen.chef
	kitchen.orders.auto_spawn = false   # заказы добавляем сами, без случайных


func restart_kitchen() -> void:
	paused = false
	kitchen.queue_free()
	await process_frame
	await start_kitchen()


func _init() -> void:
	await process_frame
	game_state = root.get_node("GameState")
	game_state.save_path = "user://test_save.json"
	game_state.coins = 0
	game_state.day = 1

	await start_kitchen()
	check(kitchen.menu.size() == 2, "в смене «Классика» два блюда в меню")
	var soup := recipe_by_id("onion_soup")
	var assembly: AssemblyStation = find(AssemblyStation)
	var serve: ServeWindow = find(ServeWindow)

	print("Заказы")
	check(kitchen.orders.orders.is_empty(), "в начале заказов нет")
	var order: Order = kitchen.orders.add_order(soup)
	check(kitchen.orders.orders.size() == 1 and kitchen._tickets.has(order), "заказ появился, есть билет")
	check(is_equal_approx(order.patience, soup["time_limit"] * float(kitchen.shift.get("patience_scale", 1.0))), "терпение гостя = %d с" % order.patience)

	print("Общая тарелка")
	check(assembly.candidates.size() == 2, "на пустой тарелке подходят оба блюда меню")
	await take_from_crate("onion")
	await go(Vector2(480, 405))
	check(kitchen.find_station() != assembly, "сырой лук на тарелку не принимается")
	await chop()
	await cook()
	await add_to_dish()
	check(assembly.candidates.size() == 1 and assembly.candidates[0].recipe["id"] == "onion_soup",
			"обжаренный лук: тарелка поняла, что это луковый суп")
	check(kitchen._detail_title.text == "Луковый суп" and kitchen._detail_label.text.begins_with("Собираем"), "подсказка: " + kitchen._detail_title.text)

	await take_from_crate("onion")
	await chop()
	await cook()
	await go(Vector2(480, 405))
	check(kitchen.find_station() != assembly, "второй лук не принимается")
	check(assembly.reject_reason(chef.held).ends_with("уже добавлено"), "причина: " + assembly.reject_reason(chef.held))
	chef.drop()

	await prepare("beef_broth", false, true)
	check(assembly.candidates[0].done.has("broth"), "бульон добавлен после лука")
	await prepare("butter", false, true)
	await prepare("baguette", true, true)
	await prepare("gruyere", true, false)
	check(assembly.finished_candidate() != null, "все продукты собраны: блюдо готово")

	print("Подача")
	await go(Vector2(480, 405))
	kitchen.do_action()
	check(chef.held != null and chef.held.is_dish and chef.held.dish_recipe_id == "onion_soup", "блюдо в руках: " + chef.held.name)
	check(assembly.is_plate_empty() and assembly.candidates.size() == 2, "тарелка снова пуста")

	await go(Vector2(820, 330))
	check(kitchen.find_station() == null, "готовое блюдо в мусорку выбросить нельзя")

	var fake := FoodItem.new("dish", {"name": "Салат", "icon": "salad"})
	fake.is_dish = true
	fake.dish_recipe_id = "salade_nicoise"
	check(not serve.has_order_for(fake), "на салат заказа нет: раздача его не примет")

	await go(Vector2(840, 200))
	check(kitchen.find_station() is ServeWindow, "суп можно подать (заказ есть)")
	kitchen.do_action()
	check(kitchen.served == 1 and kitchen.earned == 40, "подано: 1 блюдо, +40 монет")
	check(game_state.coins == 40, "монеты начислены: %d" % game_state.coins)
	check(kitchen.orders.orders.is_empty() and not kitchen._tickets.has(order), "заказ закрыт, билет убран")
	check(not kitchen.ended, "смена продолжается после подачи")

	print("Смешанная тарелка")
	await take_from_crate("onion")
	await chop()
	await add_to_dish()
	check(assembly.candidates.size() == 1 and assembly.candidates[0].recipe["id"] == "salade_nicoise",
			"нарезанный лук: это уже салат нисуаз")
	await take_from_crate("onion")
	await chop()
	await cook()
	await go(Vector2(480, 405))
	check(kitchen.find_station() != assembly, "обжаренный лук в салат не принимается")
	check(assembly.reject_reason(chef.held).begins_with("нужно:"), "причина: " + assembly.reject_reason(chef.held))
	chef.drop()

	print("Гость уходит")
	var order2: Order = kitchen.orders.add_order(soup)
	kitchen.orders.update(order2.patience + 1.0)
	check(kitchen.failed == 1, "гость не дождался: потеряно заказов %d" % kitchen.failed)
	check(kitchen.orders.orders.is_empty(), "заказ убран")

	print("Конец смены")
	var day_before: int = game_state.day
	kitchen.orders.elapsed = kitchen.orders.duration()
	kitchen._process(0.0)
	check(kitchen.ended, "время вышло: смена окончена")
	check(game_state.day == day_before + 1, "наступил следующий день")

	print("Досрочный конец")
	await restart_kitchen()
	check(not kitchen.orders.is_finished(), "в начале смена не закончена")
	kitchen.orders.elapsed = kitchen.orders.spawn_cutoff() + 1.0
	check(kitchen.orders.is_finished(), "новых гостей не будет и заказов нет: смена закончена")
	kitchen.orders.add_order(soup)
	check(not kitchen.orders.is_finished(), "пока есть невыполненный заказ, смена идёт")

	print("Вино (необязательный продукт)")
	await restart_kitchen()
	assembly = find(AssemblyStation)
	await take_from_crate("white_wine")
	await cook()
	await go(Vector2(480, 405))
	check(kitchen.find_station() != assembly, "вино до лука не принимается")
	check(assembly.reject_reason(chef.held).begins_with("Луковый суп: сначала добавь"), "причина: " + assembly.reject_reason(chef.held))
	var wine := chef.drop()
	await prepare("onion", true, true)
	chef.hold(wine)
	await go(Vector2(480, 405))
	check(kitchen.find_station() == assembly, "вино после лука принимается")
	kitchen.do_action()
	check(assembly.candidates[0].done.has("wine"), "вино добавлено в блюдо")
	await prepare("beef_broth", false, true)
	check(assembly.candidates[0].done.has("broth"), "бульон принят и после вина")

	paused = false
	DirAccess.remove_absolute("user://test_save.json")
	print("")
	print("ВСЕ ТЕСТЫ ПРОШЛИ" if failures == 0 else "ПРОВАЛЕНО ТЕСТОВ: %d" % failures)
	quit(failures)
