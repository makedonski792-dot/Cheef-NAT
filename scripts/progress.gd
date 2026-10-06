class_name Progress
extends RefCounted
# Прогресс повара глазами игры: что надето и насколько прокачаны навыки.
# Игровые скрипты спрашивают здесь множители (скорость, терпение, награда) и
# названия рисунков. Состояние берётся из автозагрузки GameState в момент вызова,
# поэтому класс безопасно работает и в тестах (без состояния всё как «по умолчанию»).


static func _state() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null("GameState")


# Уровень навыка (0..5)
static func skill_level(skill_id: String) -> int:
	var state := _state()
	if state == null:
		return 0
	return int(state.skills.get(skill_id, 0))


static func _bonus(skill_id: String) -> float:
	return 1.0 + float(Skills.LIST[skill_id]["per_level"]) * skill_level(skill_id)


# Надетый предмет категории (словарь из каталога)
static func equipped_item(category_id: String) -> Dictionary:
	var state := _state()
	var id: String = ShopCatalog.default_id(category_id)
	if state != null:
		id = state.equipped.get(category_id, id)
	var item := ShopCatalog.find(id)
	if item.is_empty():
		item = ShopCatalog.find(ShopCatalog.default_id(category_id))
	return item


# Название рисунка надетого предмета (floor_tile, counter_oak, chef_red…)
static func art(category_id: String) -> String:
	return String(equipped_item(category_id).get("art", ""))


# Цвет лезвия надетого ножа
static func knife_blade() -> Color:
	return Color(String(equipped_item("knife").get("blade", "#e6ebf2")))


static func run_multiplier() -> float:
	return _bonus("legs")


# Во сколько раз быстрее нарезка (нож и навык «Руки»)
static func chop_multiplier() -> float:
	return float(equipped_item("knife").get("chop", 1.0)) * _bonus("hands")


# Во сколько раз быстрее готовка (навык «Плита»)
static func cook_multiplier() -> float:
	return _bonus("stove")


# Во сколько раз дольше блюдо не сгорает (навык «Плита»)
static func burn_multiplier() -> float:
	return 1.0 + 1.5 * float(Skills.LIST["stove"]["per_level"]) * skill_level("stove")


static func patience_multiplier() -> float:
	return _bonus("charm")


static func coin_multiplier() -> float:
	return _bonus("tips")
