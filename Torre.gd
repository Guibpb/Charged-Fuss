extends CharacterBody3D

@export var shot_range: float = 5.5
@export var shot_interval: float = 1.0
@export var damage: int = 35
@export var projectile_scene: PackedScene = preload("res://Projectile.tscn")

const TURRET_UP_SCENE: PackedScene = preload("res://modelos/TurretUp.glb")
const TESLA_SCENE: PackedScene = preload("res://modelos/Tesla1.glb")
const TESLA_UP_SCENE: PackedScene = preload("res://modelos/Tesla2.glb")

var active := false
var torre_rapida := false
var tipo_torre: String = "basica"
var modelo_melhorado := false
var balas_por_disparo: int = 1
var dano_normal_configurado: int = 0
var shot_timer := 0.0
var velocidade_rotacao: float = 20.0
var direcao_setor_global: Vector3 = Vector3(0.0, 0.0, -1.0)
var parte_superior_rotativa: Node3D
var ponto_disparo: Node3D
var efeito_pulso: MeshInstance3D
var temporizador_pulso: Timer

const ALTURA_EIXO_MODELO: float = 0.95
const ALTURA_TOTAL_MODELO: float = 2.94
const COMPRIMENTO_CANHAO_MODELO: float = 2.8
const DESLOCAMENTO_FRENTE_MODELO: float = PI * 0.5
const ESCALA_MODELO_MELHORADO: float = 1.35

func _ready() -> void:
	add_to_group("torres")
	set_physics_process(false)
	dano_normal_configurado = damage
	if tipo_torre == "tesla":
		_preparar_modelo_tesla(false)
	elif tipo_torre == "chama":
		_preparar_modelo_chamas()
	else:
		_preparar_modelo_torre()

func configurar_tipo(tipo: String) -> void:
	tipo_torre = tipo

func _preparar_modelo_tesla_malha(cena_modelo: PackedScene, melhorado: bool) -> void:
	var modelo := get_node_or_null("Modelo") as Node3D
	if modelo == null:
		return
	for filho in modelo.get_children():
		modelo.remove_child(filho)
		filho.queue_free()
	var malha_tesla := cena_modelo.instantiate() as Node3D
	if malha_tesla == null:
		push_error("Não foi possível carregar o modelo da Tesla.")
		return
	malha_tesla.name = "ModeloTesla"
	var fator_tamanho: float = 1.25 if melhorado else 1.0
	modelo.scale = Vector3.ONE * 0.8 * fator_tamanho
	modelo.position = Vector3(6.4 * fator_tamanho, -1.0, 0.0 if melhorado else -3.2)
	modelo.add_child(malha_tesla)
	modelo.reset_physics_interpolation()
	modelo_melhorado = melhorado

func _preparar_modelo_tesla(melhorado: bool) -> void:
	var cena_modelo: PackedScene = TESLA_UP_SCENE if melhorado else TESLA_SCENE
	_preparar_modelo_tesla_malha(cena_modelo, melhorado)

func _preparar_modelo_chamas() -> void:
	var modelo := get_node_or_null("Modelo") as Node3D
	if modelo == null:
		return
	for filho in modelo.get_children():
		modelo.remove_child(filho)
		filho.queue_free()
	modelo.position = Vector3(0.0, -1.0, 0.0)
	modelo.scale = Vector3.ONE
	_criar_peca_chamas(modelo, CylinderMesh.new(), Vector3(0.0, 0.32, 0.0), Vector3(1.4, 0.28, 1.4), Color(0.16, 0.2, 0.23, 1.0))
	_criar_peca_chamas(modelo, CylinderMesh.new(), Vector3(0.0, 0.72, 0.0), Vector3(0.9, 0.78, 0.9), Color(0.25, 0.3, 0.32, 1.0))
	_criar_peca_chamas(modelo, BoxMesh.new(), Vector3(0.0, 0.95, 0.0), Vector3(1.15, 0.85, 1.15), Color(0.32, 0.37, 0.39, 1.0))
	for indice in range(4):
		var angulo: float = TAU * float(indice) / 4.0
		var direcao := Vector3(sin(angulo), 0.0, -cos(angulo))
		var rotacao := Vector3(PI * 0.5, angulo, 0.0)
		_criar_peca_chamas(modelo, CylinderMesh.new(), Vector3(0.0, 1.0, 0.0) + direcao * 0.8, Vector3(0.24, 0.24, 0.6), Color(0.92, 0.37, 0.1, 1.0), rotacao)
	_atualizar_cor(Color(0.98, 0.42, 0.12, 1.0), 0.13)

func _criar_peca_chamas(pai: Node3D, malha: PrimitiveMesh, posicao: Vector3, escala: Vector3, cor: Color, rotacao: Vector3 = Vector3.ZERO) -> void:
	var peca := MeshInstance3D.new()
	peca.mesh = malha
	peca.position = posicao
	peca.scale = escala
	peca.rotation = rotacao
	var material := StandardMaterial3D.new()
	material.albedo_color = cor
	material.metallic = 0.6
	material.roughness = 0.42
	peca.material_override = material
	pai.add_child(peca)

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
	_ajustar_inclinacao_superior()

func _ajustar_inclinacao_superior() -> void:
	if parte_superior_rotativa == null:
		return
	parte_superior_rotativa.rotation.z = 0.0

func ativar(tipo: String, atributos: Dictionary = {}) -> void:
	active = true
	tipo_torre = tipo
	torre_rapida = tipo == "rapida"
	_ajustar_inclinacao_superior()
	match tipo:
		"rapida":
			shot_range = 4.5
			shot_interval = 0.2
			damage = 10
		"tesla":
			shot_range = 6.5
			shot_interval = 0.8
			damage = 6
		"chama":
			shot_range = 3.5
			shot_interval = 0.25
			damage = 4
		_:
			shot_range = 5.5
			shot_interval = 0.8
			damage = dano_normal_configurado
	shot_range = float(atributos.get("shot_range", shot_range))
	shot_interval = float(atributos.get("shot_interval", shot_interval))
	damage = int(atributos.get("damage", damage))
	if tipo == "basica" or tipo == "rapida":
		_colorir_detalhes_torre()
	shot_timer = 0.0
	_criar_visual_de_alcance()
	set_physics_process(true)

func aplicar_upgrade(tipo_upgrade: String) -> void:
	match tipo_upgrade:
		"dano":
			damage = roundi(float(damage) * 1.5)
		"alcance":
			if torre_rapida:
				return
			shot_range *= 1.5
		"velocidade":
			shot_interval /= 1.5
		"balas":
			balas_por_disparo = 2
		"tesla_rapidez":
			shot_interval = 0.5
		"tesla_alcance":
			shot_range *= 1.25
		"chama_dano":
			damage = roundi(float(damage) * 1.5)
		"chama_alcance":
			shot_range *= 1.25
		_:
			return
	if tipo_torre == "tesla":
		if not modelo_melhorado:
			_preparar_modelo_tesla(true)
		_atualizar_visual_de_alcance()
		return
	if tipo_torre == "chama":
		if not modelo_melhorado:
			_adicionar_modulos_chamas()
		_atualizar_visual_de_alcance()
		return
	if modelo_melhorado:
		if tipo_upgrade == "alcance":
			_atualizar_visual_de_alcance()
		return
	_substituir_modelo_por_upgrade()

func _atualizar_visual_de_alcance() -> void:
	var indicador_atual := get_node_or_null("IndicadorAlcance") as MeshInstance3D
	var estava_visivel := indicador_atual != null and indicador_atual.visible
	_criar_visual_de_alcance()
	var indicador_novo := get_node_or_null("IndicadorAlcance") as MeshInstance3D
	if indicador_novo != null and not estava_visivel:
		indicador_novo.hide()

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
	_colorir_detalhes_torre()
	definir_direcao_setor(direcao_setor_global)
	reset_physics_interpolation()

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
		_ajustar_inclinacao_superior()

func _physics_process(delta: float) -> void:
	if not active:
		return
	shot_timer -= delta
	if shot_timer > 0.0:
		return
	if tipo_torre == "tesla":
		_executar_pulso_tesla()
		shot_timer = shot_interval
		return
	if tipo_torre == "chama":
		_executar_pulso_chamas()
		shot_timer = shot_interval
		return

	var alvo: Node3D = _encontrar_alvo_no_alcance()
	if alvo == null:
		return

	var direcao_alvo: Vector3 = alvo.global_position - global_position
	direcao_alvo.y = 0.0
	if direcao_alvo.length_squared() < 0.0001:
		return
	var yaw_alvo: float = atan2(-direcao_alvo.x, -direcao_alvo.z)
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

func _encontrar_alvo_no_alcance() -> Node3D:
	var target: Node3D = null
	var furthest_progress: float = -1.0
	var origem := global_position
	var alcance_quadrado := shot_range * shot_range
	for inimigo in get_tree().get_nodes_in_group("inimigos"):
		var enemy: Node3D = inimigo as Node3D
		if enemy == null or enemy == self or not is_instance_valid(enemy):
			continue
		var path_follow := enemy.get_parent() as PathFollow3D
		if path_follow == null:
			continue

		var direcao_alvo: Vector3 = enemy.global_position - origem
		direcao_alvo.y = 0.0
		var distancia_quadrada := direcao_alvo.length_squared()
		if distancia_quadrada <= 0.0 or distancia_quadrada > alcance_quadrado:
			continue

		if path_follow.progress > furthest_progress:
			furthest_progress = path_follow.progress
			target = enemy
	return target

func _inimigos_na_area() -> Array[Node3D]:
	var alvos: Array[Node3D] = []
	var origem := global_position
	var alcance_quadrado := shot_range * shot_range
	for inimigo in get_tree().get_nodes_in_group("inimigos"):
		if not is_instance_valid(inimigo) or inimigo == self:
			continue
		var inimigo_3d: Node3D = inimigo as Node3D
		if inimigo_3d == null:
			continue
		var deslocamento := inimigo_3d.global_position - origem
		if deslocamento.x * deslocamento.x + deslocamento.z * deslocamento.z <= alcance_quadrado:
			alvos.append(inimigo_3d)
	return alvos

func _executar_pulso_tesla() -> void:
	var alvos := _inimigos_na_area()
	if alvos.is_empty():
		return
	for alvo in alvos:
		if alvo.has_method("take_damage"):
			alvo.call("take_damage", damage)
		if alvo.has_method("aplicar_lentidao"):
			alvo.call("aplicar_lentidao", 0.5, 1.5)
	_desenhar_raios_tesla(alvos)

func _executar_pulso_chamas() -> void:
	var alvos := _inimigos_na_area()
	if alvos.is_empty():
		return
	for alvo in alvos:
		if alvo.has_method("take_damage"):
			alvo.call("take_damage", damage)
	_mostrar_pulso_chamas()

func _adicionar_modulos_chamas() -> void:
	var modelo := get_node_or_null("Modelo") as Node3D
	if modelo == null:
		return
	for lado in [-1.0, 1.0]:
		_criar_peca_chamas(modelo, CylinderMesh.new(), Vector3(lado * 0.62, 0.72, 0.1), Vector3(0.24, 0.8, 0.24), Color(0.8, 0.25, 0.08, 1.0))
	modelo_melhorado = true

func _mostrar_pulso_chamas() -> void:
	if efeito_pulso == null:
		var malha_pulso := TorusMesh.new()
		malha_pulso.inner_radius = 0.72
		malha_pulso.outer_radius = 0.82
		malha_pulso.rings = 48
		malha_pulso.ring_segments = 8
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_color = Color(1.0, 0.32, 0.06, 0.68)
		material.emission_enabled = true
		material.emission = Color(1.0, 0.22, 0.025, 1.0)
		material.emission_energy_multiplier = 2.0
		_preparar_efeito_pulso(malha_pulso, material)
		efeito_pulso.name = "PulsoChamas"
		efeito_pulso.position.y = -0.82
	var escala := shot_range / 0.82
	efeito_pulso.scale = Vector3(escala, minf(escala, 2.0), escala)
	efeito_pulso.reset_physics_interpolation()
	efeito_pulso.show()
	temporizador_pulso.start(0.18)

func _desenhar_raios_tesla(alvos: Array[Node3D]) -> void:
	if efeito_pulso == null:
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		material.albedo_color = Color(0.26, 0.9, 1.0, 1.0)
		material.emission_enabled = true
		material.emission = Color(0.12, 0.7, 1.0, 1.0)
		material.emission_energy_multiplier = 3.0
		_preparar_efeito_pulso(ImmediateMesh.new(), material)
		efeito_pulso.name = "RaioTesla"
	var malha_raios := efeito_pulso.mesh as ImmediateMesh
	var camera := get_viewport().get_camera_3d()
	var eixo_visao := Vector3.UP if camera == null else camera.global_basis.z
	var frente_local := global_basis.inverse() * eixo_visao
	var inicio := Vector3(0.0, 1.8, 0.0)
	malha_raios.clear_surfaces()
	malha_raios.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for alvo in alvos:
		var fim := to_local(alvo.global_position + Vector3.UP * 0.45)
		var lateral := (fim - inicio).cross(frente_local).normalized() * 0.027
		if lateral.is_zero_approx():
			lateral = Vector3.RIGHT * 0.027
		for vertice: Vector3 in [inicio - lateral, inicio + lateral, fim + lateral, inicio - lateral, fim + lateral, fim - lateral]:
			malha_raios.surface_add_vertex(vertice)
	malha_raios.surface_end()
	efeito_pulso.show()
	temporizador_pulso.start(0.14)

func _preparar_efeito_pulso(malha: Mesh, material: Material) -> void:
	efeito_pulso = MeshInstance3D.new()
	efeito_pulso.mesh = malha
	efeito_pulso.material_override = material
	efeito_pulso.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(efeito_pulso)
	temporizador_pulso = Timer.new()
	temporizador_pulso.one_shot = true
	temporizador_pulso.timeout.connect(efeito_pulso.hide)
	add_child(temporizador_pulso)

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
		projectile.reset_physics_interpolation()
	shot_timer = shot_interval

func _colorir_detalhes_torre() -> void:
	var cor := Color(1.0, 0.35, 0.04) if torre_rapida else Color(0.04, 0.45, 1.0)
	for parte in find_children("*", "MeshInstance3D", true, false):
		var visual := parte as MeshInstance3D
		if visual.mesh == null:
			continue
		for superficie in range(visual.mesh.get_surface_count()):
			var original := visual.get_active_material(superficie) as StandardMaterial3D
			if original == null or original.resource_name not in ["Material.007", "Material.008"]:
				continue
			var material := original.duplicate() as StandardMaterial3D
			if material.albedo_color.v > 0.0:
				material.albedo_color = Color(cor.r, cor.g, cor.b, material.albedo_color.a)
			material.emission = cor * original.emission.v
			visual.set_surface_override_material(superficie, material)

func _atualizar_cor(cor: Color, intensidade_tinta: float = 0.15) -> void:
	for parte in find_children("*", "MeshInstance3D", true, false):
		var visual := parte as MeshInstance3D
		var nome_parte := String(visual.name).to_lower()
		if visual.mesh == null or nome_parte.contains("indicadoralcance"):
			continue

		var sobreposicao := StandardMaterial3D.new()
		sobreposicao.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		sobreposicao.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		sobreposicao.albedo_color = Color(cor.r, cor.g, cor.b, intensidade_tinta)
		visual.material_overlay = sobreposicao

		if nome_parte.contains("neon"):
			var material_neon := StandardMaterial3D.new()
			material_neon.albedo_color = cor
			material_neon.roughness = 0.35
			visual.material_override = material_neon

func _criar_visual_de_alcance() -> void:
	var indicador_existente := get_node_or_null("IndicadorAlcance") as MeshInstance3D
	if indicador_existente != null:
		remove_child(indicador_existente)
		indicador_existente.queue_free()

	var segmentos: int = 72
	var espessura: float = 0.085
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	var raio_interno := maxf(0.0, shot_range - espessura)

	for i in range(segmentos):
		var angulo_inicial: float = TAU * float(i) / float(segmentos)
		var angulo_final: float = TAU * float(i + 1) / float(segmentos)
		var direcao_inicial := Vector3(sin(angulo_inicial), 0.0, -cos(angulo_inicial))
		var direcao_final := Vector3(sin(angulo_final), 0.0, -cos(angulo_final))
		var base := vertices.size()
		vertices.append(direcao_inicial * shot_range)
		vertices.append(direcao_inicial * raio_interno)
		vertices.append(direcao_final * shot_range)
		vertices.append(direcao_final * raio_interno)
		indices.append_array(PackedInt32Array([base, base + 1, base + 2, base + 1, base + 3, base + 2]))

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	var circulo := ArrayMesh.new()
	circulo.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var cor_alcance := Color(0.18, 0.82, 1.0, 0.8)
	if tipo_torre == "rapida":
		cor_alcance = Color(1.0, 0.55, 0.22, 0.8)
	elif tipo_torre == "chama":
		cor_alcance = Color(1.0, 0.38, 0.12, 0.8)
	material.albedo_color = cor_alcance
	circulo.surface_set_material(0, material)

	var visual := MeshInstance3D.new()
	visual.name = "IndicadorAlcance"
	visual.top_level = true
	visual.mesh = circulo
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(visual)
	visual.global_position = global_position + Vector3.UP * -0.92
	visual.global_rotation = Vector3.ZERO
	visual.reset_physics_interpolation()
