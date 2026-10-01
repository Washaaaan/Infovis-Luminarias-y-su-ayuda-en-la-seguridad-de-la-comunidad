extends Control


# ============================================================
# LEYENDA DEL MAPA (ESQUINA SUPERIOR IZQUIERDA)
#
# Dibuja la leyenda según DatosComunas.modo_visual:
#  - Modo 0: gradiente crema→rojo (relación delitos/densidad personas).
#  - Modo 1: gradiente crema→rojo (delitos/zona) + notas de
#            anillos (luminarias) y niebla.
#  - Modo 2: cuadrícula bivariada 3x3 (delitos x ingreso).
#
# Solo dibuja; no captura mouse.
# ============================================================

const CREMA := Color(0.96, 0.93, 0.82, 1.0)
const ROJO := Color(0.86, 0.06, 0.05, 1.0)

const FONDO := Color(0.06, 0.07, 0.10, 0.82)
const TEXTO := Color(0.93, 0.95, 0.98, 1.0)
const TEXTO_TENUE := Color(0.68, 0.72, 0.80, 1.0)
const BORDE := Color(0.45, 0.50, 0.60, 0.8)

# Paleta bivariada (igual que el shader).
# by (ingreso) 0..2, bx (delitos) 0..2.
const BIVAR := [
	Color(0.90, 0.90, 0.90),
	Color(0.95, 0.75, 0.60),
	Color(0.92, 0.50, 0.30),
	Color(0.75, 0.82, 0.90),
	Color(0.80, 0.68, 0.70),
	Color(0.85, 0.45, 0.40),
	Color(0.35, 0.55, 0.85),
	Color(0.45, 0.50, 0.70),
	Color(0.55, 0.35, 0.45),
]

var _modo_ultimo: int = -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)


func _process(_delta: float) -> void:
	if DatosComunas.modo_visual != _modo_ultimo:
		_modo_ultimo = DatosComunas.modo_visual
		queue_redraw()


func _draw() -> void:
	set_process(true)

	var origen := Vector2(22, 22)

	if DatosComunas.modo_visual == 2:
		_dibujar_bivariado(origen)
	else:
		_dibujar_gradiente(origen)


# ============================================================
# MODO 0/1: GRADIENTE
# ============================================================

func _dibujar_gradiente(origen: Vector2) -> void:
	var w := 296.0
	var h := 120.0

	draw_rect(Rect2(origen, Vector2(w, h)), FONDO, true)
	draw_rect(Rect2(origen, Vector2(w, h)), BORDE, false, 1.0)

	var titulo := "Delitos por zona habitada"

	_texto(titulo, origen + Vector2(14, 26), 14, TEXTO)

	# Barra de gradiente (crema -> rojo).
	var bx := origen + Vector2(14, 42)
	var bw := w - 28.0
	var bh := 18.0

	var pasos := 48
	for i in range(pasos):
		var t := float(i) / float(pasos - 1)
		var c := CREMA.lerp(ROJO, t)
		draw_rect(
			Rect2(bx + Vector2(bw * float(i) / float(pasos), 0), Vector2(bw / float(pasos) + 1.0, bh)),
			c,
			true
		)

	draw_rect(Rect2(bx, Vector2(bw, bh)), BORDE, false, 1.0)

	_texto("bajo", bx + Vector2(0, bh + 18), 11, TEXTO_TENUE)
	_texto("alto", bx + Vector2(bw, bh + 18), 11, TEXTO_TENUE, false, true)

	var nota := "Más rojo = más delitos por km² habitado."

	if DatosComunas.modo_visual == 1:
		nota = "Anillos = luminarias (velocidad/intensidad ∝ densidad)."

	_texto(nota, origen + Vector2(14, h - 16), 10, TEXTO_TENUE)


# ============================================================
# MODO 2: BIVARIADO 3x3
# ============================================================

func _dibujar_bivariado(origen: Vector2) -> void:
	var w := 306.0
	var h := 230.0

	draw_rect(Rect2(origen, Vector2(w, h)), FONDO, true)
	draw_rect(Rect2(origen, Vector2(w, h)), BORDE, false, 1.0)

	_texto("Delitos por persona × Ingreso", origen + Vector2(14, 26), 14, TEXTO)

	# Cuadrícula 3x3. filas = ingreso (arriba = alto).
	var cuadro := 34.0
	var gx := origen + Vector2(78, 50)

	for fila in range(3):
		for col in range(3):
			var by := 2 - fila
			var bx := col
			var c: Color = BIVAR[by * 3 + bx]
			draw_rect(
				Rect2(gx + Vector2(cuadro * col, cuadro * fila), Vector2(cuadro, cuadro)),
				c,
				true
			)
			draw_rect(
				Rect2(gx + Vector2(cuadro * col, cuadro * fila), Vector2(cuadro, cuadro)),
				BORDE,
				false,
				1.0
			)

	# Eje ingreso (vertical, izquierda).
	_texto("Ingreso", origen + Vector2(14, 60), 11, TEXTO_TENUE)
	_texto("alto", origen + Vector2(14, 104), 11, TEXTO_TENUE)
	_texto("bajo", origen + Vector2(14, 170), 11, TEXTO_TENUE)

	# Eje delitos (horizontal, abajo).
	_texto("bajo", gx + Vector2(0, 3 * cuadro + 18), 11, TEXTO_TENUE)
	_texto("alto", gx + Vector2(3 * cuadro, 3 * cuadro + 18), 11, TEXTO_TENUE, false, true)
	_texto("Delitos por persona", gx + Vector2(3 * cuadro * 0.5, 3 * cuadro + 40), 12, TEXTO, true)

	_texto("Escala logarítmica (tercios)", origen + Vector2(14, h - 12), 10, TEXTO_TENUE)


# ============================================================
# TEXTO
# ============================================================

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

	var tam := fuente.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var p := pos
	if centrado:
		p.x -= tam.x * 0.5
	if derecha:
		p.x -= tam.x

	draw_string(fuente, p, texto, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)
