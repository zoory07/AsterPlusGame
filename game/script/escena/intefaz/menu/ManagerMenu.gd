extends Control

var viene_de_pausa = false

#****************************************(Menu_De_Inicio)*******************************************
func _on_jugar_pressed():
	get_tree().change_scene_to_file("res://game/escena/game.tscn")

func _on_opcione_pressed01():  
	print("Abriendo opciones desde menú principal")
	viene_de_pausa = false
	ocultar_interfaz_menu_seguro()
	mostrar_menu_opciones_seguro()

func _on_salir_pressed():
	get_tree().quit()

#***************************************************************************************************
#                              FUNCIONES ACTUALIZADAS                                         
#***************************************************************************************************

func _on_volver_del_menu_opciones():  
	print("Volviendo del menú de opciones")
	ocultar_menu_opciones_seguro()
	
	# Pequeña espera para asegurar que se oculte primero
	await get_tree().create_timer(0.1).timeout
	
	if viene_de_pausa:
		print("Volviendo al menú de pausa")
		mostrar_menu_pausa_seguro()
		# Comunicar al script de pausa que salimos de opciones
		var pausa_layer = get_node_or_null("/root/Game/Pausa")
		if pausa_layer and pausa_layer.has_method("salir_de_opciones"):
			pausa_layer.salir_de_opciones()
	else:
		print("Volviendo al menú principal")
		# Asegurarse de que el menú principal se muestre correctamente
		mostrar_interfaz_menu_seguro()

func ocultar_interfaz_menu_seguro():
	var root = get_tree().current_scene
	var elementos = ["TextureRect", "PanelContainer", "jugar", "opcione", "salir"]
	
	print("Ocultando elementos del menú principal...")
	for elemento in elementos:
		var node = root.find_child(elemento, true, false)
		if node:
			node.visible = false
			print("  - Ocultado: " + elemento)

func mostrar_interfaz_menu_seguro():
	var root = get_tree().current_scene
	var elementos = ["TextureRect", "PanelContainer", "jugar", "opcione", "salir"]
	
	print("Mostrando elementos del menú principal...")
	for elemento in elementos:
		var node = root.find_child(elemento, true, false)
		if node:
			node.visible = true
			print("  - Mostrado: " + elemento)
		else:
			print("  - No encontrado: " + elemento)
	
	# Asegurarse de que el menú de opciones esté oculto
	var menu_opciones = root.find_child("Menu_Opciones", true, false)
	if menu_opciones:
		menu_opciones.visible = false

func mostrar_menu_opciones_seguro():
	var root = get_tree().current_scene
	var menu_opciones = root.find_child("Menu_Opciones", true, false)
	if menu_opciones:
		print("Mostrando Menu_Opciones")
		menu_opciones.visible = true
		# Asegurarse de que el botón de volver esté conectado
		var boton_volver = menu_opciones.find_child("volver", true, false)
		if boton_volver and not boton_volver.is_connected("pressed", _on_volver_pressedOpciones):
			boton_volver.connect("pressed", _on_volver_pressedOpciones)

func ocultar_menu_opciones_seguro():
	var root = get_tree().current_scene
	var menu_opciones = root.find_child("Menu_Opciones", true, false)
	if menu_opciones:
		print("Ocultando Menu_Opciones")
		menu_opciones.visible = false

# *** FUNCIONES PARA CONTROLAR EL MENÚ DE PAUSA ***
func ocultar_menu_pausa_seguro():
	var root = get_tree().current_scene
	var color_rect = root.find_child("ColorRect", true, false)
	var pausa_label = root.find_child("pausa", true, false)
	var interfaz = root.find_child("interfaz", true, false)
	
	print("Ocultando menú de pausa...")
	if color_rect: 
		color_rect.visible = false
	if pausa_label: 
		pausa_label.visible = false
	if interfaz:
		var volver = interfaz.find_child("volver", false, false)
		var renudar = interfaz.find_child("renudar", false, false)
		var opcione = interfaz.find_child("opcione", false, false)
		if volver: volver.visible = false
		if renudar: renudar.visible = false
		if opcione: opcione.visible = false

func mostrar_menu_pausa_seguro():
	var root = get_tree().current_scene
	var color_rect = root.find_child("ColorRect", true, false)
	var pausa_label = root.find_child("pausa", true, false)
	var interfaz = root.find_child("interfaz", true, false)
	
	print("Mostrando menú de pausa...")
	if color_rect: 
		color_rect.visible = true
	if pausa_label: 
		pausa_label.visible = true
	if interfaz:
		var volver = interfaz.find_child("volver", false, false)
		var renudar = interfaz.find_child("renudar", false, false)
		var opcione = interfaz.find_child("opcione", false, false)
		if volver: volver.visible = true
		if renudar: renudar.visible = true
		if opcione: opcione.visible = true

#**************************************************************************************************#
#****************************************(Menu_De_Pausa)*******************************************#
func _on_volver_pressed():
	get_tree().paused = false
	queue_free()
	get_tree().change_scene_to_file("res://game/escena/MenuInicio.tscn")

func _on_opcione_pressed07():
	print("Opciones desde pausa")
	viene_de_pausa = true
	ocultar_menu_pausa_seguro()
	# Comunicar al script de pausa que entramos en opciones
	var pausa_layer = get_node_or_null("/root/Game/Pausa")
	if pausa_layer and pausa_layer.has_method("entrar_en_opciones"):
		pausa_layer.entrar_en_opciones()
	mostrar_menu_opciones_seguro()

func _on_renudar_pressed():
	print("Reanudando juego")
	get_tree().paused = false
	ocultar_menu_pausa_seguro()

#**************************************************************************************************#
#***************************************(Menu_De_Opciones)*****************************************#
func _on_volver_pressedOpciones():
	print("Botón volver de opciones presionado")
	
	# Guardar configuración de audio antes de salir
	guardar_configuracion_audio()
	
	_on_volver_del_menu_opciones()

func guardar_configuracion_audio():
	var root = get_tree().current_scene
	var menu_opciones = root.find_child("Menu_Opciones", true, false)
	
	if menu_opciones:
		# Buscar y guardar slider de música
		var slider_musica = menu_opciones.find_child("SliderMusica", true, false)
		if slider_musica and slider_musica.has_method("guardar_volumen"):
			slider_musica.guardar_volumen()
			print("Volumen de música guardado")
		
		# Buscar y guardar slider de sonido
		var slider_sonido = menu_opciones.find_child("SliderSonido", true, false)
		if slider_sonido and slider_sonido.has_method("guardar_volumen"):
			slider_sonido.guardar_volumen()
			print("Volumen de sonido guardado")

# Nueva función para manejar ESC en opciones - ejecuta la misma lógica que el botón volver
func cerrar_opciones_con_esc():
	print("ESC presionado en opciones - ejecutando misma función que botón volver")
	_on_volver_pressedOpciones()  # Llamar a la misma función que el botón volver


#Gameover menu
func _on_volver_a_jugar_pressed():
	get_tree().change_scene_to_file("res://game/escena/game.tscn")




func _on_volver_gameover_pressed():
	get_tree().change_scene_to_file("res://game/escena/MenuInicio.tscn")
