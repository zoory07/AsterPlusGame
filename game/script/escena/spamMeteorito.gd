extends Node2D

# Prefab del meteorito a instanciar
@export var meteorito_escena: PackedScene
@export var max_meteoritos = 999
@export var meteoritos_iniciales = 30

# Variable para controlar distancia mínima al jugador
@export var distancia_minima_jugador = 150.0  # Distancia mínima para generar nuevos meteoritos

# Variables para controlar el spawn
var meteoritos_activos = 0
var viewport_rect: Rect2
var rng = RandomNumberGenerator.new()
var tiempo_ultima_generacion = 0
var intervalo_generacion = 0  # Se establecerá aleatoriamente

# Referencia al jugador
var jugador: Node2D = null

# Nodo para agrupar todos los meteoritos
var contenedor_meteoritos: Node
var debe_generar_meteoritos = true

func _ready():
	rng.randomize()
	viewport_rect = get_viewport_rect()
	
	# Crear contenedor para meteoritos
	contenedor_meteoritos = Node.new()
	contenedor_meteoritos.name = "Meteoritos"
	add_child(contenedor_meteoritos)
	
	# Encontrar al jugador en la escena
	# Esto asume que el jugador está en el grupo "jugador"
	await get_tree().process_frame  # Esperar un frame para que todo esté inicializado
	var jugadores = get_tree().get_nodes_in_group("jugador")
	if jugadores.size() > 0:
		jugador = jugadores[0]
	else:
		print("Advertencia: No se encontró al jugador en el grupo 'jugador'")
	
	# Generar oleada inicial (sin restricción de distancia)
	generar_oleada_inicial(meteoritos_iniciales)
	
	# Establecer un intervalo inicial aleatorio
	_resetear_intervalo_generacion()

func _process(delta):
	# Actualizar temporizador
	tiempo_ultima_generacion += delta
	
	# Verificar si es momento de generar un meteorito
	if meteoritos_activos < max_meteoritos and debe_generar_meteoritos and tiempo_ultima_generacion > intervalo_generacion:
		# Intentar generar un meteorito lejos del jugador
		if _intentar_generar_meteorito_lejos():
			# Reiniciar temporizador y establecer nuevo intervalo aleatorio
			tiempo_ultima_generacion = 0
			_resetear_intervalo_generacion()

# Establece un nuevo intervalo aleatorio para la generación
func _resetear_intervalo_generacion():
	# Intervalo entre 5 y 12 segundos para que sea menos predecible
	intervalo_generacion = rng.randf_range(5.0, 12.0)

# Intenta generar un meteorito lejos del jugador
func _intentar_generar_meteorito_lejos() -> bool:
	# Si no tenemos referencia al jugador, generar normalmente
	if not jugador:
		_spawn_meteorito(_obtener_posicion_spawn())
		return true
	
	# Hacer varios intentos para encontrar una posición adecuada
	for _intento in range(5):  # 5 intentos máximo
		var pos = _obtener_posicion_spawn()
		
		# Verificar si está lo suficientemente lejos del jugador
		if jugador.global_position.distance_to(pos) >= distancia_minima_jugador:
			_spawn_meteorito(pos)
			return true
	
	# Si todos los intentos fallaron, no generamos meteorito
	return false

# Genera la oleada inicial sin restricciones de distancia
func generar_oleada_inicial(cantidad: int):
	for i in range(cantidad):
		if meteoritos_activos < max_meteoritos:
			_spawn_meteorito(_obtener_posicion_spawn())
			await get_tree().create_timer(0.05).timeout

func _spawn_meteorito(pos: Vector2):
	var meteorito = meteorito_escena.instantiate()
	
	# Configurar física básica
	meteorito.gravity_scale = 0.0
	meteorito.contact_monitor = true
	meteorito.max_contacts_reported = 4
	
	# Posicionar el meteorito en la posición dada
	meteorito.position = pos
	
	# Dirección con variación hacia un punto aleatorio en la pantalla
	# Evitamos apuntar directamente al jugador
	var target_pos
	if jugador and randf() < 0.7:  # 70% de las veces evitamos al jugador
		# Encontrar un punto que no esté cerca del jugador
		var angulo = rng.randf_range(0, 2 * PI)
		var distancia = rng.randf_range(100, 300)
		target_pos = Vector2(
			viewport_rect.size.x/2 + cos(angulo) * distancia,
			viewport_rect.size.y/2 + sin(angulo) * distancia
		)
	else:
		# Punto aleatorio en la pantalla
		target_pos = Vector2(
			rng.randf_range(100, viewport_rect.size.x - 100),
			rng.randf_range(100, viewport_rect.size.y - 100)
		)
	
	var direccion = (target_pos - pos).normalized()
	direccion = direccion.rotated(rng.randf_range(-0.3, 0.3))
	
	# Aplicar velocidad y rotación
	var velocidad = rng.randf_range(60, 120)
	meteorito.linear_velocity = direccion * velocidad
	meteorito.angular_velocity = rng.randf_range(-2, 2)
	
	# Aplicar tamaño aleatorio
	var escala = rng.randf_range(0.7, 1.5)
	meteorito.scale = Vector2(escala, escala)
	
	# Configurar colisiones
	meteorito.collision_layer = 2  # Capa para meteoritos
	meteorito.collision_mask = 1 | 4  # Colisiona con jugador (1) y proyectiles (4)
	
	# Asegurarnos de que esté en el grupo meteorito
	meteorito.add_to_group("meteorito")
	
	# Conectar señal para cuando el meteorito sea destruido
	if not meteorito.is_connected("tree_exited", _on_meteorito_destruido):
		meteorito.connect("tree_exited", _on_meteorito_destruido)
	
	# Configurar detector para salida de pantalla
	_configurar_notificador_pantalla(meteorito)
	
	# Agregar el meteorito al contenedor
	contenedor_meteoritos.add_child(meteorito)
	meteoritos_activos += 1

func _obtener_posicion_spawn() -> Vector2:
	var pos = Vector2()
	var margen = 50
	
	var lado = rng.randi_range(0, 3)
	
	match lado:
		0:  # Arriba
			pos.x = rng.randf_range(0, viewport_rect.size.x)
			pos.y = -margen
		1:  # Derecha
			pos.x = viewport_rect.size.x + margen
			pos.y = rng.randf_range(0, viewport_rect.size.y)
		2:  # Abajo
			pos.x = rng.randf_range(0, viewport_rect.size.x)
			pos.y = viewport_rect.size.y + margen
		3:  # Izquierda
			pos.x = -margen
			pos.y = rng.randf_range(0, viewport_rect.size.y)
	
	return pos

func _configurar_notificador_pantalla(meteorito):
	if meteorito.has_node("ScreenNotifier"):
		return  # Ya tiene el notificador, no necesitamos duplicarlo
		
	var notifier = VisibleOnScreenNotifier2D.new()
	notifier.name = "ScreenNotifier"
	
	var pantalla_expandida = Rect2(
		-200, -200,
		viewport_rect.size.x + 400,
		viewport_rect.size.y + 400
	)
	notifier.rect = pantalla_expandida
	
	notifier.connect("screen_exited", _on_meteorito_muy_lejos.bind(meteorito))
	
	meteorito.add_child(notifier)

func _on_meteorito_destruido():
	meteoritos_activos -= 1

func _on_meteorito_muy_lejos(meteorito):
	meteorito.queue_free()

# Generar una oleada adicional en posiciones aleatorias
func generar_oleada_extra(cantidad := 5, con_retraso := true):
	for i in range(cantidad):
		if meteoritos_activos < max_meteoritos:
			_spawn_meteorito(_obtener_posicion_spawn())
			if con_retraso:
				await get_tree().create_timer(0.05).timeout

# Control de generación
func pausar_generacion():
	debe_generar_meteoritos = false

func reanudar_generacion():
	debe_generar_meteoritos = true
