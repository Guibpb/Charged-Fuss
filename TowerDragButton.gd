extends Button

@export var tipo_torre: String = "basica"
var camada_soltar: Control

func _get_drag_data(_posicao: Vector2) -> Variant:
	if disabled:
		return null

	var preview := Label.new()
	preview.text = text
	preview.add_theme_font_size_override("font_size", 15)
	preview.add_theme_color_override("font_color", Color(0.38, 0.9, 0.96, 1.0))
	set_drag_preview(preview)
	if camada_soltar != null and camada_soltar.has_method("ativar_destino"):
		camada_soltar.call("ativar_destino")
	return {"tipo_torre": tipo_torre}
