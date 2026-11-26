extends Resource

const Rodada = preload("res://fases/Rodada.gd")

@export var titulo_menu: String = ""
@export_multiline var mensagem_vitoria: String = ""
@export_multiline var instrucao_inicial: String = "Arraste uma defesa até uma base livre."
@export_multiline var mensagem_espera: String = "A partida começa quando você posicionar a primeira torre."
@export var iniciar_ao_entrar: bool = false

@export var vida_inicial: int = 50
@export var energia_inicial: int = 100
@export var energia_por_eliminacao: int = 1
@export var bonus_rodada: int = 15
@export var dano_fuga: int = 1
@export var dano_fuga_chefe: int = 35
@export var multiplicador_vida_chefe: int = 5
@export var intervalo_entre_rodadas: float = 3.0
@export var custos_torres: Dictionary[String, int] = {}
@export var custos_upgrades: Dictionary[String, int] = {}
@export var atributos_torres: Dictionary[String, Dictionary] = {}
@export var rodadas: Array[Rodada] = []
