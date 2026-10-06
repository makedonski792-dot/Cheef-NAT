class_name Skills
extends RefCounted
# Навыки повара и уровни. Опыт даётся за поданные блюда, каждый новый уровень
# даёт одно очко навыка. Очки тратятся на улучшение навыков (до MAX_SKILL).

const MAX_LEVEL := 10
const MAX_SKILL := 5

# per_level — на сколько растёт эффект за каждый уровень навыка
const LIST := {
	"legs": {"name": "Ноги", "desc": "Повар бегает быстрее", "per_level": 0.08, "unit": "скорость бега"},
	"hands": {"name": "Руки", "desc": "Нарезка идёт быстрее", "per_level": 0.10, "unit": "скорость нарезки"},
	"stove": {"name": "Плита", "desc": "Готовка быстрее, а сгорает позже", "per_level": 0.08, "unit": "скорость готовки"},
	"charm": {"name": "Обаяние", "desc": "Гости терпеливее ждут заказ", "per_level": 0.06, "unit": "терпение гостей"},
	"tips": {"name": "Чаевые", "desc": "Больше монет за каждое блюдо", "per_level": 0.05, "unit": "награда"},
}
const ORDER := ["legs", "hands", "stove", "charm", "tips"]


# Сколько всего опыта нужно, чтобы дойти до уровня level
static func xp_for_level(level: int) -> int:
	return 60 * (level - 1) * level


static func level_for_xp(xp: int) -> int:
	var level := 1
	while level < MAX_LEVEL and xp >= xp_for_level(level + 1):
		level += 1
	return level
