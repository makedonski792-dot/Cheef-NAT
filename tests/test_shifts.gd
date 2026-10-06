extends SceneTree
# Проверка смен: данные целы, поток заказов работает честно, дни идут по кругу,
# экраны меню и начала смены открываются.
#   Godot --headless --path . --script tests/test_shifts.gd

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
	game_state.save_path = "user://test_save.json"

	print("Данные смен")
	var shifts := RecipeLoader.load_shifts()
	var recipes := RecipeLoader.load_recipes()
	check(shifts.size() == 5, "загружено 5 смен")
	var used := {}
	for shift in shifts:
		var menu := RecipeLoader.recipes_for_shift(shift)
		check(menu.size() == shift["recipes"].size(), "%s: все рецепты меню найдены" % shift["id"])
		check(RecipeLoader.ingredients_for(menu).size() <= RecipeLoader.MAX_CRATES,
				"%s: ящиков %d, помещаются" % [shift["id"], RecipeLoader.ingredients_for(menu).size()])
		check(shift["duration"] > shift.get("stop_orders_before", 110) + 60, "%s: смена достаточно длинная" % shift["id"])
		for id in shift["recipes"]:
			used[id] = true
	for recipe in recipes:
		check(used.has(recipe["id"]), "рецепт «%s» есть в какой-то смене" % recipe["name"])

	print("Поток заказов")
	var shift: Dictionary = shifts[1]
	var menu := RecipeLoader.recipes_for_shift(shift)
	var board := OrderBoard.new(shift, menu)
	var spawned: Array[String] = []
	board.order_added.connect(func(o): spawned.append(o.recipe["id"]))
	var max_active := 0
	var first_time := -1.0
	var last_time := 0.0
	var t := 0.0
	while t < board.duration():
		board.update(0.5)
		t += 0.5
		max_active = maxi(max_active, board.orders.size())
		if first_time < 0.0 and not spawned.is_empty():
			first_time = t
		if board.orders.size() > 0:
			last_time = maxf(last_time, board.orders[-1].elapsed if board.orders[-1].elapsed < 1.0 else last_time)
	check(first_time >= 2.0 and first_time <= 3.0, "первый гость приходит в начале смены (на %.1f с)" % first_time)
	check(spawned.size() >= 3, "за смену пришло гостей: %d" % spawned.size())
	check(max_active <= board.max_orders(), "одновременно не больше %d заказов (было %d)" % [board.max_orders(), max_active])
	check(spawned[0] != spawned[1], "два первых гостя заказали разное")
	for id in spawned:
		check(id in shift["recipes"], "заказ «%s» есть в меню смены" % id)
	check(board.is_finished(), "в конце времени смена закончена")

	print("Не простаиваем")
	var idle_board := OrderBoard.new(Difficulty.apply(shift, "easy"), menu)
	var arrivals: Array[float] = []
	idle_board.order_added.connect(func(o): arrivals.append(idle_board.elapsed))
	var idle_t := 0.0
	while idle_t < 200.0:
		idle_board.update(0.25)
		idle_t += 0.25
		# Игрок мгновенно обслуживает любой заказ
		if not idle_board.orders.is_empty():
			idle_board.complete(idle_board.orders[0])
	var longest_wait := 0.0
	for i in range(1, arrivals.size()):
		longest_wait = maxf(longest_wait, arrivals[i] - arrivals[i - 1])
	check(arrivals.size() >= 20, "на лёгком за 200 с пришло гостей: %d" % arrivals.size())
	check(longest_wait <= 5.0, "когда заказов нет, следующий гость приходит быстро (самая долгая пауза %.1f с)" % longest_wait)
	var busy_board := OrderBoard.new(Difficulty.apply(shift, "easy"), menu)
	var seen_two := false
	var busy_t := 0.0
	while busy_t < 60.0:
		busy_board.update(0.5)
		busy_t += 0.5
		seen_two = seen_two or busy_board.orders.size() >= 2
	check(seen_two, "на лёгком второй гость приходит в первую минуту")

	var late := OrderBoard.new(shift, menu)
	late.update(late.spawn_cutoff() + 5.0)
	check(late.orders.is_empty(), "после границы новые гости не приходят")

	print("Варианты в заказах")
	var counts := {}
	var variant_board := OrderBoard.new(shift, menu)
	for i in 600:
		var o: Order = variant_board.add_order(menu[0])
		counts[o.variant["id"]] = counts.get(o.variant["id"], 0) + 1
		variant_board.complete(o)
	check(counts.size() == menu[0]["variants"].size(), "у блюда «%s» гости заказывают все варианты: %s" % [menu[0]["name"], counts])
	var base_id: String = menu[0]["variants"][0]["id"]
	var other_id: String = menu[0]["variants"][1]["id"]
	check(counts[base_id] > counts[other_id], "обычный вариант заказывают чаще особенного (%d против %d)" % [counts[base_id], counts[other_id]])
	var forced: Order = variant_board.add_order(menu[0], other_id)
	check(forced.variant["id"] == other_id and forced.variant_name() != "", "вариант можно задать явно")

	print("Дни")
	game_state.day = 1
	check(game_state.pick_shift()["id"] == "breakfast", "день 1: завтрак")
	check(game_state.pick_shift()["id"] != game_state.pick_shift()["id"] + "x", "смена выбирается")
	game_state.day = 2
	check(game_state.pick_shift()["id"] == "classic", "день 2: классика")
	game_state.day = 6
	check(game_state.pick_shift()["id"] == "breakfast", "день 6: круг замкнулся, снова завтрак")
	game_state.day = 3
	game_state.finish_shift()
	check(game_state.day == 4, "после смены наступает следующий день")
	game_state.day = 1
	game_state.save_game()
	game_state.day = 99
	game_state.load_game()
	check(game_state.day == 1, "день сохраняется и загружается")

	print("Экраны")
	for path in ["res://scenes/main_menu.tscn", "res://scenes/shift_intro.tscn"]:
		var scene: Control = load(path).instantiate()
		root.add_child(scene)
		await process_frame
		await process_frame
		check(scene.get_child_count() > 0, "%s открывается" % path.get_file())
		scene.queue_free()
		await process_frame

	DirAccess.remove_absolute("user://test_save.json")
	print("")
	print("ВСЕ ТЕСТЫ ПРОШЛИ" if failures == 0 else "ПРОВАЛЕНО ТЕСТОВ: %d" % failures)
	quit(failures)
