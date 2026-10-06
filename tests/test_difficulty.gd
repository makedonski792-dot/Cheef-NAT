extends SceneTree
# Проверка уровней сложности: длина смены, терпение, число заказов, награда,
# выбор на экране и сохранение выбора.
#   Godot --headless --path . --script tests/test_difficulty.gd

var failures := 0


func check(condition: bool, message: String) -> void:
	if condition:
		print("  ок: ", message)
	else:
		failures += 1
		print("  ОШИБКА: ", message)


func find_button(node: Node, text: String) -> Button:
	if node is Button and node.text == text:
		return node
	for child in node.get_children():
		var found := find_button(child, text)
		if found != null:
			return found
	return null


func _init() -> void:
	await process_frame
	var game_state = root.get_node("GameState")
	game_state.save_path = "user://test_save.json"
	game_state.coins = 0
	game_state.day = 2

	var base: Dictionary = {}
	for shift in RecipeLoader.load_shifts():
		if shift["id"] == "classic":
			base = shift

	print("Расчёт уровней")
	var easy := Difficulty.apply(base, "easy")
	var normal := Difficulty.apply(base, "normal")
	var hard := Difficulty.apply(base, "hard")
	check(base["duration"] >= 600, "базовая смена длиннее: %d с" % base["duration"])
	check(easy["duration"] > normal["duration"] and normal["duration"] > hard["duration"],
			"смена: лёгкий %d с > обычный %d с > сложный %d с" % [easy["duration"], normal["duration"], hard["duration"]])
	check(normal["duration"] == base["duration"], "обычный уровень = смена как в файле")
	check(easy["patience_scale"] > normal["patience_scale"] and normal["patience_scale"] > hard["patience_scale"], "терпение гостей падает с ростом сложности")
	check(easy["order_interval"][0] > hard["order_interval"][0], "на лёгком гости приходят реже")
	check(easy["max_orders"] <= normal["max_orders"] and normal["max_orders"] < hard["max_orders"], "заказов сразу: %d / %d / %d" % [easy["max_orders"], normal["max_orders"], hard["max_orders"]])
	check(easy["max_orders"] >= 3, "на лёгком хотя бы 3 заказа сразу: игра не простаивает")
	check(easy["order_interval"][1] <= 70 and easy["second_order_delay"] <= 25, "на лёгком гости приходят часто: интервал %s, второй через %d с" % [easy["order_interval"], easy["second_order_delay"]])
	check(easy["reward_scale"] < 1.0 and hard["reward_scale"] > 1.0, "награда: лёгкий ×%s, сложный ×%s" % [easy["reward_scale"], hard["reward_scale"]])
	check(Difficulty.apply(base, "нет_такого")["difficulty"] == "normal", "неизвестный уровень = обычный")
	check(base["duration"] == 600 and not base.has("difficulty"), "исходная смена не испорчена")

	print("Поток заказов по уровням")
	var menu := RecipeLoader.recipes_for_shift(base)
	for level_id in ["easy", "hard"]:
		var board := OrderBoard.new(Difficulty.apply(base, level_id), menu)
		var max_active := 0
		var t := 0.0
		while t < board.duration():
			board.update(0.5)
			t += 0.5
			max_active = maxi(max_active, board.orders.size())
		check(max_active <= board.max_orders(), "%s: одновременно не больше %d заказов (было %d)" % [level_id, board.max_orders(), max_active])

	print("Выбор запоминается")
	game_state.difficulty = "hard"
	game_state.save_game()
	game_state.difficulty = "easy"
	game_state.load_game()
	check(game_state.difficulty == "hard", "сложность сохранилась")
	check(game_state.make_shift()["difficulty"] == "hard", "смена дня создаётся со сложностью «hard»")
	SaveGame.write({"coins": 0, "difficulty": "безумный"}, "user://test_save.json")
	game_state.load_game()
	check(game_state.difficulty == Difficulty.DEFAULT_ID, "битое значение заменяется уровнем по умолчанию")
	check(Difficulty.DEFAULT_ID == "easy", "по умолчанию «Лёгкий»")

	print("Экран выбора")
	game_state.difficulty = "easy"
	var intro: Control = load("res://scenes/shift_intro.tscn").instantiate()
	root.add_child(intro)
	await process_frame
	await process_frame
	var easy_button := find_button(intro, "Лёгкий")
	var hard_button := find_button(intro, "Сложный")
	check(easy_button != null and hard_button != null and find_button(intro, "Обычный") != null, "на экране три кнопки уровней")
	check(easy_button.button_pressed and not hard_button.button_pressed, "отмечен текущий уровень")
	check(intro._info_label.text.contains("15 мин") and intro._info_label.text.contains("до 3 заказов") and intro._info_label.text.contains("×0,8"), "описание: " + intro._info_label.text)
	hard_button.button_pressed = true
	hard_button.pressed.emit()
	check(game_state.difficulty == "hard", "нажали «Сложный»: выбор запомнен")
	check(intro._info_label.text.contains("7 мин") and intro._info_label.text.contains("×1,5"), "описание обновилось: " + intro._info_label.text)
	check(intro._shift["difficulty"] == "hard", "смена для старта пересчитана")
	intro.queue_free()
	await process_frame

	print("Награда по уровню")
	game_state.current_shift = Difficulty.apply(base, "easy")
	var kitchen: Node2D = load("res://scenes/kitchen.tscn").instantiate()
	root.add_child(kitchen)
	await physics_frame
	await physics_frame
	kitchen.orders.auto_spawn = false
	check(is_equal_approx(kitchen.orders.duration(), 900.0), "на лёгком смена идёт %d с" % kitchen.orders.duration())
	var soup: Dictionary = kitchen.menu.filter(func(r): return r["id"] == "onion_soup")[0]
	kitchen.orders.add_order(soup, "classic")
	var cooking := CookingLogic.new(soup)
	for id in ["onion", "butter", "baguette", "gruyere", "broth"]:
		cooking.do_step(id)
	var dish := FoodItem.new("dish", {"name": "Суп", "icon": "bowl-soup"})
	dish.is_dish = true
	dish.dish_recipe_id = "onion_soup"
	dish.dish_variant_id = "classic"
	dish.dish_logic = cooking
	kitchen._on_served(dish)
	check(kitchen.earned == 32 and game_state.coins == 32, "суп на лёгком: 40 × 0,8 = %d монет" % kitchen.earned)

	paused = false
	DirAccess.remove_absolute("user://test_save.json")
	print("")
	print("ВСЕ ТЕСТЫ ПРОШЛИ" if failures == 0 else "ПРОВАЛЕНО ТЕСТОВ: %d" % failures)
	quit(failures)
