class_name Order
extends RefCounted
# Один заказ гостя: какое блюдо и сколько он готов ждать.

var number: int            # порядковый номер заказа в смене
var recipe: Dictionary
var patience: float        # сколько секунд гость ждёт
var elapsed := 0.0         # сколько уже ждёт


func _init(order_number: int, recipe_data: Dictionary, wait_seconds: float) -> void:
	number = order_number
	recipe = recipe_data
	patience = wait_seconds


func remaining() -> float:
	return maxf(0.0, patience - elapsed)


# Сколько терпения осталось: от 1.0 (только пришёл) до 0.0 (уходит)
func ratio_left() -> float:
	return clampf(1.0 - elapsed / patience, 0.0, 1.0)


func is_expired() -> bool:
	return elapsed >= patience
