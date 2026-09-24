extends Node

const RUTA_CSV := "res://datos/resumen_consolidado.txt"

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


# ============================================================
# DATOS
# ============================================================

var etiquetas: PackedStringArray = []
var _por_comuna: Dictionary = {}


# ============================================================
# RANGO DE ILUMINACIÓN
# ============================================================

var iluminacion_min: float = INF
var iluminacion_max: float = -INF


# ============================================================
# READY
# ============================================================

func _ready() -> void:
	_cargar()


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
	# Todo lo demás queda proporcionalmente entre ambos.
	# ========================================================

	var nivel := inverse_lerp(
		iluminacion_min,
		iluminacion_max,
		densidad
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
