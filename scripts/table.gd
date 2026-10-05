class_name Table
extends Station
# Стол: на него можно положить один предмет и забрать обратно.

var slot: FoodItem = null
var _view: ItemView


func setup(r: Rect2, color: Color, label: String, solid := true) -> void:
	super.setup(r, color, label, solid)
	_view = ItemView.new()
	_view.position = r.size / 2.0 + Vector2(0, 8)
	_view.label_offset = -74.0
	add_child(_view)


func verb(chef: Chef) -> String:
	if chef.held != null and slot == null:
		return "Положить"
	if chef.held == null and slot != null:
		return "Взять"
	return ""


func target_name(chef: Chef) -> String:
	if chef.held != null:
		return chef.held.display_name()
	return slot.display_name() if slot != null else _label


func interact(chef: Chef) -> void:
	if chef.held != null and slot == null:
		slot = chef.drop()
		_view.set_item(slot)
	elif chef.held == null and slot != null:
		chef.hold(slot)
		slot = null
		_view.set_item(null)
