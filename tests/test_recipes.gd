extends SceneTree
# Проверка всех рецептов: данные целы, картинки есть, каждый вариант блюда
# можно приготовить на нашей кухне. Запускай после добавления нового рецепта.
#   Godot --headless --path . --script tests/test_recipes.gd

var failures := 0


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		print("  ОШИБКА: ", message)


func _init() -> void:
	var ingredients := RecipeLoader.load_ingredients()
	var recipes := RecipeLoader.load_recipes()
	print("Рецептов: %d, ингредиентов: %d" % [recipes.size(), ingredients.size()])

	# У каждого ингредиента есть картинка (основная и для особых состояний)
	for id in ingredients:
		var info: Dictionary = ingredients[id]
		check(info.has("name"), "%s: нет названия" % id)
		check(Icons.food(info.get("icon", "")) != null, "%s: нет картинки '%s'" % [id, info.get("icon", "")])
		for state in info.get("icons", {}):
			check(Icons.food(info["icons"][state]) != null, "%s: нет картинки для состояния %s" % [id, state])

	for recipe in recipes:
		var rid: String = recipe["id"]
		print("  - ", recipe["name"])
		check(Icons.food(recipe.get("dish_icon", "")) != null, "%s: нет картинки блюда" % rid)
		check(recipe.get("time_limit", 0) > recipe.get("par_time", 0), "%s: time_limit должен быть больше par_time" % rid)

		var listed: Array = recipe["ingredients"]
		check(listed.size() <= 8, "%s: больше 8 ящиков не помещается" % rid)
		for id in listed:
			check(ingredients.has(id), "%s: ингредиента '%s' нет в ingredients.json" % [rid, id])

		# Каждый шаг выполним на нашей кухне
		var used := {}
		for step in recipe["steps"]:
			var need: Dictionary = step["item"]
			used[need["id"]] = true
			check(need["id"] in listed, "%s: шаг '%s' использует '%s', которого нет в ящиках" % [rid, step["id"], need["id"]])
			var info: Dictionary = ingredients.get(need["id"], {})
			match need["state"]:
				"raw":
					pass
				"chopped":
					check(info.get("chop", false), "%s: '%s' нельзя нарезать" % [rid, need["id"]])
				"cooked":
					check(info.get("heat", false), "%s: '%s' нельзя греть" % [rid, need["id"]])
				_:
					check(false, "%s: неизвестное состояние '%s'" % [rid, need["state"]])
		for id in listed:
			check(used.has(id), "%s: ящик '%s' лишний, он нигде не нужен" % [rid, id])

		# Каждый вариант блюда можно собрать за некоторый порядок шагов
		for variant in recipe["variants"]:
			var cooking := CookingLogic.new(recipe)
			var progress := true
			while progress and not cooking.is_finished():
				progress = false
				for step_id in variant["needs"]:
					if cooking.can_do_safely(step_id):
						cooking.do_step(step_id)
						progress = true
			check(cooking.is_finished(), "%s: вариант '%s' нельзя собрать (зависимости шагов)" % [rid, variant["id"]])
			if cooking.is_finished():
				check(cooking.finished_variant()["id"] == variant["id"], "%s: собрался другой вариант вместо '%s'" % [rid, variant["id"]])
				check(cooking.grade(1.0)["reward"] == recipe["base_reward"] + variant["bonus"], "%s: неверная награда варианта '%s'" % [rid, variant["id"]])

	print("")
	print("ВСЕ ТЕСТЫ ПРОШЛИ" if failures == 0 else "ПРОВАЛЕНО ТЕСТОВ: %d" % failures)
	quit(failures)
