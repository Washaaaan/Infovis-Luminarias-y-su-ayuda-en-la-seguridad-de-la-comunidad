extends CanvasLayer

@export var camara: Camera2D

@onready var panel: Control = $Panel
@onready var contenido: RichTextLabel = $Panel/MarginContainer/Contenido

# Sangría de cada fila del CSV (0 = categoría, 1 = subtipo, 2 = sub-subtipo)
const SANGRIA: Array[int] = [0, 1, 0, 1, 2, 2, 1, 0, 1, 1, 0, 0, 0, 0]
const FILA_TERRITORIO := 10


func _ready() -> void:
	# Activar BBCode para que [b] y [font_size] se interpreten
	contenido.bbcode_enabled = true

	# Ocupar la tercera columna: del 66,67% al 100% del ancho, alto completo
	panel.anchor_left = 2.0 / 3.0
	panel.anchor_top = 0.0
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = 0.0
	panel.offset_top = 0.0
	panel.offset_right = 0.0
	panel.offset_bottom = 0.0

	panel.visible = false
	camara.comuna_seleccionada.connect(_on_comuna_seleccionada)
	camara.comuna_deseleccionada.connect(ocultar)


func _on_comuna_seleccionada(comuna: Node) -> void:
	mostrar(comuna.name)


func mostrar(nombre: String) -> void:
	var valores := DatosComunas.obtener(nombre)

	if valores.is_empty():
		contenido.text = "[b]%s[/b]\n\nSin datos en el CSV." % nombre
	else:
		var texto := "[font_size=28][b]%s[/b][/font_size]\n\n" % nombre
		for i in valores.size():
			if i == FILA_TERRITORIO:
				texto += "\n"
			var nivel: int = SANGRIA[i] if i < SANGRIA.size() else 0
			texto += "%s%s: [b]%s[/b]\n" % [
				"    ".repeat(nivel),
				DatosComunas.etiquetas[i],
				DatosComunas.formatear(valores[i]),
			]
		contenido.text = texto

	panel.visible = true


func ocultar() -> void:
	panel.visible = false
