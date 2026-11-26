extends Node3D

const BaseConstrucao = preload("res://fases/BaseConstrucao.gd")
const RegrasFase = preload("res://fases/RegrasFase.gd")
const METRICA_MAPA = preload("res://MetricaMapa.gd")

@export var caminho: Path3D
@export var container_bases: Node3D
@export var camera: Camera3D
@export var luz: DirectionalLight3D
@export var regras: RegrasFase
@export var altura_inimigo: float = 0.2
@export var escala_visual_drone: float = 1.0
@export var escala_visual_chefe: float = 1.0
@export var alturas_torres: Dictionary[String, float] = {}

@export_group("Enquadramento")
@export var enquadrar_automaticamente: bool = true
@export var deslocamento_camera: Vector3 = Vector3(13, 20, 50)
@export var altura_minima_camera: float = METRICA_MAPA.ALTURA_EFETIVA
@export var altura_torres_camera: float = 4.0
@export var margem_mundo: Vector2 = Vector2(4.0, 2.2)
@export var margens_tela: Vector4 = Vector4(364, 156, 42, 50)
## Comprimento do trecho final ignorado ao calcular o enquadramento.
@export var trecho_final_fora_do_enquadramento: float = 0.0
# Pontos locais adicionais para regiões importantes fora da rota e das bases.
@export var pontos_enquadramento: PackedVector3Array

@export_group("Piso e faixa auxiliares")
@export var piso_expansivel: MeshInstance3D
@export var plano_soltar_comum: Node3D
@export var ajuste_bases_camera: float = 0.0
@export var largura_faixa: float = 0.0
@export var altura_faixa: float = 0.15

func listar_bases() -> Array[BaseConstrucao]:
	var resultado: Array[BaseConstrucao] = []
	for filho in container_bases.get_children():
		if filho is BaseConstrucao:
			resultado.append(filho)
	return resultado

func enquadrar(tela: Vector2, bases: Array[BaseConstrucao]) -> void:
	if not enquadrar_automaticamente or tela.x <= 0.0 or tela.y <= 0.0:
		return

	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	var orientacao := Basis.looking_at(-deslocamento_camera)
	var local_camera := orientacao.inverse()
	var minimo := Vector2(INF, INF)
	var maximo := Vector2(-INF, -INF)
	var pontos := PackedVector3Array()
	var pontos_rota := caminho.curve.get_baked_points()
	var fim_visivel := maxf(0.0, caminho.curve.get_baked_length() - trecho_final_fora_do_enquadramento)
	var distancia := 0.0
	for indice in range(pontos_rota.size()):
		if trecho_final_fora_do_enquadramento > 0.0 and indice > 0:
			distancia += pontos_rota[indice - 1].distance_to(pontos_rota[indice])
			if distancia > fim_visivel:
				pontos.append(caminho.to_global(caminho.curve.sample_baked(fim_visivel)))
				break
		pontos.append(caminho.to_global(pontos_rota[indice]))
	for base in bases:
		var referencia := base.global_position + Vector3.UP * ajuste_bases_camera
		pontos.append(referencia)
		pontos.append(referencia + Vector3.UP * altura_torres_camera)
	for ponto in pontos_enquadramento:
		pontos.append(to_global(ponto))
	for ponto in pontos:
		var local := local_camera * ponto
		var plano := Vector2(local.x, local.y)
		minimo = minimo.min(plano)
		maximo = maximo.max(plano)

	var area := Rect2(margens_tela.x, margens_tela.y,
		maxf(tela.x - margens_tela.x - margens_tela.z, 1.0),
		maxf(tela.y - margens_tela.y - margens_tela.w, 1.0))
	var extensao := maximo - minimo + margem_mundo
	var unidades_por_pixel := maxf(altura_minima_camera / tela.y,
		maxf(extensao.x / area.size.x, extensao.y / area.size.y))
	camera.size = unidades_por_pixel * tela.y
	var centro := (minimo + maximo) * 0.5
	var desvio := area.get_center() - tela * 0.5
	var alvo := orientacao * Vector3(centro.x - desvio.x * unidades_por_pixel, centro.y + desvio.y * unidades_por_pixel, 0.0)
	camera.global_position = alvo + deslocamento_camera
	camera.look_at(alvo)
	camera.reset_physics_interpolation()

	if piso_expansivel != null:
		var plano_chao := piso_expansivel.mesh as PlaneMesh
		if plano_chao != null:
			var tamanho_chao := maxf(tela.x * unidades_por_pixel, camera.size) * 4.0
			plano_chao.size = Vector2(tamanho_chao, tamanho_chao)
		piso_expansivel.global_position = Vector3(alvo.x, piso_expansivel.global_position.y, alvo.z)
		piso_expansivel.reset_physics_interpolation()

func criar_visual_do_caminho() -> void:
	if largura_faixa <= 0.0:
		return
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

		var centro := pontos[i] + Vector3.UP * altura_faixa
		vertices.append(centro + lateral * largura_faixa * 0.5)
		vertices.append(centro - lateral * largura_faixa * 0.5)
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
