extends CharacterBody3D

@export var shot_range: float = 4.5
@export var sector_angle_degrees: float = 100.0
@export var shot_interval: float = 1.0
@export var damage: int = 25
@export var projectile_scene: PackedScene = preload("res://Projectile.tscn")

var active := false
var shot_timer := 0.0
var velocidade_rotacao: float = 20.0
var direcao_setor_global: Vector3 = Vector3(0.0, 0.0, -1.0)

func _ready() -> void:
	add_to_group("torres")
	set_physics_process(false)
	_atualizar_cor(Color(0.34, 0.37, 0.39, 1.0))

func ativar(rapida: bool) -> void:
	active = true
	if rapida:
		shot_range = 3.5
		sector_angle_degrees = 60.0
		shot_interval = 0.2
		damage = 10
		_atualizar_cor(Color(1.0, 0.56, 0.2, 1.0))
	else:
		shot_range = 4.5
		sector_angle_degrees = 100.0
		shot_interval = 0.8
		damage = 25
		_atualizar_cor(Color(0.18, 0.58, 0.78, 1.0))
	shot_timer = 0.0
	_criar_visual_de_alcance()
	set_physics_process(true)

func definir_direcao_setor(direcao: Vector3) -> void:
	direcao.y = 0.0
	if direcao.length_squared() < 0.0001:
		return
	direcao_setor_global = direcao.normalized()
	var yaw := atan2(-direcao_setor_global.x, -direcao_setor_global.z)
	global_rotation.y = yaw

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
	global_rotation.y = rotate_toward(global_rotation.y, yaw_alvo, velocidade_rotacao * delta)
	var erro_angular := absf(wrapf(yaw_alvo - global_rotation.y, -PI, PI))
	if shot_timer <= 0.0 and erro_angular <= deg_to_rad(3.0):
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
	var direction: Vector3 = (target.global_position - global_position).normalized()
	var projectile = projectile_scene.instantiate()
	projectile.shooter = self
	projectile.damage = damage
	get_tree().current_scene.add_child(projectile)
	projectile.global_position = global_position + direction * 1.2 + Vector3.UP * 0.2
	projectile.direction = direction
	shot_timer = shot_interval

func _atualizar_cor(cor: Color) -> void:
	var visual := get_node_or_null("MeshInstance3D") as MeshInstance3D
	if visual == null:
		return
	var material := StandardMaterial3D.new()
	material.albedo_color = cor
	visual.material_override = material

func _criar_visual_de_alcance() -> void:
	var indicador_existente := get_node_or_null("IndicadorAlcance") as MeshInstance3D
	if indicador_existente != null:
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
