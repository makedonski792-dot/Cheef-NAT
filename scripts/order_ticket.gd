class_name OrderTicket
extends Control
# Билет заказа на экране: картинка блюда, название и полоска терпения гостя.
# Полоска сначала зелёная, потом жёлтая, перед уходом гостя красная и мигает.

const TICKET_SIZE := Vector2(150, 54)

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
	draw_rect(rect, Color(1.0, 0.86, 0.84, 0.95) if blink else Color(1, 1, 1, 0.9))
	draw_rect(rect, Color("3b2a1a"), false, 2.0)
	if highlighted:
		draw_rect(rect.grow(2), Color("ffd22e"), false, 4.0)

	var icon := Icons.food(order.recipe.get("dish_icon", ""))
	if icon != null:
		draw_texture_rect(icon, Rect2(4, 7, 40, 40), false)

	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(48, 19), order.recipe["name"], HORIZONTAL_ALIGNMENT_LEFT, 98, 13, Color("2b2018"))

	# Полоска терпения
	var bar := Rect2(48, 27, 98, 8)
	draw_rect(bar, Color("1f2937"))
	var color := Color("4ade80")
	if ratio < 0.5:
		color = Color("fbbf24")
	if urgent:
		color = Color("ef4444")
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * ratio, bar.size.y)), color)
	draw_rect(bar, Color("3b2a1a"), false, 1.0)

	draw_string(font, Vector2(48, 49), "%d с" % ceili(order.remaining()), HORIZONTAL_ALIGNMENT_LEFT, 98, 11, Color("5b4a3a"))
