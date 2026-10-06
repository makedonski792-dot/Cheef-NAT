class_name ScreenJoystick
extends Control
# «Плавающий» экранный джойстик. Появляется там, где ты коснулся пальцем в левой
# половине экрана, и едет за пальцем, если его оттянуть далеко (не нужно возвращаться
# к центру). Понимает несколько пальцев одновременно: одним ведём повара, другим
# жмём кнопку действия. Результат лежит в value: вектор длиной от 0 до 1.

const RADIUS := 60.0       # радиус круга джойстика
const KNOB_RADIUS := 28.0  # радиус «шарика»
const DEAD_ZONE := 0.12    # маленькие отклонения игнорируем
const ZONE_WIDTH_RATIO := 0.5   # управлять можно в левой половине экрана
const ZONE_TOP := 100.0         # выше этой линии (билеты заказов) касания не считаются

var value := Vector2.ZERO

var _touch_index := -1
var _center := Vector2.ZERO       # где сейчас центр круга
var _knob_offset := Vector2.ZERO
var _home := Vector2(130, 420)    # где рисуем «подсказку» джойстика, пока никто не касается


func _ready() -> void:
	# Занимает весь экран, но сам не перехватывает мышь и кнопки
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_update_home()
	get_viewport().size_changed.connect(_update_home)


func _update_home() -> void:
	_home = Vector2(130.0, get_viewport_rect().size.y - 120.0)
	queue_redraw()


# Область, где джойстик «слушает» касания
func zone() -> Rect2:
	var screen := get_viewport_rect().size
	return Rect2(0.0, ZONE_TOP, screen.x * ZONE_WIDTH_RATIO, screen.y - ZONE_TOP)


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and _touch_index == -1 and zone().has_point(event.position):
			_touch_index = event.index
			_center = _keep_on_screen(event.position)
			_update(event.position)
		elif not event.pressed and event.index == _touch_index:
			_release()
	elif event is InputEventScreenDrag and event.index == _touch_index:
		_update(event.position)


# Не даём кругу выходить за край экрана
func _keep_on_screen(point: Vector2) -> Vector2:
	var screen := get_viewport_rect().size
	var margin := RADIUS + 10.0
	return Vector2(clampf(point.x, margin, screen.x - margin), clampf(point.y, margin, screen.y - margin))


func _update(touch_position: Vector2) -> void:
	var offset: Vector2 = touch_position - _center
	if offset.length() > RADIUS:
		# Палец ушёл дальше круга: круг «догоняет» палец
		_center += offset.normalized() * (offset.length() - RADIUS)
		offset = touch_position - _center
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
	if _touch_index == -1:
		# Подсказка, где можно начать: бледный круг и надпись
		draw_circle(_home, RADIUS, Color(0, 0, 0, 0.10))
		draw_arc(_home, RADIUS, 0.0, TAU, 48, Color(1, 1, 1, 0.35), 3.0)
		draw_string(ThemeDB.fallback_font, _home + Vector2(-60, 6), "Веди пальцем",
				HORIZONTAL_ALIGNMENT_CENTER, 120, 15, Color(1, 1, 1, 0.75))
		return
	draw_circle(_center, RADIUS, Color(0, 0, 0, 0.25))
	draw_arc(_center, RADIUS, 0.0, TAU, 48, Color(1, 1, 1, 0.55), 3.0)
	draw_circle(_center + _knob_offset, KNOB_RADIUS, Color(1, 1, 1, 0.7))
