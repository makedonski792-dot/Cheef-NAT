extends SceneTree
# Проверка звуков и анимаций: файлы на месте, звук включается и выключается,
# у станций появляются частицы.
#   Godot --headless --path . --script tests/test_effects.gd

var failures := 0


func check(condition: bool, message: String) -> void:
	if condition:
		print("  ок: ", message)
	else:
		failures += 1
		print("  ОШИБКА: ", message)


func count_particles(node: Node) -> int:
	return node.get_children().filter(func(c): return c is CPUParticles2D).size()


func _init() -> void:
	await process_frame
	var game_state = root.get_node("GameState")
	var sfx = root.get_node("Sfx")
	game_state.save_path = "user://test_save.json"
	game_state.sound_enabled = true

	print("Звуки")
	for sound_name in sfx.SOUNDS:
		var path := "res://audio/%s.wav" % sound_name
		var stream = load(path) if ResourceLoader.exists(path) else null
		check(stream is AudioStreamWAV and stream.get_length() > 0.05, "%s.wav загружается" % sound_name)
	for sound_name in sfx.LOOPS:
		var stream: AudioStreamWAV = load("res://audio/%s.wav" % sound_name)
		check(stream.loop_mode == AudioStreamWAV.LOOP_FORWARD and stream.loop_end == int(round(stream.get_length() * stream.mix_rate)) and stream.loop_end > 20000, "%s зациклен на всю длину (%d отсчётов)" % [sound_name, stream.loop_end])

	Sound.play("chop")
	Sound.play("нет_такого_звука")
	Sound.set_loop("sizzle", true)
	await process_frame
	Sound.set_loop("sizzle", false)
	check(true, "воспроизведение и выключение петли не падают")

	Sound.set_enabled(false)
	check(game_state.sound_enabled == false, "звук выключен")
	game_state.sound_enabled = true
	game_state.load_game()
	check(game_state.sound_enabled == false, "выключенный звук запомнился в сохранении")
	Sound.set_enabled(true)
	game_state.load_game()
	check(game_state.sound_enabled == true, "включённый звук тоже запоминается")

	print("Анимации")
	for shift in RecipeLoader.load_shifts():
		if shift["id"] == "classic":
			game_state.current_shift = shift
	var kitchen: Node2D = load("res://scenes/kitchen.tscn").instantiate()
	root.add_child(kitchen)
	await physics_frame
	await physics_frame
	var chef: Chef = kitchen.chef
	var board: CuttingBoard = kitchen.stations.filter(func(s): return s is CuttingBoard)[0]
	var stove: Stove = kitchen.stations.filter(func(s): return s is Stove)[0]
	var ingredients := RecipeLoader.load_ingredients()

	var before := count_particles(board)
	chef.hold(FoodItem.new("onion", ingredients["onion"]))
	chef.position = Vector2(280, 335)
	await physics_frame
	kitchen.do_action()
	board.tick(0.1)
	check(board.is_working(), "доска работает, пока повар рядом")
	check(count_particles(board) > before, "при ударе ножа летят кусочки")
	await process_frame
	await process_frame
	check(chef.working, "повар «рубит» (анимация)")
	chef.position = Vector2(280, 480)
	await process_frame
	await process_frame
	check(not chef.working, "отошёл: анимация рубки остановилась")
	chef.position = Vector2(280, 335)
	board.tick(3.1)
	kitchen.do_action()

	chef.position = Vector2(680, 335)
	await physics_frame
	kitchen.do_action()
	await process_frame
	await process_frame
	check(stove.is_working() and stove._steam.emitting, "над плитой идёт пар")
	stove.tick(4.1)
	stove.progress = 4.0   # готово давно, вот-вот сгорит
	await process_frame
	await process_frame
	check(stove._is_about_to_burn() and stove._smoke.emitting, "перед пригоранием идёт дым")
	stove.tick(2.1)
	check(stove.slot.state == "burnt", "сгорело")

	game_state.sound_enabled = true
	DirAccess.remove_absolute("user://test_save.json")
	print("")
	print("ВСЕ ТЕСТЫ ПРОШЛИ" if failures == 0 else "ПРОВАЛЕНО ТЕСТОВ: %d" % failures)
	quit(failures)
