extends Node

const RUTA_CSV := "res://datos/resumen_consolidado.txt"
const ACENTOS := {"á": "a", "é": "e", "í": "i", "ó": "o", "ú": "u", "ü": "u", "ñ": "n"}

var etiquetas: PackedStringArray = []
var _por_comuna: Dictionary = {}


func _ready() -> void:
	_cargar()


func _cargar() -> void:
	var archivo := FileAccess.open(RUTA_CSV, FileAccess.READ)
	if archivo == null:
		push_error("No se pudo abrir " + RUTA_CSV)
		return

	var encabezado := archivo.get_csv_line()
	var claves: Array[String] = []
	for i in encabezado.size():
		var clave := normalizar(encabezado[i])
		if i == 0 or clave == "total":
			claves.append("")
		else:
			claves.append(clave)
			_por_comuna[clave] = PackedStringArray()

	while not archivo.eof_reached():
		var fila := archivo.get_csv_line()
		if fila.size() < 2:
			continue
		etiquetas.append(fila[0].strip_edges())
		for i in claves.size():
			if claves[i] == "":
				continue
			var valor := fila[i].strip_edges() if i < fila.size() else ""
			_por_comuna[claves[i]].append(valor)


static func normalizar(texto: String) -> String:
	var t := texto.to_lower().strip_edges()
	for k in ACENTOS:
		t = t.replace(k, ACENTOS[k])
	return t.replace(" ", "").replace("_", "").replace("-", "")


func obtener(nombre: String) -> PackedStringArray:
	return _por_comuna.get(normalizar(nombre), PackedStringArray())


func formatear(valor: String) -> String:
	if valor.ends_with("~"):
		return "≈ " + valor.trim_suffix("~").strip_edges()
	return valor


func numero(nombre: String, fila: int) -> float:
	var valores := obtener(nombre)
	if fila >= valores.size():
		return 0.0
	return valores[fila].trim_suffix("~").replace(",", ".").to_float()
