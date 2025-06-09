# ManagerMusica.gd - Control de volumen
extends HSlider

const MUSIC_BUS = "Music"
const SAVE_FILE = "user://audio_config.save"
var bus_index01: int

func _ready():
	# Configurar slider
	min_value = 0.0
	max_value = 1.0
	step = 0.01
	value = 0.8
	
	# Obtener bus de audio
	bus_index01 = AudioServer.get_bus_index(MUSIC_BUS)
	if bus_index01 == -1:
		# Crear el bus si no existe
		bus_index01 = AudioServer.bus_count
		AudioServer.add_bus()
		AudioServer.set_bus_name(bus_index01, MUSIC_BUS)
		# Asegurarse de que el bus Music envíe audio al Master
		AudioServer.set_bus_send(bus_index01, "Master")
		print("Bus 'Music' creado")
	
	# Cargar configuración guardada
	cargar_volumen()
	
	# Conectar señal
	value_changed.connect(_on_value_changed)
	
	# Aplicar valor inicial
	_on_value_changed(value)

func _on_value_changed(valor: float):
	if valor <= 0.0:
		AudioServer.set_bus_volume_db(bus_index01, -80.0)
		AudioServer.set_bus_mute(bus_index01, true)
	else:
		AudioServer.set_bus_mute(bus_index01, false)
		AudioServer.set_bus_volume_db(bus_index01, linear_to_db(valor))

func guardar_volumen():
	var config = ConfigFile.new()
	config.set_value("audio", "musica", value)
	config.save(SAVE_FILE)

func cargar_volumen():
	var config = ConfigFile.new()
	if config.load(SAVE_FILE) == OK:
		value = config.get_value("audio", "musica", 0.8)

# Método adicional para obtener el volumen actual
func get_volumen_actual() -> float:
	return value

# ========================================
