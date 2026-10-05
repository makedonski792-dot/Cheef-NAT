class_name Sound
extends RefCounted
# Короткий путь к звукам для любого скрипта: Sound.play("chop").
# Менеджер звуков (автозагрузка Sfx) ищется в момент вызова, поэтому
# этот класс можно безопасно использовать из любых скриптов и тестов.


static func _manager() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null("Sfx")


static func play(sound_name: String, volume_db := 0.0, pitch := 1.0) -> void:
	var manager := _manager()
	if manager != null:
		manager.play(sound_name, volume_db, pitch)


static func set_loop(sound_name: String, active: bool) -> void:
	var manager := _manager()
	if manager != null:
		manager.set_loop(sound_name, active)


static func stop_loops() -> void:
	var manager := _manager()
	if manager != null:
		manager.stop_loops()


static func set_enabled(enabled: bool) -> void:
	var manager := _manager()
	if manager != null:
		manager.set_enabled(enabled)
