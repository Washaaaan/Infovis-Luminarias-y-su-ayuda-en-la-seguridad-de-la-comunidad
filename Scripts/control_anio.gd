extends Control


# ============================================================
# CONTROL DE AÑO
#
# Slider 2005 - 2026 que recolorea el mapa según el año.
# ============================================================

var _mapa: Node = null

var _slider: HSlider
var _etiqueta: Label

var _modo: int = 0
var _boton_modo: Button


# ============================================================
# READY
# ============================================================

func _ready() -> void:

	_crear_ui()

	_crear_boton_modo()

	DatosComunas.establecer_anio(
		DatosComunas.anio_actual
	)

	aplicar_anio(
		DatosComunas.anio_actual
	)


# ============================================================
# BOTÓN DE MODO (ABAJO A LA DERECHA)
# ============================================================

func _crear_boton_modo() -> void:

	var panel := PanelContainer.new()

	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0

	panel.offset_left = -320.0
	panel.offset_right = -20.0
	panel.offset_top = -84.0
	panel.offset_bottom = -20.0

	add_child(panel)


	var margen := MarginContainer.new()

	margen.add_theme_constant_override("margin_left", 10)
	margen.add_theme_constant_override("margin_right", 10)
	margen.add_theme_constant_override("margin_top", 8)
	margen.add_theme_constant_override("margin_bottom", 8)

	panel.add_child(margen)


	_boton_modo = Button.new()

	_boton_modo.text = _texto_modo()

	_boton_modo.pressed.connect(
		_on_modo_presionado
	)

	margen.add_child(_boton_modo)


func _texto_modo() -> String:

	if _modo == 1:

		return "Mapa: Luminarias vs Delitos"

	if _modo == 2:

		return "Mapa: Ingreso vs Delitos"


	return "Mapa: Personas vs Delitos"


func _on_modo_presionado() -> void:

	_modo = (_modo + 1) % 3

	DatosComunas.modo_visual = _modo

	_boton_modo.text = _texto_modo()


	if _mapa == null:

		_mapa = get_node_or_null("../../Mapa")


	if _mapa != null:

		for comuna in _mapa.get_children():

			var area := comuna.get_node_or_null("Area2D")

			if area == null:
				continue

			if area.has_method("establecer_modo"):

				area.establecer_modo(_modo)


	# Refrescar el detalle (scatter y forma) si está abierto.

	var ui := get_parent()

	if ui != null and ui.has_method("actualizar_anio_panel"):

		ui.actualizar_anio_panel()


# ============================================================
# CREAR UI
# ============================================================

func _crear_ui() -> void:

	var panel := PanelContainer.new()

	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0

	panel.offset_left = -240.0
	panel.offset_right = 240.0
	panel.offset_top = -110.0
	panel.offset_bottom = -20.0

	add_child(panel)


	var margen := MarginContainer.new()

	margen.add_theme_constant_override("margin_left", 12)
	margen.add_theme_constant_override("margin_right", 12)
	margen.add_theme_constant_override("margin_top", 8)
	margen.add_theme_constant_override("margin_bottom", 8)

	panel.add_child(margen)


	var columna := VBoxContainer.new()

	columna.add_theme_constant_override("separation", 6)

	margen.add_child(columna)


	_etiqueta = Label.new()

	_etiqueta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	columna.add_child(_etiqueta)


	_slider = HSlider.new()

	_slider.min_value = DatosComunas.anio_min
	_slider.max_value = DatosComunas.anio_max
	_slider.step = 1.0
	_slider.value = DatosComunas.anio_actual
	_slider.custom_minimum_size = Vector2(440, 0)

	_slider.value_changed.connect(_on_valor_cambiado)

	columna.add_child(_slider)


	_actualizar_etiqueta()


# ============================================================
# CAMBIO DE VALOR
# ============================================================

func _on_valor_cambiado(valor: float) -> void:

	aplicar_anio(
		int(round(valor))
	)


# ============================================================
# APLICAR AÑO
# ============================================================

func aplicar_anio(anio: int) -> void:

	DatosComunas.establecer_anio(anio)

	_actualizar_etiqueta()

	if _mapa == null:
		_mapa = get_node_or_null("../../Mapa")

	if _mapa == null:
		return


	for comuna in _mapa.get_children():

		var area := comuna.get_node_or_null("Area2D")

		if area == null:
			continue

		if area.has_method("establecer_anio"):
			area.establecer_anio(DatosComunas.anio_actual)


	var ui := get_parent()

	if ui != null and ui.has_method("actualizar_anio_panel"):
		ui.actualizar_anio_panel()


# ============================================================
# ETIQUETA
# ============================================================

func _actualizar_etiqueta() -> void:

	if _etiqueta == null:
		return

	_etiqueta.text = "Año %d" % DatosComunas.anio_actual
