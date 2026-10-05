class_name FoodItem
extends RefCounted
# Предмет еды, который повар может держать в руках или положить на стол.
# state — в каком виде продукт: "raw" (сырой), "chopped" (нарезан),
# "cooked" (приготовлен), "burnt" (сгорел).

var id: String
var name: String
var color: Color
var state := "raw"
var info: Dictionary


# ingredient_id — id из ingredients.json, ingredient_info — запись этого ингредиента
func _init(ingredient_id: String, ingredient_info: Dictionary) -> void:
	id = ingredient_id
	info = ingredient_info
	name = info.get("name", ingredient_id)
	color = Color(info.get("color", "#cccccc"))


# Есть ли у ингредиента свойство: "chop" (можно резать), "heat" (можно греть)
func can(flag: String) -> bool:
	return info.get(flag, false)


# Название с пометкой состояния, например «Лук (нарезка)»
func display_name() -> String:
	match state:
		"chopped":
			return "%s (нарезка)" % name
		"cooked":
			return "%s (готово)" % name
		"burnt":
			return "%s (сгорело)" % name
	return name
