class_name Crate
extends Station
# Ящик с ингредиентом: из него можно взять сколько угодно штук (по одной).

var ingredient_id: String
var info: Dictionary


# r — как выглядит ящик; он стоит на столе у стены, поэтому сам не твёрдый
func setup_crate(id: String, ingredient_info: Dictionary, r: Rect2) -> void:
	ingredient_id = id
	info = ingredient_info
	setup(r, Color(info.get("color", "#cccccc")), info.get("name", id), false)
	# Достать можно, подойдя к столу у ящика (расширяем зону до стены)
	reach_rect = Rect2(r.position.x - 7, 0, r.size.x + 14, 70)


func verb(chef: Chef) -> String:
	return "Взять" if chef.held == null else ""


func interact(chef: Chef) -> void:
	if chef.held == null:
		chef.hold(FoodItem.new(ingredient_id, info))
