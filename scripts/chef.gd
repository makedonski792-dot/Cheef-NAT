class_name Chef
extends CharacterBody2D
# Повар. Двигается стрелками на клавиатуре (для проверки на Mac)
# или экранным джойстиком (на телефоне). Стены его не пускают.
# Анимация: переваливается при ходьбе и «рубит» у доски (working).

const SPEED := 240.0
const RADIUS := 18.0
const WALK_BOB_SPEED := 14.0   # как быстро качается при ходьбе
const WORK_BOB_SPEED := 20.0   # как быстро «рубит» у доски

# Джойстик подключает кухня
var joystick: ScreenJoystick
# Куда смотрит повар (понадобится, чтобы брать предметы перед собой)
var facing := Vector2.DOWN

# Что повар держит в руках (null — руки пусты)
var held: FoodItem = null

# Кухня включает это, пока повар режет у доски (для анимации)
var working := false

var _held_view: ItemView
var _phase := 0.0          # фаза качания
var _moving := false


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
	Sound.play("pickup", -4.0, randf_range(0.95, 1.08))


# Отдать предмет из рук (возвращает его, руки становятся пустыми)
func drop() -> FoodItem:
	var item := held
	held = null
	_held_view.set_item(null)
	if item != null:
		Sound.play("drop", -4.0, randf_range(0.95, 1.05))
	return item


func _physics_process(delta: float) -> void:
	var direction := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if joystick != null and joystick.value != Vector2.ZERO:
		direction = joystick.value

	velocity = direction * SPEED
	move_and_slide()

	_moving = direction.length() > 0.1
	if _moving:
		facing = direction.normalized()

	# Анимация: качаемся, пока идём или рубим; в покое плавно возвращаемся в ровное положение
	if _moving or working:
		_phase += delta * (WORK_BOB_SPEED if working else WALK_BOB_SPEED)
		_held_view.position.y = -38.0 + sin(_phase) * 1.5
		queue_redraw()
	elif _phase != 0.0:
		_phase = 0.0
		_held_view.position.y = -38.0
		queue_redraw()


# Рисуем повара картинкой, повёрнутой туда, куда он смотрит.
# Если картинки нет, рисуем запасной кружок с точкой-направлением.
func _draw() -> void:
	# Тень под поваром
	draw_circle(Vector2(0, 4), RADIUS + 2.0, Color(0, 0, 0, 0.18))

	var wobble := 0.0
	var squash := 1.0
	var lunge := Vector2.ZERO
	if working:
		# Рубит: короткие рывки вперёд и лёгкое сжатие
		var hit := absf(sin(_phase))
		squash = 1.0 + 0.1 * hit
		lunge = facing * 3.0 * hit
	elif _moving:
		wobble = sin(_phase) * 0.08
		squash = 1.0 + 0.05 * sin(_phase * 2.0)

	var texture := Icons.kitchen("chef")
	if texture != null:
		draw_set_transform(lunge, facing.angle() + wobble, Vector2(squash, 2.0 - squash))
		draw_texture_rect(texture, Rect2(-30, -30, 60, 60), false)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		draw_circle(Vector2.ZERO, RADIUS, Color("f2f2f2"))
		draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 32, Color("5b3a1e"), 3.0)
		draw_circle(facing * 11.0, 5.0, Color("5b3a1e"))
