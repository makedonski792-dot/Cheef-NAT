extends Control
# Мастерская: покупка интерьера, ножей и костюмов за монеты и прокачка навыков повара.

const INK := Color("3b2a1a")
# Вкладки: [id категории или "skills", название]
const TABS := [["floor", "Пол"], ["wall", "Стены"], ["table", "Столы"],
		["knife", "Ножи"], ["costume", "Костюмы"], ["skills", "Навыки"]]

var _tab := "floor"
var _list: VBoxContainer
var _coins_label: Label
var _level_label: Label
var _xp_bar: ProgressBar
var _points_label: Label
var _message: Label
var _tab_buttons := {}


func _ready() -> void:
	var background := ColorRect.new()
	background.color = Color("f5ecd9")
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	margin.add_child(root)

	root.add_child(_build_header())

	var main := HBoxContainer.new()
	main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_theme_constant_override("separation", 12)
	root.add_child(main)

	main.add_child(_build_tabs())

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 4)
	main.add_child(right)

	_message = _label("", 16, Color("8a3b00"))
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	right.add_child(_message)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(scroll)

	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_list)

	var back := Button.new()
	back.text = "Назад в меню"
	back.custom_minimum_size = Vector2(0, 44)
	back.add_theme_font_size_override("font_size", 20)
	back.pressed.connect(_on_back_pressed)
	root.add_child(back)

	_show_tab("floor")


# ---------- Верхняя панель ----------

func _build_header() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)

	var title := _label("Мастерская", 32, INK)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.add_child(title)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	_coins_label = _label("", 24, Color("8a5a00"))
	row.add_child(_coins_label)

	var level_box := VBoxContainer.new()
	level_box.add_theme_constant_override("separation", 0)
	_level_label = _label("", 16, INK)
	level_box.add_child(_level_label)
	_xp_bar = ProgressBar.new()
	_xp_bar.custom_minimum_size = Vector2(190, 12)
	_xp_bar.show_percentage = false
	level_box.add_child(_xp_bar)
	_points_label = _label("", 14, Color("1b5e20"))
	level_box.add_child(_points_label)
	row.add_child(level_box)
	return row


func _refresh_header() -> void:
	_coins_label.text = "Монеты: %d" % GameState.coins
	var level := GameState.chef_level()
	_level_label.text = "Повар: уровень %d" % level
	if level >= Skills.MAX_LEVEL:
		_xp_bar.max_value = 1.0
		_xp_bar.value = 1.0
		_points_label.text = "Максимум! Очков: %d" % GameState.skill_points()
	else:
		var start := Skills.xp_for_level(level)
		var end := Skills.xp_for_level(level + 1)
		_xp_bar.max_value = float(end - start)
		_xp_bar.value = float(GameState.xp - start)
		_points_label.text = "Опыт %d/%d · очков: %d" % [GameState.xp, end, GameState.skill_points()]


# ---------- Вкладки ----------

func _build_tabs() -> Control:
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(150, 0)
	column.add_theme_constant_override("separation", 6)
	var group := ButtonGroup.new()
	for tab in TABS:
		var button := Button.new()
		button.text = tab[1]
		button.toggle_mode = true
		button.button_group = group
		button.custom_minimum_size = Vector2(150, 46)
		button.add_theme_font_size_override("font_size", 20)
		var selected := StyleBoxFlat.new()
		selected.bg_color = Color("e08a1e")
		selected.set_corner_radius_all(4)
		for style_name in ["pressed", "hover_pressed"]:
			button.add_theme_stylebox_override(style_name, selected)
		button.add_theme_color_override("font_pressed_color", Color.WHITE)
		button.add_theme_color_override("font_hover_pressed_color", Color.WHITE)
		button.pressed.connect(_show_tab.bind(tab[0]))
		column.add_child(button)
		_tab_buttons[tab[0]] = button
	return column


func _show_tab(tab_id: String) -> void:
	_tab = tab_id
	if _tab_buttons.has(tab_id):
		_tab_buttons[tab_id].button_pressed = true
	_refresh_header()
	for child in _list.get_children():
		child.queue_free()
	if tab_id == "skills":
		_build_skills()
	else:
		for item in ShopCatalog.items(tab_id):
			_list.add_child(_item_card(tab_id, item))


# ---------- Предметы ----------

func _item_card(category_id: String, item: Dictionary) -> Control:
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.8)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(8)
	card.add_theme_stylebox_override("panel", style)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)

	row.add_child(_preview(category_id, item))

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 0)
	var name_label := _label(item["name"], 20, INK)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	info.add_child(name_label)
	var desc := _label(item.get("desc", ""), 14, Color("5b4a3a"))
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	info.add_child(desc)
	row.add_child(info)

	row.add_child(_action_button(item))
	return card


# Картинка предмета: рисунок пола, стены, стола, костюм или цвет лезвия ножа
func _preview(category_id: String, item: Dictionary) -> Control:
	var holder := CenterContainer.new()
	holder.custom_minimum_size = Vector2(110, 56)
	if category_id == "knife":
		var blade := ColorRect.new()
		blade.color = Color(String(item.get("blade", "#e6ebf2")))
		blade.custom_minimum_size = Vector2(90, 16)
		holder.add_child(blade)
		return holder
	var texture := Icons.kitchen(String(item.get("art", "")))
	if texture != null:
		var picture := TextureRect.new()
		picture.texture = texture
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_SCALE
		picture.custom_minimum_size = Vector2(52, 52) if category_id in ["floor", "wall", "costume"] else Vector2(100, 44)
		holder.add_child(picture)
	return holder


# Кнопка карточки: Купить, Надеть или Надето
func _action_button(item: Dictionary) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(170, 48)
	button.add_theme_font_size_override("font_size", 18)
	var item_id: String = item["id"]
	if GameState.owns(item_id):
		if GameState.equipped.get(item["category"] if item.has("category") else _tab, "") == item_id:
			button.text = "Надето"
			button.disabled = true
		else:
			button.text = "Надеть"
			button.pressed.connect(_on_equip.bind(item_id))
	else:
		var problem := GameState.buy_problem(item_id)
		var price := int(item.get("price", 0))
		if GameState.chef_level() < int(item.get("level", 1)):
			button.text = "С уровня %d" % int(item.get("level", 1))
			button.disabled = true
		else:
			button.text = "Купить за %d" % price
			button.disabled = problem != ""
			button.pressed.connect(_on_buy.bind(item_id))
	return button


func _on_buy(item_id: String) -> void:
	var item := ShopCatalog.find(item_id)
	if GameState.buy(item_id):
		GameState.equip(item_id)
		Sound.play("add")
		_message.text = "Куплено и надето: %s" % item["name"]
	else:
		_message.text = "Нельзя купить: %s" % GameState.buy_problem(item_id)
	_show_tab(_tab)


func _on_equip(item_id: String) -> void:
	if GameState.equip(item_id):
		Sound.play("pickup")
		_message.text = "Надето: %s" % ShopCatalog.find(item_id)["name"]
	_show_tab(_tab)


# ---------- Навыки ----------

func _build_skills() -> void:
	var points := GameState.skill_points()
	_message.text = "Свободных очков навыков: %d (улучшение стоит 1 очко, новое очко даёт каждый уровень)" % points
	for skill_id in Skills.ORDER:
		_list.add_child(_skill_card(skill_id))


func _skill_card(skill_id: String) -> Control:
	var skill: Dictionary = Skills.LIST[skill_id]
	var level := int(GameState.skills.get(skill_id, 0))

	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.8)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(8)
	card.add_theme_stylebox_override("panel", style)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 0)
	info.custom_minimum_size = Vector2(120, 0)
	var name_label := _label(skill["name"], 20, INK)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	info.add_child(name_label)
	var bonus := int(round(float(skill["per_level"]) * level * 100.0))
	var desc := _label("%s. Сейчас: +%d%%" % [skill["desc"], bonus], 14, Color("5b4a3a"))
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(120, 0)
	info.add_child(desc)
	row.add_child(info)

	# Пять квадратиков: сколько уровней уже получено
	var pips := HBoxContainer.new()
	pips.add_theme_constant_override("separation", 4)
	for i in Skills.MAX_SKILL:
		var pip := ColorRect.new()
		pip.custom_minimum_size = Vector2(20, 20)
		pip.color = Color("e08a1e") if i < level else Color("cfc5b0")
		pips.add_child(pip)
	row.add_child(pips)

	var button := Button.new()
	button.custom_minimum_size = Vector2(130, 48)
	button.add_theme_font_size_override("font_size", 18)
	button.tooltip_text = "Стоит 1 очко навыка"
	if level >= Skills.MAX_SKILL:
		button.text = "Максимум"
		button.disabled = true
	else:
		button.text = "Улучшить"
		button.disabled = GameState.skill_points() <= 0
		button.pressed.connect(_on_upgrade.bind(skill_id))
	row.add_child(button)
	return card


func _on_upgrade(skill_id: String) -> void:
	if GameState.upgrade_skill(skill_id):
		Sound.play("done", -4.0)
		_message.text = "Навык улучшен: %s" % Skills.LIST[skill_id]["name"]
	_show_tab("skills")


func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
