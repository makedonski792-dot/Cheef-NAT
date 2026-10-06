extends Control
# Перенос прогресса: сохранить его в виде кода (скопировать) и загрузить обратно.
# Нужно, если игру пришлось удалить и поставить заново, или при смене телефона.

const INK := Color("3b2a1a")

var _export_box: TextEdit
var _import_box: TextEdit
var _message: Label
var _confirm_button: Button
var _pending_data: Dictionary = {}   # проверенный код, ждущий подтверждения


func _ready() -> void:
	var background := ColorRect.new()
	background.color = Color("f5ecd9")
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	margin.add_child(root)

	root.add_child(_label("Перенос прогресса", 32, INK))
	var hint := _label("Код хранит монеты, день, опыт, покупки и навыки. Сохрани его в заметки или отправь себе, и после переустановки игры прогресс вернётся.", 15, Color("5b4a3a"))
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(hint)

	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 20)
	root.add_child(columns)

	columns.add_child(_build_export_column())
	columns.add_child(_build_import_column())

	_message = _label("", 17, Color("8a3b00"))
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_message)

	var back := Button.new()
	back.text = "Назад в меню"
	back.custom_minimum_size = Vector2(0, 44)
	back.add_theme_font_size_override("font_size", 20)
	back.pressed.connect(_on_back_pressed)
	root.add_child(back)


# ---------- Сохранить: скопировать код ----------

func _build_export_column() -> Control:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 6)
	column.add_child(_label("1. Сохранить прогресс", 22, INK))

	_export_box = TextEdit.new()
	_export_box.editable = false
	_export_box.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_export_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_export_box.text = GameState.export_code()
	column.add_child(_export_box)

	var copy := _button("Скопировать код")
	copy.pressed.connect(_on_copy_pressed)
	column.add_child(copy)
	return column


# ---------- Загрузить: вставить код ----------

func _build_import_column() -> Control:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 6)
	column.add_child(_label("2. Загрузить прогресс", 22, INK))

	_import_box = TextEdit.new()
	_import_box.placeholder_text = "Вставь сюда код (долгое нажатие → «Вставить»)"
	_import_box.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_import_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_import_box.text_changed.connect(_on_import_text_changed)
	column.add_child(_import_box)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	column.add_child(buttons)

	var paste := _button("Вставить из буфера")
	paste.pressed.connect(_on_paste_pressed)
	buttons.add_child(paste)

	var check := _button("Проверить код")
	check.pressed.connect(_on_check_pressed)
	buttons.add_child(check)

	_confirm_button = _button("Заменить мой прогресс этим")
	_confirm_button.visible = false
	_confirm_button.pressed.connect(_on_confirm_pressed)
	column.add_child(_confirm_button)
	return column


func _on_copy_pressed() -> void:
	DisplayServer.clipboard_set(_export_box.text)
	_message.text = "Код скопирован. Вставь его в заметки или отправь себе в сообщении."


func _on_paste_pressed() -> void:
	_import_box.text = DisplayServer.clipboard_get()
	_on_import_text_changed()
	if _import_box.text.strip_edges() == "":
		_message.text = "В буфере обмена ничего нет. Сначала скопируй код."
	else:
		_on_check_pressed()


# Если код поменяли, прежняя проверка уже не действует
func _on_import_text_changed() -> void:
	_pending_data = {}
	_confirm_button.visible = false


# Проверить код и показать, что в нём лежит
func _on_check_pressed() -> void:
	var result := ProgressCode.decode(_import_box.text)
	if not result["ok"]:
		_pending_data = {}
		_confirm_button.visible = false
		_message.text = result["error"]
		return
	_pending_data = result["data"]
	_confirm_button.visible = true
	_message.text = "Код верный: %s.\nТекущий прогресс (%s) будет заменён." % [
		ProgressCode.summary(_pending_data), ProgressCode.summary(GameState._save_data())
	]


func _on_confirm_pressed() -> void:
	if _pending_data.is_empty():
		return
	var error := GameState.import_code(_import_box.text)
	if error != "":
		_message.text = error
		return
	_pending_data = {}
	_confirm_button.visible = false
	_export_box.text = GameState.export_code()
	_message.text = "Готово! Прогресс загружен: %s." % ProgressCode.summary(GameState._save_data())
	Sound.play("success", -4.0)


func _button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 46)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 17)
	return button


func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
