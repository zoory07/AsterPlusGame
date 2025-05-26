extends Control

# Variables para el sistema de vidas
var vidas_actuales = 3  # Número inicial de vidas
var iconos_vida = []    # Este array se llenará con los iconos creados dinámicamente

# Señales
signal sin_vidas  # Se emite cuando se pierden todas las vidas
signal vida_perdida(vidas_restantes)  # Se emite cuando se pierde una vida

# Contenedor para los iconos
var container = null

# Personalización de iconos
@export var usar_texturas_existentes: bool = true  # Si es true, usará los iconos que ya existen en la escena
@export var textura_icono: Texture2D  # Textura a usar para los iconos de vida
@export var tamanio_icono: Vector2 = Vector2(30, 30)  # Tamaño de los iconos

func _ready():
	print("SISTEMA VIDAS: Iniciando...")
	
	# Registrarse en un grupo para ser encontrado fácilmente
	add_to_group("sistema_vida")
	
	# Usar los iconos existentes si están disponibles
	if usar_texturas_existentes and tiene_iconos_existentes():
		print("SISTEMA VIDAS: Usando iconos existentes")
		container = $CanvasLayer/HBoxContainer
		obtener_iconos_existentes()
	else:
		# Crear contenedor para los iconos si no existe
		container = crear_contenedor()
		
		# Crear los iconos dinámicamente
		crear_iconos_vida()
	
	print("SISTEMA VIDAS: Inicializado con " + str(vidas_actuales) + " vidas")

# Verificar si ya tiene iconos en la escena
func tiene_iconos_existentes() -> bool:
	if has_node("CanvasLayer/HBoxContainer/IconVida1"):
		return true
	return false

# Obtener los iconos existentes en la escena
func obtener_iconos_existentes():
	iconos_vida.clear()
	
	# Intentar obtener los tres iconos
	if has_node("CanvasLayer/HBoxContainer/IconVida1"):
		iconos_vida.append($CanvasLayer/HBoxContainer/IconVida1)
	
	if has_node("CanvasLayer/HBoxContainer/IconVida2"):
		iconos_vida.append($CanvasLayer/HBoxContainer/IconVida2)
	
	if has_node("CanvasLayer/HBoxContainer/IconVida3"):
		iconos_vida.append($CanvasLayer/HBoxContainer/IconVida3)
	
	# Mostrar todos los iconos
	for icono in iconos_vida:
		icono.visible = true
	
	print("SISTEMA VIDAS: Se encontraron " + str(iconos_vida.size()) + " iconos existentes")

# Crear o encontrar el contenedor para los iconos
func crear_contenedor():
	# Verificar si ya tenemos un HBoxContainer
	var hbox = get_node_or_null("CanvasLayer/HBoxContainer")
	if hbox:
		print("SISTEMA VIDAS: Contenedor HBoxContainer encontrado")
		return hbox
		
	# Si no hay CanvasLayer, créalo
	var canvas = get_node_or_null("CanvasLayer")
	if not canvas:
		canvas = CanvasLayer.new()
		canvas.name = "CanvasLayer"
		add_child(canvas)
		print("SISTEMA VIDAS: CanvasLayer creado")
	
	# Crear HBoxContainer
	var nuevo_hbox = HBoxContainer.new()
	nuevo_hbox.name = "HBoxContainer"
	# Configurar posición y tamaño
	nuevo_hbox.position = Vector2(10, 10)
	nuevo_hbox.add_theme_constant_override("separation", 5)
	canvas.add_child(nuevo_hbox)
	
	print("SISTEMA VIDAS: Nuevo contenedor HBoxContainer creado")
	return nuevo_hbox

# Crear iconos de vida dinámicamente
func crear_iconos_vida():
	# Limpiar array por si acaso
	iconos_vida.clear()
	
	# Eliminar iconos existentes en el contenedor
	for child in container.get_children():
		child.queue_free()
	
	# Crear nuevos iconos
	for i in range(3):
		var icono = crear_icono_vida(i)
		container.add_child(icono)
		iconos_vida.append(icono)
		print("SISTEMA VIDAS: Icono " + str(i+1) + " creado")
	
	# Actualizar visibilidad basada en vidas actuales
	actualizar_visibilidad_iconos()

# Crear un único icono de vida usando sprite
func crear_icono_vida(indice):
	var icono
	
	# Si hay una textura asignada, usar TextureRect
	if textura_icono:
		icono = TextureRect.new()
		icono.name = "IconVida" + str(indice+1)
		icono.texture = textura_icono
		icono.expand = true
		icono.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icono.custom_minimum_size = tamanio_icono
	else:
		# Intentar cargar la textura del icono de Godot como fallback
		var textura_default = load("res://icon.png")
		
		if textura_default:
			icono = TextureRect.new()
			icono.name = "IconVida" + str(indice+1)
			icono.texture = textura_default
			icono.expand = true
			icono.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icono.custom_minimum_size = tamanio_icono
		else:
			# Si todo falla, crear un rectángulo rojo
			icono = ColorRect.new()
			icono.name = "IconVida" + str(indice+1)
			icono.custom_minimum_size = tamanio_icono
			icono.color = Color(1, 0, 0)  # Rojo
	
	return icono

# Actualizar visibilidad de los iconos basada en vidas actuales
func actualizar_visibilidad_iconos():
	# Verificar que tengamos iconos
	if iconos_vida.size() == 0:
		print("SISTEMA VIDAS: No hay iconos para actualizar")
		return
	
	# Asegurarse de que cada icono tenga la visibilidad correcta
	for i in range(iconos_vida.size()):
		if i < vidas_actuales:
			iconos_vida[i].visible = true
		else:
			iconos_vida[i].visible = false
	
	print("SISTEMA VIDAS: Visibilidad de iconos actualizada")

# Perder una vida cuando colisiona con meteorito
func perder_vida() -> bool:
	print("SISTEMA VIDAS: Función perder_vida() llamada, vidas actuales: " + str(vidas_actuales))
	
	if vidas_actuales <= 0:
		return false  # Ya no hay vidas
	
	# Reducir contador de vidas
	vidas_actuales -= 1
	
	# Actualizar visibilidad de los iconos
	actualizar_visibilidad_iconos()
	
	# Emitir señal
	emit_signal("vida_perdida", vidas_actuales)
	
	# Verificar si quedan vidas
	if vidas_actuales <= 0:
		print("SISTEMA VIDAS: ¡Sin vidas! Game Over")
		emit_signal("sin_vidas")
		return false
	
	return true  # Aún quedan vidas

# Ganar una vida adicional (hasta un máximo de 3)
func ganar_vida():
	if vidas_actuales >= 3:
		print("SISTEMA VIDAS: Ya tienes el máximo de vidas (3)")
		return
	
	# Aumentar contador
	vidas_actuales += 1
	
	# Actualizar visibilidad de los iconos
	actualizar_visibilidad_iconos()
	
	print("SISTEMA VIDAS: Vida ganada, ahora tienes " + str(vidas_actuales))

# Reiniciar el sistema de vidas
func reiniciar():
	vidas_actuales = 3
	actualizar_visibilidad_iconos()
	print("SISTEMA VIDAS: Sistema reiniciado con 3 vidas")

# Obtener el número actual de vidas
func obtener_vidas() -> int:
	return vidas_actuales
