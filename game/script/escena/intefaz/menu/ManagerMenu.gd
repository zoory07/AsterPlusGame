extends Control

#****************************************(Menu De Inicio)*******************************************
func _on_jugar_pressed():
	get_tree().change_scene_to_file("res://game/escena/game.tscn")

func _on_opcione_pressed():
	pass # Replace with function body.

func _on_salir_pressed():
	get_tree().quit()
#***************************************************************************************************
#/                                                                                                /#
#/                                                                                                /#
#/                                                                                                /#
#***************************************(MenuGameOver)**********************************************
func _on_volver_a_jugar_pressed():
	get_tree().change_scene_to_file("res://game/escena/game.tscn")

func _on_volver_2_pressed():
	get_tree().change_scene_to_file("res://game/escena/MenuInicio.tscn")
#***************************************************************************************************
#/                                                                                                /#
#/                                                                                                /#
#/                                                                                                /#
#***************************************(MenuPausa)*************************************************
func _on_volver_pressed():
	get_tree().paused = false
	queue_free()
	get_tree().change_scene_to_file("res://game/escena/MenuInicio.tscn")
	
func _on_renudar_pressed():
	# Desactiva la pausa (descongela la pantalla)
	get_tree().paused = false
	
	# Oculta todos los elementos del menú de pausa
	$"../ColorRect".visible = false
	$"../pausa".visible = false
	$volver.visible = false
	$renudar.visible = false
#***************************************************************************************************
