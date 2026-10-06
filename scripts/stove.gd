class_name Stove
extends WorkStation
# Плита: готовит продукт сама, повар может отойти. Но если забыть, всё сгорит!
# Анимация: конфорка светится, идёт пар. Перед пригоранием мигает красным,
# пищит и дымит. Когда сгорело, чёрный дым.

const COOK_SECONDS := 3.5   # до готовности
const BURN_SECONDS := 6.0   # от готовности до пригорания
const WARNING_SECONDS := 2.5   # за сколько секунд до пригорания начинается тревога

var _steam: CPUParticles2D
var _smoke: CPUParticles2D
var _alarm_timer := 0.0


func setup(r: Rect2, color: Color, label: String, solid := true) -> void:
	super.setup(r, color, label, solid)
	var center := Vector2(r.size.x / 2.0, r.size.y / 2.0 + 4.0)
	_steam = Fx.make_steam(Color(0.97, 0.98, 1.0, 0.9), 12)
	_steam.position = center
	add_child(_steam)
	_smoke = Fx.make_steam(Color(0.12, 0.12, 0.14, 0.9), 16)
	_smoke.position = center
	add_child(_smoke)


# Принимает то, что можно греть. Если продукт режется (лук, багет…),
# его сначала надо нарезать. Если не режется (масло, бульон), годится сырой.
func accepts(item: FoodItem) -> bool:
	if not item.can("heat"):
		return false
	return item.state == "chopped" or (item.state == "raw" and not item.can("chop"))


# Почему на плите это не готовится
func reject_reason(item: FoodItem) -> String:
	if accepts(item):
		return ""
	if not item.can("heat"):
		return "%s нельзя готовить на плите" % item.name
	if item.state == "raw" and item.can("chop"):
		return "сначала нарежь %s на Доске" % item.name.to_lower()
	if item.state == "burnt":
		return "%s сгорело, выбрось в мусорку" % item.name
	return "%s уже готово" % item.name


func step_duration(item: FoodItem) -> float:
	match item.state:
		"raw", "chopped":
			return COOK_SECONDS
		"cooked":
			return BURN_SECONDS
	return 0.0


func advance(item: FoodItem) -> void:
	if item.state == "cooked":
		item.state = "burnt"
	else:
		item.state = "cooked"


# Оранжевая полоска — готовится, красная — вот-вот сгорит
func bar_color(item: FoodItem) -> Color:
	return Color("ef4444") if item.state == "cooked" else Color("f59e0b")


# Скоро сгорит: готовое лежит на плите слишком долго
func _is_about_to_burn() -> bool:
	return slot != null and slot.state == "cooked" and BURN_SECONDS - progress < WARNING_SECONDS


func _on_work(delta: float) -> void:
	if _is_about_to_burn():
		_alarm_timer -= delta
		if _alarm_timer <= 0.0:
			_alarm_timer = 0.7
			Sound.play("alarm", -4.0)


func _on_step_finished(item: FoodItem) -> void:
	_alarm_timer = 0.0
	if item.state == "cooked":
		Sound.play("done", -6.0)
		Fx.burst(self, _steam.position, Color("fff3a0"), 8, 80.0, 0.5, 120.0)
	elif item.state == "burnt":
		Sound.play("burnt", -3.0)


func _process(delta: float) -> void:
	super._process(delta)
	# Пар идёт, пока готовится. Дым — когда вот-вот сгорит или уже сгорело.
	var smoking := slot != null and (slot.state == "burnt" or _is_about_to_burn())
	_steam.emitting = is_working() and not smoking
	_smoke.emitting = smoking
	if is_working() or smoking:
		queue_redraw()


# Полоска прогресса, свечение конфорок и красное мигание перед пригоранием
func _draw_extra() -> void:
	super._draw_extra()
	var scale_k := Vector2(_visual_size.x / 120.0, _visual_size.y / 70.0)
	if is_working() or (slot != null and slot.state == "burnt"):
		var heat := 0.55 + 0.35 * sin(Time.get_ticks_msec() / 130.0)
		var color := Color(1.0, 0.4, 0.1, heat)
		if _is_about_to_burn() and int(Time.get_ticks_msec() / 160.0) % 2 == 0:
			color = Color(1.0, 0.1, 0.1, 0.95)
		for burner in [Vector2(33, 28), Vector2(87, 28)]:
			draw_arc(burner * scale_k, 19.0, 0.0, TAU, 32, color, 4.0)
			draw_arc(burner * scale_k, 11.0, 0.0, TAU, 32, Color(color, color.a * 0.7), 3.0)
