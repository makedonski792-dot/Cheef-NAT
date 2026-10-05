class_name CuttingBoard
extends WorkStation
# Разделочная доска: режет сырые продукты. Повар должен стоять рядом.

const CHOP_SECONDS := 3.0


func _init() -> void:
	requires_chef = true


# Принимает только сырое, что можно резать
func accepts(item: FoodItem) -> bool:
	return item.state == "raw" and item.can("chop")


func step_duration(item: FoodItem) -> float:
	return CHOP_SECONDS if item.state == "raw" else 0.0


func advance(item: FoodItem) -> void:
	item.state = "chopped"
