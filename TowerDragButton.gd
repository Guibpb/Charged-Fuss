extends "res://ui/LinhaDefesa.gd"

@export var tipo_torre: String = "basica"
var camada_soltar: Control

func _get_drag_data(_posicao: Vector2) -> Variant:
	if disabled or not is_instance_valid(camada_soltar):
		return null

	set_drag_preview(criar_imagem(icone, 48.0))
	camada_soltar.call("ativar_destino", tipo_torre)
	return {"tipo_torre": tipo_torre}
