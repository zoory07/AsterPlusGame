extends RigidBody2D

# Variables para el proyectil
@export var tiempo_vida = 99.0
@export var danio = 2
@export var velocidad = 900.0  # Aumentada para mayor alcance
@export var longitud_disparo = 1.0  # Factor de escala para la longitud visual
var nave_ignorada = null
var escala_original = Vector2(1, 1)

func _ready():
	# Configurar física básica
	gravity_scale = 0.0  # Sin gravedad
	contact_monitor = true
	max_contacts_reported = 4
	
	# Configurar capas de colisión
	collision_layer = 4  # Capa 3 para proyectiles
	collision_mask = 2   # Colisiona con capa 2 (meteoritos)
	
	# Guardar escala original para referencia
	escala_original = scale
	
	# Aplicar escala para longitud visual
	if longitud_disparo > 1.0:
		estirar_proyectil()
	
	# Asegurar que no colisione con la nave al inicio
	if nave_ignorada:
		add_collision_exception_with(nave_ignorada)
	
	# Timer de auto-destrucción
	var timer = Timer.new()
	timer.name = "AutoDestruir"
	timer.one_shot = true
	timer.wait_time = tiempo_vida
	timer.timeout.connect(_on_vida_terminada)
	add_child(timer)
	timer.start()
	
	# Conectar señal de colisión
	body_entered.connect(_on_body_entered)
	
	# Agregar al grupo
	add_to_group("proyectil")
	
	# Imprimir configuración para depuración
	print("Proyectil inicializado - Velocidad: ", velocidad, " Longitud: ", longitud_disparo)

# Función para estirar visualmente el proyectil
func estirar_proyectil():
	# Estirar el sprite en la dirección del movimiento
	if has_node("Sprite2D"):
		# Mantener el ancho pero estirar en la dirección del movimiento
		var nueva_escala = Vector2(escala_original.x, escala_original.y * longitud_disparo)
		$Sprite2D.scale = nueva_escala
		
		# También ajustar el collision shape si existe
		if has_node("CollisionShape2D"):
			$CollisionShape2D.scale = nueva_escala

# Para evitar colisiones iniciales con la nave
func ignore_collision_with(body):
	nave_ignorada = body
	if is_inside_tree():
		add_collision_exception_with(body)

func _on_vida_terminada():
	queue_free()

func _on_body_entered(body):
	# Solo procesamos si no es la nave ignorada
	if body == nave_ignorada:
		return
		
	# Imprimir para depuración
	print("Colisión detectada con: ", body.name, " en grupos: ", body.get_groups())
	
	# MODIFICACIÓN IMPORTANTE: Verificar primero si es un OVNI específicamente
	if body.is_in_group("ovnis"):
		print("¡Colisión con OVNI confirmada!")
		
		# SIEMPRE usar recibir_danio para los OVNIs para activar la animación de eliminación
		if body.has_method("recibir_danio"):
			print("Aplicando daño al OVNI...")
			body.recibir_danio(danio)
			
			# Sumar puntos si tenemos sistema de puntuación
			_sumar_puntos("ovni")
			
			# Destruir el proyectil
			queue_free()
			return
	
	# Si choca con un meteorito (que no sea OVNI)
	if body.is_in_group("meteorito") or body.get_collision_layer_value(2):
		print("¡Colisión con meteorito confirmada!")
		
		# Determinar el tipo de meteorito para el sistema de puntuación
		var tipo_meteorito = "mediano"  # Valor por defecto (simplificado para nuestro sistema)
		
		# Intentar determinar el tamaño por grupos
		if body.is_in_group("asteroide_grande"):
			tipo_meteorito = "grande"
		elif body.is_in_group("asteroide_mediano"):
			tipo_meteorito = "mediano"
		elif body.is_in_group("asteroide_pequeño"):
			tipo_meteorito = "pequeno"
		# Intentar determinar por tamaño si tiene la propiedad
		elif body.has_method("get") and body.get("tamano_meteorito") != null:
			var tamano = body.tamano_meteorito
			if tamano >= 1.5:
				tipo_meteorito = "grande"
			elif tamano >= 0.8:
				tipo_meteorito = "mediano"
			else:
				tipo_meteorito = "pequeno"
		
		# Sumar puntos
		_sumar_puntos(tipo_meteorito)
		
		# MODIFICACIÓN: Para meteoritos normales, primero intentar recibir_danio
		# para permitir animaciones de destrucción
		if body.has_method("recibir_danio"):
			body.recibir_danio(danio)
		# Solo si no tienen método para recibir daño, usar destruir directamente
		elif body.has_method("destruir"):
			body.destruir()
		
		# Destruir el proyectil
		queue_free()
	
	# Para otros objetos que no sean la nave o los meteoritos
	elif not body.is_in_group("jugador") and not body.get_collision_layer_value(1):
		queue_free()


func _sumar_puntos(tipo_objeto):
	print("Proyectil: Buscando sistema de puntuación...")
	var puntuacion = get_node_or_null("/root/Puntuacion")
	if puntuacion != null and puntuacion.has_method("sumar_puntos_asteroide"):
		print("Proyectil: Sistema de puntuación encontrado")
		
		# Usar el sistema simple adaptado
		puntuacion.sumar_puntos_asteroide(tipo_objeto)
		print("Proyectil: Puntos añadidos via sistema de puntuación")
	else:
		# Si no encuentra nuestro sistema, intentar con ScoreManager
		print("Proyectil: Sistema de puntuación NO encontrado, intentando ScoreManager...")
		var score_manager = get_node_or_null("/root/ScoreManager")
		if score_manager != null:
			print("Proyectil: ScoreManager encontrado")
			
			# Convertir tipo_objeto a formato que entiende ScoreManager
			var tipo_para_score = "medium"  # Por defecto
			
			if tipo_objeto == "grande":
				tipo_para_score = "large"
			elif tipo_objeto == "ovni":
				tipo_para_score = "large"  # Considerar OVNI como objeto grande
			elif tipo_objeto == "pequeno":
				tipo_para_score = "small"
			
			# Añadir puntos según el tipo de asteroide
			print("Proyectil: Llamando a add_asteroid_points con tipo: " + tipo_para_score)
			score_manager.add_asteroid_points(tipo_para_score)
			print("Proyectil: Puntos añadidos via ScoreManager")
		else:
			# Fallback al sistema antiguo
			print("Proyectil: ScoreManager NO encontrado, intentando sistema antiguo")
			var puntaje_manager = get_node_or_null("/root/PuntajeManager")
			if puntaje_manager != null:
				if puntaje_manager.has_method("destruir_objeto"):
					# Uso el tipo compatible con el sistema antiguo
					var tipo_antiguo = tipo_objeto
					if tipo_objeto == "grande" or tipo_objeto == "mediano" or tipo_objeto == "pequeno":
						tipo_antiguo = "asteroide_" + tipo_objeto
					
					var puntos = puntaje_manager.destruir_objeto(tipo_antiguo)
					print("¡" + tipo_antiguo + " destruido! +" + str(puntos) + " puntos")
				else:
					# Mantener compatibilidad con el sistema antiguo más básico
					puntaje_manager.sumar_puntos()
					print("¡Puntos sumados por colisión!")
			else:
				print("Proyectil: Ningún sistema de puntuación encontrado")


func _integrate_forces(state):
	# Mantener velocidad constante exacta sin importar física
	state.linear_velocity = state.linear_velocity.normalized() * velocidad
	
	# Wrapping por los bordes de la pantalla
	var transform = state.transform
	var screen_size = get_viewport_rect().size
	
	if transform.origin.x < -20:
		transform.origin.x = screen_size.x + 10
	elif transform.origin.x > screen_size.x + 20:
		transform.origin.x = -10
		
	if transform.origin.y < -20:
		transform.origin.y = screen_size.y + 10
	elif transform.origin.y > screen_size.y + 20:
		transform.origin.y = -10
	
	state.transform = transform
