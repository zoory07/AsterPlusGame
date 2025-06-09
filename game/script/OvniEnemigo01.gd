extends CharacterBody2D

@export var velocidad = 200.0
@export var intervalo_disparo = 2.0
@export var salud = 2  # Para que sea consistente con el daño de la munición del jugador
@export var danio_colision = 1  # Daño que causa al jugador al colisionar

# Variables para seguimiento
var puede_disparar = true
var timer_disparo = null
var direccion_inicial = Vector2.RIGHT
var explosion_en_progreso = false  # Para controlar si la animación de explosión está en curso

# Sistema de efectos de audio
var efectos_audio: Node = null

func _ready():
	# Buscar sistema de efectos de audio
	buscar_sistema_efectos()
	
	# Asegurarse de que está en el grupo correcto
	if not is_in_group("ovnis"):
		add_to_group("ovnis")
	
	# Añadir también al grupo de meteoritos para compatibilidad con el sistema de colisión existente
	if not is_in_group("meteorito"):
		add_to_group("meteorito")
	
	# Configurar capas de colisión para que la munición del player lo detecte
	set_collision_layer_value(1, false)  # No está en la capa 1 (jugador)
	set_collision_layer_value(2, true)   # Está en la capa 2 (meteoritos)
	
	# Crear el temporizador para los disparos
	timer_disparo = Timer.new()
	timer_disparo.wait_time = intervalo_disparo
	timer_disparo.one_shot = false
	timer_disparo.autostart = true
	timer_disparo.timeout.connect(_on_timer_disparo_timeout)
	add_child(timer_disparo)
	
	# Establecer una dirección aleatoria inicial
	var angulo_aleatorio = randf_range(0, 2 * PI)
	direccion_inicial = Vector2(cos(angulo_aleatorio), sin(angulo_aleatorio))
	rotation = angulo_aleatorio
	
	# Conectar la señal de finalización de animación si existe un AnimationPlayer
	var animation_player = get_node_or_null("AnimationPlayer")
	if animation_player:
		if not animation_player.is_connected("animation_finished", _on_animation_finished):
			animation_player.animation_finished.connect(_on_animation_finished)
		print("OVNI: AnimationPlayer conectado correctamente")
	else:
		print("OVNI: ADVERTENCIA - No se encontró AnimationPlayer")

func buscar_sistema_efectos():
	# Buscar el sistema de efectos de audio global
	efectos_audio = get_tree().get_first_node_in_group("efecto_audio")
	
	if not efectos_audio:
		# Buscar por Autoload si está configurado
		if has_node("/root/EfectoAudio"):
			efectos_audio = get_node("/root/EfectoAudio")
			print("OVNI: Sistema de efectos encontrado como Autoload")
		else:
			print("OVNI: No se encontró sistema de efectos global")
	else:
		print("OVNI: Sistema de efectos encontrado por grupo")

# Función segura para reproducir sonido de explosión
func reproducir_sonido_explosion():
	if efectos_audio and efectos_audio.has_method("reproducir_explosion_enemigo"):
		efectos_audio.reproducir_explosion_enemigo(global_position)
	else:
		print("OVNI: No se pudo reproducir sonido de explosión")

func _physics_process(delta):
	# Si está ejecutando la animación de explosión, no procesar movimiento
	if explosion_en_progreso:
		return
		
	# Aplicar velocidad en la dirección inicial (sin cambios)
	velocity = direccion_inicial * velocidad
	
	# Mover el OVNI y detectar colisiones
	var colision = move_and_slide()
	
	# Verificar colisiones con el jugador
	for i in get_slide_collision_count():
		var colision_obj = get_slide_collision(i)
		var cuerpo_colisionado = colision_obj.get_collider()
		
		# Si colisiona con el jugador
		if cuerpo_colisionado != null and cuerpo_colisionado.is_in_group("jugador"):
			print("OVNI: Colisión con jugador detectada")
			
			# Llamar al método recibir_impacto del jugador para activar su sistema de daño
			# En lugar de aplicar daño directamente, dejamos que el sistema del jugador lo maneje
			if cuerpo_colisionado.has_method("recibir_impacto"):
				cuerpo_colisionado.recibir_impacto()
			
			# Reproducir animación de eliminado
			iniciar_explosion()
			return  # Salir del método después de iniciar la explosión
	
	# Auto-eliminación si está fuera de la pantalla
	var viewport_rect = get_viewport_rect().size
	if position.x < -100 or position.x > viewport_rect.x + 100 or position.y < -100 or position.y > viewport_rect.y + 100:
		queue_free()
	
	# Disparar si el temporizador lo permite

func _on_timer_disparo_timeout():
	puede_disparar = true

# Método para iniciar la animación de explosión
func iniciar_explosion():
	# Reproducir sonido de explosión de forma segura
	reproducir_sonido_explosion()
	
	if explosion_en_progreso:
		return  # Evitar llamadas múltiples
		
	print("OVNI: Iniciando explosión")
	explosion_en_progreso = true
	
	# Detener el movimiento
	velocity = Vector2.ZERO
	
	# Desactivar colisiones durante la animación para evitar daños múltiples
	set_collision_layer_value(1, false)
	set_collision_layer_value(2, false)
	set_collision_mask_value(1, false)
	
	# Obtener el AnimationPlayer
	var animation_player = get_node_or_null("AnimationPlayer")
	if animation_player and animation_player.has_animation("eliminado"):
		print("OVNI: Reproduciendo animación 'eliminado'")
		# Reproducir la animación de eliminado
		animation_player.play("eliminado")
	else:
		print("OVNI: Error - No se encontró la animación 'eliminado'")
		# Si no hay animación, crear una explosión visual simple
		crear_explosion_visual()
		# Destruir después de un momento
		await get_tree().create_timer(0.5).timeout
		call_deferred("destruir")

# Crear efecto visual de explosión si no hay animación
func crear_explosion_visual():
	var particulas = CPUParticles2D.new()
	particulas.emitting = true
	particulas.amount = 30
	particulas.lifetime = 0.8
	particulas.one_shot = true
	particulas.explosiveness = 1.0
	particulas.gravity = Vector2.ZERO
	particulas.initial_velocity_min = 50
	particulas.initial_velocity_max = 150
	particulas.color = Color(1, 0.5, 0, 1)
	get_parent().add_child(particulas)
	particulas.global_position = global_position
	
	# Auto-destruir partículas
	var timer_part = Timer.new()
	timer_part.wait_time = 2.0
	timer_part.one_shot = true
	timer_part.autostart = true
	timer_part.timeout.connect(func(): particulas.queue_free())
	particulas.add_child(timer_part)

# Método para ser destruido directamente - compatible con la munición del jugador
func destruir():
	print("¡OVNI destruido!")
	
	# Intentar usar los diferentes sistemas de puntuación en orden de prioridad
	var puntuacion = get_node_or_null("/root/Puntuacion")
	if puntuacion != null and puntuacion.has_method("sumar_puntos_asteroide"):
		# Usar nuestro sistema simple - considerar el OVNI como un asteroide grande
		puntuacion.sumar_puntos_asteroide("grande")
	else:
		var score_manager = get_node_or_null("/root/ScoreManager")
		if score_manager != null:
			# Usar ScoreManager - considerar el OVNI como un objeto grande
			score_manager.add_asteroid_points("large")
		else:
			var puntaje_manager = get_node_or_null("/root/PuntajeManager")
			if puntaje_manager != null:
				if puntaje_manager.has_method("destruir_objeto"):
					# Usar el sistema antiguo con tipo
					puntaje_manager.destruir_objeto("ovni")
				else:
					# Usar el sistema básico
					puntaje_manager.sumar_puntos()
	
	# Eliminar del grupo antes de destruirse
	remove_from_group("ovnis")
	remove_from_group("meteorito")
	
	# Destruir el OVNI
	queue_free()

# Manejador de evento para cuando finaliza la animación
func _on_animation_finished(anim_name):
	if anim_name == "eliminado":
		print("OVNI: Animación de explosión completada")
		call_deferred("destruir")

# Método alternativo para recibir daño - compatible con la munición del jugador
func recibir_danio(cantidad):
	if explosion_en_progreso:
		return  # No recibir daño si ya está explotando
		
	salud -= cantidad
	print("OVNI: Recibió " + str(cantidad) + " de daño. Salud restante: " + str(salud))
	
	if salud <= 0 and not explosion_en_progreso:
		iniciar_explosion()  # Iniciar explosión al ser destruido por disparos
