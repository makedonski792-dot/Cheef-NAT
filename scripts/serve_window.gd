class_name ServeWindow
extends Station
# Раздача: сюда приносят готовое блюдо, чтобы подать его гостю.
# Принимает только то блюдо, на которое сейчас есть заказ.

signal served(item: FoodItem)

# Поток заказов смены (подключает кухня)
var orders: OrderBoard


# Есть ли заказ именно на этот вариант блюда
func has_order_for(dish: FoodItem) -> bool:
	return orders != null and orders.find_for(dish.dish_recipe_id, dish.dish_variant_id) != null


func verb(chef: Chef) -> String:
	if chef.held != null and chef.held.is_dish and has_order_for(chef.held):
		return "Подать"
	return ""


func target_name(chef: Chef) -> String:
	return chef.held.name if chef.held != null else _label


# Почему блюдо нельзя подать (подсказка игроку). Пусто, если можно или в руках не блюдо.
func reject_reason(chef: Chef) -> String:
	if chef.held == null or not chef.held.is_dish or has_order_for(chef.held):
		return ""
	# Блюдо заказано, но другого варианта: говорим, чего хочет гость
	var other := orders.find_for(chef.held.dish_recipe_id) if orders != null else null
	if other != null:
		return "гость просит «%s», а это другой вариант" % other.variant_name()
	return "на такое блюдо нет заказа"


func interact(chef: Chef) -> void:
	if chef.held != null and chef.held.is_dish and has_order_for(chef.held):
		var dish := chef.drop()
		Sound.play("serve_bell")
		# Конфетти разных цветов
		var center := Vector2(_visual_size.x / 2.0 - 30.0, _visual_size.y / 2.0)
		for color in [Color("f2b632"), Color("d9453b"), Color("4ade80"), Color("60a5fa")]:
			Fx.burst(self, center, color, 14, 170.0, 0.9, 200.0)
		served.emit(dish)
