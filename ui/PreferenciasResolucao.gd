extends Control

const ARQUIVO := "user://graficos.cfg"
const RESOLUCOES: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080)]
const NOMES_PERFIS := ["Econômico", "Equilibrado", "Alto"]
const ESCALAS_3D := [0.75, 5.0 / 6.0, 1.0]
const MODOS_AA := [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X]
const MODOS_SOMBRA := [
	DirectionalLight3D.SHADOW_ORTHOGONAL,
	DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS,
	DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS,
]

var luz: DirectionalLight3D
var caminho_config := ARQUIVO
var resolucao := 1
var perfil := 1
var _titulo: Label
var _qualidade: VBoxContainer
var _perfil_lista: OptionButton
var _resolucao_lista: OptionButton
var _status: Label
var _aplicar: Button
var _manter: Button
var _voltar: Button
var _timer: Timer
var _origem: Control
var _modo_anterior: Window.Mode
var _tamanho_anterior: Vector2i
var _posicao_anterior: Vector2i

func _ready() -> void:
	hide()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = preload("res://ui/TemaInterface.tres")
	_montar_interface()
	var config := ConfigFile.new()
	resolucao = _preferida()
	if config.load(caminho_config) == OK:
		resolucao = clampi(int(config.get_value("video", "resolucao", resolucao)), 0, RESOLUCOES.size() - 1)
		perfil = clampi(int(config.get_value("video", "perfil", perfil)), 0, NOMES_PERFIS.size() - 1)
	_aplicar_perfil()
	if DisplayServer.get_name() != "headless":
		if not _suportada(resolucao):
			resolucao = _preferida()
		if _suportada(resolucao):
			_aplicar_resolucao.call_deferred(resolucao)

func abrir(origem: Control, mostrar_qualidade: bool = false) -> void:
	_origem = origem
	_titulo.text = "Gráficos" if mostrar_qualidade else "Resolução de saída"
	_qualidade.visible = mostrar_qualidade
	for i in RESOLUCOES.size():
		_resolucao_lista.set_item_disabled(i, not _suportada(i))
	_restaurar_campos()
	show()
	var primeiro_campo := _perfil_lista if mostrar_qualidade else _resolucao_lista
	primeiro_campo.grab_focus()

func _input(evento: InputEvent) -> void:
	if visible and evento.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_fechar_ou_reverter()

func _preferida() -> int:
	for i in range(RESOLUCOES.size() - 1, -1, -1):
		if _suportada(i):
			return i
	return 0

func _suportada(indice: int) -> bool:
	if DisplayServer.get_name() == "headless":
		return true
	var tela := get_window().current_screen
	var tamanho := RESOLUCOES[indice]
	var util := DisplayServer.screen_get_usable_rect(tela).size
	return tamanho == DisplayServer.screen_get_size(tela) or (tamanho.x + 20 <= util.x and tamanho.y + 48 <= util.y)

func _aplicar_resolucao(indice: int) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var janela := get_window()
	var tela := janela.current_screen
	var tamanho := RESOLUCOES[indice]
	if tamanho == DisplayServer.screen_get_size(tela):
		janela.mode = Window.MODE_FULLSCREEN
		return
	janela.mode = Window.MODE_WINDOWED
	janela.size = tamanho
	var util := DisplayServer.screen_get_usable_rect(tela)
	janela.position = util.position + (util.size - tamanho) / 2

func _demonstrar() -> void:
	var nova_resolucao := _resolucao_lista.selected
	if nova_resolucao == resolucao:
		if _qualidade.visible:
			_confirmar_perfil()
			_salvar()
		return
	if not _suportada(nova_resolucao):
		return
	var janela := get_window()
	_modo_anterior = janela.mode
	_tamanho_anterior = janela.size
	_posicao_anterior = janela.position
	_aplicar_resolucao(nova_resolucao)
	_estado_confirmacao(true)
	_status.text = "Confirme a nova resolução. Ela será revertida em 12 segundos."
	_timer.start()
	_manter.grab_focus()

func _confirmar() -> void:
	_timer.stop()
	resolucao = _resolucao_lista.selected
	_confirmar_perfil()
	_estado_confirmacao(false)
	_salvar()
	_aplicar.grab_focus()

func _reverter() -> void:
	_timer.stop()
	if DisplayServer.get_name() != "headless":
		var janela := get_window()
		janela.mode = _modo_anterior
		if _modo_anterior == Window.MODE_WINDOWED:
			janela.size = _tamanho_anterior
			janela.position = _posicao_anterior
	_restaurar_campos()
	_status.text = "Configurações anteriores restauradas."
	_aplicar.grab_focus()

func _fechar_ou_reverter() -> void:
	if not _timer.is_stopped():
		_reverter()
		return
	hide()
	if is_instance_valid(_origem):
		_origem.grab_focus()

func _restaurar_campos() -> void:
	_resolucao_lista.select(resolucao)
	_perfil_lista.select(perfil)
	_estado_confirmacao(false)
	_status.text = ""

func _estado_confirmacao(confirmando: bool) -> void:
	_resolucao_lista.disabled = confirmando
	_perfil_lista.disabled = confirmando
	_aplicar.visible = not confirmando
	_manter.visible = confirmando
	_voltar.text = "Reverter" if confirmando else "Voltar"

func _salvar() -> void:
	var config := ConfigFile.new()
	config.set_value("video", "resolucao", resolucao)
	config.set_value("video", "perfil", perfil)
	_status.text = "Configurações salvas." if config.save(caminho_config) == OK else "Configurações aplicadas nesta sessão. Não foi possível salvar."

func _confirmar_perfil() -> void:
	if _qualidade.visible and perfil != _perfil_lista.selected:
		perfil = _perfil_lista.selected
		_aplicar_perfil()

func _aplicar_perfil() -> void:
	var viewport := get_viewport()
	viewport.scaling_3d_scale = ESCALAS_3D[perfil]
	viewport.msaa_3d = MODOS_AA[perfil]
	if is_instance_valid(luz):
		luz.directional_shadow_mode = MODOS_SOMBRA[perfil]
	RenderingServer.directional_shadow_atlas_set_size(4096 if perfil == 2 else 2048, true)

func _montar_interface() -> void:
	var fundo := ColorRect.new()
	fundo.color = Color("#10181DD9")
	add_child(fundo)
	fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var centro := CenterContainer.new()
	add_child(centro)
	centro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var placa := PanelContainer.new()
	placa.custom_minimum_size.x = 526
	placa.theme_type_variation = &"PainelOperacao"
	centro.add_child(placa)
	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 12)
	placa.add_child(coluna)
	_titulo = Label.new()
	_titulo.text = "Resolução de saída"
	_titulo.add_theme_font_size_override("font_size", 22)
	coluna.add_child(_titulo)
	_qualidade = VBoxContainer.new()
	_qualidade.add_theme_constant_override("separation", 8)
	coluna.add_child(_qualidade)
	var rotulo_qualidade := Label.new()
	rotulo_qualidade.text = "Qualidade gráfica"
	_qualidade.add_child(rotulo_qualidade)
	_perfil_lista = OptionButton.new()
	_perfil_lista.custom_minimum_size.y = 44
	_perfil_lista.accessibility_name = rotulo_qualidade.text
	for nome: String in NOMES_PERFIS:
		_perfil_lista.add_item(nome)
	_qualidade.add_child(_perfil_lista)
	_resolucao_lista = OptionButton.new()
	_resolucao_lista.custom_minimum_size.y = 44
	_resolucao_lista.accessibility_name = "Resolução de saída"
	coluna.add_child(_resolucao_lista)
	for tamanho in RESOLUCOES:
		_resolucao_lista.add_item("%d × %d" % [tamanho.x, tamanho.y])
	_status = Label.new()
	_status.custom_minimum_size.y = 50
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_color_override("font_color", Color("#BAC5C8"))
	coluna.add_child(_status)
	var acoes := HBoxContainer.new()
	acoes.add_theme_constant_override("separation", 8)
	coluna.add_child(acoes)
	_aplicar = _adicionar_botao(acoes, "Aplicar", _demonstrar, true)
	_manter = _adicionar_botao(acoes, "Manter resolução", _confirmar, true)
	_manter.hide()
	_voltar = _adicionar_botao(acoes, "Voltar", _fechar_ou_reverter, false)
	_timer = Timer.new()
	_timer.wait_time = 12.0
	_timer.one_shot = true
	_timer.ignore_time_scale = true
	_timer.timeout.connect(_reverter)
	add_child(_timer)

func _adicionar_botao(pai: HBoxContainer, nome: String, acao: Callable, principal: bool) -> Button:
	var botao := Button.new()
	botao.text = nome
	botao.custom_minimum_size = Vector2(128, 44)
	if principal:
		botao.theme_type_variation = &"AcaoPrincipal"
	botao.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	botao.pressed.connect(acao)
	pai.add_child(botao)
	return botao
