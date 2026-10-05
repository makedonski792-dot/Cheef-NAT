extends SceneTree
# Автоматическая проверка логики готовки. Запуск из Терминала:
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

	print("Луковый суп: классический вариант")
	var soup := CookingLogic.new(recipe_by_id(recipes, "onion_soup"))
	check(not soup.do_step("simmer"), "нельзя томить суп до бульона")
	check(soup.available_steps().size() == 4, "в начале доступно 4 независимых шага")
	var ok := run_steps(soup, ["slice_bread", "slice_onion", "melt_butter", "caramelize_onion", "add_broth"])
	check(ok, "шаги можно делать в разном порядке")
	check(not soup.can_do("deglaze_wine"), "вино нельзя добавить после бульона")
	run_steps(soup, ["simmer", "toast_bread", "grate_cheese", "gratinate"])
	check(soup.is_finished(), "классический суп готов")
	var g := soup.grade(10.0)
	check(g["stars"] == 3 and g["reward"] == 40, "быстро: 3 звезды, 40 монет")
	g = soup.grade(soup.par_time() * 1.2)
	check(g["stars"] == 2 and g["reward"] == 32, "чуть медленнее: 2 звезды, 32 монеты")
	g = soup.grade(soup.par_time() * 3)
	check(g["stars"] == 1 and g["reward"] == 24, "очень медленно: 1 звезда, 24 монеты")

	print("Луковый суп: вариант с вином")
	soup = CookingLogic.new(recipe_by_id(recipes, "onion_soup"))
	run_steps(soup, ["slice_onion", "melt_butter", "caramelize_onion", "deglaze_wine", "add_broth", "simmer",
			"slice_bread", "toast_bread", "grate_cheese", "gratinate"])
	check(soup.is_finished(), "суп с вином готов")
	check(soup.grade(10.0)["reward"] == 55, "с вином награда 40 + 15 = 55")

	print("Рататуй: смешали два способа")
	var rata := CookingLogic.new(recipe_by_id(recipes, "ratatouille"))
	run_steps(rata, ["heat_oil", "slice_onion", "slice_pepper", "slice_eggplant", "slice_zucchini", "slice_tomato",
			"saute_base", "add_veg"])
	check(not rata.is_ruined(), "пока идём по пути «тушёный» — не испорчено")
	check(rata.possible_variants().size() == 1, "остался один возможный вариант")
	rata.do_step("layer_veg")
	check(rata.is_ruined(), "добавили шаг из второго способа — блюдо испорчено")
	check(rata.grade(5.0)["reward"] == 0, "за испорченное блюдо нет монет")

	print("Крем-брюле: кофейный вариант")
	var cb := CookingLogic.new(recipe_by_id(recipes, "creme_brulee"))
	check(run_steps(cb, ["heat_cream", "infuse_coffee", "whisk_yolks", "temper"]), "кофе настаиваем до смешивания")
	check(not cb.can_do("infuse_coffee"), "кофе второй раз добавить нельзя")
	run_steps(cb, ["strain", "bake_bath", "chill", "sugar_top"])
	check(not cb.is_finished(), "без горелки блюдо не готово")
	check(cb.grade(5.0)["reward"] == 0, "недоготовленное блюдо не оплачивается")
	cb.do_step("torch")
	check(cb.is_finished() and cb.grade(5.0)["reward"] == 55, "кофейное готово: 45 + 10 = 55")

	print("")
	if failures == 0:
		print("ВСЕ ТЕСТЫ ПРОШЛИ")
	else:
		print("ПРОВАЛЕНО ТЕСТОВ: ", failures)
	quit(failures)
