class_name Icons
extends RefCounted
# Загрузка картинок еды и кухни. Картинки лежат в art/food (png или svg)
# и art/kitchen. Если картинки нет, возвращаем null, и код рисует запасной кружок.

const FOOD_DIR := "res://art/food/"
const KITCHEN_DIR := "res://art/kitchen/"

# Кэш, чтобы не загружать одну картинку много раз
static var _cache := {}


# Картинка из папки еды по имени без расширения («onion»)
static func food(icon_name: String) -> Texture2D:
	return _load(FOOD_DIR, icon_name, ["png", "svg"])


# Картинка из папки кухни («stove»)
static func kitchen(art_name: String) -> Texture2D:
	return _load(KITCHEN_DIR, art_name, ["svg", "png"])


# Картинка для предмета с учётом его состояния: у ингредиента в «icons» могут
# быть свои картинки для "chopped" и "cooked". Иначе берётся основная «icon».
static func for_item(item: FoodItem) -> Texture2D:
	var by_state: Dictionary = item.info.get("icons", {})
	if by_state.has(item.state):
		return food(by_state[item.state])
	return food(item.info.get("icon", ""))


# Есть ли у предмета отдельная картинка именно для его текущего состояния
static func has_state_icon(item: FoodItem) -> bool:
	return item.info.get("icons", {}).has(item.state)


static func _load(dir: String, file_name: String, extensions: Array) -> Texture2D:
	if file_name == "":
		return null
	var key := dir + file_name
	if _cache.has(key):
		return _cache[key]
	var texture: Texture2D = null
	for ext in extensions:
		var path := "%s%s.%s" % [dir, file_name, ext]
		if ResourceLoader.exists(path):
			texture = load(path)
			break
	_cache[key] = texture
	return texture
