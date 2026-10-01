extends CanvasLayer

# ============================================================
# DETALLE DE COMUNA
#
# Al entrar en SOLO_COMUNA se muestran los gráficos
# (radar + dispersión conectada) en lugar del mapa ampliado.
# Los botones ◀ / ▶ permiten recorrer las comunas.
# ============================================================

@export var camara: Camera2D

# Margen (escala normalizada 0-1) alrededor del promedio que separa
# la zona de peligro de la zona segura. En el medio: silencio.
@export var margen_medio: float = 0.05

# Intervalo máximo entre sonidos (segundos), en el umbral de peligro.
@export var intervalo_max: float = 6.0

@onready var panel: Control = $Panel
@onready var grafico: Control = $GraficoComuna
@onready var alerta: AudioStreamPlayer = $AlertaPeligro
@onready var alerta_segura: AudioStreamPlayer = $AlertaSegura

var comuna_actual: String = ""

var _comunas: Array = []
var _indice_actual: int = 0

var _comuna_nodo: Node = null
var _acumulado: float = 0.0
var _intervalo: float = 1.0

var _boton_izq: Button
var _boton_der: Button


func _ready() -> void:
	# Ocultar el panel de texto; su lugar lo ocupa el gráfico.
	panel.visible = false
	grafico.visible = false
	grafico.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_construir_lista_comunas()
	_crear_botones()
	_configurar_alerta()
	_crear_leyenda()

	camara.comuna_seleccionada.connect(_on_comuna_seleccionada)
	camara.comuna_deseleccionada.connect(ocultar)


# ============================================================
# LEYENDA DEL MAPA
# ============================================================

func _crear_leyenda() -> void:
	var leyenda: Node = load(
		"res://Scripts/leyenda_mapa.gd"
	).new()

	leyenda.name = "LeyendaMapa"

	add_child(leyenda)


# ============================================================
# SONIDO DE PELIGRO
# ============================================================

func _configurar_alerta() -> void:
	if alerta != null:
		var sp := alerta.stream
		if sp is AudioStreamWAV:
			sp.loop_mode = AudioStreamWAV.LOOP_FORWARD
			sp.loop_begin = 0
			sp.loop_end = sp.data.size() / 2
		elif sp is AudioStreamMP3:
			sp.loop = true

	if alerta_segura != null:
		var ss := alerta_segura.stream
		if ss is AudioStreamMP3:
			ss.loop = true
		elif ss is AudioStreamWAV:
			ss.loop_mode = AudioStreamWAV.LOOP_FORWARD
			ss.loop_begin = 0
			ss.loop_end = ss.data.size() / 2


func _actualizar_alerta() -> void:
	_acumulado = 0.0

	if alerta == null:
		return

	if comuna_actual == "":
		_detener_sonidos()
		return

	_aplicar_estado_sonoro()


# ============================================================
# UMBRALES ADAPTATIVOS (PROMEDIO +/- MARGEN)
# ============================================================

func _umbral_peligro() -> float:
	return _promedio_tasa() + margen_medio


func _umbral_seguro() -> float:
	return _promedio_tasa() - margen_medio


# Promedio de la métrica del modo sobre las 52 comunas.

func _promedio_tasa() -> float:
	if _comunas.is_empty():
		return 0.0

	var modo_area := 0

	if _comuna_nodo != null:
		var area_sel: Variant = _comuna_nodo.get_node_or_null("Area2D")
		if area_sel != null:
			modo_area = area_sel.modo

	var suma := 0.0
	var cuenta := 0

	for comuna in _comunas:
		var area: Variant = comuna.get_node_or_null("Area2D")
		if area == null:
			continue
		var valor: float = (
			area.nivel_delitos_persona
			if modo_area == 2
			else area.nivel_delitos_zona
		)
		suma += valor
		cuenta += 1

	if cuenta == 0:
		return 0.0

	return suma / float(cuenta)


# Decide y aplica el sonido que corresponde ahora (safe / silencio).
# El peligro se dispara por intervalos en _process.

func _aplicar_estado_sonoro() -> void:
	if comuna_actual == "" or _comuna_nodo == null:
		_detener_sonidos()
		return

	var tasa := _tasa_peligro()

	if tasa >= _umbral_peligro():
		_detener_seguro()
	elif tasa < _umbral_seguro():
		_iniciar_seguro()
	else:
		_detener_sonidos()


func _iniciar_seguro() -> void:
	if alerta != null and alerta.playing:
		alerta.stop()

	if alerta_segura != null and not alerta_segura.playing:
		alerta_segura.play()


func _detener_seguro() -> void:
	if alerta_segura != null and alerta_segura.playing:
		alerta_segura.stop()


func _detener_sonidos() -> void:
	if alerta != null and alerta.playing:
		alerta.stop()

	_detener_seguro()


# ============================================================
# BUCLE DEL SONIDO DE PELIGRO
#
# A mayor tasa (modo activo), intervalos más cortos.
# En el máximo: una vez por segundo.
# ============================================================

func _process(delta: float) -> void:
	if alerta == null:
		return

	if comuna_actual == "" or _comuna_nodo == null:
		return

	var tasa := _tasa_peligro()
	var umbral_p := _umbral_peligro()

	if tasa < umbral_p:
		# No es peligro: decidir entre seguro y silencio.
		_aplicar_estado_sonoro()
		_acumulado = 0.0
		return

	# Peligro.
	_detener_seguro()

	_intervalo = lerpf(
		intervalo_max,
		1.0,
		_factor_peligro(
			tasa,
			_tasa_maxima(),
			umbral_p
		)
	)

	_acumulado += delta

	if _acumulado >= _intervalo:
		_acumulado = 0.0
		alerta.play()


# Tasa de peligro de la comuna según el modo activo.

func _tasa_peligro() -> float:
	if _comuna_nodo == null:
		return 0.0

	var area: Variant = _comuna_nodo.get_node_or_null("Area2D")

	if area == null:
		return 0.0

	var modo_area: int = area.modo

	if modo_area == 2:
		return area.nivel_delitos_persona

	return area.nivel_delitos_zona


# Máxima tasa entre todas las comunas (modo activo, año actual).

func _tasa_maxima() -> float:
	var modo_area := 0

	if _comuna_nodo != null:
		var area_sel: Variant = _comuna_nodo.get_node_or_null("Area2D")
		if area_sel != null:
			modo_area = area_sel.modo

	var maximo := 0.0

	for comuna in _comunas:
		var area: Variant = comuna.get_node_or_null("Area2D")
		if area == null:
			continue
		var valor: float = (
			area.nivel_delitos_zona
			if modo_area == 1
			else area.nivel_relacion
		)
		maximo = maxf(maximo, valor)

	return maximo


# 0.0 en el umbral, 1.0 en el máximo real (tasa_max).

func _factor_peligro(
	tasa: float,
	tasa_max: float,
	umbral: float
) -> float:
	if tasa_max <= umbral:
		return 1.0

	return clampf(
		(tasa - umbral) /
		(tasa_max - umbral),
		0.0,
		1.0
	)


# ============================================================
# LISTA DE COMUNAS (orden del mapa)
# ============================================================

func _construir_lista_comunas() -> void:
	var mapa := get_node_or_null("../Mapa")
	if mapa == null:
		return
	for hijo in mapa.get_children():
		if hijo.get_node_or_null("Area2D") != null:
			_comunas.append(hijo)


# ============================================================
# BOTONES
# ============================================================

func _crear_botones() -> void:
	_boton_izq = _crear_boton("<")
	_boton_izq.anchor_left = 0.0
	_boton_izq.anchor_right = 0.0
	_boton_izq.anchor_top = 0.5
	_boton_izq.anchor_bottom = 0.5
	_boton_izq.offset_left = 20.0
	_boton_izq.offset_right = 84.0
	_boton_izq.offset_top = -36.0
	_boton_izq.offset_bottom = 36.0
	_boton_izq.pressed.connect(_ir_anterior)

	_boton_der = _crear_boton(">")
	_boton_der.anchor_left = 1.0
	_boton_der.anchor_right = 1.0
	_boton_der.anchor_top = 0.5
	_boton_der.anchor_bottom = 0.5
	_boton_der.offset_left = -84.0
	_boton_der.offset_right = -20.0
	_boton_der.offset_top = -36.0
	_boton_der.offset_bottom = 36.0
	_boton_der.pressed.connect(_ir_siguiente)


func _crear_boton(texto: String) -> Button:
	var b := Button.new()
	b.text = texto
	b.visible = false
	b.add_theme_font_size_override("font_size", 28)
	add_child(b)
	return b


func _ir_anterior() -> void:
	_navegar(-1)


func _ir_siguiente() -> void:
	_navegar(1)


func _navegar(delta: int) -> void:
	if _comunas.is_empty():
		return
	_indice_actual = wrapi(_indice_actual + delta, 0, _comunas.size())
	camara.seleccionar_comuna_grafico(_comunas[_indice_actual])


func _actualizar_botones(mostrar_botones: bool) -> void:
	if _boton_izq != null:
		_boton_izq.visible = mostrar_botones
	if _boton_der != null:
		_boton_der.visible = mostrar_botones


# ============================================================
# SELECCIÓN
# ============================================================

func _on_comuna_seleccionada(comuna: Node) -> void:
	comuna_actual = comuna.name
	_comuna_nodo = comuna
	var idx := _comunas.find(comuna)
	if idx >= 0:
		_indice_actual = idx
	mostrar(comuna_actual)
	_actualizar_alerta()


func mostrar(nombre: String) -> void:
	if grafico.has_method("mostrar"):
		grafico.mostrar(nombre, DatosComunas.anio_actual)
	panel.visible = false
	_actualizar_botones(true)


func actualizar_anio_panel() -> void:
	if grafico == null:
		return
	if not grafico.visible:
		return
	if comuna_actual == "":
		return
	if grafico.has_method("mostrar"):
		grafico.mostrar(comuna_actual, DatosComunas.anio_actual)

	_actualizar_alerta()


func ocultar() -> void:
	grafico.ocultar()
	panel.visible = false
	_actualizar_botones(false)
	comuna_actual = ""
	_comuna_nodo = null
	_acumulado = 0.0
	_detener_sonidos()
