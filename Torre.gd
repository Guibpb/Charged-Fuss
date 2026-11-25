extends CharacterBody3D

@export var shot_range: float = 5.5
@export var sector_angle_degrees: float = 100.0
@export var shot_interval: float = 1.0
@export var damage: int = 35
@export var projectile_scene: PackedScene = preload("res://Projectile.tscn")

const TURRET_UP_SCENE: PackedScene = preload("res://modelos/TurretUp.glb")

var active := false
var torre_rapida := false
var modelo_melhorado := false
var balas_por_disparo: int = 1
var dano_normal_configurado: int = 0
var shot_timer := 0.0
var velocidade_rotacao: float = 20.0
var direcao_setor_global: Vector3 = Vector3(0.0, 0.0, -1.0)
var parte_superior_rotativa: Node3D
var ponto_disparo: Node3D

const ALTURA_EIXO_MODELO: float = 0.95
const ALTURA_TOTAL_MODELO: float = 2.94
const COMPRIMENTO_CANHAO_MODELO: float = 2.8
const DESLOCAMENTO_FRENTE_MODELO: float = PI * 0.5
const ESCALA_MODELO_MELHORADO: float = 1.35

func _ready() -> void:
	add_to_group("torres")
	set_physics_process(false)
	dano_normal_configurado = damage
	_preparar_modelo_torre()
	_atualizar_cor(Color(0.34, 0.37, 0.39, 1.0))

func _preparar_modelo_torre() -> void:
	var modelo := get_node_or_null("Modelo") as Node3D
	if modelo == null:
		return

	var escala_modelo := absf(modelo.scale.x)
	var pivo := Node3D.new()
	pivo.name = "ParteSuperiorRotativa"
	add_child(pivo)
	pivo.position.y = -1.12 + ALTURA_EIXO_MODELO * escala_modelo
	parte_superior_rotativa = pivo

	for parte in modelo.find_children("*", "MeshInstance3D", true, false):
		var nome_parte := String(parte.name).to_lower().replace(".", "").replace("_", "")
		var visual_parte := parte as MeshInstance3D
		if visual_parte.mesh != null:
			nome_parte += String(visual_parte.mesh.resource_name).to_lower().replace(".", "").replace("_", "")
		if nome_parte.contains("gun") or nome_parte.contains("baseturret"):
			visual_parte.reparent(pivo, true)

	var marcador := Node3D.new()
	marcador.name = "PontoDisparo"
	pivo.add_child(marcador)
	var comprimento_canhao := 3.4 if modelo_melhorado else COMPRIMENTO_CANHAO_MODELO
	var altura_total := 3.0 if modelo_melhorado else ALTURA_TOTAL_MODELO
	marcador.position = Vector3(
		comprimento_canhao * escala_modelo,
		(altura_total - ALTURA_EIXO_MODELO) * escala_modelo,
		0.0
	)
	ponto_disparo = marcador
	parte_superior_rotativa.global_rotation.y = global_rotation.y + DESLOCAMENTO_FRENTE_MODELO

func ativar(rapida: bool) -> void:
	active = true
	torre_rapida = rapida
	if rapida:
		shot_range = 4.5
		sector_angle_degrees = 60.0
		shot_interval = 0.2
		damage = 10
		_atualizar_cor(Color(1.0, 0.56, 0.2, 1.0))
	else:
		shot_range = 5.5
		sector_angle_degrees = 100.0
		shot_interval = 0.8
		damage = dano_normal_configurado
		_atualizar_cor(Color(0.18, 0.58, 0.78, 1.0))
	shot_timer = 0.0
	_criar_visual_de_alcance()
	set_physics_process(true)

func aplicar_upgrade(tipo_upgrade: String) -> void:
	match tipo_upgrade:
		"dano":
			damage = roundi(float(damage) * 1.5)
		"alcance":
			shot_range *= 1.5
		"velocidade":
			shot_interval /= 1.5
		"balas":
			balas_por_disparo = 2
		_:
			return
	_substituir_modelo_por_upgrade()
	
func _substituir_modelo_por_upgrade() -> void:
	if modelo_melhorado:
		return
	var modelo := get_node_or_null("Modelo") as Node3D
	if modelo == null:
		return

	var indicador := get_node_or_null("IndicadorAlcance") as MeshInstance3D
	var indicador_estava_visivel := indicador != null and indicador.visible
	if parte_superior_rotativa != null:
		remove_child(parte_superior_rotativa)
		parte_superior_rotativa.queue_free()
	parte_superior_rotativa = null
	ponto_disparo = null

	var modelo_anterior := modelo.get_node_or_null("Turret1")
	if modelo_anterior != null:
		modelo.remove_child(modelo_anterior)
		modelo_anterior.queue_free()

	modelo.position.z = 0.0
	modelo.scale *= ESCALA_MODELO_MELHORADO
	# Mantém a compensação horizontal do GLB proporcional à nova escala.
	modelo.position.x *= ESCALA_MODELO_MELHORADO
	var novo_modelo := TURRET_UP_SCENE.instantiate() as Node3D
	if novo_modelo == null:
		push_error("Não foi possível carregar o modelo TurretUp.glb.")
		return
	novo_modelo.name = "TurretUp"
	modelo.add_child(novo_modelo)
	modelo_melhorado = true
	_preparar_modelo_torre()
	var identificador := get_node_or_null("Identificador") as Label3D
	if identificador != null:
		identificador.position.y = 2.45
	_atualizar_cor(Color(1.0, 0.56, 0.2, 1.0) if torre_rapida else Color(0.18, 0.58, 0.78, 1.0))
	definir_direcao_setor(direcao_setor_global)

	_criar_visual_de_alcance()
	var novo_indicador := get_node_or_null("IndicadorAlcance") as MeshInstance3D
	if novo_indicador != null and not indicador_estava_visivel:
		novo_indicador.hide()

func definir_direcao_setor(direcao: Vector3) -> void:
	direcao.y = 0.0
	if direcao.length_squared() < 0.0001:
		return
	direcao_setor_global = direcao.normalized()
	var yaw := atan2(-direcao_setor_global.x, -direcao_setor_global.z)
	global_rotation.y = yaw
	if parte_superior_rotativa != null:
		parte_superior_rotativa.global_rotation.y = yaw + DESLOCAMENTO_FRENTE_MODELO

func _physics_process(delta: float) -> void:
	if not active:
		return
	shot_timer -= delta
	if shot_timer > 0.0:
		return

	var alvo := _encontrar_alvo_no_setor()
	if alvo == null:
		return

	var direcao_alvo := alvo.global_position - global_position
	direcao_alvo.y = 0.0
	if direcao_alvo.length_squared() < 0.0001:
		return
	var yaw_alvo := atan2(-direcao_alvo.x, -direcao_alvo.z)
	if parte_superior_rotativa != null:
		var yaw_modelo_alvo := yaw_alvo + DESLOCAMENTO_FRENTE_MODELO
		var diferenca_angular_modelo := wrapf(yaw_modelo_alvo - parte_superior_rotativa.global_rotation.y, -PI, PI)
		parte_superior_rotativa.global_rotation.y += clampf(
			diferenca_angular_modelo,
			-velocidade_rotacao * delta,
			velocidade_rotacao * delta
		)
		var erro_angular_modelo := absf(wrapf(yaw_modelo_alvo - parte_superior_rotativa.global_rotation.y, -PI, PI))
		if shot_timer <= 0.0 and erro_angular_modelo <= deg_to_rad(3.0):
			_atirar_no_alvo(alvo)
		return

	var diferenca_angular_base := wrapf(yaw_alvo - global_rotation.y, -PI, PI)
	global_rotation.y += clampf(diferenca_angular_base, -velocidade_rotacao * delta, velocidade_rotacao * delta)
	var erro_angular_base := absf(wrapf(yaw_alvo - global_rotation.y, -PI, PI))
	if shot_timer <= 0.0 and erro_angular_base <= deg_to_rad(3.0):
		_atirar_no_alvo(alvo)

func _encontrar_alvo_no_setor() -> Node3D:
	var target = null
	var furthest_progress := -1.0
	for enemy in get_tree().get_nodes_in_group("inimigos"):
		if enemy == self or not is_instance_valid(enemy):
			continue
		var path_follow := enemy.get_parent() as PathFollow3D
		if path_follow == null:
			continue

		var direcao_alvo: Vector3 = enemy.global_position - global_position
		direcao_alvo.y = 0.0
		var distancia_alvo := direcao_alvo.length()
		if distancia_alvo <= 0.0 or distancia_alvo > shot_range:
			continue

		var alinhamento := direcao_setor_global.dot(direcao_alvo / distancia_alvo)
		var limite_setor := cos(deg_to_rad(sector_angle_degrees * 0.5))
		if alinhamento >= limite_setor and path_follow.progress > furthest_progress:
			furthest_progress = path_follow.progress
			target = enemy
	return target as Node3D


func _atirar_no_alvo(target: Node3D) -> void:
	var origem := global_position + Vector3.UP * 0.2
	if ponto_disparo != null:
		origem = ponto_disparo.global_position
	var direcao_base: Vector3 = (target.global_position - origem).normalized()
	var lateral := Vector3(direcao_base.z, 0.0, -direcao_base.x).normalized()
	if lateral.length_squared() < 0.0001:
		lateral = Vector3.RIGHT
	for indice_bala in range(balas_por_disparo):
		var deslocamento_lateral := (float(indice_bala) - float(balas_por_disparo - 1) * 0.5) * 0.18
		var origem_bala := origem + lateral * deslocamento_lateral
		var direction: Vector3 = (target.global_position - origem_bala).normalized()
		var projectile = projectile_scene.instantiate()
		projectile.shooter = self
		projectile.damage = damage
		get_tree().current_scene.add_child(projectile)
		projectile.global_position = origem_bala
		projectile.direction = direction
	shot_timer = shot_interval

func _atualizar_cor(cor: Color) -> void:
	var visual := get_node_or_null("MeshInstance3D") as MeshInstance3D
	if visual == null:
		for parte in find_children("*", "MeshInstance3D", true, false):
			if not String(parte.name).to_lower().contains("neon"):
				continue
			var material_neon := StandardMaterial3D.new()
			material_neon.albedo_color = cor
			material_neon.roughness = 0.35
			(parte as MeshInstance3D).material_override = material_neon
		return
	var material := StandardMaterial3D.new()
	material.albedo_color = cor
	visual.material_override = material

func _criar_visual_de_alcance() -> void:
	var indicador_existente := get_node_or_null("IndicadorAlcance") as MeshInstance3D
	if indicador_existente != null:
		remove_child(indicador_existente)
		indicador_existente.queue_free()

	var segmentos := 64
	var espessura := 0.07
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	var raio_interno := maxf(0.0, shot_range - espessura)
	var meia_abertura := deg_to_rad(sector_angle_degrees * 0.5)

	for i in range(segmentos):
		var angulo_inicial := -meia_abertura + sector_angle_degrees * PI / 180.0 * float(i) / float(segmentos)
		var angulo_final := -meia_abertura + sector_angle_degrees * PI / 180.0 * float(i + 1) / float(segmentos)
		var direcao_inicial := Vector3(sin(angulo_inicial), 0.0, -cos(angulo_inicial))
		var direcao_final := Vector3(sin(angulo_final), 0.0, -cos(angulo_final))
		var base := vertices.size()
		vertices.append(direcao_inicial * shot_range)
		vertices.append(direcao_inicial * raio_interno)
		vertices.append(direcao_final * shot_range)
		vertices.append(direcao_final * raio_interno)
		indices.append_array(PackedInt32Array([base, base + 1, base + 2, base + 1, base + 3, base + 2]))

	for angulo in [-meia_abertura, meia_abertura]:
		var direcao := Vector3(sin(angulo), 0.0, -cos(angulo))
		var lateral := Vector3(-direcao.z, 0.0, direcao.x).normalized() * espessura * 0.5
		var base := vertices.size()
		vertices.append(lateral)
		vertices.append(-lateral)
		vertices.append(direcao * shot_range + lateral)
		vertices.append(direcao * shot_range - lateral)
		indices.append_array(PackedInt32Array([base, base + 1, base + 2, base + 1, base + 3, base + 2]))

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	var setor := ArrayMesh.new()
	setor.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = Color(0.18, 0.82, 1.0, 0.8)
	setor.surface_set_material(0, material)

	var visual := MeshInstance3D.new()
	visual.name = "IndicadorAlcance"
	visual.top_level = true
	visual.mesh = setor
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(visual)
	visual.global_position = global_position + Vector3.UP * -0.98
	visual.global_rotation = Vector3(0.0, atan2(-direcao_setor_global.x, -direcao_setor_global.z), 0.0)
