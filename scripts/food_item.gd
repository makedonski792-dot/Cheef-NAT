class_name FoodItem
extends RefCounted
# Предмет еды, который повар может держать в руках или положить на стол.
# state пригодится позже: «raw» (сырой), потом «chopped» (нарезанный) и т.д.

var id: String
var name: String
var color: Color
var state := "raw"


# ingredient_id — id из ingredients.json, info — запись этого ингредиента
func _init(ingredient_id: String, info: Dictionary) -> void:
	id = ingredient_id
	name = info.get("name", ingredient_id)
	color = Color(info.get("color", "#cccccc"))
