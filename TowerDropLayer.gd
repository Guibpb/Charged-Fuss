extends Control

var controlador: Node
var destino_ativo: bool = false

func ativar_destino() -> void:
	destino_ativo = true
	mouse_filter = Control.MOUSE_FILTER_STOP

func _process(_delta: float) -> void:
	if destino_ativo and not get_viewport().gui_is_dragging():
		destino_ativo = false
		mouse_filter = Control.MOUSE_FILTER_IGNORE

func _can_drop_data(_posicao: Vector2, dados: Variant) -> bool:
	if not dados is Dictionary or not dados.has("tipo_torre"):
		return false
	if controlador == null or not is_instance_valid(controlador):
		return false
	var menu: Control = controlador.get_node("HUD/MenuTorres") as Control
	var painel: Control = controlador.get_node("HUD/MenuTorres/Painel") as Control
	return not menu.visible or not painel.get_global_rect().has_point(get_global_mouse_position())

func _drop_data(_posicao: Vector2, dados: Variant) -> void:
	if controlador == null or not is_instance_valid(controlador):
		return
	if not dados is Dictionary:
		destino_ativo = false
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		return
	controlador.call("receber_soltar_torre", str(dados.get("tipo_torre", "")), get_viewport().get_mouse_position())
	destino_ativo = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
