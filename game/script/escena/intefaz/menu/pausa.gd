extends CanvasLayer

func _ready():
	# Configura este nodo para que siga procesando durante la pausa
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Oculta el menú de pausa al inicio
	$interfaz/renudar.visible = false
	$ColorRect.visible = false
	$pausa.visible = false
	$interfaz/volver.visible = false
	
func _physics_process(delta):
	if Input.is_action_just_pressed("pausa"):
		get_tree().paused = not get_tree().paused
		$ColorRect.visible = not $ColorRect.visible
		$pausa.visible = not $pausa.visible
		$interfaz/volver.visible = not $interfaz/volver.visible
		$interfaz/renudar.visible = not $interfaz/renudar.visible
