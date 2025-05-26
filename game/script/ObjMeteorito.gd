extends RigidBody2D

signal impacto_con_jugador

@export var velocidad_rotacion = 0.5
@export var tamano_meteorito = 1.0
@export var puntos_destruccion = 10
@export_file("*.tscn") var escena_particula = "res://particula.tscn"
@export var es_fragmento = false  # Variable para controlar si es un fragmento generado

var destruible_por_jugador = true
var esta_destruyendose = false
var tipo_asteroide = "mediano"  # Por defecto
var impactado_por_ovni = false  # Variable clave para controlar si suma puntos

#sonido
@onready var explosion = $explosion

# Referencias a nodos
@onready var animation_player = $AnimationPlayer if has_node("AnimationPlayer") else null

func _ready():
	# Establecer propiedades físicas
	gravity_scale = 0.0
	contact_monitor = true
	max_contacts_reported = 4
	
	# Configurar capa de colisión
	collision_layer = 2  # Capa 2 para meteoritos
	collision_mask = 13  # Colisiona con capa 1 (jugador), 3 (proyectiles) y 4 (munición OVNI)
	
	# Ajustar masa según tamaño
	mass = 2.0 * tamano_meteorito
	
	# Conectar señal de colisión
	body_entered.connect(_on_body_entered)
	
	# Conectar la señal de fin de animación si existe AnimationPlayer
	if animation_player:
		if not animation_player.is_connected("animation_finished", _on_animation_finished):
			animation_player.animation_finished.connect(_on_animation_finished)
		
	# Determinar el tipo de asteroide según su tamaño
	determinar_tipo_asteroide()
	
	# Asegurarse de que está en el grupo correcto para colisiones
	add_to_group("meteorito")
	add_to_group("asteroide_" + tipo_asteroide)
	
	# Si es un fragmento, añadir al grupo correspondiente
	if es_fragmento:
		add_to_group("particula_meteorito")
		
		# Los fragmentos pueden tener una rotación más rápida
		velocidad_rotacion *= 1.5
		
	# Si ya está marcado como impactado por OVNI, añadir al grupo correspondiente
	if impactado_por_ovni:
		add_to_group("impactado_por_ovni")
		print("Meteorito inicializado como impactado por OVNI")

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

# Función para marcar el meteorito como impactado por OVNI
func marcar_impacto_ovni():
	impactado_por_ovni = true
	print("METEORITO: Marcado como impactado por OVNI")
	
	# También agregarlo a un grupo especial para fácil detección
	if not is_in_group("impactado_por_ovni"):
		add_to_group("impactado_por_ovni")

# Función para desactivar la puntuación
func desactivar_puntuacion():
	impactado_por_ovni = true
	print("METEORITO: Puntuación desactivada para este meteorito")

# 1) _on_body_entered
func _on_body_entered(body):
	if esta_destruyendose:
		return

	if body.is_in_group("proyectil") or body.is_in_group("municion_player"):
		print("METEORITO: Impactado por jugador → SUMAR")
		destruir(true)
	elif body.is_in_group("proyectil_enemigo") \
		 or body.is_in_group("proyectil_ovni") \
		 or body.is_in_group("municion_ovni"):
		print("METEORITO: Impactado por enemigo/OVNI → NO SUMAR")
		destruir(false)
	elif body.is_in_group("jugador"):
		# tu lógica de rebote/daño al jugador...
		return
  

# 2) destruir(sumarpuntos: bool)
func destruir(sumarpuntos: bool):
	if esta_destruyendose:
		return
	esta_destruyendose = true
	contact_monitor = false

	if sumarpuntos:
		print("METEORITO: Llamando a sumar puntos")
		var sistema = obtener_sistema_puntuacion()
		if sistema and sistema.has_method("sumar_puntos_asteroide"):
			sistema.sumar_puntos_asteroide(tipo_asteroide)
	else:
		print("METEORITO: No suma puntos")

	# efectos visuales y fragmentos, exactamente igual que antes…
	if not es_fragmento and tipo_asteroide != "pequeno":
		_generar_fragmentos_por_tipo()
	else:
		_crear_explosion_visual()

	if animation_player and animation_player.has_animation("a_explosion"):
		linear_velocity = Vector2.ZERO
		angular_velocity = 0
		animation_player.play("a_explosion")
	else:
		queue_free()


# Crear un efecto visual simple de explosión
func _crear_explosion_visual():
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
	print("METEORITO: Recibiendo daño: " + str(danio))
	#destruir()

# Sumar puntos según el tipo de asteroide utilizando el sistema de puntuación
func sumar_puntos_asteroide():
	# VERIFICACIÓN CRÍTICA: Comprobación triple para no sumar puntos
	if impactado_por_ovni:
		print("METEORITO CRÍTICO: No sumando puntos - impactado_por_ovni = true")
		return
		
	if is_in_group("impactado_por_ovni"):
		print("METEORITO CRÍTICO: No sumando puntos - pertenece al grupo impactado_por_ovni")
		return
		
	if has_meta("impactado_por_ovni") and get_meta("impactado_por_ovni"):
		print("METEORITO CRÍTICO: No sumando puntos - tiene metadata impactado_por_ovni")
		return
	
	# VERIFICACIÓN EXTREMA: Comprobar si hay impactos recientes de OVNI
	if Time.get_ticks_msec() - Engine.get_physics_frames() * 16 < 500:  # ~500ms desde el último frame
		var municiones_ovni = get_tree().get_nodes_in_group("municion_ovni")
		for municion in municiones_ovni:
			if municion and is_instance_valid(municion):
				if global_position.distance_to(municion.global_position) < 100:
					print("METEORITO CRÍTICO: No sumando puntos - munición OVNI cercana detectada")
					return
	
	# VERIFICACIÓN SISTEMA: Intentar usar método específico del sistema de puntuación
	var puntuacion = obtener_sistema_puntuacion()
	if puntuacion:
		if puntuacion.has_method("esta_objeto_bloqueado") and puntuacion.esta_objeto_bloqueado(self):
			print("METEORITO CRÍTICO: Objeto bloqueado en sistema de puntuación")
			return
	
		if puntuacion.has_method("sumar_puntos_asteroide"):
			# PASAR SELF COMO SEGUNDO PARÁMETRO para que se pueda verificar
			puntuacion.sumar_puntos_asteroide(tipo_asteroide, self)
			print("METEORITO: Puntos sumados vía sistema de puntuación")
			return
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
				print("METEORITO: +" + str(puntos) + " puntos sumados directamente")
	else:
		print("METEORITO: No se encontró sistema de puntuación")

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
	# Cuando termina la animación "a_explosion", eliminar el objeto
	if anim_name == "a_explosion":
		queue_free()

# Función que implementa la mecánica de Asteroids para fragmentación
func _generar_fragmentos_por_tipo():
	# Según mecánica de Asteroids:
	# - Grande -> genera 2 medianos
	# - Mediano -> genera 2 pequeños
	# - Pequeño -> no genera nada
	explosion.play()
	if tipo_asteroide == "pequeno":
		# Los pequeños no generan fragmentos
		return
	
	# Determinar tipo del fragmento según el meteorito actual
	var tipo_fragmento = "pequeno"  # Por defecto para medianos
	var tamano_fragmento = 0.5      # Tamaño para pequeños
	
	if tipo_asteroide == "grande":
		tipo_fragmento = "mediano"
		tamano_fragmento = 0.8      # Tamaño para medianos
	
	# Cantidad de fragmentos
	var num_fragmentos = 2          # Siempre 2 según mecánica original
	
	# Primero intentar usar la escena de partícula configurada
	var particula_escena = null
	if escena_particula:
		particula_escena = load(escena_particula)
	
	# Si tenemos la escena de partícula, usarla preferentemente
	if particula_escena:
		print("METEORITO: Usando escena de partícula configurada: " + escena_particula)
		
		for i in range(num_fragmentos):
			var particula = particula_escena.instantiate()
			
			# Asegurarse de que tenga las propiedades correctas
			if particula is RigidBody2D:
				# CLAVE: Asegurar colisión correcta para la munición
				particula.collision_layer = 2  # Capa de meteoritos
				particula.collision_mask = 13  # Jugador, proyectiles y munición OVNI
				
				
				if "es_fragmento" in particula:
					particula.es_fragmento = true
				
				if "impactado_por_ovni" in particula:
					particula.impactado_por_ovni = impactado_por_ovni
					
					if impactado_por_ovni:
						print("FRAGMENTO: Heredó propiedad impactado_por_ovni = true")
						
						# Añadir al grupo para mayor seguridad
						particula.add_to_group("impactado_por_ovni")
				
				# Configurar propiedades del fragmento
				if "tamano_meteorito" in particula:
					particula.tamano_meteorito = tamano_fragmento
				if "tipo_asteroide" in particula:
					particula.tipo_asteroide = tipo_fragmento
				
				# Hacer el fragmento un poco más grande para mejor visibilidad
				var sprite = particula.get_node_or_null("Sprite2D")
				if sprite:
					sprite.scale = sprite.scale * 1.5
				
				# Ajustar colisionador si existe
				var colision = particula.get_node_or_null("CollisionShape2D")
				if colision and colision.shape is CircleShape2D:
					colision.shape.radius *= 1.2  # 20% más grande
				
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
				var velocidad = randf_range(70, 150)
				particula.linear_velocity = direccion * velocidad
				
				print("METEORITO: Creada partícula del tipo " + tipo_fragmento)
		
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
			
			# SOLUCIÓN AL BUG: Marcar como fragmento para evitar bucle
			fragmento.es_fragmento = true
			
			# TRANSFERIR PROPIEDAD impactado_por_ovni
			fragmento.impactado_por_ovni = impactado_por_ovni
			
			if impactado_por_ovni:
				print("FRAGMENTO AUTOCLONADO: Heredó propiedad impactado_por_ovni = true")
				fragmento.add_to_group("impactado_por_ovni")
			
			# CLAVE: Asegurar configuración correcta para detección
			fragmento.collision_layer = 2  # Capa de meteoritos
			fragmento.collision_mask = 13  # Jugador, proyectiles y munición OVNI
			
			# Añadir a la escena
			get_parent().add_child(fragmento)
			
			# Posicionarlo cerca del original con pequeña variación
			var offset = Vector2(randf_range(-20, 20), randf_range(-20, 20))
			fragmento.global_position = global_position + offset
			
			# Dar velocidad aleatoria en dirección distinta
			var direccion = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
			var velocidad = randf_range(70, 150)
			fragmento.linear_velocity = direccion * velocidad
			
			print("METEORITO: Creado fragmento " + tipo_fragmento + " a partir de " + tipo_asteroide)
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
		print("METEORITO: No se encontró ninguna escena de meteorito. Creando fragmento básico.")
		_crear_fragmentos_basicos(tipo_fragmento, tamano_fragmento, num_fragmentos)
		return
	
	print("METEORITO: Usando escena de meteorito alternativa: " + ruta_encontrada)
	
	for i in range(num_fragmentos):
		# Instanciar el fragmento
		var fragmento = fragmento_escena.instantiate()
		
		# SOLUCIÓN AL BUG: Marcar como fragmento si es posible
		if "es_fragmento" in fragmento:
			fragmento.es_fragmento = true
		
		# TRANSFERIR PROPIEDAD impactado_por_ovni
		if "impactado_por_ovni" in fragmento:
			fragmento.impactado_por_ovni = impactado_por_ovni
			
			if impactado_por_ovni:
				print("FRAGMENTO ALTERNATIVO: Heredó propiedad impactado_por_ovni = true")
				fragmento.add_to_group("impactado_por_ovni")
		
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
			fragmento.collision_mask = 13  # Jugador, proyectiles y munición OVNI
		
		# Añadir a grupos importantes para detección
		fragmento.add_to_group("meteorito")
		fragmento.add_to_group("particula_meteorito")
		fragmento.add_to_group("asteroide_" + tipo_fragmento)
		
		# Hacer el fragmento más grande para mejor visibilidad
		var sprite = fragmento.get_node_or_null("Sprite2D")
		if sprite:
			sprite.scale = sprite.scale * 1.5
			
		# Ajustar colisionador si existe
		var colision = fragmento.get_node_or_null("CollisionShape2D")
		if colision and colision.shape is CircleShape2D:
			colision.shape.radius *= 1.2  # 20% más grande
		
		# Añadirlo al árbol de escena
		get_parent().add_child(fragmento)
		
		# Posicionarlo con una pequeña variación
		var offset = Vector2(randf_range(-20, 20), randf_range(-20, 20))
		fragmento.global_position = global_position + offset
		
		# Dar velocidad aleatoria en dirección distinta
		var direccion = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
		var velocidad = randf_range(70, 150)
		if fragmento is RigidBody2D:
			fragmento.linear_velocity = direccion * velocidad
		
		print("METEORITO: Creado fragmento alternativo " + tipo_fragmento)

# Crear fragmentos básicos si no se encuentra ninguna escena
func _crear_fragmentos_basicos(tipo_fragmento, tamano_fragmento, num_fragmentos):
	for i in range(num_fragmentos):
		# Crear un RigidBody2D como fragmento básico
		var fragmento = RigidBody2D.new()
		fragmento.gravity_scale = 0.0
		fragmento.contact_monitor = true
		fragmento.max_contacts_reported = 4
		fragmento.collision_layer = 2
		fragmento.collision_mask = 13  # Jugador, proyectiles y munición OVNI
		
		# Añadir colisionador
		var colision = CollisionShape2D.new()
		var forma = CircleShape2D.new()
		
		# Tamaño del colisionador según tipo
		if tipo_fragmento == "mediano":
			forma.radius = 15.0
		else:  # pequeño
			forma.radius = 10.0  # Un poco más grande para mejor detección
			
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
			
			# Escala según tipo
			if tipo_fragmento == "mediano":
				sprite.scale = Vector2(0.8, 0.8)
			else:  # pequeño
				sprite.scale = Vector2(0.5, 0.5)  # Un poco más grande
				
			fragmento.add_child(sprite)
		
		# Propiedades específicas para la mecánica de Asteroids
		fragmento.set_meta("tipo_asteroide", tipo_fragmento)
		fragmento.set_meta("tamano_meteorito", tamano_fragmento)
		fragmento.set_meta("esta_destruyendose", false)
		fragmento.set_meta("es_fragmento", true)  # SOLUCIÓN AL BUG
		
		# TRANSFERIR PROPIEDAD impactado_por_ovni USANDO META
		fragmento.set_meta("impactado_por_ovni", impactado_por_ovni)
		
		if impactado_por_ovni:
			print("FRAGMENTO BÁSICO: Heredó propiedad impactado_por_ovni como metadata")
			fragmento.add_to_group("impactado_por_ovni")
		
		# Añadir a grupos
		fragmento.add_to_group("meteorito")
		fragmento.add_to_group("particula_meteorito")
		fragmento.add_to_group("asteroide_" + tipo_fragmento)
		
		# Intentar cargar script para fragmento
		var script_fragmento = load("res://fragmento.gd")
		if script_fragmento:
			fragmento.set_script(script_fragmento)
		else:
			# Si no existe script, implementar lógica básica
			fragmento.body_entered.connect(
				func(body):
					if (body.is_in_group("proyectil") or body.is_in_group("municion_player")) and not fragmento.get_meta("esta_destruyendose"):
						print("FRAGMENTO BÁSICO: Colisión con proyectil del jugador")
						fragmento.set_meta("esta_destruyendose", true)
						
						# Sumar puntos SOLO si no fue impactado por OVNI
						var no_sumar_puntos = fragmento.has_meta("impactado_por_ovni") and fragmento.get_meta("impactado_por_ovni")
						no_sumar_puntos = no_sumar_puntos or fragmento.is_in_group("impactado_por_ovni")
						
						if not no_sumar_puntos:
							# Sumar puntos
							var puntuacion = obtener_sistema_puntuacion()
							if puntuacion and puntuacion.has_method("sumar_puntos_asteroide"):
								puntuacion.sumar_puntos_asteroide(tipo_fragmento)
						else:
							print("FRAGMENTO BÁSICO: No sumando puntos (impactado por OVNI)")
						
						# Crear explosión simple
						var particulas = CPUParticles2D.new()
						particulas.emitting = true
						particulas.amount = 15
						particulas.lifetime = 0.5
						particulas.one_shot = true
						particulas.explosiveness = 1.0
						particulas.gravity = Vector2.ZERO
						particulas.initial_velocity_min = 30
						particulas.initial_velocity_max = 80
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
		var velocidad = randf_range(70, 150)
		fragmento.linear_velocity = direccion * velocidad
		
		print("METEORITO: Creado fragmento básico " + tipo_fragmento)

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
