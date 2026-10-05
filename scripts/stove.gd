class_name Stove
extends WorkStation
# Плита: готовит продукт сама, повар может отойти. Но если забыть, всё сгорит!

const COOK_SECONDS := 4.0   # до готовности
const BURN_SECONDS := 5.0   # от готовности до пригорания


# Принимает сырое или нарезанное, что можно греть
func accepts(item: FoodItem) -> bool:
	return item.can("heat") and (item.state == "raw" or item.state == "chopped")


func step_duration(item: FoodItem) -> float:
	match item.state:
		"raw", "chopped":
			return COOK_SECONDS
		"cooked":
			return BURN_SECONDS
	return 0.0


func advance(item: FoodItem) -> void:
	if item.state == "cooked":
		item.state = "burnt"
	else:
		item.state = "cooked"


# Оранжевая полоска — готовится, красная — вот-вот сгорит
func bar_color(item: FoodItem) -> Color:
	return Color("ef4444") if item.state == "cooked" else Color("f59e0b")
