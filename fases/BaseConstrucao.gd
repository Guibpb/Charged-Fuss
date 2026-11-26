extends Marker3D

@export var dimensoes: Vector2 = Vector2(2.3, 2.3)
# Zero usa o retângulo do topo. Um valor positivo usa um raio em unidades do mapa.
@export var tolerancia_soltar: float = 0.0
@export var tipo_inicial: String = ""
@export var altura_torre: float = 0.88
@export var altura_indicador: float = 0.04
