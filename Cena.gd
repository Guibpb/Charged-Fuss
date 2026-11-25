extends Node3D

const ENEMY_SCENE = preload("res://Enemy.tscn")
const METRICA_MAPA = preload("res://MetricaMapa.gd")
const BASIC_TOWER_COST = 60
const FAST_TOWER_COST = 75
const UPGRADE_COSTS: Dictionary = {
	"dano": 45,
	"alcance": 30,
	"velocidade": 55,
	"balas": 65,
}
const UPGRADE_NAMES: Dictionary = {
	"dano": "Mais dano",
	"alcance": "Alcance +",
	"velocidade": "Velocidade +",
	"balas": "Balas ×2",
}
const TOTAL_RODADAS: int = 10
const INIMIGOS_POR_RODADA: Array[int] = [5, 8, 15, 15, 25, 30, 35, 40, 50, 50]
const ENERGIA_POR_DERROTA: int = 1
const BONUS_RODADA: int = 10
const INTERVALOS_RODADA: Array[float] = [1.8, 1.8, 1.5, 0.8, 1.0, 1.0, 0.8, 0.6, 0.8, 0.8]
const TUTORIAIS_RODADA: Array[String] = [
	"Ative uma torre para defender a rota. A rodada já começou.",
	"Compare a torre normal com a rápida: elas têm ritmos e setores diferentes.",
	"Cada inimigo derrotado gera energia para ativar mais torres.",
	"Observe o setor de visão e o alcance das torres ao longo do caminho.",
	"Combine torres com características diferentes para cobrir melhor a rota.",
	"Você pode abrir o painel durante a partida; o jogo continuará acontecendo.",
	"Distribua as ativações para cobrir diferentes trechos do caminho.",
	"Mais inimigos estarão na rota ao mesmo tempo. Acompanhe o campo inteiro.",
	"Prepare suas torres para a rodada final e guarde energia quando puder.",
	"Última rodada: derrote o chefe, que tem três vezes a vida normal.",
]

@export var enemy_vertical_offset: float = 0.2
@export var player_health: int = 50
@export var player_energy: int = 100
@export var path_visual_width: float = METRICA_MAPA.LARGURA_CAMINHO
@export var path_surface_offset: float = 0.13

@onready var caminho: Path3D = $Path3D
@onready var vida_label: Label = $HUD/VidaLabel
@onready var energia_label: Label = $HUD/EnergiaLabel
@onready var ganho_energia_label: Label = $HUD/GanhoEnergiaLabel
@onready var painel_rodada: Panel = $HUD/PainelRodada
@onready var rodada_label: Label = $HUD/PainelRodada/RodadaLabel
@onready var velocidade_label: Label = $HUD/VelocidadeLabel
@onready var menu_inicial: Control = $HUD/MenuInicial
@onready var menu_torres: Control = $HUD/MenuTorres
@onready var botao_jogo: Button = $HUD/MenuTorres/Painel/Conteudo/Comecar
@onready var instrucao_torres: Label = $HUD/MenuTorres/Painel/Conteudo/Instrucao
@onready var status_ativacao: Label = $HUD/MenuTorres/Painel/Conteudo/Status
@onready var botao_gerenciar_torres: Button = $HUD/GerenciarTorres
@onready var botao_pause: Button = $HUD/BotaoPause
@onready var botao_ativar_basica: Array[Button] = [
	$HUD/MenuTorres/Painel/Conteudo/Torre1/Linha/AtivarBasica,
	$HUD/MenuTorres/Painel/Conteudo/Torre2/Linha/AtivarBasica,
	$HUD/MenuTorres/Painel/Conteudo/Torre3/Linha/AtivarBasica,
	$HUD/MenuTorres/Painel/Conteudo/Torre4/Linha/AtivarBasica,
]
@onready var botao_ativar_rapida: Array[Button] = [
	$HUD/MenuTorres/Painel/Conteudo/Torre1/Linha/AtivarRapida,
	$HUD/MenuTorres/Painel/Conteudo/Torre2/Linha/AtivarRapida,
	$HUD/MenuTorres/Painel/Conteudo/Torre3/Linha/AtivarRapida,
	$HUD/MenuTorres/Painel/Conteudo/Torre4/Linha/AtivarRapida,
]
@onready var status_torres: Array[Label] = [
	$HUD/MenuTorres/Painel/Conteudo/Torre1/Estado,
	$HUD/MenuTorres/Painel/Conteudo/Torre2/Estado,
	$HUD/MenuTorres/Painel/Conteudo/Torre3/Estado,
	$HUD/MenuTorres/Painel/Conteudo/Torre4/Estado,
]
@onready var torres: Array[Node] = [
	$Torre1,
	$Torre2,
	$Torre3,
	$Torre4,
]
@onready var camera: Camera3D = $Camera3D
@onready var malha_chao: MeshInstance3D = $Chão/StaticBody3D/MeshInstance3D
@onready var tela_derrota: Control = $HUD/TelaDerrota
@onready var tela_vitoria: Control = $HUD/TelaVitoria

var tipos_ativados: Array[String] = ["", "", "", ""]
var upgrades_comprados: Array[Dictionary] = [
	{"dano": false, "alcance": false, "velocidade": false, "balas": false},
	{"dano": false, "alcance": false, "velocidade": false, "balas": false},
	{"dano": false, "alcance": false, "velocidade": false, "balas": false},
	{"dano": false, "alcance": false, "velocidade": false, "balas": false},
]
var partida_iniciada := false
var rodada_atual: int = 0
var inimigos_restantes: int = 0
var spawn_em_andamento: bool = false
var rodada_concluida: bool = false
var fase_encerrada: bool = false
var energia_ganha_em_eliminacoes: int = 0
var energia_ganha_em_rodadas: int = 0
var revisao_ganho_energia: int = 0
var nivel_velocidade: int = 1
var sequencia_cheat: String = ""
var revisao_fluxo_rodadas: int = 0
var torre_com_alcance_selecionada: Node3D = null

func _ready() -> void:
	Engine.time_scale = 1.0
	set_process_unhandled_key_input(true)
	get_tree().paused = true
	_configurar_camera()
	_update_health_label()
	_atualizar_economia()
	botao_pause.pressed.connect(_alternar_pausa)
	botao_jogo.pressed.connect(_on_game_play_pressed)
	botao_gerenciar_torres.pressed.connect(_on_gerenciar_torres_pressed)
	for indice in range(torres.size()):
		botao_ativar_basica[indice].pressed.connect(_ativar_torre.bind(indice, "basica"))
		botao_ativar_rapida[indice].pressed.connect(_ativar_torre.bind(indice, "rapida"))
		var torre_clicavel := torres[indice] as CollisionObject3D
		if torre_clicavel != null:
			torre_clicavel.input_ray_pickable = true
			torre_clicavel.input_event.connect(_ao_clicar_torre.bind(indice))
	get_viewport().physics_object_picking = true

	if caminho.curve == null or caminho.curve.get_baked_length() <= 0.0:
		push_error("O Path3D precisa ter uma curva com pelo menos dois pontos.")
		botao_jogo.disabled = true
	else:
		_orientar_torres_para_caminho()
		_criar_visual_do_caminho()

func _orientar_torres_para_caminho() -> void:
	var pontos := caminho.curve.get_baked_points()
	if pontos.is_empty():
		return

	for torre in torres:
		var torre_3d := torre as Node3D
		if torre_3d == null:
			continue
		var ponto_mais_proximo := caminho.to_global(pontos[0])
		var menor_distancia := INF
		for ponto in pontos:
			var ponto_global := caminho.to_global(ponto)
			var diferenca := ponto_global - torre_3d.global_position
			diferenca.y = 0.0
			var distancia_quadrada := diferenca.length_squared()
			if distancia_quadrada < menor_distancia:
				menor_distancia = distancia_quadrada
				ponto_mais_proximo = ponto_global
		ponto_mais_proximo.y = torre_3d.global_position.y
		var direcao_setor := ponto_mais_proximo - torre_3d.global_position
		if torre_3d.has_method("definir_direcao_setor"):
			torre_3d.call("definir_direcao_setor", direcao_setor)

func _iniciar_rodada(numero_rodada: int) -> void:
	if fase_encerrada or not partida_iniciada:
		return
	if numero_rodada > TOTAL_RODADAS:
		_encerrar_fase(true)
		return

	revisao_fluxo_rodadas += 1
	var revisao_atual: int = revisao_fluxo_rodadas

	rodada_atual = numero_rodada
	spawn_em_andamento = true
	rodada_concluida = false
	instrucao_torres.text = TUTORIAIS_RODADA[rodada_atual - 1]

	var quantidade_na_rodada: int = INIMIGOS_POR_RODADA[rodada_atual - 1]
	var total_de_spawns: int = quantidade_na_rodada + (1 if rodada_atual == TOTAL_RODADAS else 0)
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
		enemy.position.y = enemy_vertical_offset
		var eh_chefe: bool = rodada_atual == TOTAL_RODADAS and indice == quantidade_na_rodada
		if eh_chefe:
			enemy.call("configurar_como_chefe")
		enemy.connect("reached_end", _on_enemy_reached_end.bind(eh_chefe))
		enemy.connect("defeated", _on_enemy_defeated.bind(eh_chefe))
		path_follow.add_child(enemy)
		_atualizar_hud_rodada()

		if indice < total_de_spawns - 1:
			await get_tree().create_timer(INTERVALOS_RODADA[rodada_atual - 1], false).timeout
			if revisao_atual != revisao_fluxo_rodadas:
				return

	if revisao_atual != revisao_fluxo_rodadas:
		return
	spawn_em_andamento = false
	_atualizar_hud_rodada()
	_verificar_fim_rodada()

func _on_enemy_reached_end(eh_chefe: bool) -> void:
	var dano: int = 40 if eh_chefe else 1
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
	player_energy += ENERGIA_POR_DERROTA
	_mostrar_ganho_energia(ENERGIA_POR_DERROTA, false)
	_atualizar_economia()
	if eh_chefe:
		_vencer_nivel_pelo_chefe()
		return
	_resolver_inimigo()

func _vencer_nivel_pelo_chefe() -> void:
	if rodada_atual >= TOTAL_RODADAS and not rodada_concluida:
		rodada_concluida = true
		player_energy += BONUS_RODADA
		_mostrar_ganho_energia(BONUS_RODADA, true)
		_atualizar_economia()
	_encerrar_fase(true)

func _mostrar_ganho_energia(quantidade: int, bonus_rodada: bool) -> void:
	if bonus_rodada:
		energia_ganha_em_rodadas += quantidade
	else:
		energia_ganha_em_eliminacoes += quantidade

	revisao_ganho_energia += 1
	var revisao_atual: int = revisao_ganho_energia
	var texto_ganho: String = ""
	if energia_ganha_em_eliminacoes > 0:
		var rotulo_eliminacoes: String = "ELIMINAÇÃO" if energia_ganha_em_eliminacoes == 1 else "ELIMINAÇÕES"
		texto_ganho = "+%d E  •  %s" % [energia_ganha_em_eliminacoes, rotulo_eliminacoes]
	if energia_ganha_em_rodadas > 0:
		if not texto_ganho.is_empty():
			texto_ganho += "   |   "
		texto_ganho += "+%d E  •  RODADA CONCLUÍDA" % energia_ganha_em_rodadas
	ganho_energia_label.text = texto_ganho
	ganho_energia_label.show()
	_esconder_ganho_energia(revisao_atual)

func _esconder_ganho_energia(revisao: int) -> void:
	await get_tree().create_timer(1.8).timeout
	if revisao == revisao_ganho_energia:
		energia_ganha_em_eliminacoes = 0
		energia_ganha_em_rodadas = 0
		ganho_energia_label.hide()

func _resolver_inimigo() -> void:
	inimigos_restantes = maxi(0, inimigos_restantes - 1)
	_atualizar_hud_rodada()
	_verificar_fim_rodada()

func _verificar_fim_rodada() -> void:
	if fase_encerrada or spawn_em_andamento or inimigos_restantes > 0 or rodada_concluida:
		return

	rodada_concluida = true
	player_energy += BONUS_RODADA
	_mostrar_ganho_energia(BONUS_RODADA, true)
	_atualizar_economia()
	_atualizar_hud_rodada()
	if rodada_atual >= TOTAL_RODADAS:
		_encerrar_fase(true)
		return
	_aguardar_proxima_rodada(rodada_atual + 1)

func _aguardar_proxima_rodada(proxima_rodada: int) -> void:
	var revisao_atual: int = revisao_fluxo_rodadas
	await get_tree().create_timer(3.0, false).timeout
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
	menu_torres.hide()
	botao_gerenciar_torres.hide()
	botao_pause.hide()
	velocidade_label.hide()
	Engine.time_scale = 1.0
	nivel_velocidade = 1
	if vitoria:
		rodada_label.text = "FASE CONCLUÍDA"
	else:
		rodada_label.text = "FIM DE JOGO"
		tela_derrota.show()
	get_tree().paused = true
	if vitoria:
		_mostrar_tela_vitoria_com_transicao()

func _mostrar_tela_vitoria_com_transicao() -> void:
	await get_tree().create_timer(0.8, true, false, true).timeout
	tela_vitoria.modulate = Color(1.0, 1.0, 1.0, 0.0)
	tela_vitoria.show()
	var transicao: Tween = create_tween()
	transicao.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	transicao.set_trans(Tween.TRANS_CUBIC)
	transicao.set_ease(Tween.EASE_OUT)
	transicao.tween_property(tela_vitoria, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.8)

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
	botao_pause.text = "CONTINUAR" if get_tree().paused else "PAUSAR"

func _unhandled_key_input(event: InputEvent) -> void:
	var tecla_evento: InputEventKey = event as InputEventKey
	if tecla_evento == null or not tecla_evento.pressed or tecla_evento.echo:
		return
	if menu_inicial.visible or fase_encerrada:
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
	if not partida_iniciada or fase_encerrada or rodada_atual >= TOTAL_RODADAS:
		return

	for filho in caminho.get_children():
		if filho is PathFollow3D:
			filho.queue_free()

	inimigos_restantes = 0
	spawn_em_andamento = false
	rodada_concluida = false
	_mostrar_mensagem_energia("CÓDIGO B  •  RODADA FINAL")
	_iniciar_rodada(TOTAL_RODADAS)

func _mostrar_mensagem_energia(mensagem: String) -> void:
	energia_ganha_em_eliminacoes = 0
	energia_ganha_em_rodadas = 0
	revisao_ganho_energia += 1
	var revisao_atual: int = revisao_ganho_energia
	ganho_energia_label.text = mensagem
	ganho_energia_label.show()
	_esconder_ganho_energia(revisao_atual)

func _update_health_label() -> void:
	vida_label.text = "VIDA: %d" % player_health

func _on_menu_play_pressed() -> void:
	menu_inicial.hide()
	menu_torres.show()
	energia_label.show()
	painel_rodada.hide()
	rodada_label.hide()
	ganho_energia_label.hide()
	velocidade_label.hide()
	botao_pause.hide()
	botao_gerenciar_torres.hide()
	instrucao_torres.text = "Escolha sua primeira torre. A rodada começa assim que você ativá-la."
	status_ativacao.text = "A primeira torre inicia a partida automaticamente."
	get_tree().paused = true
	_atualizar_economia()

func _iniciar_fase() -> void:
	if partida_iniciada or fase_encerrada:
		return
	_orientar_torres_para_caminho()
	menu_torres.hide()
	partida_iniciada = true
	painel_rodada.show()
	rodada_label.show()
	velocidade_label.show()
	velocidade_label.text = "%d×" % nivel_velocidade
	botao_pause.show()
	botao_pause.text = "PAUSAR"
	botao_gerenciar_torres.show()
	_ocultar_alcances_torres()
	_atualizar_economia()
	get_tree().paused = false
	_iniciar_rodada(1)

func _on_gerenciar_torres_pressed() -> void:
	if not partida_iniciada:
		return
	botao_jogo.text = "FECHAR PAINEL"
	botao_gerenciar_torres.hide()
	menu_torres.show()

func _ativar_torre(indice: int, tipo: String) -> void:
	if indice < 0 or indice >= torres.size():
		return
	if not tipos_ativados[indice].is_empty():
		_comprar_upgrade(indice, tipo)
		return

	var custo := BASIC_TOWER_COST if tipo == "basica" else FAST_TOWER_COST
	if player_energy < custo:
		status_ativacao.text = "Energia insuficiente. Você precisa de %d E." % custo
		return

	torres[indice].call("ativar", tipo == "rapida")
	player_energy -= custo
	tipos_ativados[indice] = tipo
	_ocultar_alcances_torres()

	var nome_tipo := "rápida" if tipo == "rapida" else "normal"
	status_ativacao.text = "Torre %d ativada como %s por %d E." % [indice + 1, nome_tipo, custo]
	_atualizar_economia()
	if not partida_iniciada:
		_iniciar_fase()

func _comprar_upgrade(indice: int, botao_tipo: String) -> void:
	var tipo_torre := tipos_ativados[indice]
	var melhoria := ""
	if tipo_torre == "rapida":
		melhoria = "velocidade" if botao_tipo == "basica" else "balas"
	else:
		melhoria = "dano" if botao_tipo == "basica" else "alcance"

	var custo := int(UPGRADE_COSTS[melhoria])
	if upgrades_comprados[indice][melhoria]:
		return
	if player_energy < custo:
		status_ativacao.text = "Energia insuficiente. Você precisa de %d E." % custo
		return

	torres[indice].call("aplicar_upgrade", melhoria)
	upgrades_comprados[indice][melhoria] = true
	player_energy -= custo
	status_ativacao.text = "%s comprada para a torre %d por %d E." % [UPGRADE_NAMES[melhoria], indice + 1, custo]
	_atualizar_economia()

func _ao_clicar_torre(_camera_evento: Camera3D, evento: InputEvent, _posicao: Vector3, _normal: Vector3, _indice_forma: int, indice: int) -> void:
	if not evento is InputEventMouseButton:
		return
	var clique := evento as InputEventMouseButton
	if clique.button_index != MOUSE_BUTTON_LEFT or not clique.pressed:
		return
	if indice < 0 or indice >= torres.size():
		return
	var torre := torres[indice] as Node3D
	if torre == null:
		return
	var indicador := torre.get_node_or_null("IndicadorAlcance") as MeshInstance3D
	if indicador == null:
		return
	if not tipos_ativados[indice].is_empty() and torre_com_alcance_selecionada == torre and indicador.visible:
		indicador.hide()
		torre_com_alcance_selecionada = null
		return
	if torre_com_alcance_selecionada != null:
		var indicador_anterior := torre_com_alcance_selecionada.get_node_or_null("IndicadorAlcance") as MeshInstance3D
		if indicador_anterior != null:
			indicador_anterior.hide()
	if tipos_ativados[indice].is_empty():
		torre_com_alcance_selecionada = null
		return
	indicador.show()
	torre_com_alcance_selecionada = torre

func _ocultar_alcances_torres() -> void:
	torre_com_alcance_selecionada = null
	for torre in torres:
		var indicador := torre.get_node_or_null("IndicadorAlcance") as MeshInstance3D
		if indicador != null:
			indicador.hide()

func _atualizar_economia() -> void:
	energia_label.text = "%d E" % player_energy
	for indice in range(tipos_ativados.size()):
		var tipo := tipos_ativados[indice]
		if tipo.is_empty():
			status_torres[indice].text = "TORRE %02d  •  DESLIGADA" % (indice + 1)
			status_torres[indice].add_theme_color_override("font_color", Color(0.62, 0.7, 0.74, 1))
			botao_ativar_basica[indice].add_theme_font_size_override("font_size", 14)
			botao_ativar_rapida[indice].add_theme_font_size_override("font_size", 14)
			botao_ativar_basica[indice].text = "Normal · %d E" % BASIC_TOWER_COST
			botao_ativar_rapida[indice].text = "Rápida · %d E" % FAST_TOWER_COST
			botao_ativar_basica[indice].disabled = player_energy < BASIC_TOWER_COST
			botao_ativar_rapida[indice].disabled = player_energy < FAST_TOWER_COST
		else:
			var nome_tipo := "rápida" if tipo == "rapida" else "normal"
			var tipo_melhoria_1 := "velocidade" if tipo == "rapida" else "dano"
			var tipo_melhoria_2 := "balas" if tipo == "rapida" else "alcance"
			var tem_melhoria: bool = bool(upgrades_comprados[indice][tipo_melhoria_1]) or bool(upgrades_comprados[indice][tipo_melhoria_2])
			var estado := nome_tipo.to_upper() + (" +" if tem_melhoria else "")
			status_torres[indice].text = "TORRE %02d  •  %s" % [indice + 1, estado]
			status_torres[indice].add_theme_color_override("font_color", Color(0.4, 0.88, 0.84, 1))
			botao_ativar_basica[indice].add_theme_font_size_override("font_size", 12)
			botao_ativar_rapida[indice].add_theme_font_size_override("font_size", 12)
			botao_ativar_basica[indice].text = "%s\n%d E%s" % [UPGRADE_NAMES[tipo_melhoria_1], UPGRADE_COSTS[tipo_melhoria_1], " ✓" if upgrades_comprados[indice][tipo_melhoria_1] else ""]
			botao_ativar_rapida[indice].text = "%s\n%d E%s" % [UPGRADE_NAMES[tipo_melhoria_2], UPGRADE_COSTS[tipo_melhoria_2], " ✓" if upgrades_comprados[indice][tipo_melhoria_2] else ""]
			botao_ativar_basica[indice].disabled = upgrades_comprados[indice][tipo_melhoria_1] or player_energy < UPGRADE_COSTS[tipo_melhoria_1]
			botao_ativar_rapida[indice].disabled = upgrades_comprados[indice][tipo_melhoria_2] or player_energy < UPGRADE_COSTS[tipo_melhoria_2]

	if partida_iniciada:
		botao_jogo.text = "FECHAR PAINEL"
		botao_jogo.disabled = false
		botao_jogo.show()
	else:
		botao_jogo.hide()

func _on_game_play_pressed() -> void:
	if not partida_iniciada:
		return
	menu_torres.hide()
	botao_gerenciar_torres.show()

func _configurar_camera() -> void:
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	var tamanho_viewport := get_viewport().get_visible_rect().size
	var aspecto := tamanho_viewport.x / maxf(tamanho_viewport.y, 1.0)
	var tamanho_efetivo := METRICA_MAPA.tamanho_efetivo(aspecto)
	camera.size = tamanho_efetivo.y
	var largura_view := tamanho_efetivo.x / (1.0 - METRICA_MAPA.FRACAO_CONTROLES)
	var largura_controles := largura_view * METRICA_MAPA.FRACAO_CONTROLES
	var deslocamento_camera := Vector3(13.0, 20.0, 18.0)
	var eixo_direita_camera := Vector3(deslocamento_camera.z, 0.0, -deslocamento_camera.x).normalized()
	var centro_mapa := Vector3(-largura_controles * 0.5, malha_chao.global_position.y, 0.0) - eixo_direita_camera * 6.0
	camera.global_position = centro_mapa + deslocamento_camera
	camera.look_at(centro_mapa, Vector3.UP)
	var plano := malha_chao.mesh as PlaneMesh
	if plano != null:
		var tamanho_chao := maxf(largura_view, camera.size) * 4.0
		plano.size = Vector2(tamanho_chao, tamanho_chao)
	malha_chao.global_position = Vector3(centro_mapa.x, malha_chao.global_position.y, centro_mapa.z)

func _criar_visual_do_caminho() -> void:
	var pontos := caminho.curve.get_baked_points()
	if pontos.size() < 2:
		return

	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	for i in range(pontos.size()):
		var anterior := pontos[maxi(i - 1, 0)]
		var proximo := pontos[mini(i + 1, pontos.size() - 1)]
		var tangente := proximo - anterior
		tangente.y = 0.0
		var lateral := Vector3(tangente.z, 0.0, -tangente.x)
		if lateral.length_squared() < 0.000001:
			lateral = Vector3.RIGHT
		else:
			lateral = lateral.normalized()

		var centro := pontos[i] + Vector3.UP * path_surface_offset
		vertices.append(centro + lateral * path_visual_width * 0.5)
		vertices.append(centro - lateral * path_visual_width * 0.5)
		if i < pontos.size() - 1:
			var base := i * 2
			indices.append_array(PackedInt32Array([base, base + 1, base + 2, base + 1, base + 3, base + 2]))

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	var faixa := ArrayMesh.new()
	faixa.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = Color(0.65, 0.69, 0.73, 1.0)
	faixa.surface_set_material(0, material)

	var visual := MeshInstance3D.new()
	visual.name = "VisualCaminho"
	visual.mesh = faixa
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	caminho.add_child(visual)
