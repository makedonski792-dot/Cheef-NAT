extends Node
# Общее состояние игры. Godot создаёт его один раз при запуске,
# и к нему можно обратиться из любой сцены по имени GameState.

# Где хранится сохранение (тесты подменяют путь, чтобы не трогать настоящее)
var save_path: String = SaveGame.DEFAULT_PATH

# Монеты игрока
var coins: int = 0

# Включён ли звук (запоминается в сохранении)
var sound_enabled: bool = true

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
	SaveGame.write({"coins": coins, "sound": sound_enabled, "day": day, "tutorial": tutorial_seen, "difficulty": difficulty}, save_path)


# Загрузить сохранение. Если его нет, начинаем с 0 монет.
func load_game() -> void:
	var data := SaveGame.read(save_path)
	# int(...) нужен, потому что JSON хранит числа как дробные
	coins = maxi(0, int(data.get("coins", 0)))
	sound_enabled = bool(data.get("sound", true))
	day = maxi(1, int(data.get("day", 1)))
	tutorial_seen = bool(data.get("tutorial", false))
	difficulty = String(data.get("difficulty", Difficulty.DEFAULT_ID))
	if not Difficulty.LEVELS.has(difficulty):
		difficulty = Difficulty.DEFAULT_ID
