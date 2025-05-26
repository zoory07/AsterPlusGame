extends Label

# Formato para mostrar la puntuación (puedes personalizarlo)
@export var formato_texto = "Puntuacion Final: %d"

# Formato para puntuación alta
@export var formato_record = "¡NUEVO RÉCORD!"

# Color para puntuación normal y récord
@export var color_normal: Color = Color(1, 1, 1, 1)  # Blanco por defecto
@export var color_record: Color = Color(1, 0.8, 0, 1)  # Dorado para récord

# Variable para almacenar la puntuación máxima
var puntuacion_maxima = 0

func _ready():
	# Cargar la puntuación desde el archivo temporal
	var puntuacion_final = cargar_puntuacion_final()
	
	# Cargar la puntuación máxima histórica
	cargar_puntuacion_maxima()
	
	# Establecer el texto con la puntuación
	text = formato_texto % puntuacion_final
	
	# Verificar si es puntuación máxima
	if puntuacion_final > puntuacion_maxima:
		# Guardar nueva puntuación máxima
		puntuacion_maxima = puntuacion_final
		guardar_puntuacion_maxima()
		
		# Mostrar indicador de récord
		text += "\n" + formato_record
		
		# Aplicar estilo de récord
		add_theme_color_override("font_color", color_record)
		
		# Animación para récord
		var tween = create_tween()
		tween.tween_property(self, "scale", Vector2(1.2, 1.2), 0.5)
		tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.5)
	else:
		# Estilo normal
		add_theme_color_override("font_color", color_normal)
	
	# Animación de entrada del texto
	modulate.a = 0 
	var tween_entrada = create_tween()
	tween_entrada.tween_property(self, "modulate:a", 1.0, 0.5).set_delay(0.3)

# Función para cargar la puntuación final
func cargar_puntuacion_final() -> int:
	var puntuacion = 0
	
	if FileAccess.file_exists("user://puntuacion_final.save"):
		var file = FileAccess.open("user://puntuacion_final.save", FileAccess.READ)
		puntuacion = file.get_var()
		
		# Opcional: Eliminar archivo temporal después de usarlo
		file = null
		var dir = DirAccess.open("user://")
		dir.remove("puntuacion_final.save")
	
	return puntuacion

# Guardar la puntuación máxima
func guardar_puntuacion_maxima() -> void:
	var save_data = FileAccess.open("user://puntuacion_maxima.save", FileAccess.WRITE)
	save_data.store_var(puntuacion_maxima)

# Cargar la puntuación máxima
func cargar_puntuacion_maxima() -> void:
	if FileAccess.file_exists("user://puntuacion_maxima.save"):
		var save_data = FileAccess.open("user://puntuacion_maxima.save", FileAccess.READ)
		puntuacion_maxima = save_data.get_var()
