extends Node

@onready var home = $home
@onready var NaveEspacial = $NaveEspacial
@onready var relax = $relax
@onready var CancionDeEspacio = $CancionDeEspacio

var musicas: Array = []
var musica_actual: AudioStreamPlayer2D = null
var manager_musica: HSlider = null

signal cancion_cambiada(nombre_cancion: String)

func _ready():
	# Buscar el ManagerMusica en el árbol de escenas
	manager_musica = get_node_or_null("/root/Main/UI/ManagerMusica")  # Ajusta la ruta según tu escena
	if not manager_musica:
		# Buscar en todo el árbol si no está en la ruta esperada
		manager_musica = _buscar_manager_musica(get_tree().root)
		if manager_musica:
			print("ManagerMusica encontrado en: " + str(manager_musica.get_path()))
		else:
			push_warning("ManagerMusica no encontrado")
	
	# Verificar que los nodos existan
	if not home or not NaveEspacial or not relax or not CancionDeEspacio:
		push_error("Error: Uno o más AudioStreamPlayer2D no se encontraron")
		return
	
	# Configurar las músicas
	musicas = [home, NaveEspacial, relax, CancionDeEspacio]
	
	# Asegurarse de que todas usen el bus Music
	for musica in musicas:
		musica.bus = "Music"
		# Conectar señal finished para reproducir la siguiente canción
		if not musica.finished.is_connected(_on_musica_terminada):
			musica.finished.connect(_on_musica_terminada.bind(musica))
	
	# Reproducir una música aleatoria
	reproducir_aleatoria()

func _buscar_manager_musica(nodo: Node) -> HSlider:
	if nodo.get_script() != null and nodo is HSlider:
		# Verificar si tiene las propiedades esperadas
		if "MUSIC_BUS" in nodo:
			return nodo
	
	for hijo in nodo.get_children():
		var resultado = _buscar_manager_musica(hijo)
		if resultado:
			return resultado
	
	return null

func reproducir_aleatoria():
	if musicas.is_empty():
		push_error("No hay músicas disponibles")
		return
	
	detener_todo()
	
	var indice_aleatorio = randi() % musicas.size()
	var musica_elegida = musicas[indice_aleatorio]
	
	_reproducir_musica(musica_elegida)

func _reproducir_musica(musica: AudioStreamPlayer2D):
	if musica and musica.stream:
		musica_actual = musica
		musica.play()
		print("Reproduciendo: " + musica.name)
		cancion_cambiada.emit(musica.name)
		
		# Asegurarse de que use el volumen actual del slider
		if manager_musica:
			manager_musica._on_value_changed(manager_musica.value)
	else:
		push_error("La música seleccionada no tiene un stream asignado")

func detener_todo():
	for musica in musicas:
		if musica:
			musica.stop()
	musica_actual = null

func _on_musica_terminada(musica_que_termino: AudioStreamPlayer2D):
	if musica_que_termino == musica_actual:
		# Reproducir siguiente canción aleatoria cuando termine la actual
		reproducir_aleatoria()

# Funciones específicas para cada música
func reproducir_juego():
	detener_todo()
	_reproducir_musica(NaveEspacial)

func reproducir_relax():
	detener_todo()
	_reproducir_musica(relax)

func reproducir_espacio():
	detener_todo()
	_reproducir_musica(CancionDeEspacio)

func reproducir_menu():
	detener_todo()
	_reproducir_musica(home)

# Funciones adicionales útiles
func pausar_musica():
	if musica_actual and musica_actual.playing:
		musica_actual.stream_paused = true

func reanudar_musica():
	if musica_actual:
		musica_actual.stream_paused = false

func get_musica_actual() -> String:
	if musica_actual:
		return musica_actual.name
	return ""

func cambiar_siguiente():
	if musicas.is_empty():
		return
	
	var indice_actual = -1
	if musica_actual:
		indice_actual = musicas.find(musica_actual)
	
	var siguiente_indice = (indice_actual + 1) % musicas.size()
	detener_todo()
	_reproducir_musica(musicas[siguiente_indice])

func cambiar_anterior():
	if musicas.is_empty():
		return
	
	var indice_actual = -1
	if musica_actual:
		indice_actual = musicas.find(musica_actual)
	
	var anterior_indice = indice_actual - 1
	if anterior_indice < 0:
		anterior_indice = musicas.size() - 1
	
	detener_todo()
	_reproducir_musica(musicas[anterior_indice])
