extends SceneTree
# Проверка вариантов блюд: гость просит конкретный вариант, раздача принимает только его,
# тарелку можно очистить, подсказки говорят, что именно заказано.
#   Godot --headless --path . --script tests/test_variants.gd

var failures := 0
var kitchen: Node2D
var chef: Chef


func check(condition: bool, message: String) -> void:
	if condition:
		print("  ок: ", message)
	else:
		failures += 1
		print("  ОШИБКА: ", message)


func find(type) -> Station:
	return kitchen.stations.filter(func(s): return is_instance_of(s, type))[0]


func go(pos: Vector2) -> void:
	chef.position = pos
	await physics_frame


func take_from_crate(ingredient_id: String) -> void:
	for s in kitchen.stations:
		if s is Crate and s.ingredient_id == ingredient_id:
			await go(Vector2(s.reach_rect.get_center().x, 95))
			kitchen.do_action()
			return


func prepare(ingredient_id: String, do_chop: bool, do_cook: bool) -> void:
	await take_from_crate(ingredient_id)
	if do_chop:
		await go(Vector2(280, 335))
		kitchen.do_action()
		find(CuttingBoard).tick(3.1)
		kitchen.do_action()
	if do_cook:
		await go(Vector2(680, 335))
		kitchen.do_action()
		find(Stove).tick(4.1)
		kitchen.do_action()
	await go(Vector2(480, 405))
	kitchen.do_action()


func _init() -> void:
	await process_frame
	var game_state = root.get_node("GameState")
	game_state.save_path = "user://test_save.json"
	game_state.coins = 0
	for shift in RecipeLoader.load_shifts():
		if shift["id"] == "classic":
			game_state.current_shift = shift
	kitchen = load("res://scenes/kitchen.tscn").instantiate()
	root.add_child(kitchen)
	await physics_frame
	await physics_frame
	chef = kitchen.chef
	kitchen.orders.auto_spawn = false
	var assembly: AssemblyStation = find(AssemblyStation)
	var serve: ServeWindow = find(ServeWindow)
	var soup: Dictionary = kitchen.menu.filter(func(r): return r["id"] == "onion_soup")[0]

	print("Заказ с вариантом")
	var order: Order = kitchen.orders.add_order(soup, "with_wine")
	check(order.variant_name() == "С белым вином", "в заказе записан вариант: " + order.variant_name())
	check(kitchen._detail_label.text.contains("Заказ: С белым вином"), "в карточке слева написан заказанный вариант")
	check(kitchen._detail_label.text.contains("Горячее вино"), "в списке есть вино (оно нужно для этого варианта)")
	var plain: Order = kitchen.orders.add_order(soup, "classic")
	kitchen.orders.complete(plain)

	print("Не тот вариант: тарелка не готова")
	await prepare("onion", true, true)
	await prepare("beef_broth", false, true)   # бульон до вина: вино станет невозможным
	await prepare("butter", false, true)
	await prepare("baguette", true, true)
	await prepare("gruyere", true, false)
	check(assembly.candidates[0].is_finished(), "по рецепту собрался классический суп")
	check(assembly.finished_candidate() == null, "но гость просил с вином: тарелка не считает суп готовым")
	check(assembly.verb(chef) == "Очистить", "вместо «Взять блюдо» предлагается «Очистить»")
	check(kitchen._detail_label.text.contains("лишнее") == false, "лишнего на тарелке нет (всё из классического)")
	await go(Vector2(480, 405))
	kitchen.do_action()
	check(assembly.is_plate_empty() and assembly.candidates.size() == 2, "тарелка очищена")

	print("Раздача принимает только заказанный вариант")
	var classic_dish := FoodItem.new("dish", {"name": "Суп", "icon": "bowl-soup"})
	classic_dish.is_dish = true
	classic_dish.dish_recipe_id = "onion_soup"
	classic_dish.dish_variant_id = "classic"
	check(not serve.has_order_for(classic_dish), "классический суп гость не заказывал: не принимается")
	chef.hold(classic_dish)
	check(serve.reject_reason(chef).contains("С белым вином"), "подсказка: " + serve.reject_reason(chef))
	chef.drop()
	var wine_dish := FoodItem.new("dish", {"name": "Суп", "icon": "bowl-soup"})
	wine_dish.is_dish = true
	wine_dish.dish_recipe_id = "onion_soup"
	wine_dish.dish_variant_id = "with_wine"
	check(serve.has_order_for(wine_dish), "суп с вином принимается")

	print("Сборка нужного варианта")
	await prepare("onion", true, true)
	await prepare("white_wine", false, true)
	await prepare("beef_broth", false, true)
	await prepare("butter", false, true)
	await prepare("baguette", true, true)
	await prepare("gruyere", true, false)
	check(assembly.finished_candidate() != null, "суп с вином собран и готов")
	await go(Vector2(480, 405))
	kitchen.do_action()
	check(chef.held != null and chef.held.dish_variant_id == "with_wine", "в руках: " + chef.held.name)
	await go(Vector2(840, 200))
	kitchen.do_action()
	check(kitchen.served == 1 and kitchen.earned == 55, "подан: 40 + 15 бонус = %d монет" % kitchen.earned)

	print("Лишнее на тарелке")
	var order2: Order = kitchen.orders.add_order(soup, "classic")
	await prepare("onion", true, true)
	await prepare("white_wine", false, true)
	check(kitchen._detail_label.text.contains("лишнее"), "вино не из заказанного варианта помечено «лишнее»")
	check(kitchen._ticket_row.get_child_count() == 1, "билет заказа на экране")

	print("Совет учитывает заказанный вариант")
	kitchen.orders.complete(order2)
	var classic_order: Order = kitchen.orders.add_order(soup, "classic")
	var ing := RecipeLoader.load_ingredients()
	chef.hold(FoodItem.new("white_wine", ing["white_wine"]))
	check(kitchen._guide_text().contains("не нужен для текущих заказов"), "вино при заказе классики: " + kitchen._guide_text())
	chef.drop()
	var wine_order: Order = kitchen.orders.add_order(soup, "with_wine")
	chef.hold(FoodItem.new("white_wine", ing["white_wine"]))
	check(kitchen._guide_text().contains("Плит"), "вино при заказе «с вином»: " + kitchen._guide_text())

	paused = false
	DirAccess.remove_absolute("user://test_save.json")
	print("")
	print("ВСЕ ТЕСТЫ ПРОШЛИ" if failures == 0 else "ПРОВАЛЕНО ТЕСТОВ: %d" % failures)
	quit(failures)
