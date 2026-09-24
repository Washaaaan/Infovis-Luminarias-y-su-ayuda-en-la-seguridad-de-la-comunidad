shader_type canvas_item;


// ============================================================
// PALETA
// ============================================================

uniform vec4 color_bajo : source_color = vec4(
	0.018,
	0.045,
	0.12,
	1.0
);

uniform vec4 color_azul : source_color = vec4(
	0.075,
	0.16,
	0.30,
	1.0
);

uniform vec4 color_azul_gris : source_color = vec4(
	0.27,
	0.34,
	0.39,
	1.0
);

uniform vec4 color_arena : source_color = vec4(
	0.58,
	0.52,
	0.40,
	1.0
);

uniform vec4 color_dorado : source_color = vec4(
	0.82,
	0.63,
	0.32,
	1.0
);

uniform vec4 color_amarillo : source_color = vec4(
	0.98,
	0.78,
	0.39,
	1.0
);


// ============================================================
// NIVEL DE ILUMINACIÓN
// ============================================================

uniform float nivel : hint_range(
	0.0,
	1.0,
	0.01
) = 0.5;


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
// GRADIENTE INTERNO
// ============================================================

uniform float intensidad_gradiente : hint_range(
	0.0,
	1.0,
	0.01
) = 0.68;


// ============================================================
// BRILLO GENERAL
// ============================================================

uniform float brillo_general : hint_range(
	0.0,
	1.0,
	0.01
) = 0.08;


// ============================================================
// LÍMITES DEL POLYGON
// ============================================================

uniform vec2 limite_min = vec2(
	0.0,
	0.0
);

uniform vec2 limite_max = vec2(
	1.0,
	1.0
);


// ============================================================
// ATMÓSFERA
// ============================================================

uniform float velocidad_atmosfera = 25.0;


// ============================================================
// NUBES
// ============================================================

uniform float intensidad_niebla = 0.58;


// ============================================================
// ONDAS DE BRILLO
// ============================================================

uniform float intensidad_brillo = 0.15;


// ============================================================
// CANTIDAD DE ONDAS
// ============================================================

uniform float cantidad_ondas = 8.0;


// ============================================================
// VELOCIDAD DE LAS ONDAS
// ============================================================

uniform float velocidad_ondas = 0.22;


// ============================================================
// ONDAS FINAS Y DIFUSAS
// ============================================================

uniform float grosor_ondas = 0.016;

uniform float suavidad_ondas = 0.035;


// ============================================================
// POSICIÓN LOCAL
// ============================================================

varying vec2 posicion_local;


// ============================================================
// VERTEX
// ============================================================

void vertex() {

	posicion_local = VERTEX;
}


// ============================================================
// OBTENER COLOR SEGÚN NIVEL
//
// 0.00 → 0.15 : azul profundo → azul
// 0.15 → 0.28 : azul → grisáceo
// 0.28 → 0.34 : grisáceo → arena
// 0.34 → 0.55 : arena → dorado
// 0.55 → 0.78 : dorado → amarillo
// 0.78 → 1.00 : amarillo → amarillo máximo
//
// ============================================================

vec3 obtener_color(
	float valor
) {

	valor = clamp(
		valor,
		0.0,
		1.0
	);


	// --------------------------------------------------------
	// AZUL PROFUNDO → AZUL
	// --------------------------------------------------------

	if (valor < 0.15) {

		float t = smoothstep(
			0.0,
			0.15,
			valor
		);

		return mix(
			color_bajo.rgb,
			color_azul.rgb,
			t
		);
	}


	// --------------------------------------------------------
	// AZUL → GRISÁCEO
	// --------------------------------------------------------

	if (valor < 0.28) {

		float t = smoothstep(
			0.15,
			0.28,
			valor
		);

		return mix(
			color_azul.rgb,
			color_azul_gris.rgb,
			t
		);
	}


	// --------------------------------------------------------
	// GRISÁCEO → ARENA
	//
	// El promedio (~0.34) llega al color arena.
	// --------------------------------------------------------

	if (valor < 0.34) {

		float t = smoothstep(
			0.28,
			0.34,
			valor
		);

		return mix(
			color_azul_gris.rgb,
			color_arena.rgb,
			t
		);
	}


	// --------------------------------------------------------
	// ARENA → DORADO
	// --------------------------------------------------------

	if (valor < 0.55) {

		float t = smoothstep(
			0.34,
			0.55,
			valor
		);

		return mix(
			color_arena.rgb,
			color_dorado.rgb,
			t
		);
	}


	// --------------------------------------------------------
	// DORADO → AMARILLO
	// --------------------------------------------------------

	if (valor < 0.78) {

		float t = smoothstep(
			0.55,
			0.78,
			valor
		);

		return mix(
			color_dorado.rgb,
			color_amarillo.rgb,
			t
		);
	}


	// --------------------------------------------------------
	// AMARILLO → AMARILLO MÁXIMO
	// --------------------------------------------------------

	float t = smoothstep(
		0.78,
		1.0,
		valor
	);

	return mix(
		color_amarillo.rgb,
		vec3(
			1.0,
			0.88,
			0.38
		),
		t
	);
}


// ============================================================
// POSICIÓN CORREGIDA PARA EFECTOS
// ============================================================

vec2 obtener_posicion_efecto(
	vec2 posicion
) {

	float ancho =
		abs(
			limite_max.x -
			limite_min.x
		);

	float alto =
		abs(
			limite_max.y -
			limite_min.y
		);


	ancho =
		max(
			ancho,
			0.0001
		);

	alto =
		max(
			alto,
			0.0001
		);


	// --------------------------------------------------------
	// CENTRAR
	// --------------------------------------------------------

	vec2 centrado =
		posicion -
		vec2(
			0.5,
			0.5
		);


	// --------------------------------------------------------
	// CORRECCIÓN DE ASPECT RATIO
	// --------------------------------------------------------

	if (ancho > alto) {

		centrado.x *=
			ancho / alto;

	}
	else {

		centrado.y *=
			alto / ancho;
	}


	// --------------------------------------------------------
	// NORMALIZACIÓN SEGÚN EL TAMAÑO
	// --------------------------------------------------------

	float dimension_menor =
		min(
			ancho,
			alto
		);


	dimension_menor =
		max(
			dimension_menor,
			0.0001
		);


	float factor_tamano =
		clamp(
			sqrt(dimension_menor),
			0.45,
			1.0
		);


	centrado /=
		factor_tamano;


	return centrado +
		vec2(
			0.5,
			0.5
		);
}


// ============================================================
// HASH
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
		)
		*
		43758.5453123
	);
}


// ============================================================
// RUIDO
// ============================================================

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
		mix(
			a,
			b,
			f.x
		),
		mix(
			c,
			d,
			f.x
		),
		f.y
	);
}


// ============================================================
// RUIDO FRACTAL
// ============================================================

float ruido_fractal(
	vec2 p
) {

	float resultado = 0.0;

	float amplitud = 0.5;


	resultado +=
		ruido(p) *
		amplitud;


	p *= 2.0;
	amplitud *= 0.5;


	resultado +=
		ruido(p) *
		amplitud;


	p *= 2.0;
	amplitud *= 0.5;


	resultado +=
		ruido(p) *
		amplitud;


	p *= 2.0;
	amplitud *= 0.5;


	resultado +=
		ruido(p) *
		amplitud;


	return resultado;
}


// ============================================================
// CREAR NUBE ORGÁNICA
// ============================================================

float crear_nube(
	vec2 pos,
	float posicion_x,
	float posicion_y,
	float escala_x,
	float escala_y,
	float fase
) {

	vec2 distancia =
		pos -
		vec2(
			posicion_x,
			posicion_y
		);


	distancia.x /= escala_x;

	distancia.y /= escala_y;


	float ruido_nube =
		ruido_fractal(
			pos * 7.0 +
			vec2(
				fase,
				-fase * 0.7
			)
		);


	float forma =
		1.0 -
		smoothstep(
			0.35,
			1.0,
			length(distancia)
		);


	float bulto_1 =
		1.0 -
		smoothstep(
			0.18,
			0.48,
			length(
				(
					pos -
					vec2(
						posicion_x -
						escala_x * 0.35,
						posicion_y +
						escala_y * 0.08
					)
				)
				/
				vec2(
					escala_x * 0.65,
					escala_y * 0.75
				)
			)
		);


	float bulto_2 =
		1.0 -
		smoothstep(
			0.18,
			0.52,
			length(
				(
					pos -
					vec2(
						posicion_x +
						escala_x * 0.10,
						posicion_y -
						escala_y * 0.12
					)
				)
				/
				vec2(
					escala_x * 0.70,
					escala_y * 0.85
				)
			)
		);


	float bulto_3 =
		1.0 -
		smoothstep(
			0.20,
			0.55,
			length(
				(
					pos -
					vec2(
						posicion_x +
						escala_x * 0.42,
						posicion_y +
						escala_y * 0.06
					)
				)
				/
				vec2(
					escala_x * 0.60,
					escala_y * 0.70
				)
			)
		);


	float bultos =
		bulto_1 * 0.75 +
		bulto_2 * 0.90 +
		bulto_3 * 0.65;


	float nube =
		max(
			forma * 0.65,
			bultos
		);


	nube *=
		0.72 +
		ruido_nube * 0.28;


	return clamp(
		nube,
		0.0,
		1.0
	);
}


// ============================================================
// CALCULAR NUBES / NIEBLA
// ============================================================

float calcular_nubes(
	vec2 posicion
) {

	vec2 posicion_efecto =
		obtener_posicion_efecto(
			posicion
		);


	vec2 pixel_uv =
		floor(
			posicion_efecto * 256.0
		)
		/
		256.0;


	float tiempo =
		TIME *
		velocidad_atmosfera;


	vec2 centro =
		vec2(
			0.5,
			0.5
		);


	// --------------------------------------------------------
	// PRIMERA CAPA
	// --------------------------------------------------------

	vec2 movimiento_1 =
		pixel_uv * 2.6;


	movimiento_1 +=
		vec2(
			tiempo * 0.035,
			tiempo * 0.008
		);


	// --------------------------------------------------------
	// SEGUNDA CAPA
	// --------------------------------------------------------

	vec2 movimiento_2 =
		pixel_uv * 3.8;


	movimiento_2 +=
		vec2(
			-tiempo * 0.022,
			-tiempo * 0.006
		);


	// --------------------------------------------------------
	// TERCERA CAPA
	// --------------------------------------------------------

	vec2 movimiento_3 =
		pixel_uv * 5.4;


	movimiento_3 +=
		vec2(
			tiempo * 0.012,
			-tiempo * 0.016
		);


	// --------------------------------------------------------
	// RUIDO
	// --------------------------------------------------------

	float ruido_1 =
		ruido_fractal(
			movimiento_1
		);


	float ruido_2 =
		ruido_fractal(
			movimiento_2
		);


	float ruido_3 =
		ruido_fractal(
			movimiento_3
		);


	// --------------------------------------------------------
	// COMBINACIÓN
	// --------------------------------------------------------

	float ruido_combinado =
		ruido_1 * 0.42 +
		ruido_2 * 0.38 +
		ruido_3 * 0.20;


	// --------------------------------------------------------
	// DISTANCIA AL CENTRO
	// --------------------------------------------------------

	float dist =
		distance(
			pixel_uv,
			centro
		);


	float max_dist =
		distance(
			centro,
			vec2(
				1.0,
				1.0
			)
		);


	dist =
		clamp(
			dist / max_dist,
			0.0,
			1.0
		);


	// --------------------------------------------------------
	// DEFORMACIÓN
	// --------------------------------------------------------

	float niebla =
		mix(
			1.0 -
			ruido_combinado,
			dist,
			0.25
		);


	// --------------------------------------------------------
	// FORMAR MASAS
	// --------------------------------------------------------

	niebla =
		smoothstep(
			0.28,
			0.68,
			niebla
		);


	// --------------------------------------------------------
	// DETALLE
	// --------------------------------------------------------

	float detalle =
		ruido_fractal(
			pixel_uv * 7.0 +
			vec2(
				tiempo * 0.025,
				-tiempo * 0.018
			)
		);


	niebla *=
		0.68 +
		detalle * 0.32;


	// --------------------------------------------------------
	// DENSIDAD CENTRAL
	// --------------------------------------------------------

	float densidad_centro =
		1.0 -
		smoothstep(
			0.08,
			0.80,
			dist
		);


	niebla *=
		0.68 +
		densidad_centro * 0.32;


	// --------------------------------------------------------
	// EXTREMOS
	// --------------------------------------------------------

	float extremos =
		smoothstep(
			0.80,
			1.0,
			dist
		);


	niebla *=
		1.0 -
		extremos * 0.30;


	return clamp(
		niebla,
		0.0,
		1.0
	);
}


// ============================================================
// CALCULAR ONDAS
// ============================================================

float calcular_ondas(
	vec2 posicion
) {

	vec2 posicion_efecto =
		obtener_posicion_efecto(
			posicion
		);


	vec2 centro =
		vec2(
			0.5,
			0.5
		);


	float distancia =
		distance(
			posicion_efecto,
			centro
		);


	float tiempo =
		TIME *
		velocidad_ondas;


	float ondas =
		0.0;


	for (int i = 0; i < 8; i++) {

		float indice =
			float(i);


		float fase =
			indice /
			cantidad_ondas;


		float radio =
			fract(
				tiempo * 0.18 +
				fase
			);


		float radio_actual =
			radio * 0.85;


		float diferencia =
			abs(
				distancia -
				radio_actual
			);


		// ----------------------------------------------------
		// NÚCLEO FINO
		// ----------------------------------------------------

		float nucleo =
			1.0 -
			smoothstep(
				0.0,
				grosor_ondas,
				diferencia
			);


		// ----------------------------------------------------
		// HALO DIFUSO
		// ----------------------------------------------------

		float halo =
			exp(
				-
				pow(
					diferencia /
					suavidad_ondas,
					2.0
				)
				*
				2.8
			);


		// ----------------------------------------------------
		// COMBINAR NÚCLEO + HALO
		// ----------------------------------------------------

		float onda =
			nucleo * 0.38 +
			halo * 0.62;


		// ----------------------------------------------------
		// ATENUACIÓN
		// ----------------------------------------------------

		float atenuacion =
			1.0 -
			smoothstep(
				0.15,
				0.90,
				radio_actual
			);


		onda *=
			atenuacion;


		ondas +=
			onda;
	}


	return clamp(
		ondas /
		cantidad_ondas,
		0.0,
		1.0
	);
}


// ============================================================
// FRAGMENT
// ============================================================

void fragment() {

	// ========================================================
	// COLOR BASE
	// ========================================================

	vec3 color_base =
		obtener_color(
			nivel
		);


	// ========================================================
	// POSICIÓN X NORMALIZADA
	// ========================================================

	float ancho =
		limite_max.x -
		limite_min.x;


	float x = 0.5;


	if (abs(ancho) > 0.0001) {

		x =
			(
				posicion_local.x -
				limite_min.x
			)
			/
			ancho;
	}


	x =
		clamp(
			x,
			0.0,
			1.0
		);


	// ========================================================
	// POSICIÓN Y NORMALIZADA
	// ========================================================

	float alto =
		limite_max.y -
		limite_min.y;


	float y = 0.5;


	if (abs(alto) > 0.0001) {

		y =
			(
				posicion_local.y -
				limite_min.y
			)
			/
			alto;
	}


	y =
		clamp(
			y,
			0.0,
			1.0
		);


	vec2 posicion =
		vec2(
			x,
			y
		);


	// ========================================================
	// GRADIENTE VERTICAL
	// ========================================================

	float gradiente_vertical =
		1.0 - y;


	gradiente_vertical =
		smoothstep(
			0.0,
			1.0,
			gradiente_vertical
		);


	// ========================================================
	// GRADIENTE HORIZONTAL
	// ========================================================

	float gradiente_horizontal =
		1.0 - x;


	gradiente_horizontal =
		smoothstep(
			0.0,
			1.0,
			gradiente_horizontal
		);


	// ========================================================
	// COMBINAR GRADIENTES
	// ========================================================

	float gradiente =
		gradiente_vertical * 0.70 +
		gradiente_horizontal * 0.30;


	gradiente =
		clamp(
			gradiente,
			0.0,
			1.0
		);


	// ========================================================
	// COLOR OSCURO
	// ========================================================

	vec3 color_oscuro =
		color_base * 0.72;


	// ========================================================
	// COLOR CLARO
	// ========================================================

	vec3 color_claro =
		mix(
			color_base,
			vec3(1.0),
			0.15
		);


	// ========================================================
	// GRADIENTE INTERNO
	// ========================================================

	vec3 color_final =
		mix(
			color_oscuro,
			color_claro,
			gradiente *
			intensidad_gradiente
		);


	// ========================================================
	// BRILLO GENERAL
	// ========================================================

	color_final =
		mix(
			color_final,
			color_final +
			vec3(0.06),
			brillo_general
		);


	// ========================================================
	// NUBES PROCEDURALES
	// ========================================================

	float nubes =
		calcular_nubes(
			posicion
		);


	// ========================================================
	// FUERZA DE NUBES SEGÚN NIVEL
	// ========================================================

	float fuerza_nubes =
		1.0 -
		smoothstep(
			0.32,
			0.62,
			nivel
		);


	nubes *=
		fuerza_nubes;


	// ========================================================
	// OSCURIDAD DE LA NIEBLA SEGÚN COLOR
	// ========================================================

	float suavidad_color_niebla =
		smoothstep(
			0.15,
			0.55,
			nivel
		);


	float intensidad_oscuridad_niebla =
		mix(
			1.0,
			0.32,
			suavidad_color_niebla
		);


	// ========================================================
	// COLOR DE LA NIEBLA
	// ========================================================

	vec3 color_niebla_profundo =
		color_base * 0.68;


	vec3 color_niebla_suave =
		mix(
			color_base,
			color_final,
			0.35
		);


	vec3 color_niebla =
		mix(
			color_niebla_profundo,
			color_niebla_suave,
			suavidad_color_niebla
		);


	// ========================================================
	// INTENSIDAD FINAL DE NIEBLA
	// ========================================================

	float cantidad_nube =
		nubes *
		intensidad_niebla *
		intensidad_oscuridad_niebla;


	// ========================================================
	// APLICAR NIEBLA
	// ========================================================

	color_final =
		mix(
			color_final,
			color_niebla,
			clamp(
				cantidad_nube,
				0.0,
				1.0
			)
		);


	// ========================================================
	// ONDAS
	// ========================================================

	float ondas =
		calcular_ondas(
			posicion
		);


	// ========================================================
	// INTENSIDAD DE ONDAS SEGÚN COLOR
	// ========================================================

	float ondas_gris =
		smoothstep(
			0.48,
			0.68,
			nivel
		) *
		0.40;


	float ondas_dorado =
		smoothstep(
			0.62,
			0.88,
			nivel
		) *
		mix(
			1.0,
			0.8,
			smoothstep(
				0.82,
				1.0,
				nivel
			)
		);


	float fuerza_ondas =
		max(
			ondas_gris,
			ondas_dorado
		);


	ondas *=
		fuerza_ondas;


	// ========================================================
	// COLOR DE LAS ONDAS
	// ========================================================

	vec3 color_onda =
		mix(
			color_base,
			vec3(1.0),
			0.24
		);


	// ========================================================
	// APLICAR ONDAS
	// ========================================================

	color_final +=
		color_onda *
		ondas *
		intensidad_brillo;


	// ========================================================
	// HOVER
	// ========================================================

	float brillo_hover =
		hover *
		0.22;


	color_final =
		mix(
			color_final,
			color_hover.rgb,
			brillo_hover
		);


	// ========================================================
	// RESULTADO
	// ========================================================

	COLOR =
		vec4(
			color_final,
			1.0
		);
}