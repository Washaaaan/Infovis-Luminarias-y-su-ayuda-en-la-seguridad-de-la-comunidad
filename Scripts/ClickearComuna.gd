extends Area2D


# ============================================================
# COLORES
# ============================================================

@export var color_base: Color = Color("#F2D3B1")

@export var color_hover: Color = Color("#F5B97A")

@export var color_borde: Color = Color("#E67E22")


# ============================================================
# CONFIGURACIÓN DEL BORDE
# ============================================================

@export var ancho_borde: float = 1.0


# ============================================================
# REFERENCIA AL POLYGON
# ============================================================

@onready var polygon: Polygon2D = $Polygon2D


# ============================================================
# READY
# ============================================================

func _ready() -> void:

	# --------------------------------------------------------
	# POLYGON VISIBLE DESDE EL INICIO
	# --------------------------------------------------------

	polygon.visible = true


	# --------------------------------------------------------
	# COLOR BASE
	# --------------------------------------------------------

	polygon.color = color_base


	# --------------------------------------------------------
	# CREAR BORDE
	# --------------------------------------------------------

	var borde := Line2D.new()

	borde.name = "Borde"


	# Utilizamos exactamente los puntos
	# del Polygon2D.

	borde.points = polygon.polygon


	# Cerramos el borde.

	borde.closed = true


	# Grosor inicial.

	borde.width = ancho_borde


	# Color naranja.

	borde.default_color = color_borde


	# El borde queda por encima del Polygon.

	borde.z_index = 1


	# Agregamos el borde como hijo del Area2D.

	add_child(borde)


	# --------------------------------------------------------
	# CONECTAR HOVER
	# --------------------------------------------------------

	mouse_entered.connect(
		_on_mouse_entered
	)

	mouse_exited.connect(
		_on_mouse_exited
	)


# ============================================================
# MOUSE ENTERED
# ============================================================

func _on_mouse_entered() -> void:

	var tween := create_tween()


	tween.tween_property(
		polygon,
		"color",
		color_hover,
		0.15
	).set_trans(
		Tween.TRANS_QUAD
	).set_ease(
		Tween.EASE_OUT
	)


# ============================================================
# MOUSE EXITED
# ============================================================

func _on_mouse_exited() -> void:

	var tween := create_tween()


	tween.tween_property(
		polygon,
		"color",
		color_base,
		0.15
	).set_trans(
		Tween.TRANS_QUAD
	).set_ease(
		Tween.EASE_OUT
	)
