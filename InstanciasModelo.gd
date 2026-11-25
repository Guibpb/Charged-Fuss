extends RefCounted

# Modelos rígidos com peças repetidas. Só combina malhas e materiais idênticos.
const META_ASSINATURA := &"_assinatura_instancia"

static func agrupar(modelo: Node3D, animadas: Dictionary) -> Dictionary:
	# O Forward+ já agrupa peças internamente. Nos testes A/B os lotes manuais
	# reduziram chamadas, mas pioraram o tempo de quadro nesse renderizador.
	if RenderingServer.get_current_rendering_method() == "forward_plus":
		return {}
	var grupos: Dictionary = {}
	var inversa := modelo.global_transform.affine_inverse()
	for no in modelo.find_children("*", "MeshInstance3D", true, false):
		var visual := no as MeshInstance3D
		if not visual.visible or visual.mesh == null or visual.get_child_count() != 0:
			continue
		if visual.mesh.get_surface_count() != 1 or visual.material_override != null or visual.material_overlay != null:
			continue
		var material := visual.get_active_material(0)
		var base_material := material as BaseMaterial3D
		if base_material == null or base_material.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
			continue
		if visual.get_surface_override_material(0) != null or visual.mesh.get_blend_shape_count() != 0:
			continue
		if not visual.mesh.has_meta(META_ASSINATURA):
			var dados := visual.mesh.surface_get_arrays(0)
			var contexto := HashingContext.new()
			contexto.start(HashingContext.HASH_SHA256)
			contexto.update(var_to_bytes(dados))
			visual.mesh.set_meta(META_ASSINATURA, contexto.finish().hex_encode())
		var orientacao := signf(visual.global_basis.determinant())
		var chave := [visual.mesh.get_meta(META_ASSINATURA), material.get_instance_id(), visual.cast_shadow, visual.layers, orientacao, animadas.has(visual)]
		if not grupos.has(chave):
			grupos[chave] = []
		grupos[chave].append(visual)

	var instancias_animadas: Dictionary = {}
	for chave in grupos:
		var grupo: Array = grupos[chave]
		if grupo.size() < 3:
			continue
		var referencia: MeshInstance3D = grupo.front()
		var lote := MultiMesh.new()
		lote.transform_format = MultiMesh.TRANSFORM_3D
		lote.mesh = referencia.mesh
		lote.instance_count = grupo.size()
		var visual_lote := MultiMeshInstance3D.new()
		visual_lote.name = "PecasRepetidas"
		visual_lote.multimesh = lote
		visual_lote.cast_shadow = referencia.cast_shadow
		visual_lote.layers = referencia.layers
		modelo.add_child(visual_lote)
		var limites := AABB()
		for i in grupo.size():
			var visual: MeshInstance3D = grupo[i]
			var transformacao := inversa * visual.global_transform
			lote.set_instance_transform(i, transformacao)
			lote.reset_instance_physics_interpolation(i)
			visual.hide()
			if animadas.has(visual):
				var aabb := transformacao * visual.get_aabb()
				limites = aabb if i == 0 else limites.merge(aabb)
				instancias_animadas[visual] = [lote, i]
		if animadas.has(referencia):
			# Os elos percorrem o mesmo circuito. Mantém a caixa estável durante a animação.
			lote.custom_aabb = limites.grow(0.5)
	return instancias_animadas
