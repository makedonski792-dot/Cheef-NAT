class_name KitchenFloor
extends Node2D
# Пол кухни: плитка по всей площади, а за её пределами тёмный фон
# (виден, если экран телефона шире кухни).

var size := Vector2(960, 540)
# Какой рисунок плитки использовать (из магазина)
var art_name := "floor_tile"


func _draw() -> void:
	draw_rect(Rect2(-2000, -2000, 5000, 5000), Color("2b2018"))
	var tile := Icons.kitchen(art_name)
	if tile == null:
		tile = Icons.kitchen("floor_tile")
	if tile != null:
		draw_texture_rect(tile, Rect2(Vector2.ZERO, size), true)
	else:
		draw_rect(Rect2(Vector2.ZERO, size), Color("e9dcc0"))
