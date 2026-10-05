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
		Sound.play("serve_bell")
		# Конфетти трёх цветов
		var center := Vector2(_visual_size.x / 2.0 - 30.0, _visual_size.y / 2.0)
		for color in [Color("f2b632"), Color("d9453b"), Color("4ade80"), Color("60a5fa")]:
			Fx.burst(self, center, color, 14, 170.0, 0.9, 200.0)
		served.emit(dish)
