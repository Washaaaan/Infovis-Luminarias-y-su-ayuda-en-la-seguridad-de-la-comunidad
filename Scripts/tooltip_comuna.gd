extends Control


# ============================================================
# TOOLTIP DE COMUNA
#
# Al pasar el mouse sobre una comuna (en las vistas de mapa) muestra
# un panel con el nombre, el año y los valores de las variables
# comparadas según DatosComunas.modo_visual, más una fila de tasa.
#
#   Modo 0 (Personas vs Delitos):
#     - Delitos por zona habitada
#     - Personas por zona habitada
#     - Tasa delitos/persona
#
#   Modo 1 (Luminarias vs Delitos):
#     - Luminarias por zona habitada
#     - Delitos por zona habitada
#     - Tasa delitos/persona
#
#   Modo 2 (Ingreso vs Delitos):
#     - Ingreso promedio del hogar
#     - Delitos por persona
#     - Tasa delitos/zona
#
# La comuna bajo el cursor se detecta por geometría
# (Geometry2D.is_point_in_polygon sobre el Polygon2D real de cada
# comuna), sin depender de las señales del Area2D ni del picking.
#
# Solo dibuja; no captura mouse. Se oculta cuando el panel de
# gráficos (GraficoComuna) está visible.
# ============================================================

const FONDO := Color(0.059, 0.067, 0.098, 0.94)
const BORDE := Color(0.45, 0.50, 0.60, 0.90)
const TEXTO := Color(0.93, 0.95, 0.98, 1.0)
const TENUE := Color(0.68, 0.72, 0.80, 1.0)
const ACENTO := Color(0.98, 0.75, 0.35, 1.0)

const PAD := 10.0
const LINEA := 19.0
const SEPARADOR := 8.0
const OFFSET_CURSOR := Vector2(18, 18)

var _hover: String = ""
var _cache: String = ""

var _titulo: String = ""
var _subtitulo: String = ""
var _filas: Array = []

# Lista de { "nombre": String, "poly": Polygon2D }.
var _comunas: Array = []


# ============================================================
# READY
# ============================================================

func _ready() -> void:

	mouse_filter = Control.MOUSE_FILTER_IGNORE

	set_process(true)

	_recopilar_comunas()


func _recopilar_comunas() -> void:

	_comunas = []

	var mapa := get_node_or_null("../../Mapa")

	if mapa == null:
		return


	for nodo in mapa.get_children():

		var poly := nodo.get_node_or_null("Area2D/Polygon2D")

		if poly == null:
			continue

		if poly.polygon.is_empty():
			continue

		_comunas.append({
			"nombre": nodo.name,
			"poly": poly
		})


# ============================================================
# PROCESO
# ============================================================

func _process(_delta: float) -> void:

	# Ocultar en SOLO_COMUNA (panel de gráficos visible).

	var grafico := get_parent().get_node_or_null("GraficoComuna")

	var bloqueado: bool = grafico != null and grafico.visible

	var nuevo := ""

	if not bloqueado:
		nuevo = _detectar_hover()


	if nuevo != _hover:

		_hover = nuevo
		_cache = ""
		queue_redraw()


	if _hover == "":
		return


	var clave := "%s|%d|%d" % [
		_hover,
		DatosComunas.modo_visual,
		DatosComunas.anio_actual
	]


	if clave != _cache:

		_cache = clave
		_construir_contenido()


	queue_redraw()


# ============================================================
# DETECCIÓN POR GEOMETRÍA
# ============================================================

func _detectar_hover() -> String:

	for item in _comunas:

		var poly: Polygon2D = item["poly"]

		if not is_instance_valid(poly):
			continue

		if Geometry2D.is_point_in_polygon(
			poly.get_local_mouse_position(),
			poly.polygon
		):
			return item["nombre"]

	return ""


# ============================================================
# CONTENIDO SEGÚN EL MODO
# ============================================================

func _construir_contenido() -> void:

	_titulo = _hover
	_subtitulo = "Año %d" % DatosComunas.anio_actual

	var anio := DatosComunas.anio_actual
	var modo := DatosComunas.modo_visual

	var del_zona := DatosComunas.delitos_zona_anio(_hover, anio)
	var del_persona := DatosComunas.delitos_persona_anio(_hover, anio)

	_filas = []

	if modo == 2:

		var ingreso := DatosComunas.ingreso_anio(_hover, anio)

		_filas.append([
			"Ingreso promedio del hogar",
			"$ " + _miles(ingreso)
		])

		_filas.append([
			"Delitos por persona",
			_decimal(del_persona, 3)
		])

		_filas.append([
			"Tasa delitos/zona",
			_miles(del_zona)
		])

	elif modo == 1:

		var lum := DatosComunas.luminarias_zona_habitada(_hover)

		_filas.append([
			"Luminarias por zona habitada",
			_miles(lum)
		])

		_filas.append([
			"Delitos por zona habitada",
			_miles(del_zona)
		])

		_filas.append([
			"Tasa delitos/persona",
			_decimal(del_persona, 3)
		])

	else:

		var densidad := DatosComunas.densidad_anio(_hover, anio)

		_filas.append([
			"Delitos por zona habitada",
			_miles(del_zona)
		])

		_filas.append([
			"Personas por zona habitada",
			_miles(densidad)
		])

		_filas.append([
			"Tasa delitos/persona",
			_decimal(del_persona, 3)
		])


# ============================================================
# DIBUJO
# ============================================================

func _draw() -> void:

	if _hover == "":
		return

	var fuente := get_theme_default_font()

	if fuente == null:
		return


	var fs_titulo := 15
	var fs_sub := 11
	var fs_fila := 12


	# --------------------------------------------------------
	# MEDIDAS
	# --------------------------------------------------------

	var ancho := fuente.get_string_size(
		_titulo, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_titulo
	).x

	var ancho_sub := fuente.get_string_size(
		_subtitulo, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_sub
	).x

	ancho = max(ancho, ancho_sub)


	for fila in _filas:

		var a := fuente.get_string_size(
			fila[0], HORIZONTAL_ALIGNMENT_LEFT, -1, fs_fila
		).x

		var b := fuente.get_string_size(
			fila[1], HORIZONTAL_ALIGNMENT_LEFT, -1, fs_fila
		).x

		ancho = max(ancho, a + 22.0 + b)


	ancho += PAD * 2.0

	var altura := PAD * 2.0 \
		+ LINEA \
		+ LINEA * 0.8 \
		+ SEPARADOR \
		+ LINEA * float(_filas.size())


	# --------------------------------------------------------
	# POSICIÓN (junto al cursor, con límites)
	# --------------------------------------------------------

	var pos := get_local_mouse_position() + OFFSET_CURSOR

	if pos.x + ancho > size.x - 8.0:
		pos.x = get_local_mouse_position().x - ancho - OFFSET_CURSOR.x

	if pos.y + altura > size.y - 8.0:
		pos.y = get_local_mouse_position().y - altura - OFFSET_CURSOR.y

	pos.x = clampf(pos.x, 8.0, max(8.0, size.x - ancho - 8.0))
	pos.y = clampf(pos.y, 8.0, max(8.0, size.y - altura - 8.0))


	# --------------------------------------------------------
	# PANEL
	# --------------------------------------------------------

	var caja := StyleBoxFlat.new()

	caja.bg_color = FONDO
	caja.border_color = BORDE
	caja.set_border_width_all(1)
	caja.set_corner_radius_all(8)

	draw_style_box(caja, Rect2(pos, Vector2(ancho, altura)))


	# --------------------------------------------------------
	# TEXTOS
	# --------------------------------------------------------

	var x := pos.x + PAD
	var y := pos.y + PAD

	draw_string(
		fuente,
		Vector2(x, y + fs_titulo),
		_titulo,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		fs_titulo,
		TEXTO
	)

	y += LINEA

	var sy := y + fs_sub

	draw_string(
		fuente,
		Vector2(x, sy),
		_subtitulo,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		fs_sub,
		TENUE
	)

	y += LINEA * 0.8


	draw_line(
		Vector2(x, y + 2.0),
		Vector2(pos.x + ancho - PAD, y + 2.0),
		BORDE,
		1.0,
		true
	)

	y += SEPARADOR


	var derecha := pos.x + ancho - PAD

	for fila in _filas:

		var ty := y + fs_fila

		draw_string(
			fuente,
			Vector2(x, ty),
			fila[0],
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			fs_fila,
			TENUE
		)

		var vb := fuente.get_string_size(
			fila[1], HORIZONTAL_ALIGNMENT_LEFT, -1, fs_fila
		).x

		draw_string(
			fuente,
			Vector2(derecha - vb, ty),
			fila[1],
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			fs_fila,
			ACENTO
		)

		y += LINEA


# ============================================================
# FORMATEO
# ============================================================

func _miles(valor: float) -> String:

	var entero := int(round(abs(valor)))

	var s := str(entero)
	var resultado := ""
	var contador := 0


	for i in range(s.length() - 1, -1, -1):

		resultado = s[i] + resultado
		contador += 1

		if contador % 3 == 0 and i > 0:
			resultado = "." + resultado


	if valor < 0.0:
		resultado = "-" + resultado


	return resultado


func _decimal(valor: float, n: int) -> String:

	return (("%." + str(n) + "f") % valor).replace(".", ",")
