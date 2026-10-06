class_name OrderBoard
extends RefCounted
# Поток заказов смены: гости приходят по одному, у каждого свой таймер терпения.
# Настройки берутся из файла смены (data/shifts/*.json).

signal order_added(order: Order)
signal order_expired(order: Order)   # гость ушёл, не дождавшись
signal order_removed(order: Order)   # заказ закрыт (подан или гость ушёл)

var orders: Array[Order] = []
var elapsed := 0.0                    # сколько секунд идёт смена
var auto_spawn := true                # тесты выключают случайные заказы

var _shift: Dictionary
var _menu: Array
var _next_spawn := 0.0
var _counter := 0
var _bag: Array = []                  # «мешок» рецептов: блюда выпадают по очереди, без долгих повторов
var _rng := RandomNumberGenerator.new()


func _init(shift: Dictionary, menu: Array) -> void:
	_shift = shift
	_menu = menu
	_rng.randomize()
	_next_spawn = float(shift.get("first_order_delay", 2.0))


func duration() -> float:
	return float(_shift.get("duration", 420.0))


# После этого момента новые гости не приходят (иначе блюдо не успеть приготовить)
func spawn_cutoff() -> float:
	return duration() - float(_shift.get("stop_orders_before", 110.0))


func max_orders() -> int:
	return int(_shift.get("max_orders", 3))


# Смена закончилась: время вышло или гостей больше не будет и все обслужены
func is_finished() -> bool:
	return elapsed >= duration() or (elapsed >= spawn_cutoff() and orders.is_empty())


# Продвинуть время: заказы теряют терпение, приходят новые гости
func update(delta: float) -> void:
	elapsed += delta
	for order in orders.duplicate():
		order.elapsed += delta
		if order.is_expired():
			orders.erase(order)
			order_expired.emit(order)
			order_removed.emit(order)

	if auto_spawn and elapsed >= _next_spawn and elapsed <= spawn_cutoff() and orders.size() < max_orders():
		add_order(_next_recipe())
		var interval: Array = _shift.get("order_interval", [55, 80])
		var wait := float(_shift.get("second_order_delay", 25.0)) if _counter == 1 \
				else _rng.randf_range(float(interval[0]), float(interval[1]))
		_next_spawn = elapsed + wait


# Добавить заказ на блюдо (тесты вызывают это напрямую). Если вариант не указан,
# он выбирается случайно: обычный заказывают чаще остальных.
func add_order(recipe: Dictionary, variant_id := "") -> Order:
	_counter += 1
	var patience := float(recipe.get("time_limit", 300.0)) * float(_shift.get("patience_scale", 1.0)) * Progress.patience_multiplier()
	var order := Order.new(_counter, recipe, patience, _pick_variant(recipe, variant_id))
	orders.append(order)
	order_added.emit(order)
	return order


# Заказ на это блюдо, который дольше всех ждёт (или null, если такого заказа нет).
# Если указан вариант, ищем заказ именно на него.
func find_for(recipe_id: String, variant_id := "") -> Order:
	for order in orders:
		if order.recipe["id"] == recipe_id and (variant_id == "" or order.variant.get("id", "") == variant_id):
			return order
	return null


func has_order(recipe_id: String, variant_id := "") -> bool:
	return find_for(recipe_id, variant_id) != null


# Выбрать вариант блюда для заказа
func _pick_variant(recipe: Dictionary, variant_id: String) -> Dictionary:
	var variants: Array = recipe["variants"]
	if variant_id != "":
		for variant in variants:
			if variant["id"] == variant_id:
				return variant
	# Обычный вариант (без бонуса) выпадает чаще, особенный реже
	var total := 0.0
	for variant in variants:
		total += 3.0 if int(variant.get("bonus", 0)) == 0 else 2.0
	var roll := _rng.randf() * total
	for variant in variants:
		roll -= 3.0 if int(variant.get("bonus", 0)) == 0 else 2.0
		if roll <= 0.0:
			return variant
	return variants[0]


# Заказ выполнен
func complete(order: Order) -> void:
	orders.erase(order)
	order_removed.emit(order)


func _next_recipe() -> Dictionary:
	if _bag.is_empty():
		_bag = _menu.duplicate()
		_bag.shuffle()
	return _bag.pop_back()
