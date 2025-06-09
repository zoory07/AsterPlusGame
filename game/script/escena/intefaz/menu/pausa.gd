extends CanvasLayer

var en_opciones = false  # Variable para controlar si estamos en opciones

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	ocultar_menu_pausa()
	
func _physics_process(delta):
	if Input.is_action_just_pressed("pausa"):
		# Verificar si el menú de opciones está visible ANTES de hacer cualquier cosa
		if esta_menu_opciones_visible():
			print("ESC ignorado - Menú de opciones está abierto")
			return  # No hacer nada si opciones está visible
		
		# Si no estamos en opciones, comportamiento normal
		if not en_opciones:
			toggle_pausa()

func toggle_pausa():
	get_tree().paused = not get_tree().paused
	if get_tree().paused:
		mostrar_menu_pausa()
	else:
		ocultar_menu_pausa()

func mostrar_menu_pausa():
	print("CanvasLayer: Mostrando menú de pausa")
	$ColorRect.visible = true
	$pausa.visible = true
	$interfaz/volver.visible = true
	$interfaz/renudar.visible = true
	$interfaz/opcione.visible = true

func ocultar_menu_pausa():
	print("CanvasLayer: Ocultando menú de pausa")
	$ColorRect.visible = false
	$pausa.visible = false
	$interfaz/volver.visible = false
	$interfaz/renudar.visible = false
	$interfaz/opcione.visible = false

# *** FUNCIONES PARA COMUNICARSE CON MENUMANAGER ***
func entrar_en_opciones():
	en_opciones = true
	print("CanvasLayer: Modo opciones activado")

func salir_de_opciones():
	en_opciones = false
	print("CanvasLayer: Modo opciones desactivado")

# Nueva función para verificar si el menú de opciones está visible
func esta_menu_opciones_visible() -> bool:
	var root = get_tree().current_scene
	var menu_opciones = root.find_child("Menu_Opciones", true, false)
	return menu_opciones != null and menu_opciones.visible
