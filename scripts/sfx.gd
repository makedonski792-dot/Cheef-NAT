extends Node
# Звуки игры. Автозагружаемый скрипт: доступен из любого места как Sfx.
#   Sfx.play("chop")                 — разовый звук
#   Sfx.set_loop("sizzle", true)     — включить/выключить зацикленный звук
# Файлы лежат в audio/ (создаются tools/make_sounds.py, можно заменить своими).

const SOUNDS := ["chop", "sizzle", "pickup", "drop", "add", "reject", "done", "alarm",
		"burnt", "serve_bell", "success", "fail", "ambient"]
# Зацикленные звуки и их громкость (дБ)
const LOOPS := {"sizzle": -9.0, "ambient": -17.0}
const SILENT_DB := -50.0
const POOL_SIZE := 8

# Состояние игры (ищем сами, чтобы скрипт не зависел от порядка загрузки автозагрузок)
var _state: Node

var _streams := {}
var _pool: Array[AudioStreamPlayer] = []
var _pool_index := 0
var _loop_players := {}
var _loop_wanted := {}


func _ready() -> void:
	# Звуки должны играть и на паузе (например, мелодия в конце заказа)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_state = get_node("/root/GameState")

	for sound_name in SOUNDS:
		var path := "res://audio/%s.wav" % sound_name
		if not ResourceLoader.exists(path):
			continue
		var stream: AudioStreamWAV = load(path)
		if LOOPS.has(sound_name):
			stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
			stream.loop_begin = 0
			stream.loop_end = _sample_count(stream)
		_streams[sound_name] = stream

	for i in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_pool.append(player)


# Сколько отсчётов в WAV (для границы петли). Считаем по длине звука,
# чтобы не зависеть от формата (сжатый или нет).
func _sample_count(stream: AudioStreamWAV) -> int:
	return int(round(stream.get_length() * stream.mix_rate))


# Проиграть звук один раз. pitch — высота (1.0 = обычная), чтобы повторы не надоедали.
func play(sound_name: String, volume_db := 0.0, pitch := 1.0) -> void:
	if not _state.sound_enabled or not _streams.has(sound_name):
		return
	var player := _pool[_pool_index]
	_pool_index = (_pool_index + 1) % _pool.size()
	player.stream = _streams[sound_name]
	player.volume_db = volume_db
	player.pitch_scale = pitch
	player.play()


# Включить или выключить зацикленный звук (плавно). Можно вызывать каждый кадр.
func set_loop(sound_name: String, active: bool) -> void:
	active = active and _state.sound_enabled and _streams.has(sound_name)
	if _loop_wanted.get(sound_name, false) == active:
		return
	_loop_wanted[sound_name] = active

	var player: AudioStreamPlayer = _loop_players.get(sound_name)
	if player == null:
		player = AudioStreamPlayer.new()
		player.stream = _streams[sound_name]
		add_child(player)
		_loop_players[sound_name] = player

	var tween := create_tween()
	if active:
		player.volume_db = SILENT_DB
		player.play()
		tween.tween_property(player, "volume_db", LOOPS[sound_name], 0.3)
	else:
		tween.tween_property(player, "volume_db", SILENT_DB, 0.25)
		tween.tween_callback(player.stop)


# Выключить все зацикленные звуки сразу (при выходе с кухни и в конце заказа)
func stop_loops() -> void:
	for sound_name in _loop_players:
		_loop_wanted[sound_name] = false
		_loop_players[sound_name].stop()


# Включить или выключить звук в игре (запоминается в сохранении)
func set_enabled(enabled: bool) -> void:
	_state.sound_enabled = enabled
	_state.save_game()
	if not enabled:
		stop_loops()
		for player in _pool:
			player.stop()
