extends Control

## Panel de Teclado Virtual – Símbolos y fragmentos de código copiables para SpidoCode
## Permite copiar al portapapeles caracteres difíciles de escribir y snipets de misiones.

signal fragmento_seleccionado(texto: String)

# Símbolos individuales agrupados
const SIMBOLOS := [
	{ "label": "=",    "valor": "=",    "tooltip": "Igual / Asignación" },
	{ "label": "==",   "valor": "==",   "tooltip": "Igual a (comparación)" },
	{ "label": "!=",   "valor": "!=",   "tooltip": "Diferente de" },
	{ "label": "<",    "valor": "<",    "tooltip": "Menor que" },
	{ "label": ">",    "valor": ">",    "tooltip": "Mayor que" },
	{ "label": "<=",   "valor": "<=",   "tooltip": "Menor o igual que" },
	{ "label": ">=",   "valor": ">=",   "tooltip": "Mayor o igual que" },
	{ "label": ":",    "valor": ":",    "tooltip": "Dos puntos (bloque de código)" },
	{ "label": "( )",  "valor": "()",   "tooltip": "Paréntesis" },
	{ "label": "[ ]",  "valor": "[]",   "tooltip": "Corchetes (listas)" },
	{ "label": "#",    "valor": "# ",   "tooltip": "Comentario" },
	{ "label": "   ",  "valor": "    ", "tooltip": "4 espacios (sangría)" },
	{ "label": "True", "valor": "True", "tooltip": "Verdadero (booleano)" },
	{ "label": "False","valor": "False","tooltip": "Falso (booleano)" },
]

# Fragmentos completos de código por misión/concepto
const FRAGMENTOS := [
	{ "nombre": "Minar y transferir",            "codigo": "spid.minar()\nspid.transferir()" },
	{ "nombre": "Bucle while infinito",          "codigo": "while True:\n    spid.norte()\n    spid.minar()\n    spid.sur()\n    spid.transferir()" },
	{ "nombre": "While con spid.tiene_espacio()","codigo": "while spid.tiene_espacio():\n    spid.minar()" },
	{ "nombre": "If hay mineral",                "codigo": "if spid.hay_mineral():\n    spid.minar()" },
	{ "nombre": "Bucle for N repeticiones",      "codigo": "for ciclo in range(3):\n    spid.norte()\n    spid.minar()\n    spid.sur()\nspid.transferir()" },
	{ "nombre": "minerales_en_nave() < 10",      "codigo": "spid.minerales_en_nave() < 10" },
	{ "nombre": "minerales_en_spid() < 3",       "codigo": "spid.minerales_en_spid() < 3" },
	{ "nombre": "minerales_en_nave() >= 20",     "codigo": "spid.minerales_en_nave() >= 20" },
	{ "nombre": "While cuota de minerales",      "codigo": "while spid.minerales_en_nave() < 20:\n    spid.norte()\n    spid.minar()\n    spid.sur()\n    spid.transferir()" },
	{ "nombre": "Variable pasos = 1",            "codigo": "pasos = 1\nspid.norte(pasos)\nspid.minar()\nspid.sur(pasos)\nspid.transferir()" },
	{ "nombre": "Usar tamano_mundo()",           "codigo": "limite = spid.tamano_mundo()\nfor ciclo in range(limite - 1):\n    spid.norte()\n    spid.minar()\nspid.transferir()" },
]

@onready var contenedor_simbolos: HFlowContainer = get_node_or_null("VBox/SeccionSimbolos/VBoxSym/Grid")
@onready var contenedor_fragmentos: VBoxContainer = get_node_or_null("VBox/SeccionFragmentos/VBoxFrag/Scroll/Lista")
@onready var label_feedback: Label = get_node_or_null("VBox/LabelFeedback")
@onready var boton_cerrar: Button = get_node_or_null("VBox/Cabecera/BotonCerrar")


func _ready() -> void:
	if contenedor_simbolos == null:
		contenedor_simbolos = find_child("Grid", true, false) as HFlowContainer
	if contenedor_fragmentos == null:
		contenedor_fragmentos = find_child("Lista", true, false) as VBoxContainer
	if label_feedback == null:
		label_feedback = find_child("LabelFeedback", true, false) as Label
	if boton_cerrar != null:
		boton_cerrar.pressed.connect(hide)
	_construir_simbolos()
	_construir_fragmentos()


func _construir_simbolos() -> void:
	if contenedor_simbolos == null:
		return
	for sym in SIMBOLOS:
		var btn := Button.new()
		btn.text = sym["label"]
		btn.tooltip_text = sym["tooltip"]
		btn.custom_minimum_size = Vector2(60, 44)
		btn.add_theme_font_size_override("font_size", 15)
		btn.add_theme_color_override("font_color", Color("F4F6F2"))
		var estilo := _crear_estilo(Color("3D4756"), Color("545F72"))
		var estilo_hover := _crear_estilo(Color("6FAF78"), Color("4F8F5B"))
		btn.add_theme_stylebox_override("normal", estilo)
		btn.add_theme_stylebox_override("hover", estilo_hover)
		btn.add_theme_stylebox_override("focus", estilo)
		btn.pressed.connect(_copiar.bind(sym["valor"], sym["label"]))
		contenedor_simbolos.add_child(btn)


func _construir_fragmentos() -> void:
	if contenedor_fragmentos == null:
		return
	for frag in FRAGMENTOS:
		var hbox := HBoxContainer.new()
		hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var lbl := Label.new()
		lbl.text = frag["nombre"]
		lbl.add_theme_font_size_override("font_size", 13)
		lbl.add_theme_color_override("font_color", Color("C8D0DB"))
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.clip_text = true

		var btn := Button.new()
		btn.text = "COPIAR"
		btn.custom_minimum_size = Vector2(78, 32)
		btn.add_theme_font_size_override("font_size", 12)
		btn.add_theme_color_override("font_color", Color("F4F6F2"))
		var estilo := _crear_estilo(Color("4F8F5B"), Color("3A6B44"))
		var estilo_hover := _crear_estilo(Color("6FAF78"), Color("4F8F5B"))
		btn.add_theme_stylebox_override("normal", estilo)
		btn.add_theme_stylebox_override("hover", estilo_hover)
		btn.add_theme_stylebox_override("focus", estilo)
		btn.pressed.connect(_copiar.bind(frag["codigo"], frag["nombre"]))

		hbox.add_child(lbl)
		hbox.add_child(btn)
		contenedor_fragmentos.add_child(hbox)

		var sep := HSeparator.new()
		sep.add_theme_constant_override("separation", 2)
		sep.modulate = Color(1, 1, 1, 0.08)
		contenedor_fragmentos.add_child(sep)


func _crear_estilo(fondo: Color, borde: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fondo
	s.border_color = borde
	s.set_border_width_all(2)
	s.border_width_bottom = 4
	s.set_corner_radius_all(10)
	s.content_margin_left = 8
	s.content_margin_right = 8
	s.content_margin_top = 4
	s.content_margin_bottom = 4
	s.shadow_color = Color("111720")
	s.shadow_offset = Vector2(0, 3)
	return s


func _copiar(valor: String, nombre: String) -> void:
	DisplayServer.clipboard_set(valor)
	fragmento_seleccionado.emit(valor)
	_mostrar_feedback("Copiado: " + nombre)


func _mostrar_feedback(msg: String) -> void:
	label_feedback.text = msg
	label_feedback.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_interval(1.6)
	tween.tween_property(label_feedback, "modulate:a", 0.0, 0.5)
