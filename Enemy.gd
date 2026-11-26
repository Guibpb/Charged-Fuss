extends CharacterBody3D

const CAMINHO_MODELO_CHEFE := "res://modelos/boss3.glb"
const INSTANCIAS_MODELO = preload("res://InstanciasModelo.gd")

signal reached_end
signal defeated

@export var speed: float = 5.0
@export var gravity = 9.8

class SegmentoEsteira:
	var malha: MeshInstance3D
	var lote: MultiMesh
	var indice_lote: int
	var escala: Vector3
	var progresso: float = 0.0
	var posicao_x: float = 0.0

var health: int = 40
var escala_visual: float = 1.0
var is_boss: bool = false
var multiplicador_lentidao: float = 1.0
var tempo_lentidao: float = 0.0

var caminho: PathFollow3D
var death_processed := false
var _modelo_inimigo: Node3D
var _segmentos_esteira: Array[SegmentoEsteira] = []
var _comprimentos_percurso_esteira: Array[float] = []
var _direcoes_percurso_esteira: Array[Vector2] = []
var _comprimento_total_esteira: float = 0.0
var _avanco_esteira := 0.0
var _pontos_percurso_esteira: Array[Vector2] = [
	Vector2(-0.044, -0.564),
	Vector2(-0.044, 0.592),
	Vector2(-0.020, 0.719),
	Vector2(0.101, 0.815),
	Vector2(0.252, 0.815),
	Vector2(0.400, 0.815),
	Vector2(0.501, 0.729),
	Vector2(0.533, 0.592),
	Vector2(0.533, -0.564),
	Vector2(0.501, -0.733),
	Vector2(0.400, -0.813),
	Vector2(0.252, -0.813),
	Vector2(0.101, -0.813),
	Vector2(-0.020, -0.719),
]

func _ready():
	add_to_group("inimigos")
	caminho = get_parent() as PathFollow3D
	_modelo_inimigo = get_node_or_null("boss" if is_boss else "inimigo") as Node3D
	if not is_boss and _modelo_inimigo != null:
		_modelo_inimigo.scale = Vector3.ONE * (1.25 * escala_visual)
		_preparar_esteiras()
	elif _modelo_inimigo != null:
		INSTANCIAS_MODELO.agrupar(_modelo_inimigo, {})

func configurar_como_chefe(multiplicador_vida: int = 5) -> void:
	is_boss = true
	health *= multiplicador_vida
	var modelo_normal := get_node_or_null("inimigo")
	if modelo_normal != null:
		remove_child(modelo_normal)
		modelo_normal.queue_free()

	var estado := ResourceLoader.load_threaded_get_status(CAMINHO_MODELO_CHEFE)
	var cena_chefe: PackedScene
	if estado == ResourceLoader.THREAD_LOAD_IN_PROGRESS or estado == ResourceLoader.THREAD_LOAD_LOADED:
		cena_chefe = ResourceLoader.load_threaded_get(CAMINHO_MODELO_CHEFE) as PackedScene
	else:
		cena_chefe = load(CAMINHO_MODELO_CHEFE) as PackedScene
	var modelo_chefe := cena_chefe.instantiate() as Node3D if cena_chefe != null else null
	if modelo_chefe == null:
		push_error("O modelo do chefe precisa ter um nó raiz Node3D: " + CAMINHO_MODELO_CHEFE)
		return
	modelo_chefe.name = "boss"
	modelo_chefe.scale = Vector3.ONE * (1.15 * escala_visual)
	modelo_chefe.position.y = 0.12 * escala_visual
	add_child(modelo_chefe)

func _physics_process(delta) -> void:
	if death_processed or not is_instance_valid(caminho):
		return
	if tempo_lentidao > 0.0:
		tempo_lentidao = maxf(0.0, tempo_lentidao - delta)
		if tempo_lentidao <= 0.0:
			multiplicador_lentidao = 1.0

	var path := caminho.get_parent() as Path3D
	if path == null or path.curve == null:
		queue_free()
		return

	var comprimento_caminho: float = path.curve.get_baked_length()
	var distancia_percorrida: float = minf(maxf(float(speed) * multiplicador_lentidao * delta, 0.0), maxf(comprimento_caminho - caminho.progress, 0.0))
	caminho.progress += distancia_percorrida
	_atualizar_esteiras(distancia_percorrida)
	if caminho.progress >= path.curve.get_baked_length():
		death_processed = true
		reached_end.emit()
		_remover_do_percurso()

func _preparar_esteiras() -> void:
	if _modelo_inimigo == null:
		return

	_comprimento_total_esteira = 0.0
	_comprimentos_percurso_esteira.clear()
	_direcoes_percurso_esteira.clear()
	for indice in range(_pontos_percurso_esteira.size()):
		var inicio: Vector2 = _pontos_percurso_esteira[indice]
		var fim: Vector2 = _pontos_percurso_esteira[(indice + 1) % _pontos_percurso_esteira.size()]
		var comprimento: float = inicio.distance_to(fim)
		_comprimentos_percurso_esteira.append(comprimento)
		_direcoes_percurso_esteira.append((fim - inicio) / comprimento)
		_comprimento_total_esteira += comprimento

	_segmentos_esteira.clear()
	_coletar_segmentos_esteira(_modelo_inimigo, _modelo_inimigo.global_transform.affine_inverse())
	if _segmentos_esteira.is_empty():
		push_warning("Não encontrei os segmentos quadrados das esteiras no modelo inimigo.")
	var animadas: Dictionary = {}
	for elo in _segmentos_esteira:
		animadas[elo.malha] = true
	var lotes := INSTANCIAS_MODELO.agrupar(_modelo_inimigo, animadas)
	for elo in _segmentos_esteira:
		if lotes.has(elo.malha):
			var instancia: Array = lotes[elo.malha]
			elo.lote = instancia[0]
			elo.indice_lote = instancia[1]

func _coletar_segmentos_esteira(no: Node, inversa_modelo: Transform3D) -> void:
	if no is MeshInstance3D:
		var malha := no as MeshInstance3D
		var transformacao_local: Transform3D = inversa_modelo * malha.global_transform
		var posicao_local: Vector3 = transformacao_local.origin
		var escala_local: Vector3 = transformacao_local.basis.get_scale()
		var esta_na_lateral := absf(absf(posicao_local.x) - 0.824) < 0.06
		var tem_formato_de_elo := absf(escala_local.x) > 0.08 and absf(escala_local.y) < 0.03 and absf(escala_local.z) > 0.04
		var esta_na_altura_da_esteira := posicao_local.y >= -0.08 and posicao_local.y <= 0.57 and absf(posicao_local.z) <= 0.86
		if String(malha.name).begins_with("Cubo") and esta_na_lateral and tem_formato_de_elo and esta_na_altura_da_esteira:
			var elo := SegmentoEsteira.new()
			elo.malha = malha
			elo.escala = escala_local
			elo.posicao_x = posicao_local.x
			elo.progresso = _projetar_no_percurso(Vector2(posicao_local.y, posicao_local.z))
			_segmentos_esteira.append(elo)
			malha.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	for filho in no.get_children():
		_coletar_segmentos_esteira(filho, inversa_modelo)

func _projetar_no_percurso(posicao: Vector2) -> float:
	var melhor_distancia_quadrada: float = INF
	var melhor_progresso: float = 0.0
	var progresso_acumulado: float = 0.0

	for indice in range(_pontos_percurso_esteira.size()):
		var inicio: Vector2 = _pontos_percurso_esteira[indice]
		var fim: Vector2 = _pontos_percurso_esteira[(indice + 1) % _pontos_percurso_esteira.size()]
		var segmento: Vector2 = fim - inicio
		var comprimento: float = _comprimentos_percurso_esteira[indice]
		var fracao: float = clampf((posicao - inicio).dot(segmento) / (comprimento * comprimento), 0.0, 1.0)
		var ponto_mais_proximo: Vector2 = inicio + segmento * fracao
		var distancia_quadrada: float = posicao.distance_squared_to(ponto_mais_proximo)
		if distancia_quadrada < melhor_distancia_quadrada:
			melhor_distancia_quadrada = distancia_quadrada
			melhor_progresso = progresso_acumulado + comprimento * fracao
		progresso_acumulado += comprimento

	return melhor_progresso

func _amostrar_percurso(progresso: float) -> Vector4:
	var restante: float = fposmod(progresso, _comprimento_total_esteira)
	for indice in range(_pontos_percurso_esteira.size()):
		var inicio: Vector2 = _pontos_percurso_esteira[indice]
		var fim: Vector2 = _pontos_percurso_esteira[(indice + 1) % _pontos_percurso_esteira.size()]
		var comprimento: float = _comprimentos_percurso_esteira[indice]
		if restante <= comprimento or indice == _pontos_percurso_esteira.size() - 1:
			var fracao: float = clampf(restante / comprimento, 0.0, 1.0)
			var ponto: Vector2 = inicio.lerp(fim, fracao)
			var direcao := _direcoes_percurso_esteira[indice]
			return Vector4(ponto.x, ponto.y, direcao.x, direcao.y)
		restante -= comprimento
	return Vector4.ZERO

func _atualizar_esteiras(distancia: float) -> void:
	if distancia <= 0.0 or _comprimento_total_esteira <= 0.0:
		return

	_avanco_esteira = fposmod(_avanco_esteira + distancia / escala_visual, _comprimento_total_esteira)
	var transformacao_modelo := _modelo_inimigo.global_transform
	for elo in _segmentos_esteira:
		var amostra: Vector4 = _amostrar_percurso(elo.progresso + _avanco_esteira)
		var direcao: Vector3 = Vector3(0.0, amostra.z, amostra.w)
		var eixo_vertical: Vector3 = direcao.cross(Vector3.RIGHT)
		var base: Basis = Basis(Vector3.RIGHT, eixo_vertical, direcao).scaled(elo.escala)
		var posicao_local := Vector3(elo.posicao_x, amostra.x, amostra.y)
		var transformacao := Transform3D(base, posicao_local)
		if elo.lote != null:
			elo.lote.set_instance_transform(elo.indice_lote, transformacao)
		else:
			elo.malha.global_transform = transformacao_modelo * transformacao

func _remover_do_percurso() -> void:
	if is_instance_valid(caminho) and caminho.get_child_count() == 1:
		caminho.queue_free()
	else:
		queue_free()

func aplicar_lentidao(multiplicador: float, duracao: float) -> void:
	# Pulsos repetidos renovam o mesmo efeito; a velocidade não se multiplica de novo.
	multiplicador_lentidao = minf(multiplicador_lentidao, clampf(multiplicador, 0.0, 1.0))
	tempo_lentidao = maxf(tempo_lentidao, duracao)

func take_damage(amount: int) -> void:
	if death_processed:
		return
	health -= amount
	if health <= 0:
		death_processed = true
		defeated.emit()
		_remover_do_percurso()
