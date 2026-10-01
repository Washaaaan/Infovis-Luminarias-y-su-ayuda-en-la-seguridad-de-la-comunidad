shader_type canvas_item;


// ============================================================
// FONDO DEL MAPA
//
// Vignette radial navy: centro azul-grafito levemente mas claro
// y bordes casi negros. Da profundidad y contraste a las comunas
// calidas (crema -> rojo) del mapa.
//
// Se aplica a un ColorRect a pantalla completa en un CanvasLayer
// con layer = -10 (detras de todo e inmune a la camara).
// ============================================================

uniform vec4 color_centro : source_color = vec4(
	0.075,
	0.094,
	0.157,
	1.0
);

uniform vec4 color_borde : source_color = vec4(
	0.016,
	0.020,
	0.035,
	1.0
);

// Radio donde empieza la transicion (0 = centro, 1 = borde).
uniform float radio : hint_range(0.0, 1.5) = 0.65;

// Suavidad de la transicion.
uniform float suavidad : hint_range(0.01, 1.0) = 0.45;

// Desplazamiento del foco (para centrar un poco mas arriba).
uniform vec2 centro_offset = vec2(0.0, -0.04);


void fragment() {

	vec2 p = UV - (vec2(0.5, 0.5) + centro_offset);

	// Distancia radial: 0 en el centro, ~1 en el borde medio.
	float d = length(p) * 2.0;

	float t = smoothstep(
		radio - suavidad,
		radio + suavidad,
		d
	);

	vec3 col = mix(
		color_centro.rgb,
		color_borde.rgb,
		t
	);

	// Ruido minimo para evitar bandas en el degradado oscuro.
	float n = fract(
		sin(dot(UV, vec2(12.9898, 78.233))) * 43758.5453
	);

	col += (n - 0.5) * 0.006;

	COLOR = vec4(col, 1.0);
}
