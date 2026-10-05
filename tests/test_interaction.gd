extends SceneTree
# Проверка ящиков, столов и мусорки без окна.
#   Godot --headless --path . --script tests/test_interaction.gd

var failures := 0


func check(condition: bool, message: String) -> void:
	if condition:
		print("  ок: ", message)
	else:
		failures += 1
		print("  ОШИБКА: ", message)


func _init() -> void:
	await process_frame

	# Берём рецепт «Луковый суп»
	var game_state = root.get_node("GameState")
	for shift in RecipeLoader.load_shifts():
		if shift["id"] == "classic":
			game_state.current_shift = shift

	var kitchen: Node2D = load("res://scenes/kitchen.tscn").instantiate()
	root.add_child(kitchen)
	await physics_frame
	await physics_frame
	var chef: Chef = kitchen.chef

	var crates: Array = kitchen.stations.filter(func(s): return s is Crate)
	check(crates.size() == 11, "для смены «Классика» поставлено 11 ящиков")

	print("Ящик")
	var crate: Crate = crates[0]
	chef.position = Vector2(crate.reach_rect.get_center().x, 95)
	kitchen.do_action()
	check(chef.held != null and chef.held.id == crate.ingredient_id, "из ящика взят «%s»" % crate.ingredient_id)

	var held_id := chef.held.id
	chef.position = Vector2(crates[1].reach_rect.get_center().x, 95)
	kitchen.do_action()
	check(chef.held.id == held_id, "с полными руками из другого ящика ничего не взять")

	print("Стол")
	chef.position = Vector2(480, 335)
	await physics_frame
	check(kitchen.find_station() is Table, "возле острова доступен стол")
	kitchen.do_action()
	check(chef.held == null, "предмет выложен на стол, руки пусты")
	kitchen.do_action()
	check(chef.held != null and chef.held.id == held_id, "предмет снова взят со стола")

	print("Мусорка")
	chef.position = Vector2(820, 330)
	await physics_frame
	check(kitchen.find_station() is TrashBin, "возле мусорки доступно действие")
	kitchen.do_action()
	check(chef.held == null, "предмет выброшен")
	check(kitchen.find_station() == null, "с пустыми руками мусорка не предлагает действий")

	print("")
	print("ВСЕ ТЕСТЫ ПРОШЛИ" if failures == 0 else "ПРОВАЛЕНО ТЕСТОВ: %d" % failures)
	quit(failures)
