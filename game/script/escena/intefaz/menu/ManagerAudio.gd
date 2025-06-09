extends HSlider

const SFX_BUS = "SFX"  # CAMBIO IMPORTANTE: Usar SFX en lugar de Master
const SAVE_FILE = "user://audio_config.save"
var bus_index: int

func _ready():
	# Configurar slider
	min_value = 0.0
	max_value = 1.0
	step = 0.01
	value = 0.8
	
	# Obtener índice del bus SFX
	bus_index = AudioServer.get_bus_index(SFX_BUS)
	if bus_index == -1:
		# Crear el bus si no existe
		bus_index = AudioServer.bus_count
		AudioServer.add_bus()
		AudioServer.set_bus_name(bus_index, SFX_BUS)
		AudioServer.set_bus_send(bus_index, "Master")
		print("Bus SFX creado")
	
	# Cargar configuración
	cargar_volumen()
	
	# Conectar señal
	value_changed.connect(_on_value_changed)
	
	# Aplicar valor inicial
	_on_value_changed(value)

func _on_value_changed(valor: float):
	# Controlar el volumen del bus SFX
	if valor <= 0.0:
		AudioServer.set_bus_volume_db(bus_index, -80.0)
		AudioServer.set_bus_mute(bus_index, true)
	else:
		AudioServer.set_bus_mute(bus_index, false)
		AudioServer.set_bus_volume_db(bus_index, linear_to_db(valor))
	
	# Guardar
	guardar_volumen()

func guardar_volumen():
	var config = ConfigFile.new()
	config.load(SAVE_FILE)  # Cargar primero para no perder otros valores
	config.set_value("audio", "efectos", value)
	config.save(SAVE_FILE)

func cargar_volumen():
	var config = ConfigFile.new()
	if config.load(SAVE_FILE) == OK:
		value = config.get_value("audio", "efectos", 0.8)
