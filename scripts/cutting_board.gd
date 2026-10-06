class_name CuttingBoard
extends WorkStation
# Разделочная доска: режет сырые продукты. Повар должен стоять рядом.
# Пока идёт нарезка, над продуктом машет нож, летят кусочки и стучит звук.

const CHOP_SECONDS := 2.5
const HIT_INTERVAL := 0.33   # как часто «удар ножа»

var _hit_timer := 0.0
var _knife_phase := 0.0


func _init() -> void:
	requires_chef = true


# Принимает только сырое, что можно резать
func accepts(item: FoodItem) -> bool:
	return item.state == "raw" and item.can("chop")


# Почему на доске это не режется
func reject_reason(item: FoodItem) -> String:
	if accepts(item):
		return ""
	if not item.can("chop"):
		return "%s нельзя нарезать" % item.name
	if item.state == "chopped":
		return "%s уже нарезано" % item.name
	return "%s уже готовили, резать поздно" % item.name


func step_duration(item: FoodItem) -> float:
	return CHOP_SECONDS if item.state == "raw" else 0.0


func advance(item: FoodItem) -> void:
	item.state = "chopped"


# Каждый «удар»: стук, кусочки продукта разлетаются
func _on_work(delta: float) -> void:
	_knife_phase += delta * TAU / HIT_INTERVAL
	_hit_timer -= delta
	if _hit_timer <= 0.0:
		_hit_timer = HIT_INTERVAL
		Sound.play("chop", -3.0, randf_range(0.92, 1.1))
		Fx.burst(self, _item_center(), slot.color.lightened(0.15), 5, 75.0, 0.4)


# Нарезано: колокольчик и искорки
func _on_step_finished(_item: FoodItem) -> void:
	Sound.play("done", -6.0)
	Fx.burst(self, _item_center(), Color("fff3a0"), 10, 100.0, 0.55, 180.0)


func _item_center() -> Vector2:
	return Vector2(_visual_size.x / 2.0, _visual_size.y / 2.0 + 8.0)


# Полоска прогресса (из WorkStation) и качающийся нож поверх продукта
func _draw_extra() -> void:
	super._draw_extra()
	if not is_working():
		return
	var swing := absf(sin(_knife_phase / 2.0))   # от 0 до 1
	var pivot := _item_center() + Vector2(30.0, -8.0)
	draw_set_transform(pivot, -0.95 + swing * 0.95, Vector2.ONE)
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, -5), Vector2(-36, -2), Vector2(-39, 5), Vector2(0, 5)
	]), Color("e6ebf2"))
	draw_polyline(PackedVector2Array([Vector2(0, -5), Vector2(-36, -2), Vector2(-39, 5), Vector2(0, 5)]),
			Color("7b8794"), 1.5)
	draw_rect(Rect2(0, -5, 18, 10), Color("5b3a1e"))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
