extends SceneTree
# Проверка кухни без окна: повар двигается и не проходит сквозь стены.
#   Godot --headless --path . --script tests/test_kitchen.gd

var failures := 0


func check(condition: bool, message: String) -> void:
	if condition:
		print("  ок: ", message)
	else:
		failures += 1
		print("  ОШИБКА: ", message)


# Держим джойстик в нужную сторону заданное число физических кадров
func hold(kitchen: Node2D, direction: Vector2, frames: int) -> void:
	kitchen.joystick.value = direction
	for i in frames:
		await physics_frame
	kitchen.joystick.value = Vector2.ZERO


func _init() -> void:
	await process_frame
	var kitchen: Node2D = load("res://scenes/kitchen.tscn").instantiate()
	root.add_child(kitchen)
	await physics_frame
	await physics_frame

	var start: Vector2 = kitchen.chef.position
	await hold(kitchen, Vector2.RIGHT, 30)
	check(kitchen.chef.position.x > start.x + 50, "повар бежит вправо (x: %d -> %d)" % [start.x, kitchen.chef.position.x])

	await hold(kitchen, Vector2.DOWN, 120)
	check(kitchen.chef.position.y < 520, "нижняя стена не пускает (y = %d)" % kitchen.chef.position.y)

	await hold(kitchen, Vector2.RIGHT, 200)
	check(kitchen.chef.position.x < 940, "правая стена не пускает (x = %d)" % kitchen.chef.position.x)

	await hold(kitchen, Vector2.UP, 200)
	check(kitchen.chef.position.y > 70, "верхний стол не пускает (y = %d)" % kitchen.chef.position.y)

	# Остров посередине: едем на него сверху вниз с левой стороны острова
	kitchen.chef.position = Vector2(480, 200)
	await physics_frame
	await hold(kitchen, Vector2.DOWN, 60)
	check(kitchen.chef.position.y < 240, "остров не пускает (y = %d)" % kitchen.chef.position.y)

	print("")
	print("ВСЕ ТЕСТЫ ПРОШЛИ" if failures == 0 else "ПРОВАЛЕНО ТЕСТОВ: %d" % failures)
	quit(failures)
