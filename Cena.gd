extends Node3D

const ENEMY_SCENE = preload("res://Enemy.tscn")
const CAMINHO_MODELO_CHEFE := preload("res://Enemy.gd").CAMINHO_MODELO_CHEFE
const TOWER_SCENE: PackedScene = preload("res://TorreBasica.tscn")
const Tabuleiro = preload("res://fases/Tabuleiro.gd")
const BaseConstrucao = preload("res://fases/BaseConstrucao.gd")
const RegrasFase = preload("res://fases/RegrasFase.gd")
const Rodada = preload("res://fases/Rodada.gd")
const TOWER_NAMES: Dictionary = {"basica": "Torre normal", "rapida": "Torre rápida", "tesla": "Tesla", "chama": "Lança-chamas"}
const TOWER_TYPES: Array[String] = ["basica", "rapida", "tesla", "chama"]
const TOWER_DRAG_BUTTON_SCRIPT: Script = preload("res://TowerDragButton.gd")
const TOWER_DROP_LAYER_SCRIPT: Script = preload("res://TowerDropLayer.gd")
const LINHA_DEFESA = preload("res://ui/LinhaDefesa.gd")
const PREFERENCIAS_RESOLUCAO = preload("res://ui/PreferenciasResolucao.gd")
const ICONES_TORRES := {
	"basica": preload("res://ui/torres/basica.png"),
	"rapida": preload("res://ui/torres/rapida.png"),
	"tesla": preload("res://ui/torres/tesla.png"),
	"chama": preload("res://ui/torres/chama.png"),
}
const TAMANHO_DESTAQUE := 2.3
const UPGRADE_NAMES: Dictionary = {
	"dano": "Mais dano",
	"alcance": "Alcance +",
	"velocidade": "Velocidade +",
	"balas": "Balas ×2",
	"tesla_rapidez": "Pulso rápido",
	"tesla_alcance": "Alcance +",
	"chama_dano": "Mais dano",
	"chama_alcance": "Alcance +",
}

@export var cena_tabuleiro: PackedScene

var tabuleiro: Tabuleiro
var regras: RegrasFase
var caminho: Path3D
var camera: Camera3D
var player_health: int
var player_energy: int

@onready var vida_label: Label = $HUD/Vida/VidaLabel
@onready var energia_label: Label = $HUD/Operacao/EnergiaLabel
@onready var ganho_energia_label: Label = $HUD/Operacao/GanhoEnergiaLabel
@onready var painel_rodada: Control = $HUD/Operacao/PainelRodada
@onready var rodada_label: Label = $HUD/Operacao/PainelRodada/RodadaLabel
@onready var velocidade_label: Label = $HUD/Operacao/VelocidadeLabel
@onready var menu_inicial: Control = $HUD/MenuInicial
@onready var menu_torres: Control = $HUD/MenuTorres
@onready var botao_gerenciar_torres: Button = $HUD/GerenciarTorres
@onready var botao_pause: Button = $HUD/Operacao/BotaoPause
@onready var tela_derrota: Control = $HUD/TelaDerrota
@onready var tela_vitoria: Control = $HUD/TelaVitoria

var instrucao_torres: Label
var status_ativacao: Label
var botao_fechar_loja: Button
var loja_torres: VBoxContainer
var painel_upgrades: VBoxContainer
var titulo_painel_torres: Label
var icone_torre_selecionada: TextureRect
var destaque_base: Node3D
var camada_soltar: Control
var animacao_loja: Tween
var animacao_ganho: Tween
var botoes_loja: Array[Button] = []
var botoes_upgrade: Array[Button] = []
var bases: Array[BaseConstrucao] = []
var torres: Array[Node3D] = []
var tipos_ativados: Array[String] = []
var upgrades_comprados: Array[Dictionary] = []
var partida_iniciada := false
var rodada_atual: int = 0
var inimigos_restantes: int = 0
var spawn_em_andamento: bool = false
var rodada_concluida: bool = false
var fase_encerrada: bool = false
var energia_ganha_em_eliminacoes: int = 0
var energia_ganha_em_rodadas: int = 0
var temporizador_ganho: Timer
var preferencias_resolucao: Control
var nivel_velocidade: int = 1
var sequencia_cheat: String = ""
var revisao_fluxo_rodadas: int = 0
var torre_com_alcance_selecionada: Node3D = null
var indice_torre_selecionada: int = -1

func _ready() -> void:
	Engine.time_scale = 1.0
	set_process_unhandled_key_input(true)
	get_tree().paused = true
	get_viewport().disable_3d = true
	if not _carregar_tabuleiro():
		$HUD/MenuInicial/Conteudo/Play.disabled = true
		return
	_criar_destaque_base()
	_configurar_camera()
	get_viewport().size_changed.connect(_configurar_camera)
	$HUD/Vida/Barra.max_value = maxi(1, player_health)
	_criar_interface_de_torres()
	_criar_camadas_de_arrastar_soltar()
	_criar_preferencias_resolucao()
	temporizador_ganho = Timer.new()
	temporizador_ganho.one_shot = true
	temporizador_ganho.wait_time = 1.8
	temporizador_ganho.timeout.connect(_esconder_ganho_energia)
	$HUD.add_child(temporizador_ganho)
	_update_health_label()
	_atualizar_economia()
	botao_pause.pressed.connect(_alternar_pausa)
	botao_gerenciar_torres.pressed.connect(_on_gerenciar_torres_pressed)
	get_viewport().physics_object_picking = true

	tabuleiro.criar_visual_do_caminho()
	for indice in range(bases.size()):
		if not bases[indice].tipo_inicial.is_empty():
			_instalar_torre(indice, bases[indice].tipo_inicial)
	menu_inicial.get_node("Conteudo/Play").grab_focus()

func _carregar_tabuleiro() -> bool:
	var instancia := cena_tabuleiro.instantiate() if cena_tabuleiro != null else null
	tabuleiro = instancia as Tabuleiro
	if tabuleiro == null:
		if instancia != null:
			instancia.free()
		push_error("Selecione uma cena com Tabuleiro.gd para a fase.")
		return false
	add_child(tabuleiro)
	caminho = tabuleiro.caminho
	camera = tabuleiro.camera
	regras = tabuleiro.regras
	if caminho == null or caminho.curve == null or caminho.curve.get_baked_length() <= 0.0:
		push_error("O tabuleiro precisa de um Path3D com uma curva de comprimento positivo.")
		return false
	if camera == null or tabuleiro.container_bases == null or regras == null or regras.rodadas.is_empty():
		push_error("Configure a câmera, o contêiner de bases e as rodadas do tabuleiro.")
		return false
	for indice in range(regras.rodadas.size()):
		var rodada: Rodada = regras.rodadas[indice]
		if rodada == null or rodada.quantidade < 0 or (rodada.tem_chefe and indice != regras.rodadas.size() - 1):
			push_error("Configure rodadas válidas, com o chefe opcional somente na última.")
			return false
	var menor_preco := 2147483647
	for tipo in TOWER_TYPES:
		if not regras.custos_torres.has(tipo) or regras.custos_torres[tipo] < 0:
			push_error("Configure o custo do tipo de torre: " + tipo)
			return false
		menor_preco = mini(menor_preco, regras.custos_torres[tipo])
	for melhoria: String in UPGRADE_NAMES:
		if not regras.custos_upgrades.has(melhoria) or regras.custos_upgrades[melhoria] < 0:
			push_error("Configure o custo da melhoria: " + melhoria)
			return false

	bases = tabuleiro.listar_bases()
	var tem_base_livre := false
	for base in bases:
		if base.tipo_inicial.is_empty():
			tem_base_livre = true
		elif not TOWER_TYPES.has(base.tipo_inicial):
			push_error("Tipo de torre inicial inválido em " + str(base.name))
			return false
	if not regras.iniciar_ao_entrar and (not tem_base_livre or menor_preco > regras.energia_inicial):
		push_error("Ative o início automático ou garanta uma base livre e saldo para a primeira compra.")
		return false

	torres.resize(bases.size())
	for indice in range(bases.size()):
		tipos_ativados.append("")
		upgrades_comprados.append({})
	player_health = regras.vida_inicial
	player_energy = regras.energia_inicial
	$HUD/MenuInicial/Conteudo/Play.text = regras.titulo_menu
	$HUD/TelaVitoria/Centro/Cartao/Conteudo/Mensagem.text = regras.mensagem_vitoria
	camera.make_current()
	return true

func _criar_interface_de_torres() -> void:
	var conteudo := $HUD/MenuTorres/Painel/Conteudo as VBoxContainer
	var cabecalho := HBoxContainer.new()
	cabecalho.add_theme_constant_override("separation", 8)
	conteudo.add_child(cabecalho)
	icone_torre_selecionada = LINHA_DEFESA.criar_imagem(null, 48.0)
	icone_torre_selecionada.hide()
	cabecalho.add_child(icone_torre_selecionada)
	titulo_painel_torres = Label.new()
	titulo_painel_torres.text = "Defesas disponíveis"
	titulo_painel_torres.add_theme_font_override("font", preload("res://fonts/Orbitron-Bold.ttf"))
	titulo_painel_torres.add_theme_font_size_override("font_size", 20)
	cabecalho.add_child(titulo_painel_torres)

	instrucao_torres = Label.new()
	instrucao_torres.text = regras.instrucao_inicial
	instrucao_torres.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	instrucao_torres.add_theme_color_override("font_color", Color("#BAC5C8"))
	conteudo.add_child(instrucao_torres)
	loja_torres = VBoxContainer.new()
	loja_torres.add_theme_constant_override("separation", 8)
	conteudo.add_child(loja_torres)
	for tipo in TOWER_TYPES:
		var botao := TOWER_DRAG_BUTTON_SCRIPT.new() as Button
		botao.set("tipo_torre", tipo)
		loja_torres.add_child(botao)
		botao.call("montar", ICONES_TORRES[tipo])
		botoes_loja.append(botao)

	painel_upgrades = VBoxContainer.new()
	painel_upgrades.hide()
	painel_upgrades.add_theme_constant_override("separation", 8)
	conteudo.add_child(painel_upgrades)
	for indice in range(2):
		var botao := LINHA_DEFESA.new() as Button
		painel_upgrades.add_child(botao)
		botao.call("montar")
		botao.pressed.connect(_comprar_upgrade.bind(indice))
		botoes_upgrade.append(botao)
	_adicionar_botao_painel(painel_upgrades, "Voltar à loja", _voltar_para_loja)

	status_ativacao = Label.new()
	status_ativacao.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_ativacao.add_theme_color_override("font_color", Color("#E6CA90"))
	conteudo.add_child(status_ativacao)
	botao_fechar_loja = _adicionar_botao_painel(conteudo, "Fechar loja", _fechar_loja)

func _adicionar_botao_painel(pai: VBoxContainer, texto: String, acao: Callable) -> Button:
	var botao := Button.new()
	botao.text = texto
	botao.custom_minimum_size.y = 44.0
	botao.pressed.connect(acao)
	pai.add_child(botao)
	return botao

func _criar_camadas_de_arrastar_soltar() -> void:
	camada_soltar = TOWER_DROP_LAYER_SCRIPT.new()
	camada_soltar.name = "CamadaSoltarTorres"
	camada_soltar.set("controlador", self)
	camada_soltar.set("painel_loja", $HUD/MenuTorres/Painel)
	$HUD.add_child(camada_soltar)
	camada_soltar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	camada_soltar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for botao in botoes_loja:
		botao.set("camada_soltar", camada_soltar)

func _criar_preferencias_resolucao() -> void:
	preferencias_resolucao = PREFERENCIAS_RESOLUCAO.new()
	preferencias_resolucao.set("luz", tabuleiro.luz)
	$HUD.add_child(preferencias_resolucao)
	var botao: Button = $HUD/Operacao/Resolucao
	botao.pressed.connect(Callable(preferencias_resolucao, "abrir").bind(botao))
	var graficos: Button = $HUD/MenuInicial/Conteudo/Opcoes/Graficos
	graficos.pressed.connect(Callable(preferencias_resolucao, "abrir").bind(graficos, true))

func _criar_destaque_base() -> void:
	destaque_base = Node3D.new()
	destaque_base.hide()
	add_child(destaque_base)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color("#59DCE3")
	var borda := TAMANHO_DESTAQUE * 0.5 - 0.05
	for x: float in [-1.0, 1.0]:
		for z: float in [-1.0, 1.0]:
			for eixo: Vector2 in [Vector2(x, 0), Vector2(0, z)]:
				var peca := MeshInstance3D.new()
				var barra := BoxMesh.new()
				barra.size = Vector3(0.38, 0.018, 0.065) if eixo.x != 0.0 else Vector3(0.065, 0.018, 0.38)
				peca.mesh = barra
				peca.material_override = material
				peca.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				peca.position = Vector3(x * borda - eixo.x * 0.16, 0.01, z * borda - eixo.y * 0.16)
				destaque_base.add_child(peca)

func mostrar_base_para_soltar(indice: int) -> void:
	if not is_instance_valid(destaque_base):
		return
	destaque_base.visible = indice >= 0 and indice < bases.size()
	if destaque_base.visible:
		var base := bases[indice]
		var rotacao := Basis(Vector3.UP, base.global_rotation.y)
		var escala := Vector3(base.dimensoes.x / TAMANHO_DESTAQUE, 1.0, base.dimensoes.y / TAMANHO_DESTAQUE)
		destaque_base.global_transform = Transform3D(rotacao.scaled_local(escala), base.global_position)
		destaque_base.reset_physics_interpolation()

func _iniciar_rodada(numero_rodada: int) -> void:
	if fase_encerrada or not partida_iniciada:
		return
	if numero_rodada > regras.rodadas.size():
		_encerrar_fase(true)
		return

	revisao_fluxo_rodadas += 1
	var revisao_atual: int = revisao_fluxo_rodadas

	rodada_atual = numero_rodada
	if regras.rodadas.back().tem_chefe and rodada_atual >= regras.rodadas.size() - 2 and ResourceLoader.load_threaded_get_status(CAMINHO_MODELO_CHEFE) == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		ResourceLoader.load_threaded_request(CAMINHO_MODELO_CHEFE, "PackedScene")
	spawn_em_andamento = true
	rodada_concluida = false
	var rodada: Rodada = regras.rodadas[numero_rodada - 1]
	instrucao_torres.text = rodada.tutorial

	var quantidade_na_rodada: int = rodada.quantidade
	var total_de_spawns: int = quantidade_na_rodada + (1 if rodada.tem_chefe else 0)
	inimigos_restantes = total_de_spawns
	_atualizar_hud_rodada()
	for indice in range(total_de_spawns):
		if revisao_atual != revisao_fluxo_rodadas:
			return
		if fase_encerrada or not partida_iniciada:
			spawn_em_andamento = false
			return

		var path_follow := PathFollow3D.new()
		path_follow.loop = false
		path_follow.rotation_mode = PathFollow3D.ROTATION_Y
		path_follow.use_model_front = true
		caminho.add_child(path_follow)

		var enemy := ENEMY_SCENE.instantiate() as CharacterBody3D
		enemy.position.y = tabuleiro.altura_inimigo
		enemy.set("health", rodada.vida)
		enemy.set("speed", rodada.velocidade)
		var eh_chefe: bool = rodada.tem_chefe and indice == quantidade_na_rodada
		if eh_chefe:
			enemy.call("configurar_como_chefe", regras.multiplicador_vida_chefe)
		enemy.connect("reached_end", _on_enemy_reached_end.bind(eh_chefe))
		enemy.connect("defeated", _on_enemy_defeated.bind(eh_chefe))
		path_follow.add_child(enemy)
		path_follow.reset_physics_interpolation()

		if indice < total_de_spawns - 1:
			await get_tree().create_timer(rodada.intervalo, false).timeout
			if revisao_atual != revisao_fluxo_rodadas:
				return

	if revisao_atual != revisao_fluxo_rodadas:
		return
	spawn_em_andamento = false
	_verificar_fim_rodada()

func _on_enemy_reached_end(eh_chefe: bool) -> void:
	var dano: int = regras.dano_fuga_chefe if eh_chefe else regras.dano_fuga
	player_health = maxi(0, player_health - dano)
	_update_health_label()
	if player_health <= 0:
		_encerrar_fase(false)
		return
	if eh_chefe:
		_vencer_nivel_pelo_chefe()
		return
	_resolver_inimigo()

func _on_enemy_defeated(eh_chefe: bool) -> void:
	player_energy += regras.energia_por_eliminacao
	_mostrar_ganho_energia(regras.energia_por_eliminacao, false)
	_atualizar_economia()
	if eh_chefe:
		_vencer_nivel_pelo_chefe()
		return
	_resolver_inimigo()

func _vencer_nivel_pelo_chefe() -> void:
	if rodada_atual >= regras.rodadas.size() and not rodada_concluida:
		rodada_concluida = true
		player_energy += regras.bonus_rodada
		_mostrar_ganho_energia(regras.bonus_rodada, true)
		_atualizar_economia()
	_encerrar_fase(true)

func _mostrar_ganho_energia(quantidade: int, bonus_rodada: bool) -> void:
	if bonus_rodada:
		energia_ganha_em_rodadas += quantidade
	else:
		energia_ganha_em_eliminacoes += quantidade

	var texto_ganho: String = ""
	if energia_ganha_em_eliminacoes > 0:
		var rotulo_eliminacoes: String = "ELIMINAÇÃO" if energia_ganha_em_eliminacoes == 1 else "ELIMINAÇÕES"
		texto_ganho = "+%d E  •  %s" % [energia_ganha_em_eliminacoes, rotulo_eliminacoes]
	if energia_ganha_em_rodadas > 0:
		if not texto_ganho.is_empty():
			texto_ganho += "\n"
		texto_ganho += "+%d E  •  RODADA CONCLUÍDA" % energia_ganha_em_rodadas
	_exibir_linha_ganho(texto_ganho)
	temporizador_ganho.start()

func _esconder_ganho_energia() -> void:
	energia_ganha_em_eliminacoes = 0
	energia_ganha_em_rodadas = 0
	ganho_energia_label.hide()

func _resolver_inimigo() -> void:
	inimigos_restantes = maxi(0, inimigos_restantes - 1)
	_verificar_fim_rodada()

func _verificar_fim_rodada() -> void:
	if fase_encerrada or spawn_em_andamento or inimigos_restantes > 0 or rodada_concluida:
		return

	rodada_concluida = true
	player_energy += regras.bonus_rodada
	_mostrar_ganho_energia(regras.bonus_rodada, true)
	_atualizar_economia()
	if rodada_atual >= regras.rodadas.size():
		_encerrar_fase(true)
		return
	_aguardar_proxima_rodada(rodada_atual + 1)

func _aguardar_proxima_rodada(proxima_rodada: int) -> void:
	var revisao_atual: int = revisao_fluxo_rodadas
	await get_tree().create_timer(regras.intervalo_entre_rodadas, false).timeout
	if revisao_atual == revisao_fluxo_rodadas and not fase_encerrada and partida_iniciada:
		_iniciar_rodada(proxima_rodada)

func _atualizar_hud_rodada() -> void:
	if rodada_atual <= 0:
		rodada_label.text = ""
		return
	rodada_label.text = "RODADA %02d" % rodada_atual

func _encerrar_fase(vitoria: bool) -> void:
	if fase_encerrada:
		return
	fase_encerrada = true
	partida_iniciada = false
	revisao_fluxo_rodadas += 1
	spawn_em_andamento = false
	camada_soltar.call("encerrar_destino")
	menu_torres.hide()
	botao_gerenciar_torres.hide()
	botao_pause.hide()
	$HUD/Operacao/Resolucao.hide()
	velocidade_label.hide()
	Engine.time_scale = 1.0
	nivel_velocidade = 1
	if vitoria:
		rodada_label.text = "FASE CONCLUÍDA"
	else:
		rodada_label.text = "FIM DE JOGO"
	get_tree().paused = true
	var tela := tela_vitoria if vitoria else tela_derrota
	var acao := "Sair" if vitoria else "Recomecar"
	_mostrar_resultado(tela, acao)

func _mostrar_resultado(tela: Control, acao: String) -> void:
	await get_tree().create_timer(0.8, true, false, true).timeout
	tela.modulate.a = 0.0
	tela.show()
	tela.get_node("Centro/Cartao/Conteudo/Acoes/%s" % acao).grab_focus()
	var transicao: Tween = create_tween()
	transicao.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	transicao.set_ignore_time_scale(true)
	transicao.set_trans(Tween.TRANS_CUBIC)
	transicao.set_ease(Tween.EASE_OUT)
	transicao.tween_property(tela, "modulate:a", 1.0, 0.8)

func _recomecar_jogo() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	get_tree().reload_current_scene()

func _sair_do_jogo() -> void:
	get_tree().quit()

func _alternar_pausa() -> void:
	if not partida_iniciada or fase_encerrada:
		return
	get_tree().paused = not get_tree().paused
	botao_pause.text = "Retomar" if get_tree().paused else "Pausar"
	$HUD/Operacao/Resolucao.visible = get_tree().paused

func _unhandled_key_input(event: InputEvent) -> void:
	var tecla_evento: InputEventKey = event as InputEventKey
	if tecla_evento == null or not tecla_evento.pressed or tecla_evento.echo:
		return
	if menu_inicial.visible or fase_encerrada or preferencias_resolucao == null or preferencias_resolucao.visible:
		sequencia_cheat = ""
		return

	if tecla_evento.keycode == KEY_B:
		sequencia_cheat = ""
		if partida_iniciada:
			_pular_para_rodada_final()
		return

	if tecla_evento.keycode == KEY_V:
		sequencia_cheat = ""
		if partida_iniciada:
			_alternar_velocidade()
		return

	var letra: String = ""
	match tecla_evento.keycode:
		KEY_C:
			letra = "C"
		KEY_G:
			letra = "G"
		KEY_T:
			letra = "T"
		_:
			sequencia_cheat = ""
			return

	var proxima_sequencia: String = sequencia_cheat + letra
	if "CGT".begins_with(proxima_sequencia):
		sequencia_cheat = proxima_sequencia
		if sequencia_cheat == "CGT":
			sequencia_cheat = ""
			_ativar_cheat_energia()
	else:
		sequencia_cheat = "C" if letra == "C" else ""

func _alternar_velocidade() -> void:
	nivel_velocidade = 1 if nivel_velocidade >= 3 else nivel_velocidade + 1
	Engine.time_scale = float(nivel_velocidade)
	velocidade_label.text = "%d×" % nivel_velocidade
	_mostrar_mensagem_energia("VELOCIDADE %d×" % nivel_velocidade)

func _ativar_cheat_energia() -> void:
	player_energy += 1000
	_atualizar_economia()
	_mostrar_mensagem_energia("+1000 E  •  CÓDIGO CGT")

func _pular_para_rodada_final() -> void:
	if not partida_iniciada or fase_encerrada or rodada_atual >= regras.rodadas.size():
		return

	for filho in caminho.get_children():
		if filho is PathFollow3D:
			filho.queue_free()

	inimigos_restantes = 0
	spawn_em_andamento = false
	rodada_concluida = false
	_mostrar_mensagem_energia("CÓDIGO B  •  RODADA FINAL")
	_iniciar_rodada(regras.rodadas.size())

func _mostrar_mensagem_energia(mensagem: String) -> void:
	energia_ganha_em_eliminacoes = 0
	energia_ganha_em_rodadas = 0
	_exibir_linha_ganho(mensagem)
	temporizador_ganho.start()

func _exibir_linha_ganho(texto: String) -> void:
	ganho_energia_label.text = texto
	if ganho_energia_label.visible:
		return
	ganho_energia_label.modulate.a = 0.0
	ganho_energia_label.show()
	if animacao_ganho != null:
		animacao_ganho.kill()
	animacao_ganho = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_ignore_time_scale(true)
	animacao_ganho.tween_property(ganho_energia_label, "modulate:a", 1.0, 0.14)

func _update_health_label() -> void:
	vida_label.text = "VIDA: %d" % player_health
	$HUD/Vida/Barra.value = player_health

func _on_menu_play_pressed() -> void:
	if preferencias_resolucao == null:
		return
	menu_inicial.hide()
	get_viewport().disable_3d = false
	_configurar_camera()
	$HUD/Vida.show()
	$HUD/Operacao.show()
	energia_label.show()
	painel_rodada.hide()
	rodada_label.hide()
	ganho_energia_label.hide()
	velocidade_label.hide()
	botao_pause.hide()
	botao_gerenciar_torres.hide()
	loja_torres.show()
	painel_upgrades.hide()
	instrucao_torres.text = regras.instrucao_inicial
	status_ativacao.text = regras.mensagem_espera
	get_tree().paused = true
	_atualizar_economia()
	if regras.iniciar_ao_entrar:
		_iniciar_fase()
	else:
		_abrir_loja()

func _iniciar_fase() -> void:
	if partida_iniciada or fase_encerrada:
		return
	menu_torres.hide()
	partida_iniciada = true
	painel_rodada.show()
	rodada_label.show()
	velocidade_label.show()
	velocidade_label.text = "%d×" % nivel_velocidade
	botao_pause.show()
	botao_pause.text = "Pausar"
	botao_gerenciar_torres.text = "Gerenciar torres"
	botao_gerenciar_torres.show()
	_ocultar_alcances_torres()
	_atualizar_economia()
	get_tree().paused = false
	_iniciar_rodada(1)

func _on_gerenciar_torres_pressed() -> void:
	if menu_torres.visible:
		_fechar_loja()
		return
	_voltar_para_loja()
	_abrir_loja()

func _abrir_loja() -> void:
	botao_gerenciar_torres.hide()
	if menu_torres.visible:
		return
	var painel := $HUD/MenuTorres/Painel as PanelContainer
	if animacao_loja != null:
		animacao_loja.kill()
	painel.position.x = 12.0
	painel.modulate.a = 0.0
	menu_torres.show()
	animacao_loja = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_ignore_time_scale(true)
	animacao_loja.set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	animacao_loja.tween_property(painel, "position:x", 20.0, 0.14)
	animacao_loja.tween_property(painel, "modulate:a", 1.0, 0.14)

func _fechar_loja() -> void:
	camada_soltar.call("encerrar_destino")
	menu_torres.hide()
	botao_gerenciar_torres.text = "Gerenciar torres" if partida_iniciada else "Abrir loja"
	botao_gerenciar_torres.show()

func receber_soltar_torre(tipo: String, posicao_tela: Vector2) -> void:
	if not TOWER_TYPES.has(tipo) or fase_encerrada:
		return
	var indice_base := base_para_soltar(tipo, posicao_tela)
	if indice_base < 0:
		if player_energy < int(regras.custos_torres[tipo]):
			status_ativacao.text = "Energia insuficiente. Você precisa de %d E." % int(regras.custos_torres[tipo])
		else:
			status_ativacao.text = "Solte a torre sobre uma base vazia."
		return
	_comprar_torre(indice_base, tipo)

func base_para_soltar(tipo: String, posicao_tela: Vector2) -> int:
	if fase_encerrada or not regras.custos_torres.has(tipo) or player_energy < int(regras.custos_torres[tipo]):
		return -1
	var origem := camera.project_ray_origin(posicao_tela)
	var direcao := camera.project_ray_normal(posicao_tela)
	if absf(direcao.y) < 0.0001:
		return -1
	var plano_comum := tabuleiro.plano_soltar_comum
	var altura_comum := plano_comum.global_position.y if plano_comum != null else 0.0
	var indice_base := -1
	var menor_profundidade := INF
	var menor_distancia := INF
	for indice in range(bases.size()):
		if torres[indice] != null:
			continue
		var base := bases[indice]
		var centro := base.global_position
		var altura := altura_comum if plano_comum != null else centro.y
		var profundidade := (altura - origem.y) / direcao.y
		if profundidade < 0.0 or profundidade > menor_profundidade:
			continue
		var ponto := origem + direcao * profundidade
		var distancia := Vector2(centro.x - ponto.x, centro.z - ponto.z).length_squared()
		if base.tolerancia_soltar > 0.0:
			if distancia > base.tolerancia_soltar * base.tolerancia_soltar:
				continue
		else:
			var ponto_local := base.to_local(ponto)
			if absf(ponto_local.x) > base.dimensoes.x * 0.5 or absf(ponto_local.z) > base.dimensoes.y * 0.5:
				continue
		if profundidade < menor_profundidade or distancia < menor_distancia:
			menor_profundidade = profundidade
			menor_distancia = distancia
			indice_base = indice
	return indice_base

func _comprar_torre(indice: int, tipo: String) -> void:
	if indice < 0 or indice >= bases.size() or torres[indice] != null:
		return
	var custo := int(regras.custos_torres[tipo])
	if player_energy < custo:
		status_ativacao.text = "Energia insuficiente. Você precisa de %d E." % custo
		return

	if not _instalar_torre(indice, tipo):
		return
	player_energy -= custo
	_ocultar_alcances_torres()
	status_ativacao.text = "%s posicionada por %d E." % [TOWER_NAMES[tipo], custo]
	_atualizar_economia()
	if not partida_iniciada:
		_iniciar_fase()

func _instalar_torre(indice: int, tipo: String) -> bool:
	var torre := TOWER_SCENE.instantiate() as Node3D
	if torre == null:
		push_error("Não foi possível criar a torre escolhida.")
		return false
	var base := bases[indice]
	torre.call("configurar_tipo", tipo)
	torre.position = Vector3.UP * base.altura_torre
	torre.set("altura_indicador_alcance", base.altura_indicador - base.altura_torre)
	base.add_child(torre)
	torres[indice] = torre
	tipos_ativados[indice] = tipo
	var torre_clicavel := torre as CollisionObject3D
	if torre_clicavel != null:
		torre_clicavel.input_ray_pickable = true
		torre_clicavel.input_event.connect(_ao_clicar_torre.bind(indice))
	torre.call("ativar", tipo, regras.atributos_torres.get(tipo, {}))
	var direcao_setor := _direcao_para_caminho(torre.global_position)
	if torre.has_method("definir_direcao_setor"):
		torre.call("definir_direcao_setor", direcao_setor)
	torre.reset_physics_interpolation()
	return true

func _direcao_para_caminho(posicao_torre: Vector3) -> Vector3:
	var mais_proximo := posicao_torre
	var distancia_menor: float = INF
	for ponto in caminho.curve.get_baked_points():
		var global_ponto := caminho.to_global(ponto)
		var diferenca := Vector2(global_ponto.x - posicao_torre.x, global_ponto.z - posicao_torre.z)
		if diferenca.length_squared() < distancia_menor:
			distancia_menor = diferenca.length_squared()
			mais_proximo = global_ponto
	mais_proximo.y = posicao_torre.y
	return mais_proximo - posicao_torre

func _mostrar_upgrades(indice: int) -> void:
	if indice < 0 or indice >= torres.size() or torres[indice] == null:
		return
	indice_torre_selecionada = indice
	var tipo: String = tipos_ativados[indice]
	var melhorias: Array[String] = []
	match tipo:
		"basica":
			melhorias = ["dano", "alcance"]
		"rapida":
			melhorias = ["velocidade", "balas"]
		"tesla":
			melhorias = ["tesla_rapidez", "tesla_alcance"]
		"chama":
			melhorias = ["chama_dano", "chama_alcance"]
	titulo_painel_torres.text = TOWER_NAMES[tipo]
	icone_torre_selecionada.texture = ICONES_TORRES[tipo]
	icone_torre_selecionada.show()
	instrucao_torres.hide()
	for indice_botao in range(botoes_upgrade.size()):
		var chave: String = melhorias[indice_botao]
		var botao: Button = botoes_upgrade[indice_botao]
		botao.set_meta("melhoria", chave)
		var comprada: bool = bool(upgrades_comprados[indice].get(chave, false))
		var custo := int(regras.custos_upgrades[chave])
		botao.call("atualizar", UPGRADE_NAMES[chave], "✓ Adquirida" if comprada else "%d E" % custo, comprada or player_energy < custo)
	loja_torres.hide()
	painel_upgrades.show()

func _voltar_para_loja() -> void:
	indice_torre_selecionada = -1
	titulo_painel_torres.text = "Defesas disponíveis"
	icone_torre_selecionada.hide()
	instrucao_torres.show()
	painel_upgrades.hide()
	loja_torres.show()

func _comprar_upgrade(indice_botao: int) -> void:
	var indice: int = indice_torre_selecionada
	if indice < 0 or indice >= torres.size() or torres[indice] == null:
		return
	if indice_botao < 0 or indice_botao >= botoes_upgrade.size():
		return
	var melhoria := str(botoes_upgrade[indice_botao].get_meta("melhoria", ""))
	var custo := int(regras.custos_upgrades.get(melhoria, 0))
	if melhoria.is_empty() or bool(upgrades_comprados[indice].get(melhoria, false)):
		return
	if player_energy < custo:
		status_ativacao.text = "Energia insuficiente. Você precisa de %d E." % custo
		return
	torres[indice].call("aplicar_upgrade", melhoria)
	upgrades_comprados[indice][melhoria] = true
	player_energy -= custo
	status_ativacao.text = "%s instalada por %d E." % [UPGRADE_NAMES[melhoria], custo]
	_atualizar_economia()
	_mostrar_upgrades(indice)

func _ao_clicar_torre(_camera_evento: Camera3D, evento: InputEvent, _posicao: Vector3, _normal: Vector3, _indice_forma: int, indice: int) -> void:
	if not evento is InputEventMouseButton:
		return
	var clique := evento as InputEventMouseButton
	if clique.button_index != MOUSE_BUTTON_LEFT or not clique.pressed:
		return
	if indice < 0 or indice >= torres.size() or torres[indice] == null:
		return
	var torre: Node3D = torres[indice]
	var indicador := torre.get_node_or_null("IndicadorAlcance") as MeshInstance3D
	if indicador == null:
		return
	if torre_com_alcance_selecionada == torre and indicador.visible:
		indicador.hide()
		torre_com_alcance_selecionada = null
		return
	if torre_com_alcance_selecionada != null:
		var indicador_anterior := torre_com_alcance_selecionada.get_node_or_null("IndicadorAlcance") as MeshInstance3D
		if indicador_anterior != null:
			indicador_anterior.hide()
	indicador.show()
	torre_com_alcance_selecionada = torre
	_mostrar_upgrades(indice)
	_abrir_loja()

func _ocultar_alcances_torres() -> void:
	torre_com_alcance_selecionada = null
	for torre in torres:
		if torre == null or not is_instance_valid(torre):
			continue
		var indicador := torre.get_node_or_null("IndicadorAlcance") as MeshInstance3D
		if indicador != null:
			indicador.hide()

func _atualizar_economia() -> void:
	energia_label.text = "%d E" % player_energy
	for indice in range(botoes_loja.size()):
		var tipo: String = TOWER_TYPES[indice]
		var custo := int(regras.custos_torres[tipo])
		botoes_loja[indice].call("atualizar", TOWER_NAMES[tipo], "%d E" % custo, player_energy < custo)
	if indice_torre_selecionada >= 0 and menu_torres.visible:
		_mostrar_upgrades(indice_torre_selecionada)

func _configurar_camera() -> void:
	tabuleiro.enquadrar(get_viewport().get_visible_rect().size, bases)
