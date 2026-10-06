extends SceneTree
# Проверка переноса прогресса: код, защита от ошибок, загрузка и экран.
#   Godot --headless --path . --script tests/test_transfer.gd

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


func set_progress(gs) -> void:
	gs.coins = 1234
	gs.day = 7
	gs.xp = 1500
	gs.difficulty = "hard"
	gs.owned = []
	gs.equipped = {}
	gs.skills = {"legs": 2, "tips": 1}
	gs._ensure_defaults()
	gs.owned.append("knife_chef")
	gs.equipped["knife"] = "knife_chef"
	gs.tutorial_seen = true
	gs.sound_enabled = false


func _init() -> void:
	await process_frame
	var gs = root.get_node("GameState")
	gs.save_path = "user://test_save.json"
	set_progress(gs)

	print("Код")
	var code: String = gs.export_code()
	check(code.begins_with("FSH1-"), "код начинается с метки игры: " + code.substr(0, 20))
	check(code.length() < 700, "код короткий: %d символов" % code.length())
	check(not code.contains(" ") and not code.contains("\n"), "код одной строкой без пробелов")
	var decoded := ProgressCode.decode(code)
	check(decoded["ok"] and int(decoded["data"]["coins"]) == 1234, "код читается обратно")

	print("Загрузка в чистую игру")
	gs.coins = 0
	gs.day = 1
	gs.xp = 0
	gs.owned = []
	gs.equipped = {}
	gs.skills = {}
	gs.difficulty = "easy"
	gs.sound_enabled = true
	gs.tutorial_seen = false
	gs._ensure_defaults()
	check(gs.import_code(code) == "", "код принят без ошибок")
	check(gs.coins == 1234 and gs.day == 7 and gs.xp == 1500 and gs.difficulty == "hard", "монеты, день, опыт и сложность вернулись")
	check(gs.owns("knife_chef") and gs.equipped["knife"] == "knife_chef", "покупки и надетое вернулись")
	check(gs.skills.get("legs") == 2 and gs.skills.get("tips") == 1, "навыки вернулись")
	check(gs.sound_enabled == false and gs.tutorial_seen == true, "настройки вернулись")
	check(gs.chef_level() == 5 and gs.skill_points() == 1, "уровень повара 5, свободное очко: %d" % gs.skill_points())
	gs.coins = 0
	gs.load_game()
	check(gs.coins == 1234, "после загрузки прогресс записан в сохранение")

	print("Защита от ошибок")
	var spaced := code.insert(30, "\n  ").insert(60, " \t")
	check(gs.import_code(spaced) == "", "переносы строк и пробелы внутри кода не мешают")
	check(not ProgressCode.decode("")["ok"], "пустой код отклонён: " + ProgressCode.decode("")["error"])
	check(not ProgressCode.decode("привет")["ok"], "посторонний текст отклонён: " + ProgressCode.decode("привет")["error"])
	check(not ProgressCode.decode(code.substr(0, code.length() - 10))["ok"], "обрезанный код отклонён: " + ProgressCode.decode(code.substr(0, code.length() - 10))["error"])
	var typo := code.substr(0, code.length() - 3) + ("AAA" if not code.ends_with("AAA") else "BBB")
	check(not ProgressCode.decode(typo)["ok"], "код с опечаткой отклонён")
	check(not ProgressCode.decode("FSH1-5-aaaaaa-xxxx")["ok"], "подделка отклонена")
	check(not ProgressCode.decode("FSH1-99999999-aaaaaa-xxxx")["ok"], "огромный размер отклонён")
	var before_coins: int = gs.coins
	check(gs.import_code("мусор") != "" and gs.coins == before_coins, "при ошибке текущий прогресс не меняется")
	var evil := ProgressCode.encode({"coins": -50, "day": 0, "xp": -9, "owned": ["нет_такого"], "skills": {"legs": 99}, "difficulty": "x"})
	check(gs.import_code(evil) == "" and gs.coins == 0 and gs.day == 1 and gs.xp == 0 and not gs.owns("нет_такого") and gs.skills["legs"] == 5 and gs.difficulty == "easy",
			"некорректные значения в коде исправляются")
	check(ProgressCode.summary(decoded["data"]).contains("День 7") and ProgressCode.summary(decoded["data"]).contains("1234"), "описание: " + ProgressCode.summary(decoded["data"]))

	print("Экран переноса")
	set_progress(gs)
	var good_code: String = gs.export_code()
	var screen: Control = load("res://scenes/transfer.tscn").instantiate()
	root.add_child(screen)
	await process_frame
	await process_frame
	check(screen._export_box.text == good_code, "на экране показан код прогресса")
	var copy := find_button(screen, "Скопировать код")
	check(copy != null, "есть кнопка «Скопировать код»")
	copy.pressed.emit()
	check(screen._message.text.begins_with("Код скопирован"), "после нажатия: " + screen._message.text)

	set_progress(gs)
	gs.coins = 10
	screen._import_box.text = good_code
	screen._import_box.text_changed.emit()
	check(not screen._confirm_button.visible, "до проверки подтверждения нет")
	find_button(screen, "Проверить код").pressed.emit()
	check(screen._confirm_button.visible and screen._message.text.contains("Код верный"), "код проверен, показано описание: " + screen._message.text.replace("\n", " "))
	check(gs.coins == 10, "пока не подтвердили, прогресс не тронут")
	screen._confirm_button.pressed.emit()
	check(gs.coins == 1234 and screen._message.text.begins_with("Готово"), "после подтверждения прогресс загружен")

	screen._import_box.text = "FSH1-12-bad-code"
	screen._import_box.text_changed.emit()
	find_button(screen, "Проверить код").pressed.emit()
	check(not screen._confirm_button.visible and screen._message.text != "", "плохой код: подтверждения нет, есть объяснение")

	var menu: Control = load("res://scenes/main_menu.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	check(find_button(menu, "Перенос прогресса") != null, "в главном меню есть кнопка переноса")

	DirAccess.remove_absolute("user://test_save.json")
	print("")
	print("ВСЕ ТЕСТЫ ПРОШЛИ" if failures == 0 else "ПРОВАЛЕНО ТЕСТОВ: %d" % failures)
	quit(failures)
