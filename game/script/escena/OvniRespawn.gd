extends Node2D

@export var escena_ovni: PackedScene
# Límites de la pantalla para el spawn (aumentado para que aparezcan más lejos)
@export var margen_pantalla = 99  # Aumentado considerablemente
@export var max_ovnis = 999
# Tiempo del ciclo de generación (en segundos)
@export var tiempo_ciclo = 15.0
# Variables internas
var timer_ciclo
var tamaño_pantalla
var rng = RandomNumberGenerator.new()

func _ready():
	# Obtener el tamaño de la pantalla
	tamaño_pantalla = get_viewport_rect().size
	
	# Inicializar el generador de números aleatorios
	rng.randomize()
	
	# Configurar el temporizador cíclico
	timer_ciclo = Timer.new()
	timer_ciclo.wait_time = tiempo_ciclo
	timer_ciclo.one_shot = false  # Cambiado a false para que se repita
	timer_ciclo.autostart = true
	timer_ciclo.timeout.connect(_on_timer_ciclo_timeout)
	add_child(timer_ciclo)
	
	print("El primer OVNI aparecerá en " + str(tiempo_ciclo) + " segundos")

func _on_timer_ciclo_timeout():  # Corregido con guion bajo
	# Verificar si podemos generar un OVNI según la cantidad máxima
	var ovnis_actuales = get_tree().get_nodes_in_group("ovnis").size()
	
	if ovnis_actuales < max_ovnis:
		generar_ovni()
		print("¡Generando OVNI! Próximo OVNI en " + str(tiempo_ciclo) + " segundos")
	else:
		print("Máximo de OVNIs alcanzado. No se generará uno nuevo.")

func generar_ovni():
	# Crear una nueva instancia del ovni
	var nuevo_ovni = escena_ovni.instantiate()
	
	# Posicionar el ovni en un borde aleatorio, pero mucho más alejado
	var posicion = Vector2.ZERO
	var borde = rng.randi() % 4  # 0: arriba, 1: derecha, 2: abajo, 3: izquierda
	
	match borde:
		0:  # Arriba
			posicion.x = rng.randf_range(-100, tamaño_pantalla.x + 100)
			posicion.y = -margen_pantalla
		1:  # Derecha
			posicion.x = tamaño_pantalla.x + margen_pantalla
			posicion.y = rng.randf_range(-100, tamaño_pantalla.y + 100)
		2:  # Abajo
			posicion.x = rng.randf_range(-100, tamaño_pantalla.x + 100)
			posicion.y = tamaño_pantalla.y + margen_pantalla
		3:  # Izquierda
			posicion.x = -margen_pantalla
			posicion.y = rng.randf_range(-100, tamaño_pantalla.y + 100)
	
	# Establecer la posición del ovni
	nuevo_ovni.global_position = posicion
	
	# Añadir el ovni al grupo "ovnis" para poder contarlos
	nuevo_ovni.add_to_group("ovnis")
	
	# Añadir el ovni a la escena
	add_child(nuevo_ovni)
	
	# Hacer que el OVNI apunte hacia un punto aleatorio dentro de la pantalla
	# para crear trayectorias más variadas y naturales
	var punto_destino = Vector2(
		rng.randf_range(tamaño_pantalla.x * 0.2, tamaño_pantalla.x * 0.8),
		rng.randf_range(tamaño_pantalla.y * 0.2, tamaño_pantalla.y * 0.8)
	)
	var direccion = (punto_destino - posicion).normalized()
	var angulo = direccion.angle()
	nuevo_ovni.rotation = angulo
	
	# Si el OVNI tiene un script con direccion_inicial, actualizar esa variable también
	if nuevo_ovni.has_method("get") and nuevo_ovni.get("direccion_inicial") != null:
		nuevo_ovni.direccion_inicial = direccion
