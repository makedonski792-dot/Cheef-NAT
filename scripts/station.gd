class_name Station
extends StaticBody2D
# Базовый класс «места на кухне», с которым повар взаимодействует:
# ящик, стол, мусорка (позже доска, плита, духовка).
# Наследники переопределяют verb(), target_name() и interact().

# Подсвечена жёлтой рамкой, когда повар рядом и может что-то сделать
var focused := false:
	set(value):
		if focused != value:
			focused = value
			queue_redraw()

# Прямоугольник, до которого считаем расстояние от повара (в мировых координатах)
var reach_rect: Rect2

var _visual_size: Vector2
var _fill: Color
var _text_color: Color
var _label := ""


# Создать место: r — прямоугольник на кухне, solid — не пускает ли повара
func setup(r: Rect2, color: Color, label: String, solid := true) -> void:
	position = r.position
	reach_rect = r
	_visual_size = r.size
	_fill = color
	_label = label
	# Тёмный текст на светлом фоне и белый на тёмном
	_text_color = Color("2b2018") if color.get_luminance() > 0.5 else Color.WHITE

	if solid:
		var shape := CollisionShape2D.new()
		var rectangle := RectangleShape2D.new()
		rectangle.size = r.size
		shape.shape = rectangle
		shape.position = r.size / 2.0
		add_child(shape)
	queue_redraw()


# Расстояние от точки до этого места (0, если точка внутри)
func distance_to(point: Vector2) -> float:
	var nearest := Vector2(
		clampf(point.x, reach_rect.position.x, reach_rect.end.x),
		clampf(point.y, reach_rect.position.y, reach_rect.end.y)
	)
	return point.distance_to(nearest)


# Что сделает кнопка действия («Взять», «Положить»). Пусто, если делать нечего.
func verb(_chef: Chef) -> String:
	return ""


# Название объекта действия для подсказки («Лук»)
func target_name(_chef: Chef) -> String:
	return _label


# Выполнить действие
func interact(_chef: Chef) -> void:
	pass


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, _visual_size), _fill)
	draw_rect(Rect2(Vector2.ZERO, _visual_size), Color("3b2a1a"), false, 2.0)
	if focused:
		draw_rect(Rect2(Vector2.ZERO, _visual_size).grow(3), Color("ffe94d"), false, 4.0)
	if _label != "":
		var font := ThemeDB.fallback_font
		draw_multiline_string(font, Vector2(0, _visual_size.y / 2.0 - 2.0), _label,
				HORIZONTAL_ALIGNMENT_CENTER, _visual_size.x, 13, 3, _text_color)
	_draw_extra()


# Место для дополнительной отрисовки в наследниках (например, полоска прогресса)
func _draw_extra() -> void:
	pass
