extends Node
# Общее состояние игры. Godot создаёт его один раз при запуске,
# и к нему можно обратиться из любой сцены по имени GameState.

# Где хранится сохранение (тесты подменяют путь, чтобы не трогать настоящее)
var save_path: String = SaveGame.DEFAULT_PATH

# Монеты игрока
var coins: int = 0

# Рецепт, который игрок выбрал для готовки
var current_recipe: Dictionary = {}


func _ready() -> void:
	load_game()


# Начислить монеты за блюдо и сразу сохранить
func add_coins(amount: int) -> void:
	coins += amount
	save_game()


func save_game() -> void:
	SaveGame.write({"coins": coins}, save_path)


# Загрузить сохранение. Если его нет, начинаем с 0 монет.
func load_game() -> void:
	var data := SaveGame.read(save_path)
	# int(...) нужен, потому что JSON хранит числа как дробные
	coins = maxi(0, int(data.get("coins", 0)))
