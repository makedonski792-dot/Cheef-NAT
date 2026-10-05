class_name ServeWindow
extends Station
# Раздача: сюда приносят готовое блюдо, чтобы подать его гостю.
# Принимает только то блюдо, на которое сейчас есть заказ.

signal served(item: FoodItem)

# Поток заказов смены (подключает кухня)
var orders: OrderBoard


# Есть ли заказ на это блюдо
func has_order_for(dish: FoodItem) -> bool:
	return orders != null and orders.find_for(dish.dish_recipe_id) != null


func verb(chef: Chef) -> String:
	if chef.held != null and chef.held.is_dish and has_order_for(chef.held):
		return "Подать"
	return ""


func target_name(chef: Chef) -> String:
	return chef.held.name if chef.held != null else _label


# Почему блюдо нельзя подать (подсказка игроку). Пусто, если можно или в руках не блюдо.
func reject_reason(chef: Chef) -> String:
	if chef.held != null and chef.held.is_dish and not has_order_for(chef.held):
		return "на такое блюдо нет заказа"
	return ""


func interact(chef: Chef) -> void:
	if chef.held != null and chef.held.is_dish and has_order_for(chef.held):
		var dish := chef.drop()
		Sound.play("serve_bell")
		# Конфетти разных цветов
		var center := Vector2(_visual_size.x / 2.0 - 30.0, _visual_size.y / 2.0)
		for color in [Color("f2b632"), Color("d9453b"), Color("4ade80"), Color("60a5fa")]:
			Fx.burst(self, center, color, 14, 170.0, 0.9, 200.0)
		served.emit(dish)
