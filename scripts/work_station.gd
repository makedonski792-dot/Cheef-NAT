class_name WorkStation
extends Station
# Станция, которая обрабатывает один предмет со временем (доска, плита, духовка).
# Кладёшь предмет, он «работает» по таймеру, забираешь результат.
# Наследники задают: что принимают, сколько длится этап и что происходит в конце.

# Повар должен стоять рядом, чтобы работа шла (как нарезка в Overcooked)
const NEAR := Chef.RADIUS + 24.0

var worker: Chef          # повар (его подключает кухня)
var requires_chef := false
var slot: FoodItem = null
var progress := 0.0       # сколько секунд идёт текущий этап

var _view: ItemView


func setup(r: Rect2, color: Color, label: String, solid := true) -> void:
	super.setup(r, color, label, solid)
	_view = ItemView.new()
	_view.position = r.size / 2.0 + Vector2(0, 8)
	add_child(_view)


# ----- Что переопределяют наследники -----

# Принимает ли станция этот предмет
func accepts(_item: FoodItem) -> bool:
	return false


# Сколько секунд длится следующий этап (0 — дальше делать нечего)
func step_duration(_item: FoodItem) -> float:
	return 0.0


# Что происходит с предметом, когда этап закончился
func advance(_item: FoodItem) -> void:
	pass


# Цвет полоски прогресса
func bar_color(_item: FoodItem) -> Color:
	return Color("4ade80")


# ----- Общая логика -----

func verb(chef: Chef) -> String:
	if chef.held != null and slot == null and accepts(chef.held):
		return "Положить"
	if chef.held == null and slot != null:
		return "Взять"
	return ""


func target_name(chef: Chef) -> String:
	if chef.held != null:
		return chef.held.display_name()
	return slot.display_name() if slot != null else _label


func interact(chef: Chef) -> void:
	if chef.held != null and slot == null and accepts(chef.held):
		slot = chef.drop()
		progress = 0.0
		_view.set_item(slot)
	elif chef.held == null and slot != null:
		chef.hold(slot)
		slot = null
		progress = 0.0
		_view.set_item(null)
	queue_redraw()


func _process(delta: float) -> void:
	tick(delta)


# Продвинуть работу на delta секунд (тесты вызывают это напрямую)
func tick(delta: float) -> void:
	if slot == null:
		return
	var duration := step_duration(slot)
	if duration <= 0.0:
		return
	if requires_chef and (worker == null or distance_to(worker.position) > NEAR):
		return
	progress += delta
	if progress >= duration:
		progress = 0.0
		advance(slot)
		_view.set_item(slot)
	queue_redraw()


# Полоска прогресса над станцией
func _draw_extra() -> void:
	if slot == null:
		return
	var bar := Rect2(0, -12, _visual_size.x, 8)
	draw_rect(bar, Color("1f2937"))
	var duration := step_duration(slot)
	var ratio := 1.0 if duration <= 0.0 else clampf(progress / duration, 0.0, 1.0)
	var color := Color("ef4444") if slot.state == "burnt" else bar_color(slot)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * ratio, bar.size.y)), color)
	draw_rect(bar, Color("3b2a1a"), false, 1.5)
