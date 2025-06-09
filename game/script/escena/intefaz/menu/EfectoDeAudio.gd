extends Node

# Player sonido
@onready var municion = $municion_efecto
@onready var ImpulsoCoete = $Audio_impulso 
# Meteoritos y enemigo
@onready var EfectoExplocion = $explosion
@onready var EnemigoExplocion = $Explocion
@onready var explocionMini = $Explosion_Mini

# Bus de audio para efectos
const SFX_BUS = "SFX"

# Control de volumen base
var volumen_efectos: float = 1.0

# Para evitar saturación de sonidos
var sonidos_activos: Dictionary = {}
const MAX_SONIDOS_SIMULTANEOS = 10

func _ready():
	# Crear bus SFX si no existe
	var bus_index = AudioServer.get_bus_index(SFX_BUS)
	if bus_index == -1:
		_crear_bus_sfx()
	
	# Configurar todos los efectos
	_configurar_efectos()
	
	# Hacer este nodo accesible globalmente
	add_to_group("efecto_audio")

func _crear_bus_sfx():
	var bus_count = AudioServer.bus_count
	AudioServer.add_bus()
	AudioServer.set_bus_name(bus_count, SFX_BUS)
	AudioServer.set_bus_send(bus_count, "Master")
	print("Bus SFX creado")

func _configurar_efectos():
	var todos_efectos = [municion, ImpulsoCoete, EfectoExplocion, EnemigoExplocion, explocionMini]
	
	for efecto in todos_efectos:
		if efecto and efecto is AudioStreamPlayer2D:
			efecto.bus = SFX_BUS
			# Configurar propiedades comunes
			efecto.max_distance = 2000
			efecto.attenuation = 1.0
			
			# Conectar señal finished para limpiar
			if not efecto.finished.is_connected(_on_sonido_terminado):
				efecto.finished.connect(_on_sonido_terminado.bind(efecto))

# ===== FUNCIONES PÚBLICAS PARA PLAYER =====

func reproducir_disparo(posicion: Vector2):
	if not municion or not municion.stream:
		push_error("municion_efecto no tiene stream asignado")
		return
	
	if _puede_reproducir("disparo"):
		municion.global_position = posicion
		municion.pitch_scale = randf_range(0.9, 1.1)  # Variación sutil
		municion.play()
		_registrar_sonido("disparo", municion)

func activar_impulso(activar: bool, posicion: Vector2 = Vector2.ZERO):
	if not ImpulsoCoete or not ImpulsoCoete.stream:
		push_error("Audio_impulso no tiene stream asignado")
		return
	
	if activar:
		if not ImpulsoCoete.playing:
			ImpulsoCoete.global_position = posicion
			ImpulsoCoete.play()
			_registrar_sonido("impulso", ImpulsoCoete)
	else:
		if ImpulsoCoete.playing:
			# Fade out suave
			var tween = create_tween()
			tween.tween_property(ImpulsoCoete, "volume_db", -20, 0.2)
			tween.tween_callback(func(): 
				ImpulsoCoete.stop()
				ImpulsoCoete.volume_db = 0
			)

# ===== FUNCIONES PÚBLICAS PARA ENEMIGOS =====

func reproducir_explosion_enemigo(posicion: Vector2):
	if not EnemigoExplocion or not EnemigoExplocion.stream:
		push_error("Explocion no tiene stream asignado")
		return
	
	if _puede_reproducir("explosion_enemigo"):
		EnemigoExplocion.global_position = posicion
		EnemigoExplocion.pitch_scale = randf_range(0.85, 1.0)
		EnemigoExplocion.play()
		_registrar_sonido("explosion_enemigo", EnemigoExplocion)

func reproducir_disparo_enemigo(posicion: Vector2):
	# Reutilizar el efecto de munición con pitch diferente
	if not municion or not municion.stream:
		return
	
	if _puede_reproducir("disparo_enemigo"):
		# Crear una copia temporal para no interferir con el disparo del jugador
		var temp_audio = AudioStreamPlayer2D.new()
		temp_audio.stream = municion.stream
		temp_audio.bus = SFX_BUS
		temp_audio.global_position = posicion
		temp_audio.pitch_scale = 0.7  # Más grave para diferenciar
		temp_audio.max_distance = 2000
		add_child(temp_audio)
		temp_audio.play()
		temp_audio.finished.connect(func(): temp_audio.queue_free())
		_registrar_sonido("disparo_enemigo", temp_audio)

# ===== FUNCIONES PÚBLICAS PARA METEORITOS =====

func reproducir_explosion_meteorito(posicion: Vector2, tamaño: String = "normal"):
	var efecto_a_usar = null
	var pitch = 1.0
	var volumen = 0.0
	
	match tamaño:
		"mini":
			efecto_a_usar = explocionMini
			pitch = randf_range(1.2, 1.5)
			volumen = -3.0
		"grande":
			efecto_a_usar = EfectoExplocion
			pitch = randf_range(0.7, 0.85)
			volumen = 3.0
		_:  # normal
			efecto_a_usar = EfectoExplocion
			pitch = randf_range(0.9, 1.1)
			volumen = 0.0
	
	if not efecto_a_usar or not efecto_a_usar.stream:
		push_error("Efecto de explosión no tiene stream asignado")
		return
	
	if _puede_reproducir("explosion_" + tamaño):
		efecto_a_usar.global_position = posicion
		efecto_a_usar.pitch_scale = pitch
		efecto_a_usar.volume_db = volumen
		efecto_a_usar.play()
		_registrar_sonido("explosion_" + tamaño, efecto_a_usar)

func reproducir_impacto_meteorito(posicion: Vector2):
	# Sonido cuando un meteorito es golpeado pero no destruido
	if municion and municion.stream:
		var temp_audio = AudioStreamPlayer2D.new()
		temp_audio.stream = municion.stream
		temp_audio.bus = SFX_BUS
		temp_audio.global_position = posicion
		temp_audio.pitch_scale = 0.5  # Muy grave
		temp_audio.volume_db = -6  # Más suave
		temp_audio.max_distance = 1500
		add_child(temp_audio)
		temp_audio.play()
		temp_audio.finished.connect(func(): temp_audio.queue_free())

# ===== FUNCIONES DE UTILIDAD =====

func _puede_reproducir(tipo: String) -> bool:
	# Limitar sonidos del mismo tipo
	var cuenta = 0
	for key in sonidos_activos:
		if key.begins_with(tipo):
			cuenta += 1
	
	# Límites por tipo
	match tipo:
		"disparo":
			return cuenta < 3
		"explosion_enemigo", "explosion_mini", "explosion_normal", "explosion_grande":
			return cuenta < 2
		_:
			return cuenta < 5

func _registrar_sonido(tipo: String, audio_player):
	var id = tipo + "_" + str(Time.get_ticks_msec())
	sonidos_activos[id] = audio_player

func _on_sonido_terminado(audio_player):
	# Limpiar del registro
	for key in sonidos_activos:
		if sonidos_activos[key] == audio_player:
			sonidos_activos.erase(key)
			break

# ===== FUNCIONES ESPECIALES =====

func reproducir_alerta():
	if municion and municion.stream:
		for i in range(3):
			await get_tree().create_timer(0.15 * i).timeout
			municion.pitch_scale = 2.0
			municion.volume_db = -3
			municion.play()

func reproducir_power_up(posicion: Vector2):
	# Sonido especial para power-ups
	if municion and municion.stream:
		var temp_audio = AudioStreamPlayer2D.new()
		temp_audio.stream = municion.stream
		temp_audio.bus = SFX_BUS
		temp_audio.global_position = posicion
		temp_audio.pitch_scale = 1.5
		temp_audio.volume_db = 0
		add_child(temp_audio)
		
		# Efecto de pitch ascendente
		var tween = create_tween()
		tween.tween_property(temp_audio, "pitch_scale", 2.5, 0.5)
		temp_audio.play()
		temp_audio.finished.connect(func(): temp_audio.queue_free())

func detener_todos_los_efectos():
	ImpulsoCoete.stop()
	for key in sonidos_activos:
		if is_instance_valid(sonidos_activos[key]):
			sonidos_activos[key].stop()
	sonidos_activos.clear()

func pausar_efectos():
	get_tree().call_group("sfx_players", "set_stream_paused", true)
	for child in get_children():
		if child is AudioStreamPlayer2D:
			child.stream_paused = true

func reanudar_efectos():
	get_tree().call_group("sfx_players", "set_stream_paused", false)
	for child in get_children():
		if child is AudioStreamPlayer2D:
			child.stream_paused = false

# ===== CONFIGURACIÓN DE VOLUMEN (para conectar con UI) =====

func set_volumen_efectos(valor: float):
	volumen_efectos = clamp(valor, 0.0, 1.0)
	
	var bus_index = AudioServer.get_bus_index(SFX_BUS)
	if bus_index != -1:
		if valor <= 0:
			AudioServer.set_bus_volume_db(bus_index, -80.0)
			AudioServer.set_bus_mute(bus_index, true)
		else:
			AudioServer.set_bus_mute(bus_index, false)
			AudioServer.set_bus_volume_db(bus_index, linear_to_db(valor))

func get_volumen_efectos() -> float:
	return volumen_efectos
