class_name ItemView
extends Node2D
# Картинка предмета: цветная фигурка и подпись. Используют повар и станции.
# Вид зависит от состояния: сырой — кружок, нарезанный — три кусочка,
# готовый — потемневший кружок, сгоревший — чёрный.

var _item: FoodItem
var _label: Label


func _ready() -> void:
	_label = Label.new()
	_label.size = Vector2(130, 18)
	_label.position = Vector2(-65, -34)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 12)
	_label.add_theme_color_override("font_color", Color.WHITE)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 4)
	add_child(_label)
	_refresh()


# Показать предмет (или null, чтобы убрать). Вызываем и после смены состояния.
func set_item(item: FoodItem) -> void:
	_item = item
	if _label != null:
		_refresh()
	queue_redraw()


func _refresh() -> void:
	_label.text = _item.display_name() if _item != null else ""
	_label.visible = _item != null


func _draw() -> void:
	if _item == null:
		return
	var outline := Color("3b2a1a")
	match _item.state:
		"chopped":
			for offset in [Vector2(-8, 4), Vector2(8, 4), Vector2(0, -8)]:
				draw_circle(offset, 7.0, _item.color.lightened(0.2))
				draw_arc(offset, 7.0, 0.0, TAU, 16, outline, 1.5)
		"cooked":
			draw_circle(Vector2.ZERO, 13.0, _item.color.darkened(0.35))
			draw_arc(Vector2.ZERO, 13.0, 0.0, TAU, 24, outline, 2.0)
		"burnt":
			draw_circle(Vector2.ZERO, 13.0, Color("1a1a1a"))
			draw_arc(Vector2.ZERO, 13.0, 0.0, TAU, 24, Color("ef4444"), 2.0)
		_:
			draw_circle(Vector2.ZERO, 13.0, _item.color)
			draw_arc(Vector2.ZERO, 13.0, 0.0, TAU, 24, outline, 2.0)
