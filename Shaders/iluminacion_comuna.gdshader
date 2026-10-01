shader_type canvas_item;


// ============================================================
// PALETA
//
// crema (valor bajo) -> rojo vivo (valor alto)
// ============================================================

uniform vec4 color_crema : source_color = vec4(
	0.96,
	0.93,
	0.82,
	1.0
);

uniform vec4 color_rojo : source_color = vec4(
	0.86,
	0.06,
	0.05,
	1.0
);


// ============================================================
// NIVEL (color)
//
// Modo 0: relación delitos / densidad de personas.
// Modo 1: delitos por zona habitada.
// ============================================================

uniform float nivel : hint_range(
	0.0,
	1.0,
	0.01
) = 0.5;


// ============================================================
// INGRESO (MODO 2, BIVARIADO)
// ============================================================

uniform float ingreso : hint_range(
	0.0,
	1.0,
	0.01
) = 0.0;


// ============================================================
// MODO
//
// 0 = densidad de personas ↔ delitos
// 1 = densidad de luminarias ↔ delitos
// ============================================================

uniform int modo = 0;


// ============================================================
// ONDAS (SOLO MODO 1)
//
// Se generan desde el centro del polígono. Su visibilidad
// depende de la densidad de luminarias (luminarias).
// ============================================================

uniform float luminarias : hint_range(
	0.0,
	1.0,
	0.01
) = 0.0;

uniform float luminarias_promedio : hint_range(
	0.0,
	1.0,
	0.01
) = 0.786;

uniform float luminarias_ref : hint_range(
	0.0,
	1.0,
	0.01
) = 0.94;

uniform vec2 centro = vec2(
	0.0,
	0.0
);

uniform float radio = 1.0;

uniform float velocidad_ondas = 0.4;

uniform float intensidad_ondas : hint_range(
	0.0,
	1.0,
	0.01
) = 0.18;

// Máximo oscurecimiento de la niebla (nunca negro).

uniform float oscuridad_max : hint_range(
	0.0,
	1.0,
	0.01
) = 0.55;

// Niebla de ruido (bajo el promedio).

uniform float escala_ruido = 0.06;

uniform float viento = 0.06;

uniform vec4 color_onda : source_color = vec4(
	1.0,
	0.9,
	0.6,
	1.0
);


const int ANILLOS = 3;


// ============================================================
// POSICIÓN LOCAL
// ============================================================

varying vec2 pos_local;


void vertex() {

	pos_local = VERTEX;
}


// ============================================================
// HOVER
// ============================================================

uniform float hover : hint_range(
	0.0,
	1.0,
	0.01
) = 0.0;

uniform vec4 color_hover : source_color = vec4(
	1.0,
	0.91,
	0.68,
	1.0
);


// ============================================================
// RUIDO
// ============================================================

float hash(
	vec2 p
) {

	return fract(
		sin(
			dot(
				p,
				vec2(
					127.1,
					311.7
				)
			)
		) *
		43758.5453123
	);
}


float ruido(
	vec2 p
) {

	vec2 i = floor(p);

	vec2 f = fract(p);

	f = f * f * (
		3.0 -
		2.0 * f
	);


	float a = hash(i);

	float b = hash(
		i +
		vec2(
			1.0,
			0.0
		)
	);

	float c = hash(
		i +
		vec2(
			0.0,
			1.0
		)
	);

	float d = hash(
		i +
		vec2(
			1.0,
			1.0
		)
	);


	return mix(
		mix(a, b, f.x),
		mix(c, d, f.x),
		f.y
	);
}


float ruido_fractal(
	vec2 p
) {

	float resultado = 0.0;

	float amplitud = 0.5;


	resultado += ruido(p) * amplitud;

	p *= 2.0;
	amplitud *= 0.5;

	resultado += ruido(p) * amplitud;

	p *= 2.0;
	amplitud *= 0.5;

	resultado += ruido(p) * amplitud;


	return resultado;
}


// ============================================================
// COLOR BIVARIADO (DELITOS x INGRESO) — MODO 2
//
// X = delitos (0..1), Y = ingreso (0..1). Paleta 3x3.
// ============================================================

vec3 bivariado(
	float delitos,
	float ing
) {

	int bx = delitos < 0.333 ? 0 : (
		delitos < 0.666 ? 1 : 2
	);

	int by = ing < 0.333 ? 0 : (
		ing < 0.666 ? 1 : 2
	);


	vec3 c;


	if (by == 0) {

		if (bx == 0) {
			c = vec3(0.90, 0.90, 0.90);
		} else if (bx == 1) {
			c = vec3(0.95, 0.75, 0.60);
		} else {
			c = vec3(0.92, 0.50, 0.30);
		}

	} else if (by == 1) {

		if (bx == 0) {
			c = vec3(0.75, 0.82, 0.90);
		} else if (bx == 1) {
			c = vec3(0.80, 0.68, 0.70);
		} else {
			c = vec3(0.85, 0.45, 0.40);
		}

	} else {

		if (bx == 0) {
			c = vec3(0.35, 0.55, 0.85);
		} else if (bx == 1) {
			c = vec3(0.45, 0.50, 0.70);
		} else {
			c = vec3(0.55, 0.35, 0.45);
		}
	}


	return c;
}


// ============================================================
// FRAGMENT
// ============================================================

void fragment() {

	// --------------------------------------------------------
	// COLOR BASE (CREMA -> ROJO)
	// --------------------------------------------------------

	float t = clamp(
		nivel,
		0.0,
		1.0
	);


	vec3 color_final = mix(
		color_crema.rgb,
		color_rojo.rgb,
		t
	);


	// --------------------------------------------------------
	// MODO 2: BIVARIADO (DELITOS x INGRESO)
	// --------------------------------------------------------

	if (modo == 2) {

		color_final = bivariado(
			clamp(nivel, 0.0, 1.0),
			clamp(ingreso, 0.0, 1.0)
		);


	// --------------------------------------------------------
	// MODO 1: NIEBLA (BAJO PROMEDIO) O ANILLOS (SOBRE)
	// --------------------------------------------------------

	} else if (modo == 1) {

		if (luminarias < luminarias_promedio) {

			// ------------------------------------------------
			// NIEBLA DE RUIDO (sin anillos)
			//
			// Manchas oscuras del mismo tono, proporcional a
			// cuán baja es la densidad. Nunca negro.
			// ------------------------------------------------

			float d = clamp(
				(
					luminarias_promedio -
					luminarias
				) / max(
					luminarias_promedio,
					0.0001
				),
				0.0,
				1.0
			);


			float n = ruido_fractal(
				pos_local *
				escala_ruido +
				vec2(
					TIME *
					viento,
					TIME *
					viento *
					0.6
				)
			);


			float niebla = smoothstep(
				0.35,
				0.9,
				n
			) * d * oscuridad_max;


			color_final = mix(
				color_final,
				color_final * 0.45,
				niebla
			);

		} else {

			// ------------------------------------------------
			// ANILLOS CIRCULARES
			// ------------------------------------------------

			float dist = length(
				pos_local -
				centro
			) / max(
				radio,
				0.0001
			);


			// Desde el promedio (0) hasta el p90 (máximo).
			float tv = clamp(
				(
					luminarias -
					luminarias_promedio
				) / max(
					luminarias_ref -
					luminarias_promedio,
					0.0001
				),
				0.0,
				1.0
			);


			float fuerza = smoothstep(
				0.0,
				1.0,
				tv
			);


			// Velocidad progresiva: máximo = actual, menores = más lentos.
			float velocidad = velocidad_ondas * mix(
				0.35,
				1.0,
				fuerza
			);


			float fase = (
				dist *
				float(ANILLOS) *
				TAU -
				TIME *
				velocidad *
				TAU
			);


			float onda = pow(
				0.5 +
				0.5 *
				sin(fase),
				3.0
			);


			// Atenuar hacia el borde del polígono.
			onda *= 1.0 - smoothstep(
				0.7,
				1.0,
				dist
			);


			// Intensidad más exigente: cae más rápido bajo el máximo.
			float fuerza_int = pow(
				fuerza,
				2.0
			);


			color_final +=
				color_onda.rgb *
				onda *
				intensidad_ondas *
				fuerza_int;
		}
	}


	// --------------------------------------------------------
	// HOVER
	// --------------------------------------------------------

	float brillo_hover =
		hover *
		0.22;


	color_final = mix(
		color_final,
		color_hover.rgb,
		brillo_hover
	);


	// --------------------------------------------------------
	// RESULTADO
	// --------------------------------------------------------

	COLOR = vec4(
		color_final,
		1.0
	);
}
