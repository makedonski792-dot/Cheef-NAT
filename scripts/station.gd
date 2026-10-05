class_name Station
extends StaticBody2D
# Базовый класс «места на кухне», с которым повар взаимодействует:
# ящик, стол, мусорка, доска, плита, сборка, раздача.
# Наследники переопределяют verb(), target_name() и interact().
# Вид: либо плоский цвет, либо картинка (set_art).

# Подсвечена жёлтой рамкой, когда повар рядом и может что-то сделать
var focused := false:
	set(value):
		if focused != value:
			focused = value
			queue_redraw()

# Прямоугольник, до которого считаем расстояние от повара (в мировых координатах)
var reach_rect: Rect2

# Положение подписи по вертикали (-1 — выбрать само) и размер шрифта
var label_y := -1.0
var label_size := 13

var _visual_size: Vector2
var _fill: Color
var _text_color: Color
var _label := ""
var _art: Texture2D
var _art_tiled := false


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


# Нарисовать место картинкой (tiled — повторять картинку, как плитку)
func set_art(texture: Texture2D, tiled := false) -> void:
	_art = texture
	_art_tiled = tiled
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
	var rect := Rect2(Vector2.ZERO, _visual_size)
	if _art != null:
		draw_texture_rect(_art, rect, _art_tiled)
	else:
		draw_rect(rect, _fill)
		draw_rect(rect, Color("3b2a1a"), false, 2.0)
	if focused:
		draw_rect(rect.grow(3), Color("ffe94d"), false, 4.0)

	if _label != "":
		var font := ThemeDB.fallback_font
		if _art != null:
			# На картинке подпись белая с тёмной обводкой, чтобы читалась на любом фоне
			var y := label_y if label_y >= 0.0 else 16.0
			draw_multiline_string_outline(font, Vector2(0, y), _label,
					HORIZONTAL_ALIGNMENT_CENTER, _visual_size.x, label_size, 3, 5, Color("2b2018"))
			draw_multiline_string(font, Vector2(0, y), _label,
					HORIZONTAL_ALIGNMENT_CENTER, _visual_size.x, label_size, 3, Color.WHITE)
		else:
			var y := label_y if label_y >= 0.0 else _visual_size.y / 2.0 - 2.0
			draw_multiline_string(font, Vector2(0, y), _label,
					HORIZONTAL_ALIGNMENT_CENTER, _visual_size.x, label_size, 3, _text_color)
	_draw_extra()


# Место для дополнительной отрисовки в наследниках (например, полоска прогресса)
func _draw_extra() -> void:
	pass
