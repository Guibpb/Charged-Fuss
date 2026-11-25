extends Button

const FONTE_MEDIA = preload("res://fonts/Orbitron-Medium.ttf")
const FONTE_NEGRITO = preload("res://fonts/Orbitron-Bold.ttf")

var rotulo_nome: Label
var rotulo_preco: Label
var icone: Texture2D

func montar(icone_defesa: Texture2D = null) -> void:
	icone = icone_defesa
	theme_type_variation = &"DefesaDisponivel"
	custom_minimum_size.y = 64.0
	var linha := HBoxContainer.new()
	linha.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(linha)
	linha.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	linha.offset_left = 10.0
	linha.offset_right = -10.0
	linha.add_theme_constant_override("separation", 8)
	if icone != null:
		linha.add_child(criar_imagem(icone, 48.0))
	rotulo_nome = Label.new()
	rotulo_nome.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rotulo_nome.add_theme_font_override("font", FONTE_MEDIA)
	rotulo_preco = Label.new()
	rotulo_preco.add_theme_font_override("font", FONTE_NEGRITO)
	rotulo_preco.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	for rotulo: Label in [rotulo_nome, rotulo_preco]:
		rotulo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rotulo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		linha.add_child(rotulo)

func atualizar(nome: String, preco: String, indisponivel: bool) -> void:
	if rotulo_nome.text == nome and rotulo_preco.text == preco and disabled == indisponivel:
		return
	rotulo_nome.text = nome
	rotulo_preco.text = preco
	accessibility_name = "%s, %s" % [nome, preco]
	tooltip_text = accessibility_name
	disabled = indisponivel
	rotulo_nome.modulate = Color("#BAC5C8") if indisponivel else Color.WHITE
	rotulo_preco.modulate = Color("#BAC5C8") if indisponivel else Color("#59DCE3")

static func criar_imagem(textura: Texture2D, tamanho: float) -> TextureRect:
	var imagem := TextureRect.new()
	imagem.texture = textura
	imagem.custom_minimum_size = Vector2.ONE * tamanho
	imagem.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	imagem.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	imagem.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	imagem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return imagem
