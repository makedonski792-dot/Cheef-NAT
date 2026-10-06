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
# Готовое блюдо, собранное на станции «Сборка» (его несут на раздачу)
var is_dish := false
# У готового блюда: какой это рецепт и как он собран (для оценки при подаче)
var dish_recipe_id := ""
var dish_variant_id := ""
var dish_logic: CookingLogic


# ingredient_id — id из ingredients.json, ingredient_info — запись этого ингредиента
func _init(ingredient_id: String, ingredient_info: Dictionary) -> void:
	id = ingredient_id
	info = ingredient_info
	name = info.get("name", ingredient_id)
	color = Color(info.get("color", "#cccccc"))


# Есть ли у ингредиента свойство: "chop" (можно резать), "heat" (можно греть)
func can(flag: String) -> bool:
	return info.get(flag, false)


# Пометка состояния для названия: " (нарезка)", " (готово)", " (сгорело)"
static func state_suffix(item_state: String) -> String:
	match item_state:
		"chopped":
			return " (нарезка)"
		"cooked":
			return " (готово)"
		"burnt":
			return " (сгорело)"
	return ""


# Название с пометкой состояния, например «Лук (нарезка)»
func display_name() -> String:
	return name + state_suffix(state)
