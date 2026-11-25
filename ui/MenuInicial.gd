extends Control

@onready var botao_graficos: Button = $Conteudo/Opcoes/Graficos

func _input(evento: InputEvent) -> void:
	if not is_visible_in_tree() or botao_graficos.visible or not evento is InputEventKey:
		return
	var tecla := evento as InputEventKey
	if not tecla.pressed or tecla.echo or tecla.ctrl_pressed or tecla.alt_pressed or tecla.meta_pressed:
		return
	if tecla.unicode in [0x00E7, 0x00C7] or tecla.keycode == 0x00C7:
		botao_graficos.show()
		botao_graficos.grab_focus()
		get_viewport().set_input_as_handled()
