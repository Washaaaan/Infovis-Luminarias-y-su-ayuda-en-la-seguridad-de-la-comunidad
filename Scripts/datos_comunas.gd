extends Node

const RUTA_CSV := "res://datos/resumen_consolidado.txt"

const RUTA_ANUAL := "res://datos/delitos_anual.txt"

const RUTA_INGRESO := "res://datos/ingreso_anual.txt"

const ACENTOS := {
	"á": "a",
	"é": "e",
	"í": "i",
	"ó": "o",
	"ú": "u",
	"ü": "u",
	"ñ": "n"
}


# ============================================================
# FILAS DEL CSV
# ============================================================

# 0  = Delitos contra la vida o integridad...
# 1  = Amenazas
# ...
# 9  = Microtráfico de sustancias
# 10 = Luminarias Públicas
# 11 = Superficie en Km²
# 12 = Superficie Habitada en Km²
# 13 = Cantidad de Luminarias Públicas x Superficie habitada

const FILA_LUMINARIAS := 10
const FILA_SUPERFICIE_HABITADA := 12
const FILA_DENSIDAD := 13

# Filas de delitos usadas para el total (evitando doble conteo).
const FILAS_DELITOS: Array[int] = [0, 1, 2, 7]

# "total personas / superficie habitada"
const FILA_DENSIDAD_PERSONAS := 17


# ============================================================
# DATOS
# ============================================================

var etiquetas: PackedStringArray = []
var _por_comuna: Dictionary = {}


# ============================================================
# MODO DE VISUALIZACIÓN
#
# 0 = densidad de personas ↔ delitos
# 1 = densidad de luminarias ↔ delitos
# ============================================================

var modo_visual: int = 0


# ============================================================
# RANGO DE ILUMINACIÓN
# ============================================================

var iluminacion_min: float = INF
var iluminacion_max: float = -INF


# ============================================================
# CORTES DE LUMINARIAS (PARA EL EFECTO)
#
# luminarias_promedio: umbral (densidad media normalizada).
# luminarias_ref: tope (p90) donde la intensidad llega al máximo.
# ============================================================

var luminarias_promedio: float = 0.5
var luminarias_ref: float = 1.0


# ============================================================
# RANGO DE RELACIÓN DELITOS / DENSIDAD DE PERSONAS
# ============================================================

var relacion_min: float = INF
var relacion_max: float = -INF


# ============================================================
# DATOS ANUALES (2005 - 2026)
# ============================================================

var anio_min: int = 0
var anio_max: int = 0
var anio_actual: int = 2025

var relacion_max_anual: float = 1.0

var _anual: Dictionary = {}


# Ingreso por comuna y año.

var _ingreso: Dictionary = {}


# Filas estáticas usadas por el radar
const FILA_LUMINARIAS_ZONA := 13
const FILA_INGRESO := 18


# ============================================================
# READY
# ============================================================

func _ready() -> void:
	_cargar()
	_cargar_anual()
	_cargar_ingreso()


# ============================================================
# CARGAR DATOS ANUALES
# ============================================================

func _cargar_anual() -> void:

	var archivo := FileAccess.open(
		RUTA_ANUAL,
		FileAccess.READ
	)

	if archivo == null:
		push_error(
			"No se pudo abrir " + RUTA_ANUAL
		)
		return


	# Encabezado
	archivo.get_csv_line()


	while not archivo.eof_reached():

		var fila := archivo.get_csv_line()

		if fila.size() < 8:
			continue


		var clave := normalizar(fila[0])

		if clave == "":
			continue


		var anio := int(fila[1])


		if not _anual.has(clave):
			_anual[clave] = {}


		_anual[clave][anio] = {
			"delitos": fila[2].to_float(),
			"poblacion": fila[3].to_float(),
			"superficie": fila[4].to_float(),
			"densidad": fila[5].to_float(),
			"relacion": fila[6].to_float(),
			"nivel": fila[7].to_float()
		}


		relacion_max_anual = max(
			relacion_max_anual,
			fila[6].to_float()
		)


		if anio_min == 0:
			anio_min = anio
		else:
			anio_min = min(anio_min, anio)

		anio_max = max(anio_max, anio)


	anio_actual = clampi(
		anio_actual,
		anio_min,
		anio_max
	)


	print(
		"Datos anuales: ",
		_anual.size(),
		" comunas, ",
		anio_min,
		"-",
		anio_max
	)


# ============================================================
# CARGAR INGRESO POR AÑO
# ============================================================

func _cargar_ingreso() -> void:

	var archivo := FileAccess.open(
		RUTA_INGRESO,
		FileAccess.READ
	)

	if archivo == null:
		push_error(
			"No se pudo abrir " + RUTA_INGRESO
		)
		return


	archivo.get_csv_line()


	while not archivo.eof_reached():

		var fila := archivo.get_csv_line()

		if fila.size() < 3:
			continue


		var clave := normalizar(fila[0])

		if clave == "":
			continue


		if not _ingreso.has(clave):
			_ingreso[clave] = {}


		_ingreso[clave][int(fila[1])] = fila[2].to_float()


	print(
		"Ingreso anual: ",
		_ingreso.size(),
		" comunas"
	)


# ============================================================
# INGRESO DE UNA COMUNA EN UN AÑO
# ============================================================

func ingreso_anio(
	nombre: String,
	anio: int
) -> float:

	var clave := normalizar(nombre)

	if not _ingreso.has(clave):
		return 0.0

	if not _ingreso[clave].has(anio):
		return 0.0

	return _ingreso[clave][anio]


# ============================================================
# MIN-MAX DE INGRESO EN UN AÑO
# ============================================================

func minmax_ingreso_anual(anio: int) -> Vector2:

	return _minmax(
		func(clave: String) -> float:
			return ingreso_anio(clave, anio)
	)


# ============================================================
# DATO ANUAL DE UNA COMUNA
# ============================================================

func _dato_anual(
	nombre: String,
	anio: int
) -> Dictionary:

	var clave := normalizar(nombre)

	if not _anual.has(clave):
		return {}

	if not _anual[clave].has(anio):
		return {}

	return _anual[clave][anio]


# ============================================================
# ESTABLECER AÑO ACTUAL
# ============================================================

func establecer_anio(anio: int) -> void:

	anio_actual = clampi(
		anio,
		anio_min,
		anio_max
	)


# ============================================================
# CONSULTAS ANUALES
# ============================================================

func nivel_anio(
	nombre: String,
	anio: int
) -> float:

	return _dato_anual(nombre, anio).get("nivel", 0.0)


func delitos_anio(
	nombre: String,
	anio: int
) -> float:

	return _dato_anual(nombre, anio).get("delitos", 0.0)


func poblacion_anio(
	nombre: String,
	anio: int
) -> float:

	return _dato_anual(nombre, anio).get("poblacion", 0.0)


func densidad_anio(
	nombre: String,
	anio: int
) -> float:

	return _dato_anual(nombre, anio).get("densidad", 0.0)


func relacion_anio(
	nombre: String,
	anio: int
) -> float:

	return _dato_anual(nombre, anio).get("relacion", 0.0)


# ============================================================
# DELITOS POR ZONA HABITADA
# ============================================================

func superficie_anio(
	nombre: String,
	anio: int
) -> float:

	return _dato_anual(nombre, anio).get("superficie", 0.0)


func delitos_zona_anio(
	nombre: String,
	anio: int
) -> float:

	var superficie := superficie_anio(nombre, anio)

	if superficie <= 0.0:
		return 0.0

	return delitos_anio(nombre, anio) / superficie


func minmax_delitos_zona(anio: int) -> Vector2:

	return _minmax(
		func(clave: String) -> float:
			return delitos_zona_anio(clave, anio)
	)


# ============================================================
# DELITOS POR PERSONA
# ============================================================

func delitos_persona_anio(
	nombre: String,
	anio: int
) -> float:

	var poblacion := poblacion_anio(nombre, anio)

	if poblacion <= 0.0:
		return 0.0

	return delitos_anio(nombre, anio) / poblacion


func minmax_delitos_persona(anio: int) -> Vector2:

	return _minmax(
		func(clave: String) -> float:
			return delitos_persona_anio(clave, anio)
	)


# ============================================================
# NÚMERO LIMPIO (miles con "." y decimales con ",")
# ============================================================

func numero_limpio(
	nombre: String,
	fila: int
) -> float:

	var valores := obtener(nombre)

	if fila >= valores.size():
		return 0.0

	return valores[fila] \
		.strip_edges() \
		.trim_suffix("~") \
		.strip_edges() \
		.replace(".", "") \
		.replace(",", ".") \
		.to_float()


# ============================================================
# VARIABLES ESTÁTICAS DEL RADAR
# ============================================================

func luminarias_zona_habitada(
	nombre: String
) -> float:

	return numero_limpio(
		nombre,
		FILA_LUMINARIAS_ZONA
	)


func ingreso_promedio(
	nombre: String
) -> float:

	return numero_limpio(
		nombre,
		FILA_INGRESO
	)


# ============================================================
# LISTA DE COMUNAS
# ============================================================

func lista_comunas() -> Array:

	return _por_comuna.keys()


# ============================================================
# MIN-MAX GENÉRICO
# ============================================================

func _minmax(
	obtener_valor: Callable
) -> Vector2:

	var minimo := INF
	var maximo := -INF


	for clave in _por_comuna.keys():

		var valor: float = obtener_valor.call(clave)

		if valor <= 0.0:
			continue

		minimo = min(minimo, valor)
		maximo = max(maximo, valor)


	if minimo == INF or maximo <= minimo:
		return Vector2(0.0, 1.0)


	return Vector2(minimo, maximo)


# ============================================================
# RANGOS PARA EL RADAR
# ============================================================

func minmax_personas(anio: int) -> Vector2:

	return _minmax(
		func(clave: String) -> float:
			return poblacion_anio(clave, anio)
	)


func minmax_delitos(anio: int) -> Vector2:

	return _minmax(
		func(clave: String) -> float:
			return delitos_anio(clave, anio)
	)


func minmax_luminarias() -> Vector2:

	return _minmax(
		func(clave: String) -> float:
			return luminarias_zona_habitada(clave)
	)


func minmax_ingreso() -> Vector2:

	return _minmax(
		func(clave: String) -> float:
			return ingreso_promedio(clave)
	)


# ============================================================
# CARGAR CSV
# ============================================================

func _cargar() -> void:

	var archivo := FileAccess.open(
		RUTA_CSV,
		FileAccess.READ
	)

	if archivo == null:
		push_error(
			"No se pudo abrir " + RUTA_CSV
		)
		return


	var encabezado := archivo.get_csv_line()

	var claves: Array[String] = []


	for i in encabezado.size():

		var clave := normalizar(
			encabezado[i]
		)

		if i == 0 or clave == "total":

			claves.append("")

		else:

			claves.append(clave)

			_por_comuna[clave] = PackedStringArray()


	while not archivo.eof_reached():

		var fila := archivo.get_csv_line()

		if fila.size() < 2:
			continue


		etiquetas.append(
			fila[0].strip_edges()
		)


		for i in claves.size():

			if claves[i] == "":
				continue


			var valor := (
				fila[i].strip_edges()
				if i < fila.size()
				else ""
			)


			_por_comuna[
				claves[i]
			].append(valor)


	# ========================================================
	# CALCULAR RANGO ENTRE LAS COMUNAS
	# ========================================================

	iluminacion_min = INF
	iluminacion_max = -INF


	for comuna in _por_comuna.keys():

		var densidad := densidad_iluminacion(
			comuna
		)


		if densidad <= 0.0:
			continue


		iluminacion_min = min(
			iluminacion_min,
			densidad
		)


		iluminacion_max = max(
			iluminacion_max,
			densidad
		)


	# ========================================================
	# PROMEDIO Y TOPE (P90) DE LUMINARIAS
	# ========================================================

	if (
		iluminacion_min > 0.0 and
		iluminacion_max > iluminacion_min
	):

		var log_min := log(
			iluminacion_min
		)

		var log_max := log(
			iluminacion_max
		)


		var suma := 0.0

		var cuenta := 0

		var normalizados := []


		for comuna in _por_comuna.keys():

			var densidad := densidad_iluminacion(
				comuna
			)


			if densidad <= 0.0:
				continue


			suma += densidad

			cuenta += 1

			normalizados.append(
				clampf(
					inverse_lerp(
						log_min,
						log_max,
						log(densidad)
					),
					0.0,
					1.0
				)
			)


		if cuenta > 0:

			luminarias_promedio = clampf(
				inverse_lerp(
					log_min,
					log_max,
					log(
						suma /
						float(cuenta)
					)
				),
				0.0,
				1.0
			)


		if normalizados.size() > 0:

			normalizados.sort()

			var idx : int = clampi(
				int(
					round(
						0.9 *
						float(
							normalizados.size() - 1
						)
					)
				),
				0,
				normalizados.size() - 1
			)

			luminarias_ref = normalizados[idx]


	# ========================================================
	# CALCULAR RANGO DE LA RELACIÓN
	# DELITOS / DENSIDAD DE PERSONAS
	# ========================================================

	relacion_min = INF
	relacion_max = -INF


	for comuna in _por_comuna.keys():

		var relacion := relacion_delitos_personas(
			comuna
		)


		if relacion <= 0.0:
			continue


		relacion_min = min(
			relacion_min,
			relacion
		)


		relacion_max = max(
			relacion_max,
			relacion
		)


	# ========================================================
	# DEBUG
	# ========================================================

	print(
		"Iluminación mínima: ",
		iluminacion_min
	)

	print(
		"Iluminación máxima: ",
		iluminacion_max
	)

	print(
		"Relación mínima: ",
		relacion_min
	)

	print(
		"Relación máxima: ",
		relacion_max
	)


# ============================================================
# NIVEL DE ILUMINACIÓN
# ============================================================

func nivel_iluminacion(nombre: String) -> float:

	var densidad := densidad_iluminacion(
		nombre
	)


	# No existe información válida
	if densidad <= 0.0:
		return 0.0


	# Seguridad
	if (
		iluminacion_max <= iluminacion_min
	):
		return 0.5


	# ========================================================
	# COMPARACIÓN ENTRE TODAS LAS COMUNAS
	# ========================================================
	#
	# Mínimo observado = 0%
	# Máximo observado = 100%
	#
	# La distribución de luminarias es muy amplia, por lo que
	# se normaliza en escala LOGARÍTMICA para dar más contraste.
	# ========================================================

	var nivel := inverse_lerp(
		log(iluminacion_min),
		log(iluminacion_max),
		log(densidad)
	)


	return clamp(
		nivel,
		0.0,
		1.0
	)


# ============================================================
# DENSIDAD DE ILUMINACIÓN
# ============================================================

func densidad_iluminacion(
	nombre: String
) -> float:

	var valores := obtener(
		nombre
	)


	if valores.size() <= FILA_DENSIDAD:
		return 0.0


	# --------------------------------------------------------
	# USAMOS DIRECTAMENTE LA COLUMNA:
	#
	# "Cantidad de Luminara publicas x Superficie habitada"
	# --------------------------------------------------------

	var densidad := _convertir_numero(
		valores[FILA_DENSIDAD]
	)


	return densidad


# ============================================================
# DELITOS TOTALES
# ============================================================

func delitos_totales(
	nombre: String
) -> float:

	var valores := obtener(
		nombre
	)

	var total := 0.0


	for fila in FILAS_DELITOS:

		if fila >= valores.size():
			continue


		total += _convertir_numero(
			valores[fila]
		)


	return total


# ============================================================
# DENSIDAD DE PERSONAS
# ============================================================

func densidad_personas(
	nombre: String
) -> float:

	var valores := obtener(
		nombre
	)


	if valores.size() <= FILA_DENSIDAD_PERSONAS:
		return 0.0


	return _convertir_numero(
		valores[FILA_DENSIDAD_PERSONAS]
	)


# ============================================================
# RELACIÓN DELITOS / DENSIDAD DE PERSONAS
# ============================================================

func relacion_delitos_personas(
	nombre: String
) -> float:

	var densidad := densidad_personas(
		nombre
	)


	if densidad <= 0.0:
		return 0.0


	return (
		delitos_totales(nombre) /
		densidad
	)


# ============================================================
# NIVEL DE LA RELACIÓN (0.0 - 1.0)
# ============================================================

func nivel_relacion(
	nombre: String
) -> float:

	var relacion := relacion_delitos_personas(
		nombre
	)


	if relacion <= 0.0:
		return 0.0


	if relacion_max <= relacion_min:
		return 0.5


	return clamp(
		inverse_lerp(
			relacion_min,
			relacion_max,
			relacion
		),
		0.0,
		1.0
	)


# ============================================================
# PORCENTAJE DE SUPERFICIE HABITADA
# ============================================================

func proporcion_habitada(
	nombre: String
) -> float:

	var valores := obtener(
		nombre
	)


	if valores.size() <= FILA_SUPERFICIE_HABITADA:
		return 0.0


	var superficie_total := _convertir_numero(
		valores[11]
	)


	var superficie_habitada := _convertir_numero(
		valores[FILA_SUPERFICIE_HABITADA]
	)


	if superficie_total <= 0.0:
		return 0.0


	return clamp(
		superficie_habitada /
		superficie_total,
		0.0,
		1.0
	)


# ============================================================
# CONVERTIR NÚMERO
# ============================================================

func _convertir_numero(
	valor: String
) -> float:

	return valor \
		.trim_suffix("~") \
		.replace(",", ".") \
		.strip_edges() \
		.to_float()


# ============================================================
# NORMALIZAR
# ============================================================

static func normalizar(
	texto: String
) -> String:

	var t := texto.to_lower().strip_edges()


	for k in ACENTOS:

		t = t.replace(
			k,
			ACENTOS[k]
		)


	return t \
		.replace(" ", "") \
		.replace("_", "") \
		.replace("-", "")


# ============================================================
# OBTENER DATOS DE COMUNA
# ============================================================

func obtener(
	nombre: String
) -> PackedStringArray:

	return _por_comuna.get(
		normalizar(nombre),
		PackedStringArray()
	)


# ============================================================
# FORMATEAR VALOR
# ============================================================

func formatear(
	valor: String
) -> String:

	if valor.ends_with("~"):

		return (
			"≈ " +
			valor
				.trim_suffix("~")
				.strip_edges()
		)


	return valor


# ============================================================
# OBTENER NÚMERO
# ============================================================

func numero(
	nombre: String,
	fila: int
) -> float:

	var valores := obtener(
		nombre
	)


	if fila >= valores.size():
		return 0.0


	return _convertir_numero(
		valores[fila]
	)
