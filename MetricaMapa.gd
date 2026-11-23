extends RefCounted

# Padrão para todos os mapas: em 16:9, reserva-se 22% da largura para controles.
const ALTURA_EFETIVA: float = 29.5
const FRACAO_CONTROLES: float = 0.22
const ESCALA_OBJETOS: float = 2.0
const LARGURA_CAMINHO: float = 1.785

static func largura_total_da_tela(aspecto: float) -> float:
	return ALTURA_EFETIVA * aspecto

static func tamanho_efetivo(aspecto: float) -> Vector2:
	return Vector2(largura_total_da_tela(aspecto) * (1.0 - FRACAO_CONTROLES), ALTURA_EFETIVA)
