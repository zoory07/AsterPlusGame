extends CharacterBody2D

# Variables de movimiento para replicar Asteroids
var rotation_speed = 5.0
var thrust_power = 5.0
var max_speed = 150.0
var friction = 0.99
var velocity_vector = Vector2.ZERO

# Variables para el sistema de disparo
@export var municio: PackedScene
@export var velocidad_disparo = 400.0
@export var tiempo_recarga = 0.3
var puede_disparar = true

# Sistema de efectos de audio
var efectos_audio: Node = null

# Variables para el sistema de vidas y colisiones
var sistema_vidas = null
var meteoritos_cercanos = []
var radio_colision = 25.0
var invulnerable = false

# Referencias a los nodos
var nave_sprite = null
var propulsor_sprite = null
var animation_player = null

# Estado del impulso
var impulso_activo = false

func _ready():
	print("NAVE: Iniciando...")
	
	# Obtener el sistema de efectos de audio
	_obtener_sistema_efectos()
	
	# Obtener referencias a nodos de forma segura
	nave_sprite = get_node_or_null("NaveSprite")
	propulsor_sprite = get_node_or_null("PropulsorSprite")
	if not propulsor_sprite:
		propulsor_sprite = get_node_or_null("a_cohete")
	animation_player = get_node_or_null("AnimationPlayer")
	
	# Verificar nodos críticos
	if not nave_sprite:
		print("NAVE: ADVERTENCIA - No se encontró el sprite de la nave")
	else:
		print("NAVE: Sprite de nave encontrado")
	
	# Inicializar propulsor si existe
	if nave_sprite and propulsor_sprite:
		posicionar_propulsor()
		propulsor_sprite.visible = false
	
	# Iniciar animación si existe
	if animation_player and animation_player.has_animation("RESET"):
		animation_player.play("RESET")
	
	# Crear timer para la recarga del disparo
	if not has_node("TimerDisparo"):
		var timer = Timer.new()
		timer.name = "TimerDisparo"
		timer.one_shot = true
		timer.wait_time = tiempo_recarga
		timer.connect("timeout", _on_timer_disparo_timeout)
		add_child(timer)
	
	# Buscar sistema de vidas
	buscar_sistema_vidas()
	
	# Agregar al grupo jugador
	add_to_group("jugador")
	
	# Timer para verificar colisiones periódicamente
	var timer_colision = Timer.new()
	timer_colision.name = "TimerColision"
	timer_colision.wait_time = 0.1
	timer_colision.autostart = true
	timer_colision.connect("timeout", _verificar_colisiones_por_distancia)
	add_child(timer_colision)
	
	print("NAVE: Inicialización completa")

func _obtener_sistema_efectos():
	# Buscar el sistema de efectos por grupo
	efectos_audio = get_tree().get_first_node_in_group("efecto_audio")
	
	# Si no lo encuentra por grupo, buscar por nombre
	if not efectos_audio:
		efectos_audio = get_node_or_null("/root/EfectoAudio")
	
	# Si aún no lo encuentra, buscar en el árbol
	if not efectos_audio:
		efectos_audio = get_tree().root.find_child("EfectoDeAudio", true, false)
	
	if efectos_audio:
		print("NAVE: Sistema de efectos de audio encontrado")
	else:
		print("NAVE: ADVERTENCIA - No se encontró el sistema de efectos de audio")

func buscar_sistema_vidas():
	# Intentar encontrar el sistema de vidas de diferentes maneras
	var sistemas = get_tree().get_nodes_in_group("sistema_vida")
	if sistemas.size() > 0:
		sistema_vidas = sistemas[0]
		print("NAVE: Sistema de vidas encontrado por grupo")
		return
	
	# Buscar por nombre de nodo
	sistema_vidas = get_node_or_null("/root/Vida")
	if sistema_vidas:
		print("NAVE: Sistema de vidas encontrado en /root/Vida")
		return
	
	# Buscar en todo el árbol
	sistema_vidas = get_tree().root.find_child("Vida", true, false)
	if sistema_vidas:
		print("NAVE: Sistema de vidas encontrado por búsqueda en árbol")
		return
	
	print("NAVE: No se pudo encontrar el sistema de vidas")

func posicionar_propulsor():
	if not nave_sprite or not propulsor_sprite:
		return
		
	var nave_height = 0
	if nave_sprite.texture:
		nave_height = nave_sprite.texture.get_height() * nave_sprite.scale.y / 2
	
	propulsor_sprite.position = Vector2(0, nave_height + 10)

func _physics_process(delta):
	# Manejo seguro de visibilidad durante invulnerabilidad
	if nave_sprite:
		if invulnerable:
			if Engine.get_frames_drawn() % 10 == 0:
				nave_sprite.visible = !nave_sprite.visible
		else:
			nave_sprite.visible = true
	
	# Rotación de la nave
	var rotation_dir = 0
	if Input.is_action_pressed("izquierda") or Input.is_action_pressed("a"):
		rotation_dir -= 1
	if Input.is_action_pressed("derecha") or Input.is_action_pressed("d"):
		rotation_dir += 1
	
	# Aplicar rotación
	rotation += rotation_dir * rotation_speed * delta
	
	# Empuje y propulsión
	if Input.is_action_pressed("ariba") or Input.is_action_pressed("w"):
		# Activar impulso usando el sistema de efectos
		if efectos_audio and not impulso_activo:
			efectos_audio.activar_impulso(true, global_position)
			impulso_activo = true
		
		# Manejo seguro de visibilidad del sprite de nave
		if nave_sprite and not invulnerable:
			nave_sprite.visible = true
		
		# Manejo seguro de animación
		if animation_player and animation_player.has_animation("a_cohete"):
			if not animation_player.is_playing() or animation_player.current_animation != "a_cohete":
				animation_player.play("a_cohete")
		
		var thrust_direction = Vector2(cos(rotation - PI/2), sin(rotation - PI/2))
		velocity_vector += thrust_direction * thrust_power
	else:
		# Desactivar impulso
		if efectos_audio and impulso_activo:
			efectos_audio.activar_impulso(false)
			impulso_activo = false
		
		# Manejo seguro de visibilidad del sprite
		if nave_sprite and not invulnerable:
			nave_sprite.visible = true
		
		# Manejo seguro de animación
		if animation_player and animation_player.has_animation("RESET"):
			if not animation_player.is_playing() or animation_player.current_animation != "RESET":
				animation_player.play("RESET")
	
	# Aplicar fricción y limitar velocidad
	velocity_vector *= friction
	if velocity_vector.length() > max_speed:
		velocity_vector = velocity_vector.normalized() * max_speed
	
	# Impulso con tecla personalizada
	if Input.is_action_just_pressed("impulso") or Input.is_action_just_pressed("shift"):
		var boost_direction = Vector2(cos(rotation - PI/2), sin(rotation - PI/2))
		velocity_vector += boost_direction * 100.0
		
		# Efecto de sonido para el boost
		if efectos_audio:
			efectos_audio.reproducir_power_up(global_position)
	
	# Sistema de disparo
	if (Input.is_action_just_pressed("ui_accept") or 
		Input.is_action_just_pressed("espacio") or 
		Input.is_action_just_pressed("space")) and puede_disparar:
		disparar()
	
	# Aplicar movimiento
	wrap_screen()
	velocity = velocity_vector
	move_and_slide()
	
	# Verificar colisiones después de mover
	_verificar_colisiones_por_physics()

# Verificar colisiones usando el sistema de física
func _verificar_colisiones_por_physics():
	if invulnerable:
		return
	
	for i in get_slide_collision_count():
		var colision = get_slide_collision(i)
		var objeto = colision.get_collider()
		
		if objeto and objeto.is_in_group("meteorito"):
			print("NAVE: Colisión física detectada con meteorito")
			recibir_impacto()
			break

# Verificar colisiones por distancia
func _verificar_colisiones_por_distancia():
	if invulnerable:
		return
	
	var meteoritos = get_tree().get_nodes_in_group("meteorito")
	
	for meteorito in meteoritos:
		if meteorito and is_instance_valid(meteorito):
			var distancia = global_position.distance_to(meteorito.global_position)
			
			var radio_combinado = radio_colision
			if "tamano_meteorito" in meteorito:
				radio_combinado += 30 * meteorito.tamano_meteorito
			else:
				radio_combinado += 30
			
			if distancia < radio_combinado:
				print("NAVE: Colisión por distancia detectada con meteorito")
				recibir_impacto()
				break

func wrap_screen():
	var screen_size = get_viewport_rect().size
	
	if position.x < 0:
		position.x = screen_size.x
	elif position.x > screen_size.x:
		position.x = 0
		
	if position.y < 0:
		position.y = screen_size.y
	elif position.y > screen_size.y:
		position.y = 0

# Función para manejar el impacto de un meteorito
func recibir_impacto():
	if invulnerable:
		return
	
	print("NAVE: Recibiendo impacto")
	
	# Detener impulso si está activo
	if efectos_audio and impulso_activo:
		efectos_audio.activar_impulso(false)
		impulso_activo = false
	
	# Reproducir sonido de explosión usando el sistema de efectos
	if efectos_audio:
		efectos_audio.reproducir_explosion_enemigo(global_position)
	
	# Activar invulnerabilidad temporal
	invulnerable = true
	
	# Buscar sistema de vidas si no lo tenemos
	if sistema_vidas == null:
		buscar_sistema_vidas()
	
	# Reducir vida
	if sistema_vidas:
		print("NAVE: Llamando a sistema_vidas.perder_vida()")
		var tiene_vidas = false
		
		# Usar call_deferred para mayor seguridad
		if sistema_vidas.has_method("perder_vida"):
			tiene_vidas = sistema_vidas.perder_vida()
			
			if not tiene_vidas:
				# Game over
				game_over()
				return
	else:
		print("NAVE: No se encontró el sistema de vidas")
	
	# Esperar antes de desactivar invulnerabilidad
	await get_tree().create_timer(2.0).timeout
	
	# Verificar que la nave no ha sido destruida durante el tiempo de espera
	if not is_inside_tree():
		return
		
	invulnerable = false
	
	# Actualizar visibilidad del sprite de manera segura
	if nave_sprite:
		nave_sprite.visible = true

# Game over
func game_over():
	# Desactivar controles
	set_physics_process(false)
	
	# Detener impulso si está activo
	if efectos_audio and impulso_activo:
		efectos_audio.activar_impulso(false)
		impulso_activo = false
	
	# Ocultar la nave de manera segura
	if nave_sprite:
		nave_sprite.visible = false
	
	# Buscar y guardar la puntuación actual
	var sistema_puntuacion = buscar_sistema_puntuacion()
	if sistema_puntuacion != null:
		if sistema_puntuacion.has_method("obtener_puntuacion"):
			# Guardar la puntuación en un archivo temporal
			var puntuacion = sistema_puntuacion.obtener_puntuacion()
			var file = FileAccess.open("user://puntuacion_final.save", FileAccess.WRITE)
			file.store_var(puntuacion)
			print("NAVE: Puntuación final guardada: " + str(puntuacion))
	
	# Crear explosión
	var explosion = CPUParticles2D.new()
	explosion.emitting = true
	explosion.one_shot = true
	explosion.explosiveness = 1.0
	explosion.amount = 30
	explosion.lifetime = 1.0
	explosion.direction = Vector2.ZERO
	explosion.spread = 180
	explosion.gravity = Vector2.ZERO
	explosion.initial_velocity_min = 50
	explosion.initial_velocity_max = 150
	explosion.color = Color(1, 0.5, 0)
	
	# Añadir explosión a la escena
	var parent = get_parent()
	if parent:
		parent.add_child(explosion)
		explosion.global_position = global_position
		
		# Reproducir sonido de explosión final
		if efectos_audio:
			efectos_audio.reproducir_explosion_enemigo(global_position)
	
	await get_tree().create_timer(1.5).timeout
	
	# Detener todos los efectos antes de cambiar de escena
	if efectos_audio:
		efectos_audio.detener_todos_los_efectos()
	
	get_tree().change_scene_to_file("res://game/escena/GameOver.tscn")
	
	print("NAVE: Game Over")

func buscar_sistema_puntuacion():
	# Buscar primero por grupos (más eficiente)
	var sistemas = get_tree().get_nodes_in_group("sistemas_puntuacion")
	if sistemas.size() > 0:
		return sistemas[0]
	
	# Buscar en todo el árbol de escena
	var puntuacion = get_tree().root.find_child("Puntuacion", true, false)
	if puntuacion:
		return puntuacion
	
	# Buscar nodos que puedan tener métodos de puntuación
	return buscar_nodo_recursivo(get_tree().root, "obtener_puntuacion")

func buscar_nodo_recursivo(nodo, nombre_metodo):
	# Verificar el nodo actual
	if nodo.has_method(nombre_metodo):
		return nodo
	
	# Buscar en los hijos
	for hijo in nodo.get_children():
		var resultado = buscar_nodo_recursivo(hijo, nombre_metodo)
		if resultado != null:
			return resultado
	
	# No se encontró
	return null

func disparar():
	# Verificar si tenemos munición configurada
	if not municio:
		print("Error: No se ha configurado la munición")
		return
	
	# Reproducir sonido de disparo usando el sistema de efectos
	if efectos_audio:
		efectos_audio.reproducir_disparo(global_position)
	
	# Crear la bala
	var bala = municio.instantiate()
	
	# Posicionar la bala correctamente en la punta de la nave
	var direccion = Vector2(0, -1).rotated(rotation)
	var offset = direccion * 30
	bala.global_position = global_position + offset
	bala.rotation = rotation
	
	# Establecer la velocidad según el tipo de nodo
	if bala is RigidBody2D:
		bala.linear_velocity = direccion * velocidad_disparo
	elif "velocity" in bala:
		bala.velocity = direccion * velocidad_disparo
	
	# Evitar colisiones iniciales con la nave
	if bala.has_method("ignore_collision_with"):
		bala.ignore_collision_with(self)
	
	# Añadir la bala a la escena del padre
	var parent = get_parent()
	if parent:
		parent.add_child(bala)
	
	# Iniciar tiempo de recarga
	puede_disparar = false
	var timer = get_node_or_null("TimerDisparo")
	if timer:
		timer.start()

func _on_timer_disparo_timeout():
	puede_disparar = true

# Limpiar al salir
func _exit_tree():
	# Asegurarse de detener el impulso
	if efectos_audio and impulso_activo:
		efectos_audio.activar_impulso(false)
