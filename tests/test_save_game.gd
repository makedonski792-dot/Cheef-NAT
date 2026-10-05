extends SceneTree
# Проверка сохранения монет (используется отдельный тестовый файл).
#   Godot --headless --path . --script tests/test_save_game.gd

const TEST_PATH := "user://test_save_game.json"
var failures := 0


func check(condition: bool, message: String) -> void:
	if condition:
		print("  ок: ", message)
	else:
		failures += 1
		print("  ОШИБКА: ", message)


func _init() -> void:
	await process_frame
	DirAccess.remove_absolute(TEST_PATH)

	check(SaveGame.read(TEST_PATH).is_empty(), "нет файла: пустой результат, без падения")

	var gs = root.get_node("GameState")
	gs.save_path = TEST_PATH
	gs.coins = 0
	gs.add_coins(40)
	gs.add_coins(15)
	check(gs.coins == 55, "монеты суммируются: 55")

	gs.coins = 0  # «закрыли игру»
	gs.load_game()  # «открыли снова»
	check(gs.coins == 55, "после перезапуска монеты на месте: 55")

	# Повреждённый файл не должен ронять игру
	var f := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	f.store_string("{ это не json")
	f.close()
	gs.load_game()
	check(gs.coins == 0, "повреждённый файл: начинаем с нуля")

	DirAccess.remove_absolute(TEST_PATH)
	DirAccess.remove_absolute("user://test_save.json")

	print("")
	print("ВСЕ ТЕСТЫ ПРОШЛИ" if failures == 0 else "ПРОВАЛЕНО ТЕСТОВ: %d" % failures)
	quit(failures)
