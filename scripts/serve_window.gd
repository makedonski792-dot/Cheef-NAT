class_name ServeWindow
extends Station
# Раздача: сюда приносят готовое блюдо, чтобы подать его гостю.

signal served(item: FoodItem)


func verb(chef: Chef) -> String:
	return "Подать" if chef.held != null and chef.held.is_dish else ""


func target_name(chef: Chef) -> String:
	return chef.held.name if chef.held != null else _label


func interact(chef: Chef) -> void:
	if chef.held != null and chef.held.is_dish:
		var dish := chef.drop()
		served.emit(dish)
