class_name ActionButton
extends Control
# Большая круглая кнопка действия справа внизу. Как и джойстик, понимает
# касания разными пальцами, поэтому её можно жать, не отпуская джойстик.

signal pressed

const RADIUS := 66.0

# Что написано на кнопке («Взять»). Пусто = сейчас делать нечего.
var label_text := "":
	set(value):
		if label_text != value:
			label_text = value
			queue_redraw()

var _touch_index := -1


func _ready() -> void:
	# Прижимаем к правому нижнему углу, размер 140x140
	anchor_left = 1.0
	anchor_right = 1.0
	anchor_top = 1.0
	anchor_bottom = 1.0
	offset_left = -170.0
	offset_right = -30.0
	offset_top = -170.0
	offset_bottom = -30.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and _touch_index == -1:
			if event.position.distance_to(get_global_rect().get_center()) <= RADIUS * 1.15:
				_touch_index = event.index
				pressed.emit()
				queue_redraw()
		elif not event.pressed and event.index == _touch_index:
			_touch_index = -1
			queue_redraw()


func _draw() -> void:
	var c := size / 2.0
	var active := label_text != ""
	var color := Color(0.95, 0.6, 0.1, 0.85) if active else Color(0.5, 0.5, 0.5, 0.35)
	if _touch_index != -1:
		color = color.darkened(0.3)
	draw_circle(c, RADIUS, color)
	draw_arc(c, RADIUS, 0.0, TAU, 48, Color(1, 1, 1, 0.6), 3.0)
	var text := label_text if active else "Действие"
	draw_string(ThemeDB.fallback_font, Vector2(0, c.y + 8), text,
			HORIZONTAL_ALIGNMENT_CENTER, size.x, 21, Color.WHITE)
