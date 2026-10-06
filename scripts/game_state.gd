extends Node
# Общее состояние игры. Godot создаёт его один раз при запуске,
# и к нему можно обратиться из любой сцены по имени GameState.

# Где хранится сохранение (тесты подменяют путь, чтобы не трогать настоящее)
var save_path: String = SaveGame.DEFAULT_PATH

# Монеты игрока
var coins: int = 0

# Включён ли звук (запоминается в сохранении)
var sound_enabled: bool = true

# Прогресс повара: опыт, купленное, надетое и прокачанные навыки
var xp: int = 0
var owned: Array = []             # id купленных предметов магазина
var equipped: Dictionary = {}     # категория -> id надетого предмета
var skills: Dictionary = {}       # навык -> уровень (0..5)

# Выбранный уровень сложности: "easy", "normal" или "hard" (запоминается)
var difficulty: String = Difficulty.DEFAULT_ID

# Видел ли игрок короткое обучение (показываем один раз)
var tutorial_seen: bool = false

# Номер игрового дня. Каждый день своя смена с новым меню (смены идут по кругу)
var day: int = 1

# Смена, которая сейчас идёт
var current_shift: Dictionary = {}


func _ready() -> void:
	load_game()


# ---------- Прогресс повара ----------

# Уровень повара (от 1 до 10) по накопленному опыту
func chef_level() -> int:
	return Skills.level_for_xp(xp)


# Свободные очки навыков: по одному за каждый уровень выше первого
func skill_points() -> int:
	var spent := 0
	for level in skills.values():
		spent += int(level)
	return chef_level() - 1 - spent


# Добавить опыт. Возвращает, на сколько уровней вырос повар.
func add_xp(amount: int) -> int:
	var before := chef_level()
	xp += maxi(0, amount)
	save_game()
	return chef_level() - before


func owns(item_id: String) -> bool:
	return item_id in owned


# Причина, почему предмет нельзя купить сейчас. Пусто, если можно.
func buy_problem(item_id: String) -> String:
	var item := ShopCatalog.find(item_id)
	if item.is_empty():
		return "нет такого предмета"
	if owns(item_id):
		return "уже куплено"
	if chef_level() < int(item.get("level", 1)):
		return "нужен уровень повара %d" % int(item.get("level", 1))
	if coins < int(item.get("price", 0)):
		return "не хватает монет (нужно %d)" % int(item.get("price", 0))
	return ""


func buy(item_id: String) -> bool:
	if buy_problem(item_id) != "":
		return false
	coins -= int(ShopCatalog.find(item_id)["price"])
	owned.append(item_id)
	save_game()
	return true


# Надеть купленный предмет (в категории надет один)
func equip(item_id: String) -> bool:
	var item := ShopCatalog.find(item_id)
	if item.is_empty() or not owns(item_id):
		return false
	equipped[item["category"]] = item_id
	save_game()
	return true


# Потратить очко навыка. Возвращает true, если получилось.
func upgrade_skill(skill_id: String) -> bool:
	if not Skills.LIST.has(skill_id) or skill_points() <= 0:
		return false
	var level := int(skills.get(skill_id, 0))
	if level >= Skills.MAX_SKILL:
		return false
	skills[skill_id] = level + 1
	save_game()
	return true


# Выдать бесплатные предметы каждой категории (если ещё не выданы)
func _ensure_defaults() -> void:
	for category in ShopCatalog.categories():
		var default_id: String = category["items"][0]["id"]
		if not owns(default_id):
			owned.append(default_id)
		if not equipped.has(category["id"]) or not owns(String(equipped[category["id"]])):
			equipped[category["id"]] = default_id


# Начислить монеты за блюдо и сразу сохранить
func add_coins(amount: int) -> void:
	coins += amount
	save_game()


# Смена на сегодня с настройками выбранного уровня сложности
func make_shift() -> Dictionary:
	var base := pick_shift()
	if base.is_empty():
		return base
	return Difficulty.apply(base, difficulty)


# Смена на сегодня без учёта сложности: смены идут по кругу, по одной в день
func pick_shift() -> Dictionary:
	var shifts := RecipeLoader.load_shifts()
	if shifts.is_empty():
		return {}
	return shifts[(day - 1) % shifts.size()]


# Смена закончена: наступает следующий день
func finish_shift() -> void:
	day += 1
	save_game()


func save_game() -> void:
	SaveGame.write({"coins": coins, "sound": sound_enabled, "day": day, "tutorial": tutorial_seen, "difficulty": difficulty,
			"xp": xp, "owned": owned, "equipped": equipped, "skills": skills}, save_path)


# Загрузить сохранение. Если его нет, начинаем с 0 монет.
func load_game() -> void:
	var data := SaveGame.read(save_path)
	# int(...) нужен, потому что JSON хранит числа как дробные
	coins = maxi(0, int(data.get("coins", 0)))
	sound_enabled = bool(data.get("sound", true))
	day = maxi(1, int(data.get("day", 1)))
	tutorial_seen = bool(data.get("tutorial", false))
	xp = maxi(0, int(data.get("xp", 0)))
	owned = data.get("owned", []).duplicate() if data.get("owned") is Array else []
	equipped = data.get("equipped", {}).duplicate() if data.get("equipped") is Dictionary else {}
	skills = {}
	if data.get("skills") is Dictionary:
		for skill_id in data["skills"]:
			if Skills.LIST.has(skill_id):
				skills[skill_id] = clampi(int(data["skills"][skill_id]), 0, Skills.MAX_SKILL)
	# Выбрасываем из сохранения предметы, которых нет в каталоге
	owned = owned.filter(func(id): return not ShopCatalog.find(String(id)).is_empty())
	_ensure_defaults()
	difficulty = String(data.get("difficulty", Difficulty.DEFAULT_ID))
	if not Difficulty.LEVELS.has(difficulty):
		difficulty = Difficulty.DEFAULT_ID
