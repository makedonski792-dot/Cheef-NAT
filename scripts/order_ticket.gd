class_name OrderTicket
extends Control
# Билет заказа на экране: картинка блюда, название, ЗАКАЗАННЫЙ ВАРИАНТ
# («Классический», «С белым вином»…) и полоска терпения гостя.
# Полоска сначала зелёная, потом жёлтая, перед уходом гостя красная и мигает.

const TICKET_SIZE := Vector2(150, 66)

var order: Order
# Подсвечен, когда на тарелке «Сборка» собирается именно это блюдо
var highlighted := false


func _init(order_data: Order) -> void:
	order = order_data
	custom_minimum_size = TICKET_SIZE
	size = TICKET_SIZE
	# Билет не должен «съедать» нажатия пальцем
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var ratio := order.ratio_left()
	var urgent := ratio < 0.25
	var blink := urgent and int(Time.get_ticks_msec() / 250.0) % 2 == 0

	var rect := Rect2(Vector2.ZERO, TICKET_SIZE)
	draw_rect(rect, Color(1.0, 0.86, 0.84, 0.95) if blink else Color(1, 1, 1, 0.92))
	draw_rect(rect, Color("3b2a1a"), false, 2.0)
	if highlighted:
		draw_rect(rect.grow(2), Color("ffd22e"), false, 4.0)

	var icon := Icons.food(order.recipe.get("dish_icon", ""))
	if icon != null:
		draw_texture_rect(icon, Rect2(4, 12, 40, 40), false)

	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(48, 16), order.recipe["name"], HORIZONTAL_ALIGNMENT_LEFT, 98, 13, Color("2b2018"))
	# Заказанный вариант: особенные (с бонусом) выделены цветом
	var special := int(order.variant.get("bonus", 0)) > 0
	draw_string(font, Vector2(48, 30), order.variant_name(), HORIZONTAL_ALIGNMENT_LEFT, 98, 11,
			Color("b45309") if special else Color("4b5563"))

	# Полоска терпения
	var bar := Rect2(48, 37, 98, 8)
	draw_rect(bar, Color("1f2937"))
	var color := Color("4ade80")
	if ratio < 0.5:
		color = Color("fbbf24")
	if urgent:
		color = Color("ef4444")
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * ratio, bar.size.y)), color)
	draw_rect(bar, Color("3b2a1a"), false, 1.0)

	draw_string(font, Vector2(48, 59), "%d с" % ceili(order.remaining()), HORIZONTAL_ALIGNMENT_LEFT, 98, 11, Color("5b4a3a"))
