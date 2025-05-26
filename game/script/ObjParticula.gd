extends RigidBody2D

signal impacto_con_jugador

@export var velocidad_rotacion = 0.5
@export var tamano_meteorito = 1.0
@export var puntos_destruccion = 10
@export_file("*.tscn") var escena_particula = ""
var destruible_por_jugador = true
var esta_destruyendose = false
var tipo_asteroide = "mediano"  # Por defecto
var es_particula_generada = false  # NUEVA VARIABLE para evitar bucles

#musica
@onready var explosion_mini = $Explosion_Mini

# Referencias a nodos
@onready var animation_player = $AnimationPlayer if has_node("AnimationPlayer") else null

func _ready():
	# Establecer propiedades físicas
	gravity_scale = 0.0
	contact_monitor = true
	max_contacts_reported = 4
	
	# Configurar capa de colisión
	collision_layer = 2  # Capa 2 para meteoritos
	collision_mask = 5   # Colisiona con capa 1 (jugador) y 3 (proyectiles)
	
	# Ajustar masa según tamaño
	mass = 2.0 * tamano_meteorito
	
	# Conectar señal de colisión
	body_entered.connect(_on_body_entered)
	
	# Conectar la señal de fin de animación si existe AnimationPlayer
	if animation_player:
		animation_player.animation_finished.connect(_on_animation_finished)
		
	# Determinar el tipo de asteroide según su tamaño
	determinar_tipo_asteroide()
	
	# Asegurarse de que está en el grupo correcto para colisiones
	add_to_group("meteorito")
	add_to_group("asteroide_" + tipo_asteroide)
	
	# Si es una partícula generada, añadir al grupo correspondiente
	if es_particula_generada:
		add_to_group("particula_meteorito")

# Determinar el tipo de asteroide según su tamaño
func determinar_tipo_asteroide():
	if tamano_meteorito >= 1.5:
		tipo_asteroide = "grande"
	elif tamano_meteorito >= 0.8:
		tipo_asteroide = "mediano"
	else:
		tipo_asteroide = "pequeno"
	
	print("Meteorito inicializado como: " + tipo_asteroide + " (tamaño: " + str(tamano_meteorito) + ")")

# Añadido para teletransportar cuando sale de la pantalla
func _physics_process(delta):
	# No hacer nada si está en proceso de destrucción
	if esta_destruyendose:
		return
		
	# Aplicar rotación continua al meteorito
	angular_velocity = velocidad_rotacion
	
	# Obtener tamaño de la pantalla
	var viewport_rect = get_viewport_rect().size
	
	# Obtener la posición actual del meteorito
	var pos = global_position
	
	# Verificar si ha salido por algún borde y teletransportarlo al lado opuesto
	if pos.x < -50:
		pos.x = viewport_rect.x + 25
	elif pos.x > viewport_rect.x + 50:
		pos.x = -25
	
	if pos.y < -50:
		pos.y = viewport_rect.y + 25
	elif pos.y > viewport_rect.y + 50:
		pos.y = -25
	
	# Actualizar la posición global del meteorito
	global_position = pos

func _on_body_entered(body):
	# No procesar colisiones si está destruyéndose
	if esta_destruyendose:
		return
		
	# Verificar si colisionó con el jugador
	if body.is_in_group("jugador"):
		print("Meteorito: Colisión con jugador detectada")
		
		# Emitir señal de impacto
		emit_signal("impacto_con_jugador")
		
		# Obtener sistema de vidas
		var sistema_vidas = encontrar_sistema_vidas()
		if sistema_vidas:
			print("Meteorito: Llamando a sistema_vidas.perder_vida()")
			sistema_vidas.perder_vida()
		else:
			print("Meteorito: No se pudo encontrar el sistema de vidas")
		
		# Rebote
		linear_velocity = linear_velocity.bounce(
			(global_position - body.global_position).normalized()
		)
		
	# Si colisiona con un proyectil del jugador, se destruye
	elif body.is_in_group("proyectil") and destruible_por_jugador:
		print("Meteorito: Colisión con proyectil del jugador, destruyendo")
		destruir()
	
	# NUEVA CONDICIÓN: Si colisiona con un proyectil del OVNI, también se destruye
	elif body.is_in_group("proyectil_enemigo") or body.is_in_group("proyectil_ovni"):
		print("Meteorito: Colisión con proyectil del OVNI, destruyendo")
		destruir()

func destruir():
	# Marcar que está en proceso de destrucción para evitar acciones adicionales
	esta_destruyendose = true
	explosion_mini.play()
	print("Meteorito " + tipo_asteroide + ": Destruyendo")
	
	# Sumar puntos según el tipo de asteroide
	sumar_puntos_asteroide()
	
	# Desactivar colisiones durante la animación
	contact_monitor = false
	
	# SOLUCIÓN AL BUG: Solo generar fragmentos si no es una partícula ya generada
	if not es_particula_generada and tipo_asteroide != "pequeno":
		_generar_fragmentos_por_tipo()
	else:
		print("Este objeto no genera más fragmentos")
	
	# Verificar si tiene AnimationPlayer y la animación "destruccion"
	if animation_player and animation_player.has_animation("a_explosion"):
		# Detener el movimiento durante la animación
		linear_velocity = Vector2.ZERO
		angular_velocity = 0
		
		# Reproducir la animación de destrucción
		animation_player.play("a_explosion")
	else:
		# CREAR EFECTO EXPLOSIÓN SIMPLE PARA PARTÍCULAS
		if es_particula_generada:
			_crear_explosion_simple()
			queue_free()
		else:
			# Si no hay animación, destruir inmediatamente
			queue_free()

# Crear efecto simple de explosión para partículas
func _crear_explosion_simple():
	var particulas = CPUParticles2D.new()
	particulas.emitting = true
	particulas.amount = 20
	particulas.lifetime = 0.6
	particulas.one_shot = true
	particulas.explosiveness = 1.0
	particulas.gravity = Vector2.ZERO
	particulas.initial_velocity_min = 40
	particulas.initial_velocity_max = 100
	particulas.color = Color(1, 0.7, 0.3, 1)
	get_parent().add_child(particulas)
	particulas.global_position = global_position
	
	# Auto-destruir partículas
	var timer_part = Timer.new()
	timer_part.wait_time = 2.0
	timer_part.one_shot = true
	timer_part.autostart = true
	timer_part.timeout.connect(func(): particulas.queue_free())
	particulas.add_child(timer_part)

# Método para recibir daño - compatible con el script del proyectil
func recibir_danio(danio):
	print("Meteorito: Recibiendo daño: " + str(danio))
	destruir()

# Sumar puntos según el tipo de asteroide utilizando el sistema de puntuación
func sumar_puntos_asteroide():
	# Buscar sistema de puntuación
	var puntuacion = obtener_sistema_puntuacion()
	if puntuacion:
		if puntuacion.has_method("sumar_puntos_asteroide"):
			# Usar el método específico del sistema
			puntuacion.sumar_puntos_asteroide(tipo_asteroide)
			print("Meteorito " + tipo_asteroide + ": Puntos sumados vía sistema de puntuación")
		else:
			# Fallback a métodos básicos
			var puntos = 10  # Valor por defecto
			
			# Determinar puntos según tipo
			if tipo_asteroide == "grande":
				puntos = 20
			elif tipo_asteroide == "mediano":
				puntos = 50
			else:  # pequeño
				puntos = 10
				
			if puntuacion.has_method("sumar_puntos"):
				puntuacion.sumar_puntos(puntos)
				print("Meteorito " + tipo_asteroide + ": +" + str(puntos) + " puntos sumados directamente")
	else:
		print("Meteorito: No se encontró sistema de puntuación")

# Función para encontrar el sistema de puntuación
func obtener_sistema_puntuacion():
	# Buscar primero por grupos (más eficiente)
	var sistemas = get_tree().get_nodes_in_group("sistemas_puntuacion")
	if sistemas.size() > 0:
		return sistemas[0]
	
	# Buscar por nodos específicos
	var puntuacion = get_node_or_null("/root/Puntuacion")
	if puntuacion:
		return puntuacion
		
	# Métodos alternativos
	var nombres_posibles = ["ScoreManager", "PuntajeManager", "Score", "Puntos", "Puntaje"]
	for nombre in nombres_posibles:
		var sistema = get_node_or_null("/root/" + nombre)
		if sistema:
			return sistema
	
	# Buscar recursivamente en el árbol
	return buscar_nodo_recursivo(get_tree().root, "sumar_puntos")

func _on_animation_finished(anim_name):
	# Cuando termina la animación "destruccion", eliminar el objeto
	if anim_name == "a_explosion":
		queue_free()

# Función que implementa la mecánica de Asteroids para fragmentación
func _generar_fragmentos_por_tipo():
	# Según mecánica de Asteroids adaptada para partículas de tamaño adecuado:
	# - Grande -> genera 2 medianos
	# - Mediano -> genera 2 medianos (más pequeños pero aún medianos)
	# - Pequeño -> no genera nada
	
	if tipo_asteroide == "pequeno":
		# Los pequeños no generan fragmentos
		return
	
	# MODIFICADO: Siempre usamos fragmentos medianos, pero con tamaño adaptado
	var tipo_fragmento = "mediano"  # Siempre usamos fragmentos medianos
	
	# Ajustar el tamaño según el origen
	var tamano_fragmento = 0.8  # Tamaño base para medianos
	
	if tipo_asteroide == "grande":
		# Si viene de un grande, pueden ser un poco más grandes
		tamano_fragmento = 0.9
	elif tipo_asteroide == "mediano":
		# Si viene de un mediano, un poco más pequeños pero aún medianos
		tamano_fragmento = 0.7
	
	# Cantidad de fragmentos
	var num_fragmentos = 2
	
	# Primero intentar usar la escena de partícula configurada
	var particula_escena = null
	if escena_particula:
		particula_escena = load(escena_particula)
	
	# Si tenemos la escena de partícula, usarla preferentemente
	if particula_escena:
		print("Usando escena de partícula configurada: " + escena_particula)
		
		for i in range(num_fragmentos):
			var particula = particula_escena.instantiate()
			
			# Asegurarse de que tenga las propiedades correctas
			if particula is RigidBody2D:
				# CLAVE: Asegurar colisión correcta para la munición
				particula.collision_layer = 2  # Capa de meteoritos
				particula.collision_mask = 5   # Jugador y proyectiles
				
				# SOLUCIÓN AL BUG: Marcar como partícula generada para evitar bucles
				if "es_particula_generada" in particula:
					particula.es_particula_generada = true
				
				# Configurar propiedades del fragmento
				if "tamano_meteorito" in particula:
					particula.tamano_meteorito = tamano_fragmento
				if "tipo_asteroide" in particula:
					particula.tipo_asteroide = tipo_fragmento
				
				# MODIFICADO: Ajustar el tamaño visualmente si tiene sprite
				var sprite = particula.get_node_or_null("Sprite2D")
				if sprite:
					# Escala original x 1.5 para que se vea bien
					sprite.scale = sprite.scale * 1.5
					
				# Colisionador un poco más grande
				var colisionador = particula.get_node_or_null("CollisionShape2D")
				if colisionador and colisionador.shape is CircleShape2D:
					colisionador.shape.radius *= 1.2  # 20% más grande
				
				# Añadir a grupos para detección
				particula.add_to_group("meteorito")
				particula.add_to_group("particula_meteorito")
				particula.add_to_group("asteroide_" + tipo_fragmento)
				
				# Añadir a la escena
				get_parent().add_child(particula)
				
				# Posicionar cerca del meteorito original
				var offset = Vector2(randf_range(-20, 20), randf_range(-20, 20))
				particula.global_position = global_position + offset
				
				# Dar velocidad aleatoria
				var direccion = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
				var velocidad = randf_range(70, 150)  # Velocidad adecuada para medianos
				particula.linear_velocity = direccion * velocidad
				
				print("Creada partícula del tipo " + tipo_fragmento + " (tamaño: " + str(tamano_fragmento) + ")")
		
		return
	
	# Si no tenemos la escena de partícula, intentar autoclonación o alternativas
	# Generar los fragmentos usando el código existente
	for i in range(num_fragmentos):
		# Intentar crear desde la misma escena (auto-clon)
		var nuevo_meteorito = load(get_scene_file_path())
		
		if nuevo_meteorito:
			var fragmento = nuevo_meteorito.instantiate()
			
			# Configurar propiedades del fragmento según tipo
			fragmento.tamano_meteorito = tamano_fragmento
			fragmento.tipo_asteroide = tipo_fragmento
			
			# SOLUCIÓN AL BUG: Marcar como partícula generada
			fragmento.es_particula_generada = true
			
			# CLAVE: Asegurar configuración correcta para detección
			fragmento.collision_layer = 2  # Capa de meteoritos
			fragmento.collision_mask = 5   # Jugador y proyectiles
			
			# Añadir a la escena
			get_parent().add_child(fragmento)
			
			# Posicionarlo cerca del original con pequeña variación
			var offset = Vector2(randf_range(-20, 20), randf_range(-20, 20))
			fragmento.global_position = global_position + offset
			
			# Dar velocidad aleatoria en dirección distinta
			var direccion = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
			var velocidad = randf_range(70, 150)  # Velocidad adecuada para medianos
			fragmento.linear_velocity = direccion * velocidad
			
			print("Creado fragmento " + tipo_fragmento + " a partir de " + tipo_asteroide)
		else:
			# Si no se puede cargar la misma escena, usar el método alternativo
			_crear_fragmentos_alternativos(tipo_fragmento, tamano_fragmento, num_fragmentos)
			break

# Método alternativo para crear fragmentos si no se puede cargar la misma escena
func _crear_fragmentos_alternativos(tipo_fragmento, tamano_fragmento, num_fragmentos):
	# Rutas posibles para el fragmento
	var rutas_posibles = [
		"res://meteorito.tscn",
		"res://meteorito_medio.tscn",
		"res://meteorito_pequeno.tscn",
		"res://asteroide.tscn",
		"res://particula.tscn",
		"res://fragmento.tscn"
	]
	
	var fragmento_escena = null
	var ruta_encontrada = ""
	
	# Intentar cargar la escena de meteorito desde varias rutas posibles
	for ruta in rutas_posibles:
		fragmento_escena = load(ruta)
		if fragmento_escena != null:
			ruta_encontrada = ruta
			break
	
	# Si no se puede cargar ninguna escena, crear un fragmento básico
	if fragmento_escena == null:
		print("No se encontró ninguna escena de meteorito. Creando fragmento básico.")
		_crear_fragmentos_basicos(tipo_fragmento, tamano_fragmento, num_fragmentos)
		return
	
	print("Usando escena de meteorito alternativa: " + ruta_encontrada)
	
	for i in range(num_fragmentos):
		# Instanciar el fragmento
		var fragmento = fragmento_escena.instantiate()
		
		# SOLUCIÓN AL BUG: Marcar como partícula generada si es posible
		if "es_particula_generada" in fragmento:
			fragmento.es_particula_generada = true
		
		# Configurar el fragmento
		if fragmento.has_method("determinar_tipo_asteroide"):
			fragmento.tamano_meteorito = tamano_fragmento
			fragmento.determinar_tipo_asteroide()
		else:
			# Si no tiene el método, configurar propiedades directamente
			if "tamano_meteorito" in fragmento:
				fragmento.tamano_meteorito = tamano_fragmento
			if "tipo_asteroide" in fragmento:
				fragmento.tipo_asteroide = tipo_fragmento
			
			fragmento.add_to_group("asteroide_" + tipo_fragmento)
		
		# CLAVE: Asegurar colisión correcta para la munición
		if fragmento is RigidBody2D:
			fragmento.collision_layer = 2  # Capa de meteoritos
			fragmento.collision_mask = 5   # Jugador y proyectiles
		
		# Añadir a grupos importantes para detección
		fragmento.add_to_group("meteorito")
		fragmento.add_to_group("particula_meteorito")
		fragmento.add_to_group("asteroide_" + tipo_fragmento)
		
		# MODIFICADO: Ajustar tamaño del sprite para que se vea mediano
		var sprite = fragmento.get_node_or_null("Sprite2D")
		if sprite:
			# Escala original x 1.5 para que se vea bien
			sprite.scale = sprite.scale * 1.5
			
		# Colisionador un poco más grande
		var colisionador = fragmento.get_node_or_null("CollisionShape2D")
		if colisionador and colisionador.shape is CircleShape2D:
			colisionador.shape.radius *= 1.2  # 20% más grande
		
		# Añadirlo al árbol de escena
		get_parent().add_child(fragmento)
		
		# Posicionarlo con una pequeña variación
		var offset = Vector2(randf_range(-20, 20), randf_range(-20, 20))
		fragmento.global_position = global_position + offset
		
		# Dar velocidad aleatoria en dirección distinta
		var direccion = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
		var velocidad = randf_range(70, 150)  # Velocidad adecuada para medianos
		if fragmento is RigidBody2D:
			fragmento.linear_velocity = direccion * velocidad
		
		print("Creado fragmento alternativo " + tipo_fragmento)

# Crear fragmentos básicos si no se encuentra ninguna escena
func _crear_fragmentos_basicos(tipo_fragmento, tamano_fragmento, num_fragmentos):
	for i in range(num_fragmentos):
		# Crear un RigidBody2D como fragmento básico
		var fragmento = RigidBody2D.new()
		fragmento.gravity_scale = 0.0
		fragmento.contact_monitor = true
		fragmento.max_contacts_reported = 4
		fragmento.collision_layer = 2
		fragmento.collision_mask = 5
		
		# Añadir colisionador
		var colision = CollisionShape2D.new()
		var forma = CircleShape2D.new()
		
		# MODIFICADO: Tamaño del colisionador más grande
		forma.radius = 15.0  # Siempre usamos tamaño mediano
			
		colision.shape = forma
		fragmento.add_child(colision)
		
		# Añadir sprite básico
		var sprite = Sprite2D.new()
		var textura = null
		
		# Intentar cargar una textura para el fragmento
		var rutas_texturas = [
			"res://assets/meteorito_" + tipo_fragmento + ".png",
			"res://icon.png"  # Usar el ícono por defecto si no hay otra textura
		]
		
		for ruta in rutas_texturas:
			textura = load(ruta)
			if textura != null:
				break
		
		if textura != null:
			sprite.texture = textura
			# MODIFICADO: Escala más grande para que se vea bien
			sprite.scale = Vector2(0.8, 0.8)  # Siempre usamos tamaño mediano
			fragmento.add_child(sprite)
		
		# Propiedades específicas para la mecánica de Asteroids
		fragmento.set_meta("tipo_asteroide", tipo_fragmento)
		fragmento.set_meta("tamano_meteorito", tamano_fragmento)
		fragmento.set_meta("esta_destruyendose", false)
		fragmento.set_meta("es_particula_generada", true)  # SOLUCIÓN AL BUG
		
		# Añadir a grupos
		fragmento.add_to_group("meteorito")
		fragmento.add_to_group("particula_meteorito")  # CLAVE para detección
		fragmento.add_to_group("asteroide_" + tipo_fragmento)
		
		# Intentar cargar script para fragmento
		var script_fragmento = load("res://fragmento.gd")
		if script_fragmento:
			fragmento.set_script(script_fragmento)
		else:
			# Si no existe script, implementar lógica básica
			fragmento.body_entered.connect(
				func(body):
					if body.is_in_group("proyectil") and not fragmento.get_meta("esta_destruyendose"):
						print("Fragmento básico " + tipo_fragmento + ": Colisión con proyectil")
						fragmento.set_meta("esta_destruyendose", true)
						
						# Sumar puntos
						var puntuacion = obtener_sistema_puntuacion()
						if puntuacion and puntuacion.has_method("sumar_puntos_asteroide"):
							puntuacion.sumar_puntos_asteroide(tipo_fragmento)
						
						# Crear explosión simple
						var particulas = CPUParticles2D.new()
						particulas.emitting = true
						particulas.amount = 20  # Más partículas
						particulas.lifetime = 0.6  # Duración ligeramente mayor
						particulas.one_shot = true
						particulas.explosiveness = 1.0
						particulas.gravity = Vector2.ZERO
						particulas.initial_velocity_min = 40
						particulas.initial_velocity_max = 100
						particulas.color = Color(1, 0.7, 0.3, 1)
						get_parent().add_child(particulas)
						particulas.global_position = fragmento.global_position
						
						# Auto-destruir partículas
						var timer_part = Timer.new()
						timer_part.wait_time = 2.0
						timer_part.one_shot = true
						timer_part.autostart = true
						timer_part.timeout.connect(func(): particulas.queue_free())
						particulas.add_child(timer_part)
						
						# Destruir fragmento
						fragmento.queue_free()
			)
		
		# Añadirlo a la escena
		get_parent().add_child(fragmento)
		
		# Posicionarlo y darle velocidad
		var offset = Vector2(randf_range(-20, 20), randf_range(-20, 20))
		fragmento.global_position = global_position + offset
		
		var direccion = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
		var velocidad = randf_range(70, 150)  # Velocidad adecuada para medianos
		fragmento.linear_velocity = direccion * velocidad
		
		print("Creado fragmento básico " + tipo_fragmento)

# Método para evitar que el meteorito se autodestruya en colisiones
func set_auto_destroy(value):
	destruible_por_jugador = value

# Función para encontrar el sistema de vidas
func encontrar_sistema_vidas():
	# Buscar por grupos primero (más eficiente)
	var sistemas = get_tree().get_nodes_in_group("sistema_vida")
	if sistemas.size() > 0:
		return sistemas[0]
	
	# Buscar por nodo específico
	var vida = get_tree().root.find_child("Vida", true, false)
	if vida and vida.has_method("perder_vida"):
		return vida
	
	# Buscar recursivamente
	return buscar_nodo_recursivo(get_tree().root, "perder_vida")

# Función recursiva para buscar un nodo con método específico
func buscar_nodo_recursivo(nodo, nombre_metodo):
	# Primero verificar el nodo actual
	if nodo.has_method(nombre_metodo):
		return nodo
	
	# Buscar en los hijos
	for hijo in nodo.get_children():
		var resultado = buscar_nodo_recursivo(hijo, nombre_metodo)
		if resultado != null:
			return resultado
	
	# No se encontró
	return null
