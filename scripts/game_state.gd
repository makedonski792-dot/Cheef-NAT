extends Node
# Общее состояние игры. Godot создаёт его один раз при запуске,
# и к нему можно обратиться из любой сцены по имени GameState.

# Монеты игрока (в шаге 5 добавим сохранение между запусками)
var coins: int = 0

# Рецепт, который игрок выбрал для готовки
var current_recipe: Dictionary = {}


# Начислить монеты за блюдо
func add_coins(amount: int) -> void:
	coins += amount
