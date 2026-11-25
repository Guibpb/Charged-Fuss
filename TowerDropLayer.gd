extends Control

var controlador: Node
var painel_loja: Control
var tipo_arrastado := ""
var cursor_arraste := Vector2(-1.0, -1.0)

func _ready() -> void:
	get_window().mouse_exited.connect(_limpar_cursor)

func _limpar_cursor() -> void:
	cursor_arraste = Vector2(-1.0, -1.0)

func ativar_destino(tipo: String) -> void:
	tipo_arrastado = tipo
	mouse_filter = Control.MOUSE_FILTER_STOP

func encerrar_destino() -> void:
	tipo_arrastado = ""
	_limpar_cursor()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if is_instance_valid(controlador):
		controlador.call("mostrar_base_para_soltar", -1)

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		encerrar_destino()

func _process(_delta: float) -> void:
	if tipo_arrastado.is_empty() or not is_instance_valid(controlador):
		return
	var indice := -1
	if _fora_da_loja(cursor_arraste):
		indice = controlador.call("base_para_soltar", tipo_arrastado, cursor_arraste)
	controlador.call("mostrar_base_para_soltar", indice)

func _fora_da_loja(cursor: Vector2) -> bool:
	return get_viewport_rect().has_point(cursor) and (not painel_loja.is_visible_in_tree() or not painel_loja.get_global_rect().has_point(cursor))

func _can_drop_data(posicao: Vector2, dados: Variant) -> bool:
	cursor_arraste = get_global_transform_with_canvas() * posicao
	return not tipo_arrastado.is_empty() and is_instance_valid(controlador) and dados is Dictionary and dados.get("tipo_torre") == tipo_arrastado and _fora_da_loja(cursor_arraste)

func _drop_data(posicao: Vector2, dados: Variant) -> void:
	if _can_drop_data(posicao, dados):
		controlador.call("receber_soltar_torre", tipo_arrastado, cursor_arraste)
	encerrar_destino()
