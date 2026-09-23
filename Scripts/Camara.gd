extends Camera2D


# ============================================================
# ESTADOS DE LA CÁMARA
# ============================================================

enum EstadoCamara {
	MAPA_COMPLETO,
	ZOOM_COMUNA,
	SOLO_COMUNA
}

signal comuna_seleccionada(comuna: Node)
signal comuna_deseleccionada

# ============================================================
# CONFIGURACIÓN GENERAL
# ============================================================

@export var velocidad_maxima: float = 500.0

@export var margen_borde: float = 30.0

@export var duracion_movimiento: float = 0.7


# ============================================================
# CONFIGURACIÓN DEL PRIMER ZOOM
# ============================================================

@export var porcentaje_primer_zoom: float = 0.32


# ============================================================
# LÍMITES DE ZOOM
# ============================================================

@export var zoom_minimo: float = 0.5

@export var zoom_maximo: float = 50.0


# ============================================================
# CONFIGURACIÓN DEL BORDE
# ============================================================

@export var grosor_borde_normal: float = 1.0

@export var grosor_borde_minimo: float = 0.32962


# ============================================================
# ESTADO ACTUAL
# ============================================================

var estado_actual: EstadoCamara = (
	EstadoCamara.MAPA_COMPLETO
)


# ============================================================
# POSICIÓN Y ZOOM INICIAL
# ============================================================

var posicion_inicial: Vector2

var zoom_inicial: Vector2


# ============================================================
# POSICIÓN Y ZOOM DEL PRIMER ZOOM
# ============================================================

var posicion_zoom_anterior: Vector2

var zoom_anterior: Vector2


# ============================================================
# COMUNA ACTUAL
# ============================================================

var comuna_actual: Node = null


# ============================================================
# CONTROL DE TRANSICIÓN
# ============================================================

var camara_en_transicion: bool = false


# ============================================================
# TWEEN ACTUAL
# ============================================================

var tween_camara: Tween = null


# ============================================================
# READY
# ============================================================

func _ready() -> void:

	# --------------------------------------------------------
	# GUARDAR POSICIÓN INICIAL
	# --------------------------------------------------------

	posicion_inicial = global_position


	# --------------------------------------------------------
	# GUARDAR ZOOM INICIAL
	# --------------------------------------------------------

	zoom_inicial = zoom


	# --------------------------------------------------------
	# CONFIGURAR COMUNAS
	# --------------------------------------------------------

	configurar_comunas()


	# --------------------------------------------------------
	# CONFIGURAR BORDES
	# --------------------------------------------------------

	actualizar_grosor_bordes()


# ============================================================
# CONFIGURAR COMUNAS
# ============================================================

func configurar_comunas() -> void:

	var mapa: Node = get_node("../Mapa")


	for comuna in mapa.get_children():

		var area: Area2D = (
			comuna.get_node_or_null("Area2D")
		)


		if area == null:
			continue


		# ----------------------------------------------------
		# PERMITIR INTERACCIÓN
		# ----------------------------------------------------

		area.input_pickable = true


		# ----------------------------------------------------
		# CONECTAR CLICK
		# ----------------------------------------------------

		area.input_event.connect(
			_on_comuna_clicked.bind(comuna)
		)


# ============================================================
# CLICK EN COMUNA
# ============================================================

func _on_comuna_clicked(
	viewport: Node,
	evento: InputEvent,
	shape_idx: int,
	comuna: Node
) -> void:

	# --------------------------------------------------------
	# IGNORAR DURANTE TRANSICIÓN
	# --------------------------------------------------------

	if camara_en_transicion:
		return


	# --------------------------------------------------------
	# VERIFICAR EVENTO
	# --------------------------------------------------------

	if not evento is InputEventMouseButton:
		return


	var mouse_evento: InputEventMouseButton = (
		evento
	)


	# --------------------------------------------------------
	# SOLO EVENTO PRESIONADO
	# --------------------------------------------------------

	if not mouse_evento.pressed:
		return


	# --------------------------------------------------------
	# SOLO CLICK IZQUIERDO
	# --------------------------------------------------------

	if mouse_evento.button_index != MOUSE_BUTTON_LEFT:
		return


	# ========================================================
	# MAPA COMPLETO
	# ========================================================

	if estado_actual == EstadoCamara.MAPA_COMPLETO:

		hacer_primer_zoom(comuna)


	# ========================================================
	# PRIMER ZOOM
	# ========================================================

	elif estado_actual == EstadoCamara.ZOOM_COMUNA:

		hacer_segundo_zoom(comuna)


	# ========================================================
	# SOLO COMUNA
	# ========================================================

	elif estado_actual == EstadoCamara.SOLO_COMUNA:

		return


# ============================================================
# CANCELAR TWEEN ACTUAL
# ============================================================

func cancelar_tween_camara() -> void:

	if tween_camara != null:

		if tween_camara.is_valid():

			tween_camara.kill()

		tween_camara = null


# ============================================================
# MOVER CÁMARA DIRECTAMENTE A UNA POSICIÓN
# ============================================================
#
# Esta función SOLO mueve la posición.
#
# NO modifica el zoom.
#
# ============================================================

func mover_camara_a(
	destino: Vector2
) -> void:

	# --------------------------------------------------------
	# CANCELAR TWEEN ANTERIOR
	# --------------------------------------------------------

	cancelar_tween_camara()


	# --------------------------------------------------------
	# CREAR TWEEN
	# --------------------------------------------------------

	tween_camara = create_tween()


	# --------------------------------------------------------
	# MOVER DIRECTAMENTE
	# --------------------------------------------------------

	tween_camara.tween_property(
		self,
		"global_position",
		destino,
		duracion_movimiento
	).set_trans(
		Tween.TRANS_QUAD
	).set_ease(
		Tween.EASE_IN_OUT
	)


	# --------------------------------------------------------
	# ESPERAR
	# --------------------------------------------------------

	await tween_camara.finished


	# --------------------------------------------------------
	# ASEGURAR POSICIÓN EXACTA
	# --------------------------------------------------------

	global_position = destino


	tween_camara = null


# ============================================================
# HACER ZOOM
# ============================================================
#
# Esta función SOLO modifica el zoom.
#
# NO modifica la posición.
#
# ============================================================

func hacer_zoom(
	nuevo_zoom: Vector2
) -> void:

	# --------------------------------------------------------
	# CANCELAR TWEEN ANTERIOR
	# --------------------------------------------------------

	cancelar_tween_camara()


	# --------------------------------------------------------
	# CREAR TWEEN
	# --------------------------------------------------------

	tween_camara = create_tween()


	# --------------------------------------------------------
	# CAMBIAR ZOOM
	# --------------------------------------------------------

	tween_camara.tween_property(
		self,
		"zoom",
		nuevo_zoom,
		duracion_movimiento
	).set_trans(
		Tween.TRANS_QUAD
	).set_ease(
		Tween.EASE_IN_OUT
	)


	# --------------------------------------------------------
	# ESPERAR
	# --------------------------------------------------------

	await tween_camara.finished


	# --------------------------------------------------------
	# ASEGURAR ZOOM EXACTO
	# --------------------------------------------------------

	zoom = nuevo_zoom


	tween_camara = null


# ============================================================
# PRIMER ZOOM
# ============================================================

func hacer_primer_zoom(comuna: Node) -> void:

	# --------------------------------------------------------
	# OBTENER POLYGON
	# --------------------------------------------------------

	var polygon: Polygon2D = (
		obtener_polygon(comuna)
	)


	if polygon == null:
		return


	# --------------------------------------------------------
	# OBTENER RECTÁNGULO GLOBAL
	# --------------------------------------------------------

	var rect_global: Rect2 = (
		obtener_rect_global_polygon(polygon)
	)


	if rect_global.size.x <= 0.0:
		return


	if rect_global.size.y <= 0.0:
		return


	# --------------------------------------------------------
	# CENTRO EXACTO DE LA COMUNA
	# --------------------------------------------------------

	var destino: Vector2 = (
		rect_global.get_center()
	)


	# --------------------------------------------------------
	# CALCULAR ZOOM
	# --------------------------------------------------------

	var nuevo_zoom: Vector2 = (
		calcular_zoom_primer_zoom(
			rect_global
		)
	)


	# --------------------------------------------------------
	# GUARDAR COMUNA
	# --------------------------------------------------------

	comuna_actual = comuna


	# --------------------------------------------------------
	# BLOQUEAR CÁMARA
	# --------------------------------------------------------

	camara_en_transicion = true


	# --------------------------------------------------------
	# CANCELAR TWEEN ANTERIOR
	# --------------------------------------------------------

	cancelar_tween_camara()


	# ========================================================
	# PRIMER ZOOM
	# ========================================================
	#
	# En el primer zoom la posición y el zoom ocurren
	# juntos.
	#
	# ========================================================

	tween_camara = create_tween()

	tween_camara.set_parallel(true)


	# --------------------------------------------------------
	# POSICIÓN
	# --------------------------------------------------------

	tween_camara.tween_property(
		self,
		"global_position",
		destino,
		duracion_movimiento
	).set_trans(
		Tween.TRANS_QUAD
	).set_ease(
		Tween.EASE_IN_OUT
	)


	# --------------------------------------------------------
	# ZOOM
	# --------------------------------------------------------

	tween_camara.tween_property(
		self,
		"zoom",
		nuevo_zoom,
		duracion_movimiento
	).set_trans(
		Tween.TRANS_QUAD
	).set_ease(
		Tween.EASE_IN_OUT
	)


	# --------------------------------------------------------
	# ESPERAR
	# --------------------------------------------------------

	await tween_camara.finished


	# --------------------------------------------------------
	# ASEGURAR POSICIÓN
	# --------------------------------------------------------

	global_position = destino


	# --------------------------------------------------------
	# ASEGURAR ZOOM
	# --------------------------------------------------------

	zoom = nuevo_zoom


	# --------------------------------------------------------
	# CAMBIAR ESTADO
	# --------------------------------------------------------

	estado_actual = EstadoCamara.ZOOM_COMUNA


	# --------------------------------------------------------
	# LIBERAR CÁMARA
	# --------------------------------------------------------

	camara_en_transicion = false

	tween_camara = null


# ============================================================
# SEGUNDO ZOOM
# ============================================================
#
# IMPORTANTE:
#
# AHORA EL SEGUNDO ZOOM OCURRE EN DOS ETAPAS.
#
# ETAPA 1:
# La cámara se mueve al centro de la comuna.
#
# ETAPA 2:
# Una vez que ya está en el centro,
# comienza el zoom.
#
# ============================================================

func hacer_segundo_zoom(comuna: Node) -> void:

	# --------------------------------------------------------
	# OBTENER POLYGON
	# --------------------------------------------------------

	var polygon: Polygon2D = (
		obtener_polygon(comuna)
	)


	if polygon == null:
		return


	# --------------------------------------------------------
	# OBTENER RECTÁNGULO GLOBAL
	# --------------------------------------------------------

	var rect_global: Rect2 = (
		obtener_rect_global_polygon(polygon)
	)


	if rect_global.size.x <= 0.0:
		return


	if rect_global.size.y <= 0.0:
		return


	# ========================================================
	# GUARDAR POSICIÓN ACTUAL
	# ========================================================

	posicion_zoom_anterior = global_position


	# ========================================================
	# GUARDAR ZOOM ACTUAL
	# ========================================================

	zoom_anterior = zoom


	# ========================================================
	# GUARDAR COMUNA
	# ========================================================

	comuna_actual = comuna


	# ========================================================
	# CENTRO EXACTO DE LA COMUNA
	# ========================================================

	var destino: Vector2 = (
		rect_global.get_center()
	)


	# ========================================================
	# CALCULAR ZOOM FINAL
	# ========================================================

	var nuevo_zoom: Vector2 = (
		calcular_zoom_segundo_zoom(
			rect_global
		)
	)
	
	destino.x += (get_viewport_rect().size.x / 6.0) / nuevo_zoom.x

	# ========================================================
	# BLOQUEAR TODO MOVIMIENTO
	# ========================================================

	camara_en_transicion = true


	# ========================================================
	# OCULTAR OTRAS COMUNAS
	# ========================================================

	ocultar_otras_comunas(comuna)


	# ========================================================
	# ETAPA 1
	# ========================================================
	#
	# PRIMERO:
	#
	# La cámara se mueve al centro de la comuna.
	#
	# El zoom NO cambia todavía.
	#
	# ========================================================

	await mover_camara_a(
		destino
	)


	# ========================================================
	# ASEGURAR QUE ESTAMOS EN EL CENTRO
	# ========================================================

	global_position = destino


	# ========================================================
	# ETAPA 2
	# ========================================================
	#
	# AHORA QUE LA CÁMARA YA ESTÁ EN EL CENTRO:
	#
	# hacemos el zoom.
	#
	# ========================================================

	await hacer_zoom(
		nuevo_zoom
	)


	# ========================================================
	# ASEGURAR VALORES FINALES
	# ========================================================

	global_position = destino

	zoom = nuevo_zoom


	# ========================================================
	# CAMBIAR ESTADO
	# ========================================================

	estado_actual = EstadoCamara.SOLO_COMUNA


	# ========================================================
	# LIBERAR TRANSICIÓN
	# ========================================================

	camara_en_transicion = false

	tween_camara = null
	
	comuna_seleccionada.emit(comuna)


# ============================================================
# CALCULAR ZOOM DEL PRIMER NIVEL
# ============================================================

func calcular_zoom_primer_zoom(
	rect_global: Rect2
) -> Vector2:

	var viewport_size: Vector2 = (
		get_viewport_rect().size
	)


	# --------------------------------------------------------
	# ESPACIO OBJETIVO
	# --------------------------------------------------------

	var ancho_objetivo: float = (
		viewport_size.x *
		porcentaje_primer_zoom
	)


	var alto_objetivo: float = (
		viewport_size.y *
		porcentaje_primer_zoom
	)


	# --------------------------------------------------------
	# ZOOM HORIZONTAL
	# --------------------------------------------------------

	var zoom_x: float = (
		ancho_objetivo /
		rect_global.size.x
	)


	# --------------------------------------------------------
	# ZOOM VERTICAL
	# --------------------------------------------------------

	var zoom_y: float = (
		alto_objetivo /
		rect_global.size.y
	)


	# --------------------------------------------------------
	# USAR EL MENOR
	# --------------------------------------------------------

	var zoom_calculado: float = min(
		zoom_x,
		zoom_y
	)


	# --------------------------------------------------------
	# SUAVIZAR
	# --------------------------------------------------------

	zoom_calculado *= 0.75


	# ========================================================
	# EL PRIMER CLICK NUNCA HACE ZOOM OUT
	# ========================================================

	var zoom_actual: float = zoom.x


	if zoom_calculado <= zoom_actual:

		zoom_calculado = (
			zoom_actual * 1.15
		)


	# --------------------------------------------------------
	# LIMITAR
	# --------------------------------------------------------

	zoom_calculado = clamp(
		zoom_calculado,
		zoom_minimo,
		zoom_maximo
	)


	return Vector2(
		zoom_calculado,
		zoom_calculado
	)


# ============================================================
# CALCULAR ZOOM DEL SEGUNDO NIVEL
# ============================================================

func calcular_zoom_segundo_zoom(
	rect_global: Rect2
) -> Vector2:

	var viewport_size: Vector2 = (
		get_viewport_rect().size
	)


	# --------------------------------------------------------
	# PORCENTAJE DE PANTALLA DISPONIBLE
	# --------------------------------------------------------

	var margen: float = 0.88


	var ancho_disponible: float = (
		viewport_size.x *
		(2.0 / 3.0) *
		margen
	)


	var alto_disponible: float = (
		viewport_size.y *
		margen
	)


	# --------------------------------------------------------
	# ZOOM HORIZONTAL
	# --------------------------------------------------------

	var zoom_x: float = (
		ancho_disponible /
		rect_global.size.x
	)


	# --------------------------------------------------------
	# ZOOM VERTICAL
	# --------------------------------------------------------

	var zoom_y: float = (
		alto_disponible /
		rect_global.size.y
	)


	# --------------------------------------------------------
	# USAR EL MENOR
	# --------------------------------------------------------

	var zoom_calculado: float = min(
		zoom_x,
		zoom_y
	)


	# --------------------------------------------------------
	# LIMITAR
	# --------------------------------------------------------

	zoom_calculado = clamp(
		zoom_calculado,
		zoom_minimo,
		zoom_maximo
	)


	return Vector2(
		zoom_calculado,
		zoom_calculado
	)


# ============================================================
# OBTENER RECTÁNGULO GLOBAL DEL POLYGON
# ============================================================

func obtener_rect_global_polygon(
	polygon: Polygon2D
) -> Rect2:

	var puntos: PackedVector2Array = (
		polygon.polygon
	)


	if puntos.is_empty():
		return Rect2()


	# --------------------------------------------------------
	# TRANSFORMACIÓN GLOBAL
	# --------------------------------------------------------

	var transformacion: Transform2D = (
		polygon.global_transform
	)


	# --------------------------------------------------------
	# PRIMER PUNTO
	# --------------------------------------------------------

	var primer_punto: Vector2 = (
		transformacion *
		puntos[0]
	)


	var rect: Rect2 = Rect2(
		primer_punto,
		Vector2.ZERO
	)


	# --------------------------------------------------------
	# RESTO DE PUNTOS
	# --------------------------------------------------------

	for i in range(1, puntos.size()):

		var punto_global: Vector2 = (
			transformacion *
			puntos[i]
		)


		rect = rect.expand(
			punto_global
		)


	return rect


# ============================================================
# OCULTAR OTRAS COMUNAS
# ============================================================

func ocultar_otras_comunas(
	comuna_seleccionada: Node
) -> void:

	var mapa: Node = get_node("../Mapa")


	for comuna in mapa.get_children():

		var area: Area2D = (
			comuna.get_node_or_null("Area2D")
		)


		if area == null:
			continue


		var polygon: Polygon2D = (
			area.get_node_or_null("Polygon2D")
		)


		if polygon == null:
			continue


		# ====================================================
		# COMUNA SELECCIONADA
		# ====================================================

		if comuna == comuna_seleccionada:

			polygon.visible = true

			polygon.modulate.a = 1.0


			var borde: Line2D = (
				area.get_node_or_null("Borde")
			)


			if borde != null:

				borde.visible = true

				borde.modulate.a = 1.0


			area.input_pickable = true


		# ====================================================
		# OTRAS COMUNAS
		# ====================================================

		else:

			polygon.visible = false


			var borde: Line2D = (
				area.get_node_or_null("Borde")
			)


			if borde != null:

				borde.visible = false


			area.input_pickable = false


# ============================================================
# OBTENER POLYGON DE UNA COMUNA
# ============================================================

func obtener_polygon(
	comuna: Node
) -> Polygon2D:

	var area: Area2D = (
		comuna.get_node_or_null("Area2D")
	)


	if area == null:
		return null


	return area.get_node_or_null(
		"Polygon2D"
	)


# ============================================================
# ACTUALIZAR GROSOR DE BORDES
# ============================================================

func actualizar_grosor_bordes() -> void:

	var mapa: Node = get_node("../Mapa")


	# --------------------------------------------------------
	# CALCULAR GROSOR
	# --------------------------------------------------------

	var grosor_actual: float = (
		grosor_borde_normal /
		zoom.x
	)


	# --------------------------------------------------------
	# LIMITAR
	# --------------------------------------------------------

	grosor_actual = clamp(
		grosor_actual,
		grosor_borde_minimo,
		grosor_borde_normal
	)


	# --------------------------------------------------------
	# APLICAR A TODAS LAS COMUNAS
	# --------------------------------------------------------

	for comuna in mapa.get_children():

		var area: Area2D = (
			comuna.get_node_or_null("Area2D")
		)


		if area == null:
			continue


		var borde: Line2D = (
			area.get_node_or_null("Borde")
		)


		if borde == null:
			continue


		borde.width = grosor_actual


# ============================================================
# PROCESS
# ============================================================

func _process(delta: float) -> void:

	# --------------------------------------------------------
	# ACTUALIZAR BORDES
	# --------------------------------------------------------

	actualizar_grosor_bordes()


	# --------------------------------------------------------
	# NO HACER NADA DURANTE TRANSICIÓN
	# --------------------------------------------------------

	if camara_en_transicion:

		return


	# --------------------------------------------------------
	# MOVIMIENTO POR BORDES
	# --------------------------------------------------------

	if estado_actual == EstadoCamara.MAPA_COMPLETO:

		mover_con_mouse(delta)


	elif estado_actual == EstadoCamara.ZOOM_COMUNA:

		mover_con_mouse(delta)


	# --------------------------------------------------------
	# SOLO_COMUNA
	# --------------------------------------------------------
	#
	# No se mueve.
	# --------------------------------------------------------


# ============================================================
# MOVIMIENTO DE CÁMARA CON MOUSE
# ============================================================

func mover_con_mouse(
	delta: float
) -> void:

	# --------------------------------------------------------
	# POSICIÓN DEL MOUSE
	# --------------------------------------------------------

	var mouse_position: Vector2 = (
		get_viewport().get_mouse_position()
	)


	# --------------------------------------------------------
	# TAMAÑO DEL VIEWPORT
	# --------------------------------------------------------

	var viewport_size: Vector2 = (
		get_viewport_rect().size
	)


	# --------------------------------------------------------
	# DIRECCIÓN
	# --------------------------------------------------------

	var direccion: Vector2 = Vector2.ZERO


	# --------------------------------------------------------
	# IZQUIERDA
	# --------------------------------------------------------

	if mouse_position.x <= margen_borde:

		direccion.x = -1.0


	# --------------------------------------------------------
	# DERECHA
	# --------------------------------------------------------

	elif mouse_position.x >= (
		viewport_size.x -
		margen_borde
	):

		direccion.x = 1.0


	# --------------------------------------------------------
	# ARRIBA
	# --------------------------------------------------------

	if mouse_position.y <= margen_borde:

		direccion.y = -1.0


	# --------------------------------------------------------
	# ABAJO
	# --------------------------------------------------------

	elif mouse_position.y >= (
		viewport_size.y -
		margen_borde
	):

		direccion.y = 1.0


	# --------------------------------------------------------
	# SIN MOVIMIENTO
	# --------------------------------------------------------

	if direccion == Vector2.ZERO:

		return


	# --------------------------------------------------------
	# NORMALIZAR
	# --------------------------------------------------------

	direccion = direccion.normalized()


	# --------------------------------------------------------
	# VELOCIDAD
	# --------------------------------------------------------

	var velocidad_actual: float = max(
		velocidad_maxima / zoom.x,
		70.0
	)


	# --------------------------------------------------------
	# MOVER USANDO GLOBAL_POSITION
	# --------------------------------------------------------

	global_position += (
		direccion *
		velocidad_actual *
		delta
	)


# ============================================================
# CLICK DERECHO
# ============================================================

func _unhandled_input(
	evento: InputEvent
) -> void:

	# --------------------------------------------------------
	# IGNORAR DURANTE TRANSICIÓN
	# --------------------------------------------------------

	if camara_en_transicion:

		return


	# --------------------------------------------------------
	# VERIFICAR EVENTO
	# --------------------------------------------------------

	if not evento is InputEventMouseButton:

		return


	var mouse_evento: InputEventMouseButton = (
		evento
	)


	# --------------------------------------------------------
	# SOLO PRESIONADO
	# --------------------------------------------------------

	if not mouse_evento.pressed:

		return


	# --------------------------------------------------------
	# SOLO CLICK DERECHO
	# --------------------------------------------------------

	if mouse_evento.button_index != MOUSE_BUTTON_RIGHT:

		return


	# ========================================================
	# SOLO COMUNA -> PRIMER ZOOM
	# ========================================================

	if estado_actual == EstadoCamara.SOLO_COMUNA:

		volver_a_zoom()


	# ========================================================
	# PRIMER ZOOM -> MAPA COMPLETO
	# ========================================================

	elif estado_actual == EstadoCamara.ZOOM_COMUNA:

		hacer_zoom_out()


# ============================================================
# VOLVER AL PRIMER ZOOM
# ============================================================

func volver_a_zoom() -> void:

	# --------------------------------------------------------
	# CANCELAR TWEEN
	# --------------------------------------------------------

	cancelar_tween_camara()


	# --------------------------------------------------------
	# BLOQUEAR MOVIMIENTO
	# --------------------------------------------------------

	camara_en_transicion = true
	
	comuna_deseleccionada.emit() 


	# --------------------------------------------------------
	# MOSTRAR TODAS LAS COMUNAS
	# --------------------------------------------------------

	mostrar_todas_las_comunas()


	# --------------------------------------------------------
	# CREAR TWEEN
	# --------------------------------------------------------

	tween_camara = create_tween()


	# --------------------------------------------------------
	# POSICIÓN
	# --------------------------------------------------------

	tween_camara.tween_property(
		self,
		"global_position",
		posicion_zoom_anterior,
		duracion_movimiento
	).set_trans(
		Tween.TRANS_QUAD
	).set_ease(
		Tween.EASE_IN_OUT
	)


	# --------------------------------------------------------
	# ZOOM
	# --------------------------------------------------------

	tween_camara.parallel().tween_property(
		self,
		"zoom",
		zoom_anterior,
		duracion_movimiento
	).set_trans(
		Tween.TRANS_QUAD
	).set_ease(
		Tween.EASE_IN_OUT
	)


	# --------------------------------------------------------
	# ESPERAR
	# --------------------------------------------------------

	await tween_camara.finished


	# --------------------------------------------------------
	# ASEGURAR POSICIÓN
	# --------------------------------------------------------

	global_position = posicion_zoom_anterior


	# --------------------------------------------------------
	# ASEGURAR ZOOM
	# --------------------------------------------------------

	zoom = zoom_anterior


	# --------------------------------------------------------
	# ESTADO
	# --------------------------------------------------------

	estado_actual = EstadoCamara.ZOOM_COMUNA


	# --------------------------------------------------------
	# LIBERAR
	# --------------------------------------------------------

	camara_en_transicion = false

	tween_camara = null


# ============================================================
# MOSTRAR TODAS LAS COMUNAS
# ============================================================

func mostrar_todas_las_comunas() -> void:

	var mapa: Node = get_node("../Mapa")


	for comuna in mapa.get_children():

		var area: Area2D = (
			comuna.get_node_or_null("Area2D")
		)


		if area == null:
			continue


		var polygon: Polygon2D = (
			area.get_node_or_null("Polygon2D")
		)


		if polygon == null:
			continue


		# ----------------------------------------------------
		# MOSTRAR POLYGON
		# ----------------------------------------------------

		polygon.visible = true

		polygon.modulate.a = 1.0


		# ----------------------------------------------------
		# MOSTRAR BORDE
		# ----------------------------------------------------

		var borde: Line2D = (
			area.get_node_or_null("Borde")
		)


		if borde != null:

			borde.visible = true

			borde.modulate.a = 1.0


		# ----------------------------------------------------
		# ACTIVAR INPUT
		# ----------------------------------------------------

		area.input_pickable = true


# ============================================================
# VOLVER AL MAPA COMPLETO
# ============================================================

func hacer_zoom_out() -> void:

	# --------------------------------------------------------
	# CANCELAR TWEEN
	# --------------------------------------------------------

	cancelar_tween_camara()


	# --------------------------------------------------------
	# BLOQUEAR MOVIMIENTO
	# --------------------------------------------------------

	camara_en_transicion = true


	# --------------------------------------------------------
	# CREAR TWEEN
	# --------------------------------------------------------

	tween_camara = create_tween()


	# --------------------------------------------------------
	# POSICIÓN
	# --------------------------------------------------------

	tween_camara.tween_property(
		self,
		"global_position",
		posicion_inicial,
		duracion_movimiento
	).set_trans(
		Tween.TRANS_QUAD
	).set_ease(
		Tween.EASE_IN_OUT
	)


	# --------------------------------------------------------
	# ZOOM
	# --------------------------------------------------------

	tween_camara.parallel().tween_property(
		self,
		"zoom",
		zoom_inicial,
		duracion_movimiento
	).set_trans(
		Tween.TRANS_QUAD
	).set_ease(
		Tween.EASE_IN_OUT
	)


	# --------------------------------------------------------
	# ESPERAR
	# --------------------------------------------------------

	await tween_camara.finished


	# --------------------------------------------------------
	# ASEGURAR POSICIÓN
	# --------------------------------------------------------

	global_position = posicion_inicial


	# --------------------------------------------------------
	# ASEGURAR ZOOM
	# --------------------------------------------------------

	zoom = zoom_inicial


	# --------------------------------------------------------
	# LIMPIAR COMUNA
	# --------------------------------------------------------

	comuna_actual = null


	# --------------------------------------------------------
	# CAMBIAR ESTADO
	# --------------------------------------------------------

	estado_actual = EstadoCamara.MAPA_COMPLETO


	# --------------------------------------------------------
	# LIBERAR
	# --------------------------------------------------------

	camara_en_transicion = false

	tween_camara = null
