class_name Difficulty
extends RefCounted
# Уровни сложности: меняют длину смены, терпение и частоту гостей, число
# одновременных заказов и награду. Сами смены (data/shifts/*.json) описаны для
# «Обычного» уровня, остальные считаются от него.

const ORDER := ["easy", "normal", "hard"]
const DEFAULT_ID := "easy"

# duration — длина смены, interval — как редко приходят гости, patience — терпение гостей,
# reward — множитель награды в монетах
const LEVELS := {
	"easy": {"name": "Лёгкий", "duration": 1.5, "interval": 1.25, "patience": 1.3, "max_orders": 2, "reward": 0.8},
	"normal": {"name": "Обычный", "duration": 1.0, "interval": 1.0, "patience": 1.0, "max_orders": 3, "reward": 1.0},
	"hard": {"name": "Сложный", "duration": 0.7, "interval": 0.8, "patience": 0.7, "max_orders": 4, "reward": 1.5},
}


static func level_name(level_id: String) -> String:
	return LEVELS.get(level_id, LEVELS["normal"])["name"]


# Копия смены с настройками выбранного уровня сложности
static func apply(shift: Dictionary, level_id: String) -> Dictionary:
	var level: Dictionary = LEVELS.get(level_id, LEVELS["normal"])
	var result := shift.duplicate(true)
	result["difficulty"] = level_id if LEVELS.has(level_id) else "normal"
	result["duration"] = roundf(float(shift["duration"]) * level["duration"])
	var interval: Array = shift.get("order_interval", [65, 90])
	result["order_interval"] = [roundf(float(interval[0]) * level["interval"]), roundf(float(interval[1]) * level["interval"])]
	result["second_order_delay"] = roundf(float(shift.get("second_order_delay", 35)) * level["interval"])
	result["patience_scale"] = float(shift.get("patience_scale", 1.0)) * level["patience"]
	result["max_orders"] = level["max_orders"]
	result["reward_scale"] = level["reward"]
	return result


# Короткое описание уровня для экрана выбора
static func describe(shift: Dictionary) -> String:
	var minutes := int(shift["duration"]) / 60
	var level: Dictionary = LEVELS.get(shift.get("difficulty", "normal"), LEVELS["normal"])
	return "Смена %d мин · до %d заказов сразу · награда ×%s" % [minutes, level["max_orders"], str(level["reward"]).replace(".", ",")]
