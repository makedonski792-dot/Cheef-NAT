extends SceneTree
# Проверка Мастерской: каталог, покупки, надевание, уровни и очки навыков,
# эффекты на игру (скорость, нож, плита, терпение, награда), сохранение.
#   Godot --headless --path . --script tests/test_progress.gd

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


func reset(game_state) -> void:
	game_state.coins = 0
	game_state.xp = 0
	game_state.owned = []
	game_state.equipped = {}
	game_state.skills = {}
	game_state._ensure_defaults()


func _init() -> void:
	await process_frame
	var gs = root.get_node("GameState")
	gs.save_path = "user://test_save.json"
	reset(gs)

	print("Уровни")
	check(Skills.xp_for_level(2) == 120 and Skills.xp_for_level(3) == 360, "порог 2 уровня 120, 3 уровня 360 опыта")
	check(Skills.level_for_xp(0) == 1 and Skills.level_for_xp(119) == 1 and Skills.level_for_xp(120) == 2, "уровень считается по опыту")
	check(Skills.level_for_xp(999999) == Skills.MAX_LEVEL, "выше %d уровня не растёт" % Skills.MAX_LEVEL)

	print("Каталог")
	var categories := ShopCatalog.categories()
	check(categories.size() == 5, "5 категорий: пол, стены, столы, ножи, костюмы")
	var ids := {}
	for category in categories:
		var items: Array = category["items"]
		check(int(items[0]["price"]) == 0 and int(items[0]["level"]) == 1, "%s: первый предмет бесплатный" % category["id"])
		var last_price := -1
		var last_level := 0
		for item in items:
			check(not ids.has(item["id"]), "%s: id уникален" % item["id"])
			ids[item["id"]] = true
			check(int(item["price"]) >= last_price and int(item["level"]) >= last_level, "%s: цена и уровень не убывают" % item["id"])
			last_price = int(item["price"])
			last_level = int(item["level"])
			if item.has("art"):
				check(Icons.kitchen(item["art"]) != null, "%s: есть картинка '%s'" % [item["id"], item["art"]])
			else:
				check(item.has("chop") and item.has("blade"), "%s: у ножа есть скорость и цвет" % item["id"])

	print("Начальное состояние")
	check(gs.owns("floor_classic") and gs.owns("knife_basic") and gs.owns("costume_classic"), "бесплатное выдано")
	check(gs.equipped["knife"] == "knife_basic" and gs.equipped["costume"] == "costume_classic", "бесплатное надето")
	check(gs.chef_level() == 1 and gs.skill_points() == 0, "уровень 1, очков нет")
	check(is_equal_approx(Progress.run_multiplier(), 1.0) and is_equal_approx(Progress.chop_multiplier(), 1.0), "без прокачки множители = 1")

	print("Покупка")
	check(gs.buy_problem("knife_chef").begins_with("нужен уровень"), "нож 2 уровня: " + gs.buy_problem("knife_chef"))
	gs.add_xp(120)
	check(gs.chef_level() == 2 and gs.skill_points() == 1, "120 опыта: уровень 2 и 1 очко")
	check(gs.buy_problem("knife_chef").begins_with("не хватает монет"), "без монет: " + gs.buy_problem("knife_chef"))
	check(not gs.buy("knife_chef"), "купить без монет нельзя")
	gs.coins = 200
	check(gs.buy_problem("knife_chef") == "", "можно купить")
	check(gs.buy("knife_chef") and gs.coins == 20 and gs.owns("knife_chef"), "куплено, осталось %d монет" % gs.coins)
	check(gs.buy_problem("knife_chef") == "уже куплено", "второй раз покупать нельзя")
	check(not gs.equip("knife_gold"), "нельзя надеть то, чего нет")
	check(gs.equip("knife_chef") and gs.equipped["knife"] == "knife_chef", "нож надет")
	check(is_equal_approx(Progress.chop_multiplier(), 1.25), "нарезка быстрее в 1,25 раза")
	check(gs.equip("knife_basic") and is_equal_approx(Progress.chop_multiplier(), 1.0), "можно вернуть обычный")
	gs.equip("knife_chef")

	print("Навыки")
	check(gs.upgrade_skill("hands") and gs.skills["hands"] == 1 and gs.skill_points() == 0, "очко потрачено на «Руки»")
	check(not gs.upgrade_skill("legs"), "очков больше нет")
	check(is_equal_approx(Progress.chop_multiplier(), 1.25 * 1.1), "нож × навык: %.3f" % Progress.chop_multiplier())
	gs.add_xp(240)
	check(gs.skill_points() == 1 and gs.chef_level() == 3, "уровень 3: ещё очко")
	gs.upgrade_skill("legs")
	gs.add_xp(360)
	for i in 4:
		gs.upgrade_skill("legs")
	check(gs.skills["legs"] <= Skills.MAX_SKILL, "навык не выше %d" % Skills.MAX_SKILL)

	print("Эффекты на игру")
	gs.skills = {"legs": 2, "hands": 1, "stove": 3, "charm": 4, "tips": 5}
	check(is_equal_approx(Progress.run_multiplier(), 1.16), "ноги: бег ×%.2f" % Progress.run_multiplier())
	check(is_equal_approx(Progress.patience_multiplier(), 1.24), "обаяние: терпение ×%.2f" % Progress.patience_multiplier())
	check(is_equal_approx(Progress.coin_multiplier(), 1.25), "чаевые: монеты ×%.2f" % Progress.coin_multiplier())
	var board := CuttingBoard.new()
	var raw_onion := FoodItem.new("onion", RecipeLoader.load_ingredients()["onion"])
	check(is_equal_approx(board.step_duration(raw_onion), 2.5 / (1.25 * 1.1)), "нарезка короче: %.2f с" % board.step_duration(raw_onion))
	var stove := Stove.new()
	var cooked := FoodItem.new("onion", RecipeLoader.load_ingredients()["onion"])
	check(stove.step_duration(cooked) < Stove.COOK_SECONDS, "готовка короче: %.2f с" % stove.step_duration(cooked))
	cooked.state = "cooked"
	check(stove.step_duration(cooked) > Stove.BURN_SECONDS, "сгорает позже: %.2f с" % stove.step_duration(cooked))
	var shift: Dictionary = RecipeLoader.load_shifts()[1]
	var order_board := OrderBoard.new(shift, RecipeLoader.recipes_for_shift(shift))
	var soup: Dictionary = RecipeLoader.recipes_for_shift(shift)[0]
	var plain_patience := float(soup["time_limit"]) * float(shift.get("patience_scale", 1.0))
	check(is_equal_approx(order_board.add_order(soup).patience, plain_patience * 1.24), "терпение гостя больше на 24%")

	print("Сохранение")
	gs.coins = 777
	gs.save_game()
	gs.coins = 0
	gs.xp = 0
	gs.owned = []
	gs.equipped = {}
	gs.skills = {}
	gs.load_game()
	check(gs.coins == 777 and gs.xp > 0 and gs.owns("knife_chef") and gs.equipped["knife"] == "knife_chef" and gs.skills["charm"] == 4,
			"монеты, опыт, покупки, надетое и навыки загрузились")
	SaveGame.write({"coins": 5, "owned": ["knife_gold", "выдуманный"], "equipped": {"knife": "knife_santoku"}, "skills": {"legs": 99, "выдуманный": 3}}, "user://test_save.json")
	gs.load_game()
	check(gs.equipped["knife"] == "knife_basic", "надет непокупавшийся нож: возвращён обычный")
	check(gs.owns("knife_gold") and not gs.owns("выдуманный"), "лишнего предмета в сохранении нет")
	check(gs.skills["legs"] == Skills.MAX_SKILL and not gs.skills.has("выдуманный"), "навыки приведены к допустимым")

	print("Кухня применяет купленное")
	reset(gs)
	gs.add_xp(2000)
	gs.coins = 5000
	for item_id in ["floor_blue", "wall_dark", "table_oak", "costume_red", "knife_santoku"]:
		check(gs.buy(item_id) and gs.equip(item_id), "куплено и надето: " + item_id)
	for shift_data in RecipeLoader.load_shifts():
		if shift_data["id"] == "classic":
			gs.current_shift = shift_data
	var kitchen: Node2D = load("res://scenes/kitchen.tscn").instantiate()
	root.add_child(kitchen)
	await physics_frame
	await physics_frame
	kitchen.orders.auto_spawn = false
	check(kitchen.chef.costume_art == "chef_red", "повар в красном кителе")
	var floor_node: KitchenFloor = kitchen.get_children().filter(func(c): return c is KitchenFloor)[0]
	check(floor_node.art_name == "floor_blue", "голубой пол")
	var island: Table = kitchen.stations.filter(func(s): return s is Table)[0]
	check(island._art == Icons.kitchen("counter_oak"), "дубовые столы")
	check(Progress.knife_blade() == Color("9fb3c8"), "нож сантоку на доске")

	print("Опыт и награда за блюдо")
	gs.xp = 0
	gs.skills = {"tips": 5}
	gs.coins = 0
	var order: Order = kitchen.orders.add_order(soup, "classic")
	var logic := CookingLogic.new(soup)
	for id in ["onion", "butter", "baguette", "gruyere", "broth"]:
		logic.do_step(id)
	var dish := FoodItem.new("dish", {"name": "Суп", "icon": "bowl-soup"})
	dish.is_dish = true
	dish.dish_recipe_id = "onion_soup"
	dish.dish_variant_id = "classic"
	dish.dish_logic = logic
	kitchen._on_served(dish)
	check(gs.xp == 40, "опыт за блюдо = %d" % gs.xp)
	check(kitchen.earned == 50 and gs.coins == 50, "монеты с чаевыми: 40 × 1,25 = %d" % kitchen.earned)

	print("Экран Мастерской")
	reset(gs)
	gs.coins = 500
	gs.add_xp(120)
	var shop: Control = load("res://scenes/shop.tscn").instantiate()
	root.add_child(shop)
	await process_frame
	await process_frame
	check(shop._coins_label.text == "Монеты: 500", "показаны монеты: " + shop._coins_label.text)
	check(shop._level_label.text == "Повар: уровень 2", "показан уровень: " + shop._level_label.text)
	var buy := find_button(shop, "Купить за 120")
	check(buy != null and not buy.disabled, "на вкладке «Пол» есть кнопка покупки")
	buy.pressed.emit()
	await process_frame
	check(gs.owns("floor_blue") and gs.coins == 380 and gs.equipped["floor"] == "floor_blue", "куплено и надето: монет осталось %d" % gs.coins)
	check(find_button(shop, "Надето") != null, "на карточке теперь «Надето»")
	check(find_button(shop, "С уровня 5") != null and find_button(shop, "С уровня 5").disabled, "дорогой предмет закрыт до уровня")
	shop._show_tab("skills")
	await process_frame
	var up := find_button(shop, "Улучшить")
	check(up != null and not up.disabled, "на вкладке «Навыки» можно улучшить")
	up.pressed.emit()
	await process_frame
	check(gs.skill_points() == 0 and gs.skills.size() == 1, "очко потрачено")
	for tab in shop.TABS:
		shop._show_tab(tab[0])
		await process_frame
		check(shop._list.get_child_count() > 0, "вкладка «%s» открывается" % tab[1])

	paused = false
	DirAccess.remove_absolute("user://test_save.json")
	print("")
	print("ВСЕ ТЕСТЫ ПРОШЛИ" if failures == 0 else "ПРОВАЛЕНО ТЕСТОВ: %d" % failures)
	quit(failures)
