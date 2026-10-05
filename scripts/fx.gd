class_name Fx
extends RefCounted
# Визуальные эффекты: фейерверк брызг, пар, дым. Всё на простых частицах.

static var _soft_texture: Texture2D


# Мягкое светящееся пятно (круглая текстура с прозрачным краем)
static func soft_texture() -> Texture2D:
	if _soft_texture == null:
		# Плотная середина и мягкий прозрачный край
		var gradient := Gradient.new()
		gradient.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
		gradient.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.8), Color(1, 1, 1, 0)])
		var texture := GradientTexture2D.new()
		texture.gradient = gradient
		texture.fill = GradientTexture2D.FILL_RADIAL
		texture.fill_from = Vector2(0.5, 0.5)
		texture.fill_to = Vector2(1.0, 0.5)
		texture.width = 32
		texture.height = 32
		_soft_texture = texture
	return _soft_texture


# Градиент «виден в начале, исчезает к концу жизни частицы»
static func _fade_ramp() -> Gradient:
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 1))
	ramp.set_color(1, Color(1, 1, 1, 0))
	return ramp


# Разовый всплеск частиц (кусочки при нарезке, искры, конфетти).
# Частицы сами удаляются, когда заканчивают лететь.
static func burst(parent: Node, position: Vector2, color: Color, amount := 8,
		speed := 90.0, lifetime := 0.5, spread := 70.0) -> void:
	var particles := CPUParticles2D.new()
	particles.position = position
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = amount
	particles.lifetime = lifetime
	particles.direction = Vector2(0, -1)
	particles.spread = spread
	particles.initial_velocity_min = speed * 0.5
	particles.initial_velocity_max = speed
	particles.gravity = Vector2(0, 260)
	particles.texture = soft_texture()
	particles.scale_amount_min = 0.3
	particles.scale_amount_max = 0.6
	particles.color = color
	particles.color_ramp = _fade_ramp()
	particles.z_index = 20
	# Частицы продолжают лететь, даже когда игра на паузе (конфетти за итоговым окном)
	particles.process_mode = Node.PROCESS_MODE_ALWAYS
	parent.add_child(particles)
	particles.emitting = true
	particles.finished.connect(particles.queue_free)


# Непрерывный пар или дым: включается и выключается через emitting
static func make_steam(color := Color(1, 1, 1, 0.5), amount := 10) -> CPUParticles2D:
	var particles := CPUParticles2D.new()
	particles.emitting = false
	particles.amount = amount
	particles.lifetime = 1.6
	particles.direction = Vector2(0, -1)
	particles.spread = 20.0
	particles.initial_velocity_min = 20.0
	particles.initial_velocity_max = 38.0
	particles.gravity = Vector2(0, -6)
	particles.texture = soft_texture()
	particles.scale_amount_min = 0.7
	particles.scale_amount_max = 1.3
	particles.color = color
	particles.color_ramp = _fade_ramp()
	particles.z_index = 15
	return particles
