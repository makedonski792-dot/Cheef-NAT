class_name ItemView
extends Node2D
# Картинка предмета и подпись. Используют повар и станции.
# Вид зависит от состояния: сырой — картинка продукта, нарезанный — свой рисунок
# или три кусочка, готовый — своя картинка или потемневшая, сгоревший — почти чёрный.
# Если картинки нет, рисуем запасной цветной кружок.

const ICON_SIZE := 40.0
const DISH_SIZE := 52.0
const COOKED_TINT := Color(0.82, 0.66, 0.5)
const BURNT_TINT := Color(0.18, 0.14, 0.14)

# Насколько выше центра предмета стоит подпись (на станциях её поднимаем выше полоски)
var label_offset := -48.0

var _item: FoodItem
var _shown_state := ""
var _label: Label


func _ready() -> void:
	_label = Label.new()
	_label.size = Vector2(150, 18)
	_label.position = Vector2(-75, label_offset)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 12)
	_label.add_theme_color_override("font_color", Color.WHITE)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 4)
	add_child(_label)
	_refresh()


# Показать предмет (или null, чтобы убрать). Вызываем и после смены состояния.
func set_item(item: FoodItem) -> void:
	# Подпрыгиваем, когда предмет появился или изменился (нарезан, приготовлен)
	var changed := item != null and (item != _item or item.state != _shown_state)
	_item = item
	_shown_state = item.state if item != null else ""
	if _label != null:
		_refresh()
	queue_redraw()
	if changed and is_inside_tree():
		_pop()


# Короткая анимация «пружинки»: предмет чуть увеличивается и возвращается
func _pop() -> void:
	scale = Vector2(1.45, 1.45)
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2.ONE, 0.28) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _refresh() -> void:
	_label.text = _item.display_name() if _item != null else ""
	_label.visible = _item != null


func _draw() -> void:
	if _item == null:
		return
	var texture := Icons.for_item(_item)
	if texture == null:
		_draw_fallback()
		return

	var tint := Color.WHITE
	if _item.state == "burnt":
		tint = BURNT_TINT
	elif _item.state == "cooked" and not Icons.has_state_icon(_item):
		tint = COOKED_TINT

	var size := DISH_SIZE if _item.is_dish else ICON_SIZE
	if _item.state == "chopped" and not Icons.has_state_icon(_item):
		# Нарезанное без своей картинки: три маленьких кусочка
		for offset in [Vector2(-11, 7), Vector2(11, 7), Vector2(0, -10)]:
			draw_texture_rect(texture, Rect2(offset - Vector2(12, 12), Vector2(24, 24)), false, tint)
	else:
		draw_texture_rect(texture, Rect2(Vector2(-size, -size) / 2.0, Vector2(size, size)), false, tint)


# Запасной вариант без картинки: цветные кружки
func _draw_fallback() -> void:
	var outline := Color("3b2a1a")
	var color := _item.color
	if _item.state == "burnt":
		color = Color("1a1a1a")
	elif _item.state == "cooked":
		color = color.darkened(0.35)
	if _item.state == "chopped":
		for offset in [Vector2(-8, 4), Vector2(8, 4), Vector2(0, -8)]:
			draw_circle(offset, 7.0, color.lightened(0.2))
			draw_arc(offset, 7.0, 0.0, TAU, 16, outline, 1.5)
	else:
		draw_circle(Vector2.ZERO, 13.0, color)
		draw_arc(Vector2.ZERO, 13.0, 0.0, TAU, 24, outline, 2.0)
