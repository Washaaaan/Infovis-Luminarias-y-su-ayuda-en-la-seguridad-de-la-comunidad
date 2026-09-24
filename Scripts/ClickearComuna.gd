extends Area2D


# ============================================================
# COLORES DEL BORDE
# ============================================================

@export var color_borde: Color = Color("#8FA9B8")


# ============================================================
# CONFIGURACIÓN DEL BORDE
# ============================================================

@export var ancho_borde: float = 0.01


# ============================================================
# CONFIGURACIÓN DE FRONTERAS
# ============================================================

# Distancia máxima para considerar que dos segmentos
# pertenecen a fronteras compartidas.

@export var distancia_maxima_vecino: float = 8.0


# Cantidad máxima de segmentos de frontera que enviaremos
# al shader.

@export var max_fronteras: int = 16


# ============================================================
# REFERENCIA AL POLYGON
# ============================================================

@onready var polygon: Polygon2D = $Polygon2D


# ============================================================
# MATERIAL
# ============================================================

var shader_material: ShaderMaterial


# ============================================================
# NIVEL DE ILUMINACIÓN
# ============================================================

var nivel_iluminacion: float = 0.0


# ============================================================
# READY
# ============================================================

func _ready() -> void:

	polygon.visible = true

	configurar_iluminacion()

	crear_borde()

	mouse_entered.connect(
		_on_mouse_entered
	)

	mouse_exited.connect(
		_on_mouse_exited
	)

	# Esperamos a que todas las comunas tengan
	# sus Polygon2D disponibles.

	call_deferred(
		"configurar_fronteras_iluminadas"
	)


# ============================================================
# CREAR BORDE
# ============================================================

func crear_borde() -> void:

	var borde := Line2D.new()

	borde.name = "Borde"

	borde.points = polygon.polygon

	borde.closed = true

	borde.width = ancho_borde

	borde.default_color = color_borde

	borde.z_index = 1

	add_child(borde)


# ============================================================
# CONFIGURAR ILUMINACIÓN
# ============================================================

func configurar_iluminacion() -> void:

	var nombre_comuna := get_parent().name

	nivel_iluminacion = DatosComunas.nivel_iluminacion(
		nombre_comuna
	)


	var shader: Shader = preload(
		"res://Shaders/iluminacion_comuna.gdshader"
	)


	shader_material = ShaderMaterial.new()

	shader_material.shader = shader


	# --------------------------------------------------------
	# NIVEL DE ESTA COMUNA
	# --------------------------------------------------------

	shader_material.set_shader_parameter(
		"nivel",
		nivel_iluminacion
	)


	# --------------------------------------------------------
	# HOVER
	# --------------------------------------------------------

	shader_material.set_shader_parameter(
		"hover",
		0.0
	)


	# --------------------------------------------------------
	# LÍMITES
	# --------------------------------------------------------

	configurar_limites_shader()


	# --------------------------------------------------------
	# MATERIAL
	# --------------------------------------------------------

	polygon.material = shader_material


# ============================================================
# CONFIGURAR LÍMITES
# ============================================================

func configurar_limites_shader() -> void:

	var puntos: PackedVector2Array = polygon.polygon

	if puntos.is_empty():
		return


	var rect := Rect2(
		puntos[0],
		Vector2.ZERO
	)


	for punto in puntos:

		rect = rect.expand(punto)


	shader_material.set_shader_parameter(
		"limite_min",
		rect.position
	)


	shader_material.set_shader_parameter(
		"limite_max",
		rect.end
	)


# ============================================================
# CONFIGURAR FRONTERAS ILUMINADAS
# ============================================================

func configurar_fronteras_iluminadas() -> void:

	if shader_material == null:
		return

	if polygon == null:
		return

	if polygon.polygon.is_empty():
		return


	# --------------------------------------------------------
	# LIMPIAR SEGMENTOS
	# --------------------------------------------------------

	var puntos_a := PackedVector4Array()
	var puntos_b := PackedVector4Array()
	var datos := PackedVector4Array()


	for i in range(max_fronteras):

		puntos_a.append(Vector4.ZERO)
		puntos_b.append(Vector4.ZERO)
		datos.append(Vector4.ZERO)


	# --------------------------------------------------------
	# OBTENER MAPA
	# --------------------------------------------------------

	var mapa: Node = get_parent().get_parent()

	if mapa == null:
		return


	# --------------------------------------------------------
	# RECTÁNGULO PROPIO
	# --------------------------------------------------------

	var rect_propio := obtener_rect_global()

	if rect_propio.size == Vector2.ZERO:
		return


	# --------------------------------------------------------
	# TODAS LAS FRONTERAS ENCONTRADAS
	# --------------------------------------------------------

	var fronteras: Array[Dictionary] = []


	# ========================================================
	# RECORRER COMUNAS
	# ========================================================

	for comuna in mapa.get_children():

		if comuna == get_parent():
			continue


		# ----------------------------------------------------
		# AREA
		# ----------------------------------------------------

		var area_vecina: Area2D = (
			comuna.get_node_or_null("Area2D")
		)

		if area_vecina == null:
			continue


		# ----------------------------------------------------
		# POLYGON
		# ----------------------------------------------------

		var polygon_vecino: Polygon2D = (
			area_vecina.get_node_or_null(
				"Polygon2D"
			)
		)

		if polygon_vecino == null:
			continue


		if polygon_vecino.polygon.is_empty():
			continue


		# ----------------------------------------------------
		# NIVEL DE LA VECINA
		# ----------------------------------------------------

		var nivel_vecina := DatosComunas.nivel_iluminacion(
			comuna.name
		)


		# ----------------------------------------------------
		# SOLO VECINAS MÁS ILUMINADAS
		# ----------------------------------------------------

		if nivel_vecina <= nivel_iluminacion:
			continue


		# ----------------------------------------------------
		# RECTÁNGULO VECINO
		# ----------------------------------------------------

		var rect_vecino := (
			obtener_rect_global_polygon(
				polygon_vecino
			)
		)


		# ----------------------------------------------------
		# FILTRO RÁPIDO
		# ----------------------------------------------------

		var rect_expandido := rect_propio.grow(
			distancia_maxima_vecino
		)


		if not rect_expandido.intersects(
			rect_vecino
		):
			continue


		# ----------------------------------------------------
		# BUSCAR SEGMENTOS COMPARTIDOS
		# ----------------------------------------------------

		var segmentos := (
			encontrar_fronteras_compartidas(
				polygon,
				polygon_vecino
			)
		)


		# ----------------------------------------------------
		# GUARDAR SEGMENTOS
		# ----------------------------------------------------

		for segmento in segmentos:

			fronteras.append({
				"a": segmento["a"],
				"b": segmento["b"],
				"nivel": nivel_vecina,
				"longitud": segmento["longitud"]
			})


	# ========================================================
	# ORDENAR POR LONGITUD
	# ========================================================
	#
	# Las fronteras más largas tienen prioridad.
	# ========================================================

	fronteras.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:

			return (
				a["longitud"] >
				b["longitud"]
			)
	)


	# ========================================================
	# ENVIAR AL SHADER
	# ========================================================

	var cantidad : float = min(
		max_fronteras,
		fronteras.size()
	)


	var rect_local := obtener_rect_local()


	for i in range(cantidad):

		var frontera: Dictionary = fronteras[i]


		var punto_a_global: Vector2 = (
			frontera["a"]
		)


		var punto_b_global: Vector2 = (
			frontera["b"]
		)


		# ----------------------------------------------------
		# PASAR A COORDENADAS LOCALES
		# ----------------------------------------------------

		var punto_a_local := polygon.to_local(
			punto_a_global
		)


		var punto_b_local := polygon.to_local(
			punto_b_global
		)


		# ----------------------------------------------------
		# NORMALIZAR
		# ----------------------------------------------------

		var punto_a := normalizar_punto(
			punto_a_local,
			rect_local
		)


		var punto_b := normalizar_punto(
			punto_b_local,
			rect_local
		)


		# ----------------------------------------------------
		# INTENSIDAD
		# ----------------------------------------------------

		var nivel_vecina: float = (
			frontera["nivel"]
		)


		var diferencia : float = max(
			nivel_vecina -
			nivel_iluminacion,
			0.0
		)


		# Intensidad base.

		var intensidad : float = clamp(
			diferencia * 1.8,
			0.0,
			1.0
		)


		# ----------------------------------------------------
		# GUARDAR
		# ----------------------------------------------------

		puntos_a[i] = Vector4(
			punto_a.x,
			punto_a.y,
			0.0,
			0.0
		)


		puntos_b[i] = Vector4(
			punto_b.x,
			punto_b.y,
			0.0,
			0.0
		)


		datos[i] = Vector4(
			nivel_vecina,
			intensidad,
			1.0,
			0.0
		)


	# ========================================================
	# ENVIAR ARRAYS AL SHADER
	# ========================================================

	shader_material.set_shader_parameter(
		"frontera_a",
		puntos_a
	)


	shader_material.set_shader_parameter(
		"frontera_b",
		puntos_b
	)


	shader_material.set_shader_parameter(
		"frontera_datos",
		datos
	)


# ============================================================
# NORMALIZAR PUNTO
# ============================================================

func normalizar_punto(
	punto: Vector2,
	rect: Rect2
) -> Vector2:

	var resultado := Vector2(
		0.5,
		0.5
	)


	if rect.size.x > 0.001:

		resultado.x = (
			punto.x -
			rect.position.x
		) / rect.size.x


	if rect.size.y > 0.001:

		resultado.y = (
			punto.y -
			rect.position.y
		) / rect.size.y


	resultado.x = clamp(
		resultado.x,
		0.0,
		1.0
	)


	resultado.y = clamp(
		resultado.y,
		0.0,
		1.0
	)


	return resultado


# ============================================================
# ENCONTRAR FRONTERAS COMPARTIDAS
# ============================================================

func encontrar_fronteras_compartidas(
	poly_a: Polygon2D,
	poly_b: Polygon2D
) -> Array[Dictionary]:

	var resultado: Array[Dictionary] = []

	var puntos_a := poly_a.polygon
	var puntos_b := poly_b.polygon


	if puntos_a.size() < 2:
		return resultado


	if puntos_b.size() < 2:
		return resultado


	# ========================================================
	# COMPARAR SEGMENTOS
	# ========================================================

	for i in range(puntos_a.size()):

		var a1: Vector2 = (
			poly_a.global_transform *
			puntos_a[i]
		)


		var a2: Vector2 = (
			poly_a.global_transform *
			puntos_a[
				(i + 1) %
				puntos_a.size()
			]
		)


		var longitud_a := (
			a1.distance_to(a2)
		)


		# Segmentos demasiado pequeños no aportan.

		if longitud_a < 0.5:
			continue


		for j in range(puntos_b.size()):

			var b1: Vector2 = (
				poly_b.global_transform *
				puntos_b[j]
			)


			var b2: Vector2 = (
				poly_b.global_transform *
				puntos_b[
					(j + 1) %
					puntos_b.size()
				]
			)


			var longitud_b := (
				b1.distance_to(b2)
			)


			if longitud_b < 0.5:
				continue


			# ------------------------------------------------
			# PUNTOS MÁS CERCANOS
			# ------------------------------------------------

			var cercanos := (
				Geometry2D
				.get_closest_points_between_segments(
					a1,
					a2,
					b1,
					b2
				)
			)


			if cercanos.size() < 2:
				continue


			var punto_a: Vector2 = (
				cercanos[0]
			)


			var punto_b: Vector2 = (
				cercanos[1]
			)


			var distancia := (
				punto_a.distance_to(
					punto_b
				)
			)


			# ------------------------------------------------
			# ¿SON REALMENTE FRONTERA?
			# ------------------------------------------------

			if distancia > distancia_maxima_vecino:
				continue


			# ------------------------------------------------
			# COMPROBAR QUE LOS SEGMENTOS TENGAN DIRECCIÓN
			# SIMILAR.
			# ------------------------------------------------

			var direccion_a := (
				a2 - a1
			).normalized()


			var direccion_b := (
				b2 - b1
			).normalized()


			var alineacion : float = abs(
				direccion_a.dot(
					direccion_b
				)
			)


			# Si las líneas no son aproximadamente paralelas,
			# probablemente se trata solamente de un cruce.

			if alineacion < 0.85:
				continue


			# ------------------------------------------------
			# CALCULAR SEGMENTO DE FRONTERA
			# ------------------------------------------------

			var punto_inicio := punto_a

			var punto_fin := punto_a


			# Usamos los puntos medios entre las dos fronteras
			# para obtener una representación estable.

			var medio_a := (
				a1 + a2
			) * 0.5


			var medio_b := (
				b1 + b2
			) * 0.5


			var medio := (
				medio_a + medio_b
			) * 0.5


			# ------------------------------------------------
			# USAR EL SEGMENTO ORIGINAL DE A
			# ------------------------------------------------

			punto_inicio = a1

			punto_fin = a2


			# ------------------------------------------------
			# RECORTARLO HACIA LA ZONA MÁS CERCANA
			# ------------------------------------------------

			var proyeccion_1 : Vector2= (
				proyectar_punto_en_segmento(
					punto_b,
					a1,
					a2
				)
			)


			if proyeccion_1 != null:

				punto_inicio = proyeccion_1


			# ------------------------------------------------
			# SEGMENTO RESULTANTE
			# ------------------------------------------------

			var longitud := (
				punto_inicio.distance_to(
					punto_fin
				)
			)


			# Si quedó muy pequeño, usamos el segmento completo.

			if longitud < 1.0:

				punto_inicio = a1
				punto_fin = a2

				longitud = longitud_a


			resultado.append({
				"a": punto_inicio,
				"b": punto_fin,
				"longitud": longitud
			})


	return resultado


# ============================================================
# PROYECCIÓN DE PUNTO SOBRE SEGMENTO
# ============================================================

func proyectar_punto_en_segmento(
	punto: Vector2,
	a: Vector2,
	b: Vector2
) -> Variant:

	var direccion := b - a

	var longitud_cuadrada := (
		direccion.length_squared()
	)


	if longitud_cuadrada <= 0.000001:
		return null


	var t := (
		(punto - a).dot(direccion)
		/ longitud_cuadrada
	)


	t = clamp(
		t,
		0.0,
		1.0
	)


	return a + direccion * t


# ============================================================
# RECTÁNGULO LOCAL
# ============================================================

func obtener_rect_local() -> Rect2:

	var puntos := polygon.polygon

	if puntos.is_empty():
		return Rect2()


	var rect := Rect2(
		puntos[0],
		Vector2.ZERO
	)


	for punto in puntos:

		rect = rect.expand(
			punto
		)


	return rect


# ============================================================
# RECTÁNGULO GLOBAL
# ============================================================

func obtener_rect_global() -> Rect2:

	return obtener_rect_global_polygon(
		polygon
	)


# ============================================================
# RECTÁNGULO GLOBAL DE POLYGON
# ============================================================

func obtener_rect_global_polygon(
	poly: Polygon2D
) -> Rect2:

	var puntos := poly.polygon

	if puntos.is_empty():
		return Rect2()


	var primer_punto := (
		poly.global_transform *
		puntos[0]
	)


	var rect := Rect2(
		primer_punto,
		Vector2.ZERO
	)


	for i in range(1, puntos.size()):

		var punto := (
			poly.global_transform *
			puntos[i]
		)


		rect = rect.expand(
			punto
		)


	return rect


# ============================================================
# HOVER
# ============================================================

func _on_mouse_entered() -> void:

	if shader_material == null:
		return


	var tween := create_tween()


	tween.tween_method(
		func(valor: float):

			shader_material.set_shader_parameter(
				"hover",
				valor
			),

		0.0,
		1.0,
		0.15

	).set_trans(
		Tween.TRANS_QUAD
	).set_ease(
		Tween.EASE_OUT
	)


# ============================================================
# HOVER EXIT
# ============================================================

func _on_mouse_exited() -> void:

	if shader_material == null:
		return


	var tween := create_tween()


	tween.tween_method(
		func(valor: float):

			shader_material.set_shader_parameter(
				"hover",
				valor
			),

		1.0,
		0.0,
		0.15

	).set_trans(
		Tween.TRANS_QUAD
	).set_ease(
		Tween.EASE_OUT
	)
