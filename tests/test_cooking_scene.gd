extends SceneTree
# Проверка экрана готовки без окна: «проходим» луковый суп нажатиями на шаги.
#   Godot --headless --path . --script tests/test_cooking_scene.gd

var failures := 0


func check(condition: bool, message: String) -> void:
	if condition:
		print("  ок: ", message)
	else:
		failures += 1
		print("  ОШИБКА: ", message)


func _init() -> void:
	# Ждём один кадр, чтобы Godot успел создать GameState
	await process_frame

	var game_state = root.get_node("GameState")
	for recipe in RecipeLoader.load_recipes():
		if recipe["id"] == "onion_soup":
			game_state.current_recipe = recipe

	var scene: Control = load("res://scenes/cooking.tscn").instantiate()
	root.add_child(scene)
	await process_frame

	check(scene._steps_box.get_child_count() == 4, "на экране 4 кнопки стартовых шагов")

	for step_id in ["slice_onion", "melt_butter", "caramelize_onion", "add_broth", "simmer",
			"slice_bread", "toast_bread", "grate_cheese", "gratinate"]:
		scene.choose_step(step_id)
	await process_frame

	check(scene._result_label.visible, "показан итог блюда")
	check(game_state.coins > 0, "монеты начислены: %d" % game_state.coins)
	print("  итог: ", scene._result_label.text.replace("\n", " | "))

	print("")
	print("ВСЕ ТЕСТЫ ПРОШЛИ" if failures == 0 else "ПРОВАЛЕНО ТЕСТОВ: %d" % failures)
	quit(failures)
