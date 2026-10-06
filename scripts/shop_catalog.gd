class_name ShopCatalog
extends RefCounted
# Каталог магазина («Мастерская»): предметы читаются из data/shop.json.
# Первый предмет каждой категории бесплатный, он выдан и надет с самого начала.

const PATH := "res://data/shop.json"

static var _categories: Array = []


# Все категории: [{id, name, items: [...]}, ...]
static func categories() -> Array:
	if _categories.is_empty():
		var file := FileAccess.open(PATH, FileAccess.READ)
		if file == null:
			push_error("Не удалось открыть каталог магазина: " + PATH)
			return []
		var parsed = JSON.parse_string(file.get_as_text())
		if parsed is Dictionary:
			_categories = parsed.get("categories", [])
	return _categories


static func items(category_id: String) -> Array:
	for category in categories():
		if category["id"] == category_id:
			return category["items"]
	return []


# Предмет по id (с добавленным полем category). Пустой словарь, если не найден.
static func find(item_id: String) -> Dictionary:
	for category in categories():
		for item in category["items"]:
			if item["id"] == item_id:
				var result: Dictionary = item.duplicate()
				result["category"] = category["id"]
				return result
	return {}


# Бесплатный предмет категории (тот, что выдан с самого начала)
static func default_id(category_id: String) -> String:
	var list := items(category_id)
	return list[0]["id"] if not list.is_empty() else ""
