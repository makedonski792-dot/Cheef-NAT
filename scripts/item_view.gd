class_name ItemView
extends Node2D
# Картинка предмета: цветной кружок и подпись. Используют повар и столы.

var _item: FoodItem
var _label: Label


func _ready() -> void:
	_label = Label.new()
	_label.size = Vector2(110, 18)
	_label.position = Vector2(-55, -34)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 12)
	_label.add_theme_color_override("font_color", Color.WHITE)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 4)
	add_child(_label)
	_refresh()


# Показать предмет (или null, чтобы убрать)
func set_item(item: FoodItem) -> void:
	_item = item
	if _label != null:
		_refresh()
	queue_redraw()


func _refresh() -> void:
	_label.text = _item.name if _item != null else ""
	_label.visible = _item != null


func _draw() -> void:
	if _item == null:
		return
	draw_circle(Vector2.ZERO, 13.0, _item.color)
	draw_arc(Vector2.ZERO, 13.0, 0.0, TAU, 24, Color("3b2a1a"), 2.0)
