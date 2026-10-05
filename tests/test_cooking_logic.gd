extends SceneTree
# Автоматическая проверка правил рецептов. Запуск из Терминала:
#   Godot --headless --path . --script tests/test_cooking_logic.gd
# В конце напишет «ВСЕ ТЕСТЫ ПРОШЛИ» или перечислит, что сломалось.

var failures := 0


func check(condition: bool, message: String) -> void:
	if condition:
		print("  ок: ", message)
	else:
		failures += 1
		print("  ОШИБКА: ", message)


func recipe_by_id(recipes: Array, id: String) -> Dictionary:
	for r in recipes:
		if r["id"] == id:
			return r
	return {}


# Выполняет список шагов подряд и возвращает true, если все прошли
func run_steps(cooking: CookingLogic, steps: Array) -> bool:
	for s in steps:
		if not cooking.do_step(s):
			print("    не удалось сделать шаг: ", s)
			return false
	return true


func _init() -> void:
	var recipes := RecipeLoader.load_recipes()
	check(recipes.size() == 3, "загружено 3 рецепта")

	print("Луковый суп: классический")
	var soup := CookingLogic.new(recipe_by_id(recipes, "onion_soup"))
	check(not soup.do_step("broth"), "бульон нельзя до лука")
	check(soup.available_steps().size() == 4, "в начале доступно 4 независимых продукта")
	run_steps(soup, ["gruyere", "onion", "baguette"])
	check(soup.can_do("wine") and soup.can_do("broth"), "после лука доступны вино и бульон")
	run_steps(soup, ["broth"])
	check(not soup.can_do("wine"), "вино нельзя после бульона")
	check(not soup.is_finished(), "без масла суп не готов")
	soup.do_step("butter")
	check(soup.is_finished(), "классический суп готов")
	var g := soup.grade(10.0)
	check(g["stars"] == 3 and g["reward"] == 40, "быстро: 3 звезды, 40 монет")
	g = soup.grade(soup.par_time() * 1.2)
	check(g["stars"] == 2 and g["reward"] == 32, "чуть медленнее: 2 звезды, 32 монеты")
	g = soup.grade(soup.par_time() * 3)
	check(g["stars"] == 1 and g["reward"] == 24, "очень медленно: 1 звезда, 24 монеты")

	print("Луковый суп: с вином")
	soup = CookingLogic.new(recipe_by_id(recipes, "onion_soup"))
	run_steps(soup, ["onion", "wine", "broth", "butter", "baguette", "gruyere"])
	check(soup.is_finished() and soup.grade(10.0)["reward"] == 55, "с вином награда 40 + 15 = 55")

	print("Рататуй: два способа")
	var rata := CookingLogic.new(recipe_by_id(recipes, "ratatouille"))
	run_steps(rata, ["oil", "onion", "pepper", "garlic", "thyme", "eggplant"])
	check(rata.can_do("zucchini_sliced"), "по правилам шаг доступен...")
	check(not rata.can_do_safely("zucchini_sliced"), "...но он бы испортил блюдо (смешали два способа)")
	run_steps(rata, ["zucchini", "tomato"])
	check(rata.is_finished() and rata.grade(10.0)["reward"] == 50, "тушёный готов: 50 монет")

	rata = CookingLogic.new(recipe_by_id(recipes, "ratatouille"))
	run_steps(rata, ["oil", "pepper", "onion", "thyme", "garlic", "tomato_sliced", "eggplant_sliced", "zucchini_sliced"])
	check(rata.is_finished() and rata.grade(10.0)["reward"] == 75, "байялди готов: 50 + 25 = 75")

	print("Подсказки сборки")
	var hint_asm := AssemblyStation.new()
	hint_asm.logic = CookingLogic.new(recipe_by_id(recipes, "ratatouille"))
	var egg := FoodItem.new("eggplant", RecipeLoader.load_ingredients()["eggplant"])
	var reason := hint_asm.reject_reason(egg)
	check(reason == "нужно: Баклажан (готово) или Баклажан (нарезка)", "сырой баклажан: " + reason)
	egg.state = "chopped"
	reason = hint_asm.reject_reason(egg)
	check(reason == "сначала добавь: горячее оливковое масло, обжаренный лук, обжаренный перец", "цепочка: " + reason)
	run_steps(hint_asm.logic, ["oil", "onion", "pepper"])
	check(hint_asm.reject_reason(egg) == "", "после масла, лука и перца нарезанный баклажан принимается")

	print("Крем-брюле")
	var cb := CookingLogic.new(recipe_by_id(recipes, "creme_brulee"))
	check(not cb.can_do("sugar"), "сахар нельзя до желтков")
	run_steps(cb, ["cream", "coffee", "yolks"])
	check(not cb.can_do("coffee"), "кофе второй раз не добавить")
	run_steps(cb, ["sugar"])
	check(not cb.is_finished(), "без ванили не готово")
	cb.do_step("vanilla")
	check(cb.is_finished() and cb.grade(5.0)["reward"] == 55, "кофейный готов: 45 + 10 = 55")

	cb = CookingLogic.new(recipe_by_id(recipes, "creme_brulee"))
	run_steps(cb, ["cream", "yolks"])
	check(not cb.can_do("coffee"), "кофе после желтков нельзя")

	print("")
	if failures == 0:
		print("ВСЕ ТЕСТЫ ПРОШЛИ")
	else:
		print("ПРОВАЛЕНО ТЕСТОВ: ", failures)
	quit(failures)
