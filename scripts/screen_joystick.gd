class_name ScreenJoystick
extends Control
# Экранный джойстик в левом нижнем углу. Понимает касания пальцем (несколько
# пальцев одновременно: одним ведём повара, другим жмём кнопки).
# Результат лежит в value: вектор длиной от 0 до 1 (куда и как сильно тянем).

const RADIUS := 80.0       # радиус основания джойстика
const KNOB_RADIUS := 34.0  # радиус «шарика»
const DEAD_ZONE := 0.15    # маленькие отклонения игнорируем

var value := Vector2.ZERO

var _touch_index := -1     # номер пальца, который держит джойстик
var _knob_offset := Vector2.ZERO


func _ready() -> void:
	# Прижимаем к левому нижнему углу, размер 240x240
	anchor_left = 0.0
	anchor_right = 0.0
	anchor_top = 1.0
	anchor_bottom = 1.0
	offset_left = 20.0
	offset_right = 260.0
	offset_top = -260.0
	offset_bottom = -20.0
	# Сам джойстик не должен «съедать» нажатия на кнопки
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and _touch_index == -1:
			# Начинаем, только если палец лёг рядом с джойстиком
			if event.position.distance_to(_center()) <= RADIUS * 1.6:
				_touch_index = event.index
				_update(event.position)
		elif not event.pressed and event.index == _touch_index:
			_release()
	elif event is InputEventScreenDrag and event.index == _touch_index:
		_update(event.position)


# Центр джойстика в координатах экрана
func _center() -> Vector2:
	return get_global_rect().get_center()


func _update(touch_position: Vector2) -> void:
	var offset: Vector2 = touch_position - _center()
	if offset.length() > RADIUS:
		offset = offset.normalized() * RADIUS
	_knob_offset = offset
	value = offset / RADIUS
	if value.length() < DEAD_ZONE:
		value = Vector2.ZERO
	queue_redraw()


func _release() -> void:
	_touch_index = -1
	_knob_offset = Vector2.ZERO
	value = Vector2.ZERO
	queue_redraw()


func _draw() -> void:
	var c := size / 2.0
	draw_circle(c, RADIUS, Color(0, 0, 0, 0.22))
	draw_arc(c, RADIUS, 0.0, TAU, 48, Color(1, 1, 1, 0.5), 3.0)
	draw_circle(c + _knob_offset, KNOB_RADIUS, Color(1, 1, 1, 0.65))
