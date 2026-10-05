class_name Crate
extends Station
# Ящик с ингредиентом: из него можно взять сколько угодно штук (по одной).

var ingredient_id: String
var info: Dictionary
var _icon: Texture2D


# r — как выглядит ящик; он стоит на столе у стены, поэтому сам не твёрдый
func setup_crate(id: String, ingredient_info: Dictionary, r: Rect2) -> void:
	ingredient_id = id
	info = ingredient_info
	setup(r, Color(info.get("color", "#cccccc")), info.get("name", id), false)
	set_art(Icons.kitchen("crate_box"))
	_icon = Icons.food(info.get("icon", ""))
	# Название внизу ящика, а картинка продукта над ним
	label_y = r.size.y - 5.0
	# Длинные названия пишем мельче, чтобы влезли в одну строку
	label_size = 11 if String(info.get("name", id)).length() <= 14 else 9
	# Достать можно, подойдя к столу у ящика (расширяем зону до стены)
	reach_rect = Rect2(r.position.x - 7, 0, r.size.x + 14, 70)


func verb(chef: Chef) -> String:
	return "Взять" if chef.held == null else ""


func interact(chef: Chef) -> void:
	if chef.held == null:
		chef.hold(FoodItem.new(ingredient_id, info))


func _draw_extra() -> void:
	if _icon != null:
		draw_texture_rect(_icon, Rect2(_visual_size.x / 2.0 - 19.0, 6.0, 38.0, 38.0), false)
