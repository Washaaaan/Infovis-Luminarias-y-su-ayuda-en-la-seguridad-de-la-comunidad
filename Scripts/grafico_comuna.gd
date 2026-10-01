extends Control


# ============================================================
# DETALLE DE COMUNA
#
# - Izquierda: forma real de la comuna (Polygon2D con el
#   mismo ShaderMaterial), para ver su color y, en modo 1,
#   la niebla / anillos.
# - Derecha: dispersión según el modo activo.
#   Modo 0: densidad de personas vs delitos totales.
#   Modo 1: luminarias por zona habitada vs delitos por zona.
#   Con recta de regresión y correlación (log-log).
#
# Solo dibuja; no captura mouse (mouse_filter = IGNORE).
# ============================================================

var _nombre: String = ""
var _anio: int = 2025

var _forma: Polygon2D = null

# Colores
const FONDO := Color(0.09, 0.11, 0.16, 1.0)
const TEXTO := Color(0.92, 0.94, 0.98, 1.0)
const TEXTO_TENUE := Color(0.65, 0.70, 0.80, 1.0)
const GRIS := Color(0.28, 0.32, 0.40, 1.0)
const BORDE := Color(0.60, 0.70, 1.0, 1.0)
const ACENTO := Color(0.98, 0.75, 0.35, 1.0)
const REGRESION := Color(1.0, 0.55, 0.35, 0.9)


# ============================================================
# API
# ============================================================

func _ready() -> void:

	_forma = Polygon2D.new()

	_forma.visible = false

	add_child(_forma)


func mostrar(nombre: String, anio: int) -> void:

	_nombre = nombre
	_anio = anio

	visible = true

	_actualizar_forma()

	queue_redraw()


func ocultar() -> void:

	visible = false

	if _forma != null:

		_forma.visible = false


# ============================================================
# FORMA DE LA COMUNA (MISMO MATERIAL / SHADER)
# ============================================================

func _actualizar_forma() -> void:

	if _forma == null:

		_forma = Polygon2D.new()

		add_child(_forma)


	_forma.visible = false


	var mapa := get_node_or_null("../../Mapa")

	if mapa == null:
		return


	var comuna := mapa.get_node_or_null(_nombre)

	if comuna == null:
		return


	var poly: Polygon2D = comuna.get_node_or_null(
		"Area2D/Polygon2D"
	)

	if poly == null or poly.polygon.is_empty():
		return


	_forma.polygon = poly.polygon

	_forma.material = poly.material


	var rect := _rect_forma()

	var minp := poly.polygon[0]
	var maxp := poly.polygon[0]


	for p in poly.polygon:

		minp.x = min(minp.x, p.x)
		minp.y = min(minp.y, p.y)
		maxp.x = max(maxp.x, p.x)
		maxp.y = max(maxp.y, p.y)


	var tam := maxp - minp

	tam.x = max(tam.x, 0.0001)
	tam.y = max(tam.y, 0.0001)


	var escala: float = min(
		rect.size.x / tam.x,
		rect.size.y / tam.y
	) * 0.85


	var centro_local := (minp + maxp) * 0.5

	var centro_rect := (
		rect.position +
		rect.size * 0.5
	)


	_forma.scale = Vector2(escala, escala)

	_forma.position = (
		centro_rect -
		centro_local * escala
	)

	_forma.visible = true


# ============================================================
# RECTÁNGULOS DE CONTENEDORES
# ============================================================

func _rect_forma() -> Rect2:

	return Rect2(
		size.x * 0.06,
		size.y * 0.22,
		size.x * 0.36,
		size.y * 0.54
	)


func _rect_scatter() -> Rect2:

	return Rect2(
		size.x * 0.52,
		size.y * 0.20,
		size.x * 0.42,
		size.y * 0.52
	)


# ============================================================
# DIBUJO
# ============================================================

func _draw() -> void:

	if not visible:
		return

	if _nombre == "":
		return


	# --------------------------------------------------------
	# FONDO
	# --------------------------------------------------------

	draw_rect(
		Rect2(Vector2.ZERO, size),
		FONDO,
		true
	)


	# --------------------------------------------------------
	# TÍTULO
	# --------------------------------------------------------

	_texto(
		"%s - Año %d" % [_nombre, _anio],
		Vector2(size.x * 0.5, size.y * 0.075),
		26,
		TEXTO,
		true
	)


	# --------------------------------------------------------
	# SCATTER (CONTENEDOR DERECHO)
	# --------------------------------------------------------

	_dibujar_relacion(
		_rect_scatter()
	)


# ============================================================
# DISPERSIÓN SEGÚN EL MODO
# ============================================================

func _dibujar_relacion(rect: Rect2) -> void:

	var modo := DatosComunas.modo_visual

	var x0: float = rect.position.x
	var x1: float = rect.position.x + rect.size.x
	var y0: float = rect.position.y
	var y1: float = rect.position.y + rect.size.y


	# --------------------------------------------------------
	# TEXTOS SEGÚN EL MODO
	# --------------------------------------------------------

	var titulo := ""
	var titulo_x := ""
	var titulo_y := ""

	if modo == 2:

		titulo = "Ingreso vs delitos por persona - %d" % _anio
		titulo_x = "Ingreso promedio del hogar"
		titulo_y = "Delitos por persona"

	elif modo == 1:

		titulo = "Luminarias vs delitos - %d" % _anio
		titulo_x = "Luminarias por zona habitada"
		titulo_y = "Delitos por zona habitada"

	else:

		titulo = "Densidad vs delitos por zona - %d" % _anio
		titulo_x = "Densidad de personas (hab/km2)"
		titulo_y = "Delitos por zona habitada"


	# --------------------------------------------------------
	# RECOLECTAR PUNTOS (52 comunas)
	# --------------------------------------------------------

	var valores_x: Array[float] = []
	var valores_y: Array[float] = []
	var lx: Array[float] = []
	var ly: Array[float] = []

	var idx_sel := -1
	var clave_sel := DatosComunas.normalizar(_nombre)


	for clave in DatosComunas.lista_comunas():

		var vx := 0.0
		var vy := 0.0

		if modo == 2:

			vx = DatosComunas.ingreso_anio(clave, _anio)
			vy = DatosComunas.delitos_persona_anio(clave, _anio)

		elif modo == 1:

			vx = DatosComunas.luminarias_zona_habitada(clave)
			vy = DatosComunas.delitos_zona_anio(clave, _anio)

		else:

			vx = DatosComunas.densidad_anio(clave, _anio)
			vy = DatosComunas.delitos_zona_anio(clave, _anio)


		if vx <= 0.0 or vy <= 0.0:
			continue


		if clave == clave_sel:
			idx_sel = valores_x.size()


		valores_x.append(vx)
		valores_y.append(vy)
		lx.append(_log10(vx))
		ly.append(_log10(vy))


	if valores_x.size() < 2:
		return


	# --------------------------------------------------------
	# RANGOS LOG
	# --------------------------------------------------------

	var min_lx: float = lx[0]
	var max_lx: float = lx[0]
	var min_ly: float = ly[0]
	var max_ly: float = ly[0]

	for i in range(lx.size()):

		min_lx = min(min_lx, lx[i])
		max_lx = max(max_lx, lx[i])
		min_ly = min(min_ly, ly[i])
		max_ly = max(max_ly, ly[i])

	if max_lx <= min_lx:
		max_lx = min_lx + 1.0

	if max_ly <= min_ly:
		max_ly = min_ly + 1.0

	min_lx -= (max_lx - min_lx) * 0.06
	max_lx += (max_lx - min_lx) * 0.06
	min_ly -= (max_ly - min_ly) * 0.06
	max_ly += (max_ly - min_ly) * 0.06


	# --------------------------------------------------------
	# REGRESIÓN (log-log)
	# --------------------------------------------------------

	var n := float(lx.size())

	var suma_x := 0.0
	var suma_y := 0.0

	for i in range(lx.size()):

		suma_x += lx[i]
		suma_y += ly[i]

	var media_x := suma_x / n
	var media_y := suma_y / n

	var sxy := 0.0
	var sxx := 0.0
	var syy := 0.0

	for i in range(lx.size()):

		var dx := lx[i] - media_x
		var dy := ly[i] - media_y

		sxy += dx * dy
		sxx += dx * dx
		syy += dy * dy

	var r := 0.0

	if sxx > 0.0 and syy > 0.0:
		r = sxy / sqrt(sxx * syy)

	var pendiente := 0.0
	var intercepto := media_y

	if sxx > 0.0:
		pendiente = sxy / sxx
		intercepto = media_y - pendiente * media_x


	# --------------------------------------------------------
	# TÍTULO
	# --------------------------------------------------------

	_texto(
		titulo,
		Vector2((x0 + x1) * 0.5, y0 - 18),
		17,
		TEXTO_TENUE,
		true
	)


	# --------------------------------------------------------
	# CUADRÍCULA Y MARCAS
	# --------------------------------------------------------

	for t in _ticks_log(min_lx, max_lx):

		var px: float = remap(t, min_lx, max_lx, x0, x1)

		draw_line(
			Vector2(px, y0),
			Vector2(px, y1),
			GRIS,
			1.0,
			true
		)

		_texto(
			_etiqueta(t),
			Vector2(px, y1 + 18),
			11,
			TEXTO_TENUE,
			true
		)


	for t in _ticks_log(min_ly, max_ly):

		var py: float = remap(t, min_ly, max_ly, y1, y0)

		draw_line(
			Vector2(x0, py),
			Vector2(x1, py),
			GRIS,
			1.0,
			true
		)

		_texto(
			_etiqueta(t),
			Vector2(x0 - 12, py + 4),
			11,
			TEXTO_TENUE,
			false,
			true
		)


	# --------------------------------------------------------
	# EJES
	# --------------------------------------------------------

	draw_line(
		Vector2(x0, y0),
		Vector2(x0, y1),
		TEXTO_TENUE,
		1.5,
		true
	)

	draw_line(
		Vector2(x0, y1),
		Vector2(x1, y1),
		TEXTO_TENUE,
		1.5,
		true
	)


	# --------------------------------------------------------
	# TÍTULOS DE EJES
	# --------------------------------------------------------

	_texto(
		titulo_x,
		Vector2((x0 + x1) * 0.5, y1 + 40),
		14,
		TEXTO,
		true
	)

	# La etiqueta del eje Y se dibuja rotada 90° a la izquierda
	# del eje para no solaparse con el título del gráfico.
	_texto_vertical(
		titulo_y,
		x0 - 66,
		(y0 + y1) * 0.5,
		14,
		TEXTO
	)


	# --------------------------------------------------------
	# PUNTOS (TODAS LAS COMUNAS, TAMAÑO FIJO)
	# --------------------------------------------------------

	for i in range(valores_x.size()):

		if i == idx_sel:
			continue

		var px: float = remap(lx[i], min_lx, max_lx, x0, x1)
		var py: float = remap(ly[i], min_ly, max_ly, y1, y0)

		draw_circle(Vector2(px, py), 3.5, BORDE)


	# --------------------------------------------------------
	# RECTA DE REGRESIÓN
	# --------------------------------------------------------

	var ya := intercepto + pendiente * min_lx
	var yb := intercepto + pendiente * max_lx

	draw_line(
		Vector2(
			remap(min_lx, min_lx, max_lx, x0, x1),
			remap(ya, min_ly, max_ly, y1, y0)
		),
		Vector2(
			remap(max_lx, min_lx, max_lx, x0, x1),
			remap(yb, min_ly, max_ly, y1, y0)
		),
		REGRESION,
		2.0,
		true
	)


	# --------------------------------------------------------
	# COMUNA SELECCIONADA
	# --------------------------------------------------------

	if idx_sel >= 0:

		var px: float = remap(lx[idx_sel], min_lx, max_lx, x0, x1)
		var py: float = remap(ly[idx_sel], min_ly, max_ly, y1, y0)

		draw_circle(Vector2(px, py), 6.5, ACENTO)

		_texto(
			_nombre,
			Vector2(px, py - 16),
			14,
			ACENTO,
			true
		)

		_texto(
			"%.1f - %.1f" % [
				valores_x[idx_sel],
				valores_y[idx_sel]
			],
			Vector2(px, py + 22),
			11,
			TEXTO_TENUE,
			true
		)


	# --------------------------------------------------------
	# CORRELACIÓN
	# --------------------------------------------------------

	_texto(
		"Asociación (r log-log) = %.3f" % r,
		Vector2(x0 + 8, y0 + 18),
		14,
		TEXTO,
		false
	)

	_texto(
		"R2 = %.3f" % (r * r),
		Vector2(x0 + 8, y0 + 38),
		14,
		TEXTO,
		false
	)

	_texto(
		"Asociación espacial a nivel comunal; no implica causalidad.",
		Vector2(x0 + 8, y0 + 58),
		11,
		TEXTO_TENUE,
		false
	)


# ============================================================
# UTILIDADES
# ============================================================

func _log10(valor: float) -> float:

	return log(valor) / 2.302585092994046


func _ticks_log(
	min_log: float,
	max_log: float
) -> Array:

	var resultado: Array = []

	for e in range(
		int(floor(min_log)),
		int(ceil(max_log)) + 1
	):

		var v := float(e)

		if v >= min_log - 0.001 and v <= max_log + 0.001:
			resultado.append(v)

	return resultado


func _etiqueta(exp10: float) -> String:

	var v := pow(10.0, exp10)

	if v >= 1000.0:
		return "%s" % _miles(int(round(v)))

	if v >= 1.0:
		return "%d" % int(round(v))

	return ("%.2f" % v) \
		.trim_suffix("0") \
		.trim_suffix("0") \
		.trim_suffix(".")


func _texto(
	texto: String,
	pos: Vector2,
	fs: int,
	color: Color,
	centrado: bool = false,
	derecha: bool = false
) -> void:

	var fuente := get_theme_default_font()

	if fuente == null:
		return


	var tam := fuente.get_string_size(
		texto,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		fs
	)

	var p := pos

	if centrado:
		p.x -= tam.x * 0.5

	if derecha:
		p.x -= tam.x


	draw_string(
		fuente,
		p,
		texto,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		fs,
		color
	)


# Dibuja texto rotado 90° (de abajo hacia arriba), centrado
# verticalmente en y_centro sobre una línea vertical en x.
func _texto_vertical(
	texto: String,
	x: float,
	y_centro: float,
	fs: int,
	color: Color
) -> void:

	var fuente := get_theme_default_font()

	if fuente == null:
		return

	var tam := fuente.get_string_size(
		texto,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		fs
	)

	draw_set_transform(
		Vector2(x, y_centro + tam.x * 0.5),
		-PI * 0.5,
		Vector2.ONE
	)

	draw_string(
		fuente,
		Vector2.ZERO,
		texto,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		fs,
		color
	)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _miles(valor: int) -> String:

	var s := str(abs(valor))
	var resultado := ""
	var contador := 0


	for i in range(s.length() - 1, -1, -1):

		resultado = s[i] + resultado
		contador += 1

		if contador % 3 == 0 and i > 0:
			resultado = "." + resultado


	if valor < 0:
		resultado = "-" + resultado


	return resultado
