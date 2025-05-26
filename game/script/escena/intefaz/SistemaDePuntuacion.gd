extends Control

var numero_label: Label  # Etiqueta para mostrar la puntuación
var puntuacion: int = 0  # Puntuación actual
var puntuacion_maxima: int = 0  # Puntuación máxima

var sumar_puntos_habilitado = true

# NUEVO: Lista de objetos marcados como "no sumables"
var objetos_bloqueados = []

# SOLUCIÓN EXTREMA: Registrar los últimos impactos OVNI
var ultimo_impacto_ovni_tiempo = 0
var bloqueo_temporal_activo = false
var contador_llamadas = 0  # Para depuración

# Valores de puntos para diferentes tipos de asteroides
var puntos_asteroides = {
	"grande": 20,    # Asteroides grandes valen 20 puntos
	"mediano": 10,   # Asteroides medianos valen 50 puntos
	"pequeno": 5     # Asteroides pequeños valen 10 puntos
}

# Señales
signal puntuacion_cambiada(nueva_puntuacion)
signal nueva_puntuacion_maxima(nueva_maxima)

func _ready():
	# Registrarse en grupos para ser fácilmente encontrado
	add_to_group("sistemas_puntuacion")
	
	# Buscar específicamente nuestro Label
	encontrar_label_especifico()
	
	# Cargar puntuación máxima
	cargar_puntuacion_maxima()
	
	# Inicializar la puntuación
	actualizar_puntuacion_display()
	
	# Registrar nuestra existencia
	print("SISTEMA DE PUNTUACIÓN: Inicializado correctamente")
	print("SISTEMA DE PUNTUACIÓN: Nombre del nodo: " + name)
	
	# Timer para limpiar referencias inválidas periódicamente
	var timer_limpieza = Timer.new()
	timer_limpieza.wait_time = 5.0  # Cada 5 segundos
	timer_limpieza.autostart = true
	timer_limpieza.timeout.connect(limpiar_objetos_bloqueados)
	add_child(timer_limpieza)
	
	# Timer para verificar el bloqueo temporal
	var timer_bloqueo = Timer.new()
	timer_bloqueo.wait_time = 0.1  # Verificar cada 0.1 segundos
	timer_bloqueo.autostart = true
	timer_bloqueo.timeout.connect(verificar_bloqueo_temporal)
	add_child(timer_bloqueo)

# NUEVA FUNCIÓN: Bloquear puntuación para un objeto específico
func bloquear_puntuacion_objeto(objeto):
	contador_llamadas += 1
	print("SISTEMA DE PUNTUACIÓN: Llamada #" + str(contador_llamadas) + " a bloquear_puntuacion_objeto")
	
	# SOLUCIÓN EXTREMA: Activar bloqueo temporal global
	ultimo_impacto_ovni_tiempo = Time.get_ticks_msec()
	bloqueo_temporal_activo = true
	print("SISTEMA DE PUNTUACIÓN: Bloqueo temporal activado por 0.5 segundos")
	
	if objeto and is_instance_valid(objeto):
		# Verificar si el objeto ya está bloqueado
		if not objeto in objetos_bloqueados:
			objetos_bloqueados.append(objeto)
			print("SISTEMA DE PUNTUACIÓN: Objeto bloqueado para puntuación: ", objeto)
			
			# Marcar el objeto directamente si es posible
			if "impactado_por_ovni" in objeto:
				objeto.impactado_por_ovni = true
				print("SISTEMA DE PUNTUACIÓN: Objeto marcado con impactado_por_ovni = true")
				
			# Añadir el objeto al grupo de objetos bloqueados
			if objeto.has_method("add_to_group") and not objeto.is_in_group("impactado_por_ovni"):
				objeto.add_to_group("impactado_por_ovni")
				print("SISTEMA DE PUNTUACIÓN: Objeto añadido al grupo impactado_por_ovni")
				
			return true
	return false

# FUNCIÓN PARA VERIFICAR EL BLOQUEO TEMPORAL
func verificar_bloqueo_temporal():
	if bloqueo_temporal_activo:
		var tiempo_actual = Time.get_ticks_msec()
		if tiempo_actual - ultimo_impacto_ovni_tiempo > 1000:  # 1000 ms = 1 segundo - AUMENTADO
			bloqueo_temporal_activo = false
			print("SISTEMA DE PUNTUACIÓN: Bloqueo temporal desactivado")

# NUEVA FUNCIÓN: Comprobar si un objeto está bloqueado para sumar puntos
func esta_objeto_bloqueado(objeto = null):
	# SOLUCIÓN EXTREMA: Si hay bloqueo temporal, bloquear todo
	if bloqueo_temporal_activo:
		print("SISTEMA DE PUNTUACIÓN: Bloqueo temporal activo - no se suman puntos")
		return true
		
	# Si no se especifica objeto, solo verificar bloqueo temporal
	if objeto == null:
		return bloqueo_temporal_activo
		
	# Verificar si el objeto está en nuestra lista de bloqueados
	if objeto in objetos_bloqueados:
		print("SISTEMA DE PUNTUACIÓN: Objeto en lista de bloqueados")
		return true
	
	# Verificar otros posibles motivos de bloqueo
	var bloqueado = false
	
	# Verificar si es un fragmento (debería estar siempre bloqueado)
	if objeto.has_method("is_in_group") and objeto.is_in_group("particula_meteorito"):
		print("SISTEMA DE PUNTUACIÓN: Objeto es un fragmento - bloqueado")
		return true
		
	# Verificar si el objeto tiene la propiedad impactado_por_ovni
	if objeto and is_instance_valid(objeto):
		if "impactado_por_ovni" in objeto and objeto.impactado_por_ovni:
			print("SISTEMA DE PUNTUACIÓN: Objeto tiene impactado_por_ovni = true")
			bloqueado = true
			
		# Verificar si el objeto está en el grupo impactado_por_ovni
		if objeto.has_method("is_in_group") and objeto.is_in_group("impactado_por_ovni"):
			print("SISTEMA DE PUNTUACIÓN: Objeto en grupo impactado_por_ovni")
			bloqueado = true
			
		# Verificar metadata como respaldo
		if objeto.has_method("has_meta") and objeto.has_meta("impactado_por_ovni") and objeto.get_meta("impactado_por_ovni"):
			print("SISTEMA DE PUNTUACIÓN: Objeto tiene metadata impactado_por_ovni = true")
			bloqueado = true
	
	# Si está bloqueado y no estaba en la lista, agregarlo
	if bloqueado and not (objeto in objetos_bloqueados):
		objetos_bloqueados.append(objeto)
		print("SISTEMA DE PUNTUACIÓN: Objeto añadido a lista de bloqueados")
		
	return bloqueado

# NUEVA FUNCIÓN: Limpiar objetos bloqueados inválidos
func limpiar_objetos_bloqueados():
	var objetos_a_eliminar = []
	
	for objeto in objetos_bloqueados:
		if not is_instance_valid(objeto):
			objetos_a_eliminar.append(objeto)
	
	for objeto in objetos_a_eliminar:
		objetos_bloqueados.erase(objeto)
		
	if objetos_a_eliminar.size() > 0:
		print("SISTEMA DE PUNTUACIÓN: Limpiados ", objetos_a_eliminar.size(), " objetos inválidos")

# Función para encontrar específicamente el Label que necesitamos
func encontrar_label_especifico():
	# PRIMERO: Buscar directamente con rutas conocidas
	var posibles_rutas = [
		"HBoxContainer/numero", 
		"HBoxContainer/Numero", 
		"HBoxContainer/score", 
		"HBoxContainer/Score",
		"numero",
		"Numero",
		"score",
		"Score"
	]
	
	for ruta in posibles_rutas:
		if has_node(ruta):
			numero_label = get_node(ruta)
			if numero_label is Label:
				print("SISTEMA DE PUNTUACIÓN: Label encontrado en ruta: " + ruta)
				return
	
	# SEGUNDO: Buscar cualquier Label que pueda servir
	print("SISTEMA DE PUNTUACIÓN: Buscando cualquier Label disponible...")
	numero_label = buscar_primer_label(self)
	
	if numero_label:
		print("SISTEMA DE PUNTUACIÓN: Label encontrado: " + numero_label.name)
	else:
		print("SISTEMA DE PUNTUACIÓN: ADVERTENCIA - No se encontró ningún Label en la escena")
		print("Por favor, verifica que tienes un Label en tu escena para mostrar la puntuación")

# Función recursiva para buscar el primer Label disponible
func buscar_primer_label(nodo):
	# Si este nodo es un Label, lo usamos
	if nodo is Label:
		return nodo
	
	# Si no, buscamos en sus hijos
	for hijo in nodo.get_children():
		var resultado = buscar_primer_label(hijo)
		if resultado != null:
			return resultado
	
	# Si no encontramos nada, retornamos null
	return null

# Función para añadir puntos
func sumar_puntos(cantidad: int) -> void:
	# SOLUCIÓN EXTREMA: Verificar si hay bloqueo temporal
	if bloqueo_temporal_activo:
		print("SISTEMA DE PUNTUACIÓN: No se suman puntos debido a bloqueo temporal")
		return
		
	puntuacion += cantidad
	print("SISTEMA DE PUNTUACIÓN: Puntos sumados: +" + str(cantidad) + ", Total: " + str(puntuacion))
	actualizar_puntuacion_display()
	emit_signal("puntuacion_cambiada", puntuacion)
	
	# Verificar si superamos la puntuación máxima
	if puntuacion > puntuacion_maxima:
		puntuacion_maxima = puntuacion
		emit_signal("nueva_puntuacion_maxima", puntuacion_maxima)
		guardar_puntuacion_maxima()
		mostrar_efecto_nueva_maxima()

# Función para añadir puntos según el tipo de asteroide
func sumar_puntos_asteroide(tipo: String, objeto = null) -> void:
	# VERIFICACIÓN EXTREMA: Verificar bloqueo temporal primero
	if bloqueo_temporal_activo:
		print("SISTEMA DE PUNTUACIÓN: No se suman puntos (bloqueo temporal activo)")
		return
		
	# VERIFICACIÓN: Comprobar si el objeto está bloqueado
	if objeto != null:
		# VERIFICACIÓN ADICIONAL: Si el objeto es un fragmento, nunca debería sumar puntos
		if objeto.has_method("is_in_group") and objeto.is_in_group("particula_meteorito"):
			print("SISTEMA DE PUNTUACIÓN: Objeto es un fragmento, no suma puntos")
			return
			
		if esta_objeto_bloqueado(objeto):
			print("SISTEMA DE PUNTUACIÓN: Objeto bloqueado para puntuación, ignorando")
			return
			
		# VERIFICACIÓN DE MUNICIONES OVNI CERCANAS
		var municiones_ovni = get_tree().get_nodes_in_group("municion_ovni")
		for municion in municiones_ovni:
			if municion and is_instance_valid(municion):
				if objeto.global_position.distance_to(municion.global_position) < 100:
					print("SISTEMA DE PUNTUACIÓN: Munición OVNI cercana detectada, bloqueando puntos")
					bloquear_puntuacion_objeto(objeto)
					return
	
	# Verificar si la suma de puntos está habilitada
	if not sumar_puntos_habilitado:
		print("SISTEMA DE PUNTUACIÓN: Suma de puntos deshabilitada, ignorando.")
		return
		
	# Continuar con la lógica original...
	if puntos_asteroides.has(tipo):
		var puntos = puntos_asteroides[tipo]
		print("SISTEMA DE PUNTUACIÓN: Asteroide " + tipo + " destruido: +" + str(puntos) + " puntos")
		sumar_puntos(puntos)
		mostrar_efecto_puntos(puntos)
	else:
		print("SISTEMA DE PUNTUACIÓN: Tipo de asteroide desconocido: " + tipo)
		# Valor predeterminado si el tipo no está en el diccionario
		sumar_puntos(5) 

# Obtener la puntuación actual
func obtener_puntuacion() -> int:
	return puntuacion

# Obtener la puntuación máxima
func obtener_puntuacion_maxima() -> int:
	return puntuacion_maxima

# Efecto visual para puntos ganados
func mostrar_efecto_puntos(puntos: int) -> void:
	if not is_instance_valid(numero_label):
		return
		
	var etiqueta = Label.new()
	etiqueta.text = "+" + str(puntos)
	
	# Copiar todas las propiedades de fuente del label principal
	if numero_label.has_theme_font_override("font"):
		etiqueta.add_theme_font_override("font", numero_label.get_theme_font("font"))
	
	if numero_label.has_theme_font_size_override("font_size"):
		etiqueta.add_theme_font_size_override("font_size", numero_label.get_theme_font_size("font_size"))
	
	# Copiar cualquier otra propiedad de estilo relevante
	if numero_label.has_theme_constant_override("line_spacing"):
		etiqueta.add_theme_constant_override("line_spacing", numero_label.get_theme_constant("line_spacing"))
	
	# Copiar el estilo de fuente si existe
	if numero_label.has_theme_stylebox_override("normal"):
		etiqueta.add_theme_stylebox_override("normal", numero_label.get_theme_stylebox("normal"))
	
	# Color amarillo para destacar
	etiqueta.add_theme_color_override("font_color", Color(1, 1, 0))
	
	# Añadir la etiqueta al nodo de puntuación
	add_child(etiqueta)
	
	# Posicionar cerca del contador
	etiqueta.position = Vector2(numero_label.position.x + 50, numero_label.position.y)
	
	var tween = create_tween()
	tween.tween_property(etiqueta, "position", etiqueta.position + Vector2(0, -30), 1.0)
	tween.parallel().tween_property(etiqueta, "modulate", Color(1, 1, 0, 0), 1.0)
	tween.tween_callback(etiqueta.queue_free)

# Efecto para nueva puntuación máxima
func mostrar_efecto_nueva_maxima() -> void:
	if not is_instance_valid(numero_label):
		return
		
	var tween = create_tween()
	tween.tween_property(numero_label, "modulate", Color(1, 1, 0), 0.1)  # Amarillo
	tween.tween_property(numero_label, "modulate", Color(1, 1, 1), 0.1)  # Blanco
	tween.tween_property(numero_label, "modulate", Color(1, 1, 0), 0.1)  # Amarillo
	tween.tween_property(numero_label, "modulate", Color(1, 1, 1), 0.1)  # Blanco

# NUEVA FUNCIÓN ESTÁTICA: Bloquear temporalmente toda la puntuación
static func bloquear_puntuacion_global():
	var sistemas = Engine.get_main_loop().get_root().get_tree().get_nodes_in_group("sistemas_puntuacion")
	for sistema in sistemas:
		if sistema.has_method("activar_bloqueo_temporal"):
			sistema.activar_bloqueo_temporal()

func limpiar_registro_completo():
	objetos_bloqueados.clear()
	bloqueo_temporal_activo = false
	ultimo_impacto_ovni_tiempo = 0
	print("SISTEMA DE PUNTUACIÓN: Registro completo limpiado")

# CORRECCIÓN: Mejorar la función activar_bloqueo_temporal
func activar_bloqueo_temporal():
	bloqueo_temporal_activo = true
	ultimo_impacto_ovni_tiempo = Time.get_ticks_msec()
	print("SISTEMA DE PUNTUACIÓN: Bloqueo temporal activado por 1 segundo")
	
	# MEJORA: Buscar todos los meteoritos cercanos a municiones OVNI y bloquearlos
	var municiones_ovni = get_tree().get_nodes_in_group("municion_ovni")
	var meteoritos = get_tree().get_nodes_in_group("meteorito")
	
	for municion in municiones_ovni:
		if not is_instance_valid(municion):
			continue
			
		for meteorito in meteoritos:
			if not is_instance_valid(meteorito):
				continue
func actualizar_puntuacion_display() -> void:
	if numero_label:
		print("SISTEMA DE PUNTUACIÓN: Actualizando label con puntuación: " + str(puntuacion))
		# Mostrar "Puntos: X" en lugar de solo el número
		numero_label.text = "Puntos: " + str(puntuacion)
	else:
		print("SISTEMA DE PUNTUACIÓN: Error - numero_label es null, no se puede mostrar la puntuación")

# Guardar la puntuación máxima
func guardar_puntuacion_maxima() -> void:
	var save_data = FileAccess.open("user://puntuacion_maxima.save", FileAccess.WRITE)
	save_data.store_var(puntuacion_maxima)

# Cargar la puntuación máximaa
func cargar_puntuacion_maxima() -> void:
	if FileAccess.file_exists("user://puntuacion_maxima.save"):
		var save_data = FileAccess.open("user://puntuacion_maxima.save", FileAccess.READ)
		puntuacion_maxima = save_data.get_var()
