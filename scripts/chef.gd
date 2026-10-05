class_name Chef
extends CharacterBody2D
# Повар. Двигается стрелками на клавиатуре (для проверки на Mac)
# или экранным джойстиком (на телефоне). Стены его не пропускают.

const SPEED := 240.0
const RADIUS := 18.0

# Джойстик подключает кухня
var joystick: ScreenJoystick
# Куда смотрит повар (понадобится, чтобы брать предметы перед собой)
var facing := Vector2.DOWN

# Что повар держит в руках (null — руки пусты)
var held: FoodItem = null

var _held_view: ItemView


func _ready() -> void:
	# Круглая «коллизия» — граница, которой повар упирается в стены
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = RADIUS
	shape.shape = circle
	add_child(shape)

	# Предмет в руках рисуем над головой повара
	_held_view = ItemView.new()
	_held_view.position = Vector2(0, -38)
	add_child(_held_view)


# Взять предмет в руки
func hold(item: FoodItem) -> void:
	held = item
	_held_view.set_item(item)


# Отдать предмет из рук (возвращает его, руки становятся пустыми)
func drop() -> FoodItem:
	var item := held
	held = null
	_held_view.set_item(null)
	return item


func _physics_process(_delta: float) -> void:
	var direction := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if joystick != null and joystick.value != Vector2.ZERO:
		direction = joystick.value

	velocity = direction * SPEED
	move_and_slide()

	if direction.length() > 0.1:
		facing = direction.normalized()
		queue_redraw()


# Рисуем повара картинкой, повёрнутой туда, куда он смотрит.
# Если картинки нет, рисуем запасной кружок с точкой-направлением.
func _draw() -> void:
	# Тень под поваром
	draw_circle(Vector2(0, 4), RADIUS + 2.0, Color(0, 0, 0, 0.18))
	var texture := Icons.kitchen("chef")
	if texture != null:
		draw_set_transform(Vector2.ZERO, facing.angle(), Vector2.ONE)
		draw_texture_rect(texture, Rect2(-30, -30, 60, 60), false)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		draw_circle(Vector2.ZERO, RADIUS, Color("f2f2f2"))
		draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 32, Color("5b3a1e"), 3.0)
		draw_circle(facing * 11.0, 5.0, Color("5b3a1e"))
