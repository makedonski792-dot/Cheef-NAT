extends Node2D
# Кухня, как в Overcooked: вид сверху, повар бегает между столами.
# Размер кухни 960x540 (горизонтальный экран).

const KITCHEN_SIZE := Vector2(960, 540)

var chef: Chef
var joystick: ScreenJoystick


func _ready() -> void:
	_build_floor_and_walls()

	# Повар
	chef = Chef.new()
	chef.position = Vector2(480, 400)
	chef.z_index = 10
	add_child(chef)

	_build_interface()


# Пол, стены и столы. Всё, что рисуем как блок, ещё и не пускает повара.
func _build_floor_and_walls() -> void:
	# Огромный тёмный фон (виден, если экран шире кухни) и сам пол
	_add_floor(Rect2(-2000, -2000, 5000, 5000), Color("2b2018"))
	_add_floor(Rect2(Vector2.ZERO, KITCHEN_SIZE), Color("e9dcc0"))

	var wall_color := Color("5b3a1e")
	var counter_color := Color("b08a5a")
	_add_block(Rect2(0, 0, 960, 70), counter_color)       # длинный стол у верхней стены
	_add_block(Rect2(0, 520, 960, 20), wall_color)        # нижняя стена
	_add_block(Rect2(0, 0, 20, 540), wall_color)          # левая стена
	_add_block(Rect2(940, 0, 20, 540), wall_color)        # правая стена
	_add_block(Rect2(400, 240, 160, 70), counter_color)   # остров посередине


func _add_floor(rect: Rect2, color: Color) -> void:
	var floor_rect := ColorRect.new()
	floor_rect.position = rect.position
	floor_rect.size = rect.size
	floor_rect.color = color
	add_child(floor_rect)


# Блок с видимой картинкой и твёрдой коллизией
func _add_block(rect: Rect2, color: Color) -> void:
	var body := StaticBody2D.new()
	body.position = rect.position
	add_child(body)

	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = rect.size
	shape.shape = rectangle
	shape.position = rect.size / 2.0
	body.add_child(shape)

	var picture := ColorRect.new()
	picture.size = rect.size
	picture.color = color
	body.add_child(picture)


# Экранный слой: заголовок, кнопка «Меню», джойстик
func _build_interface() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	var title := Label.new()
	title.text = "Кухня: %s" % GameState.current_recipe.get("name", "свободная игра")
	title.position = Vector2(30, 20)
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color("fff4dc"))
	layer.add_child(title)

	var menu_button := Button.new()
	menu_button.text = "Меню"
	menu_button.custom_minimum_size = Vector2(110, 44)
	menu_button.anchor_left = 1.0
	menu_button.anchor_right = 1.0
	menu_button.offset_left = -130
	menu_button.offset_right = -20
	menu_button.offset_top = 14
	menu_button.pressed.connect(_on_menu_pressed)
	layer.add_child(menu_button)

	joystick = ScreenJoystick.new()
	layer.add_child(joystick)
	chef.joystick = joystick


func _on_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
