# AGENTS.md --- Proyecto Mapa Interactivo de Seguridad Comunal (Godot)

## 1. Propósito de este archivo

Este archivo es el contexto persistente para agentes de IA que trabajen
sobre este proyecto mediante OpenCode u otra herramienta de edición
asistida.

**Regla principal:** antes de modificar código, inspeccionar el proyecto
real y conservar el comportamiento que ya funciona. No asumir que una
solución teórica coincide con la estructura actual del proyecto.

El objetivo es evitar regresiones y permitir que distintas
sesiones/agentes continúen el trabajo sin perder decisiones,
restricciones ni contexto.

------------------------------------------------------------------------

# 2. Objetivo general del proyecto

Se está desarrollando una **visualización interactiva de la Región
Metropolitana de Chile**, implementada en **Godot 4.7.2**, donde cada
comuna funciona como una unidad interactiva del mapa.

La visualización debe permitir interpretar simultáneamente tres
dimensiones:

1.  **Cantidad/densidad de delitos**
    -   Se representa principalmente mediante el **color interior de la
        comuna**.
    -   Menos delitos → tonos claros/cálidos.
    -   Más delitos → tonos progresivamente más rojos.
    -   La lectura debe ser inmediata: **más rojo = más delitos**.
2.  **Luminosidad / presencia de luminarias públicas**
    -   Se representa mediante el **borde de la comuna**.
    -   Más luminarias → borde más brillante, intenso y visualmente
        extendido/grueso.
    -   Menos luminarias → borde más tenue y reducido.
    -   La intensidad debe variar realmente entre comunas; no se debe
        utilizar un borde uniforme para todas.
3.  **Cantidad total de personas**
    -   Se representa mediante un **efecto visual de flujo animado
        dentro de la comuna**.
    -   Más personas → mayor intensidad/cantidad de flujo.
    -   Menos personas → flujo más escaso/sutil.
    -   La animación debe ser perceptible a simple vista.
    -   Debe parecer un flujo/corriente que atraviesa el territorio, no
        simplemente un cambio de color estático.

La visualización debe priorizar la **legibilidad**. No se busca un
efecto decorativo que oculte los datos.

------------------------------------------------------------------------

# 3. Tecnología y versión

-   Motor: **Godot 4.7.2**
-   Lenguaje principal: **GDScript**
-   Shaders: **Godot CanvasItem shaders**
-   Mapa: nodos 2D.
-   Cada comuna es un nodo padre con una estructura similar a:
    -   `Area2D`
    -   `Polygon2D`
    -   `CollisionPolygon2D`/colisión correspondiente
    -   `Borde` (`Line2D`)
    -   pueden existir otros nodos auxiliares.

La cámara es un `Camera2D`.

------------------------------------------------------------------------

# 4. Estructura conceptual del mapa

La estructura esperada es aproximadamente:

``` text
Mapa
├── Comuna_1
│   └── Area2D
│       ├── Polygon2D
│       ├── Borde
│       └── ...
├── Comuna_2
│   └── Area2D
│       ├── Polygon2D
│       ├── Borde
│       └── ...
└── ...
```

La cámara es hermana de `Mapa`, por lo que se obtiene mediante:

``` gdscript
get_node("../Mapa")
```

**No cambiar esta relación sin comprobar primero la escena real.**

------------------------------------------------------------------------

# 5. Datos disponibles

Existe un autoload/script global para cargar los datos desde:

``` text
res://datos/resumen_consolidado.txt
```

La normalización de nombres elimina diferencias de mayúsculas, espacios,
guiones, guiones bajos y acentos.

Conceptualmente, la API existente es:

``` gdscript
DatosComunas.obtener(nombre)
DatosComunas.numero(nombre, fila)
DatosComunas.formatear(valor)
DatosComunas.normalizar(texto)
```

El script mantiene un diccionario por comuna y permite recuperar los
valores por índice.

## Índices importantes del dataset

**No cambiar estos índices sin verificar el archivo de datos real.**

``` text
0  = Delitos contra la vida o integridad
1  = Amenazas
2  = Robos violentos
3  = Robos con violencia o intimidación
4  = segunda columna duplicada/mal rotulada de Robos con violencia o intimidación
5  = Robo violento de vehículo motorizado
6  = Robo por sorpresa
7  = Delitos asociados a drogas
8  = Tráfico de sustancias
9  = Microtráfico de sustancias
10 = Luminarias públicas
11 = Superficie en Km²
12 = Superficie habitada en Km²
13 = Cantidad de luminarias públicas x superficie habitada
14 = Total personas
15 = Luminarias públicas / total personas
16 = Delitos / total personas
17 = Total personas / superficie habitada
18 = Ingreso promedio del hogar
```

### Variables que interesan especialmente para el mapa

``` text
Delitos:
0 + 1 + 2 + 7
```

Esto se hace para evitar sumar categorías jerárquicas/duplicadas y
generar doble conteo.

``` text
Luminarias:
10
```

``` text
Superficie habitada:
12
```

``` text
Personas:
14
```

**Importante:** para la visualización solicitada se debe mostrar
**cantidad total de personas**, no densidad de población.

------------------------------------------------------------------------

# 6. Variables y significado visual

## 6.1 Delitos

El usuario quiere una lectura muy sencilla:

``` text
menos delitos ────────────────> más delitos
claro/cálido                    rojo intenso
```

Se puede utilizar normalización lineal o logarítmica dependiendo de la
distribución real de los datos.

La distribución histórica observada es muy amplia, por lo que una
normalización logarítmica ha sido útil para evitar que unas pocas
comunas dominen completamente el rango visual.

Rango observado anteriormente para densidad de delitos:

``` text
mínimo ≈ 13.44
máximo ≈ 1088.98
```

Esto debe volver a verificarse desde los datos reales antes de
hardcodear nuevos valores.

### Paleta histórica utilizada

``` gdscript
COLOR_DELITOS_BAJO  = vec3(0.78, 0.69, 0.55)
COLOR_DELITOS_MEDIO = vec3(0.91, 0.39, 0.12)
COLOR_DELITOS_ALTO  = vec3(0.68, 0.055, 0.035)
```

La intención es conservar la transición:

``` text
beige/marrón claro → naranja → rojo oscuro
```

------------------------------------------------------------------------

# 7. Luminarias y borde

La luminaria debe comunicarse **mediante el borde real de la comuna**,
no mediante un rectángulo o borde aproximado del bounding box.

La representación deseada es:

``` text
pocas luminarias:
    borde fino
    brillo bajo
    halo pequeño

muchas luminarias:
    borde grueso
    brillo alto
    halo más amplio
```

La idea de "luminosidad" es visual, no significa que se esté calculando
físicamente la iluminación nocturna.

## Datos

La variable base es:

``` text
índice 10 = Luminarias públicas
```

También existe:

``` text
índice 13 = Cantidad de luminarias públicas x superficie habitada
```

Pero para la representación solicitada de **luminosidad de la comuna**,
primero debe utilizarse el significado que corresponda al requisito del
proyecto y verificarse contra el encabezado real del dataset.

Si se decide usar densidad de luminarias, debe documentarse
explícitamente.

## Rango histórico observado

Se había utilizado aproximadamente:

``` text
11.52 → 1717.17
```

con normalización logarítmica.

**No asumir que estos límites siguen siendo correctos sin comprobar el
dataset actual.**

------------------------------------------------------------------------

# 8. Personas y efecto de flujo

La variable es:

``` text
índice 14 = Total Personas
```

No usar índice 17 ni calcular densidad salvo que el usuario lo solicite
expresamente.

El efecto deseado es similar a:

-   corrientes;
-   partículas/flujo de energía;
-   líneas luminosas que se desplazan;
-   pequeños trazos que recorren la comuna;
-   movimiento continuo y visible.

La intención conceptual es:

``` text
menos personas
→ pocas corrientes
→ baja intensidad
→ movimiento sutil

más personas
→ más corrientes
→ mayor intensidad
→ movimiento evidente
```

El efecto debe ser **animado**.

Un shader `CanvasItem` puede usar `TIME` para animación, pero si el
movimiento no resulta perceptible en la escala real del mapa, hay que
modificar el diseño visual en lugar de asumir que "el shader funciona
porque TIME existe".

------------------------------------------------------------------------

# 9. Problemas encontrados en iteraciones anteriores

## 9.1 Movimiento de personas casi/no visible

Se intentó generar movimiento dentro del shader usando `TIME`, `fract`,
`smoothstep` y trayectorias diagonales.

Aunque técnicamente podía existir animación, visualmente el movimiento
no era suficientemente evidente.

Problemas posibles:

-   contraste insuficiente contra el color base;
-   líneas demasiado finas;
-   patrón demasiado uniforme;
-   escala del UV poco apropiada;
-   intensidad insuficiente;
-   movimiento absorbido visualmente por el color de delitos;
-   patrón basado en bounding box poco representativo;
-   efecto demasiado abstracto para distinguirlo en pantalla.

**Nueva implementación:** el agente debe probar visualmente el efecto en
el mapa real y hacerlo claramente perceptible.

No basta con verificar que el shader compile.

------------------------------------------------------------------------

## 9.2 Borde de luminarias casi uniforme

Se intentó crear varias capas `Line2D`:

``` text
Borde
BordeGlow
BordeGlowExterior
```

con diferentes anchos, alpha y blend aditivo.

El resultado observado seguía mostrando bordes demasiado similares entre
comunas.

Posibles causas:

-   el código modificado no era el script realmente utilizado por la
    escena;
-   el ancho de `Line2D` era demasiado pequeño;
-   la variación del dato no se estaba aplicando;
-   la normalización no producía suficiente contraste;
-   el brillo no tenía bloom real;
-   la cámara/zoom afectaba la percepción;
-   el borde no se estaba construyendo a partir de la geometría
    correcta.

**Nueva implementación:** comprobar primero cómo se construye realmente
`Borde` en la escena y desde qué script se controla.

------------------------------------------------------------------------

# 10. Restricción importante: no romper la cámara

La cámara actual ya posee una lógica funcional y delicada.

Estados:

``` gdscript
enum EstadoCamara {
    MAPA_COMPLETO,
    ZOOM_COMUNA,
    SOLO_COMUNA
}
```

## Estado 1: MAPA_COMPLETO

-   Todas las comunas visibles.
-   Mouse cerca de los bordes permite desplazar la cámara.
-   Click izquierdo en una comuna → primer zoom.

## Primer zoom

-   Cámara se mueve al centro de la comuna.
-   Cámara hace zoom.
-   Posición y zoom se realizan simultáneamente.
-   El primer click **siempre debe hacer zoom IN**, incluso para comunas
    grandes.
-   No debe ocurrir accidentalmente un zoom out.

## Estado 2: ZOOM_COMUNA

-   La comuna seleccionada continúa dentro del mapa.
-   Se puede volver al estado inicial con click derecho.
-   Click izquierdo en una comuna → segundo zoom.

## Segundo zoom

El segundo zoom tiene dos etapas:

### Etapa 1

Mover la cámara al centro exacto de la comuna.

### Etapa 2

Una vez alcanzado el centro, ejecutar el zoom.

Esto es deliberado y debe conservarse.

## Estado 3: SOLO_COMUNA

-   Solo la comuna seleccionada queda visible.
-   Otras comunas se ocultan.
-   La cámara queda estática.
-   No debe existir panning automático por borde de pantalla.

## Click derecho

Desde `SOLO_COMUNA`:

``` text
SOLO_COMUNA → ZOOM_COMUNA
```

Debe volver exactamente a:

``` text
posicion_zoom_anterior
zoom_anterior
```

Desde `ZOOM_COMUNA`:

``` text
ZOOM_COMUNA → MAPA_COMPLETO
```

Debe volver exactamente a:

``` text
posicion_inicial
zoom_inicial
```

## Regla

**Una sesión dedicada al shader no debe modificar esta lógica de cámara
salvo que exista una dependencia técnica imprescindible y se
documente.**

------------------------------------------------------------------------

# 11. Cámara actual: detalles relevantes

La cámara usa:

``` gdscript
@export var velocidad_maxima: float = 500.0
@export var margen_borde: float = 30.0
@export var duracion_movimiento: float = 0.7
@export var porcentaje_primer_zoom: float = 0.32
@export var zoom_minimo: float = 0.5
@export var zoom_maximo: float = 50.0
@export var grosor_borde_normal: float = 0.8
@export var grosor_borde_minimo: float = 0.2
```

El borde históricamente se ajusta con el zoom para evitar que se vea
excesivamente grueso al acercar la cámara.

El script actual obtiene:

``` gdscript
var mapa: Node = get_node("../Mapa")
```

y recorre sus hijos.

La cámara obtiene el polígono mediante:

``` gdscript
comuna
    -> Area2D
    -> Polygon2D
```

y el borde mediante:

``` gdscript
Area2D
    -> Borde
```

------------------------------------------------------------------------

# 12. Regla de edición para agentes

Antes de modificar:

1.  Inspeccionar archivos existentes.
2.  Buscar el nombre real del script de la comuna.
3.  Buscar dónde se crea/asigna el material del `Polygon2D`.
4.  Buscar cómo se crea `Borde`.
5.  Buscar si ya existe un shader.
6.  Buscar cómo se obtiene el nombre de la comuna.
7.  Buscar cómo se accede a `DatosComunas`.
8.  Comprobar si los datos se entregan como `float`, `String`,
    `PackedStringArray`, etc.
9.  Comprobar el renderer/configuración del proyecto si el efecto
    depende de blend/glow.
10. Ejecutar el proyecto antes de modificar para establecer una línea
    base.

**No crear una arquitectura paralela si ya existe una implementación
equivalente.**

------------------------------------------------------------------------

# 13. Reglas para el shader

La implementación debe preferir una arquitectura clara:

``` text
DATOS
   ↓
GDScript
   ↓
uniforms del shader
   ↓
CanvasItem shader
   ↓
visualización
```

El shader no debe intentar leer directamente el CSV.

El GDScript debe obtener los valores.

Ejemplo conceptual:

``` gdscript
material.set_shader_parameter(
    "densidad_delitos",
    valor_delitos
)
```

``` gdscript
material.set_shader_parameter(
    "densidad_personas",
    total_personas
)
```

Y, si corresponde:

``` gdscript
material.set_shader_parameter(
    "densidad_luminarias",
    valor_luminarias
)
```

------------------------------------------------------------------------

# 14. Requisitos del shader solicitado

La primera sesión de implementación del shader debe resolver estas tres
capas:

## Capa A --- Delitos

Interior del polígono:

``` text
bajo → claro
medio → naranja
alto → rojo
```

Debe existir una transición continua.

No usar categorías discretas si una escala continua puede representar
mejor los datos.

------------------------------------------------------------------------

## Capa B --- Luminarias

El borde real de la comuna debe:

``` text
variar en intensidad
variar en grosor/alcance visual
tener un halo luminoso cuando corresponda
```

Debe ser posible identificar visualmente que una comuna con mayor valor
de luminarias tiene un borde más luminoso.

No utilizar un borde uniforme con solo cambiar el color global.

Idealmente:

``` text
Borde principal
+
halo cercano
+
halo exterior opcional
```

El efecto debe respetar la geometría real del polígono.

------------------------------------------------------------------------

## Capa C --- Personas

Dentro del polígono debe existir un flujo animado.

El flujo debe:

-   moverse constantemente;
-   tener dirección;
-   tener trazos/corrientes;
-   variar en cantidad/intensidad según personas;
-   ser visible sobre todos los colores de delitos;
-   no tapar completamente el color base;
-   evitar que todas las comunas parezcan idénticas.

Una posible estrategia es utilizar:

``` text
TIME
+
fract
+
smoothstep
+
ondas/corrientes
+
ruido procedural
```

pero el agente debe elegir la implementación que mejor funcione en el
proyecto real.

------------------------------------------------------------------------

# 15. Importante sobre UV y polígonos irregulares

No asumir que:

``` text
UV.x / UV.y
```

representan uniformemente el territorio de la comuna.

Las comunas tienen geometrías irregulares.

El agente debe inspeccionar cómo funciona el `Polygon2D` actual y, si
utiliza coordenadas locales mediante `VERTEX`, comprobar que los límites
se calculan correctamente.

Evitar crear efectos que dependan demasiado de un rectángulo imaginario
si eso hace que el patrón se vea claramente artificial.

------------------------------------------------------------------------

# 16. Requisitos visuales

La visualización final debe ser entendible sin una explicación extensa.

Un usuario debe poder mirar el mapa y deducir:

``` text
ROJO
→ más delitos

BORDE MÁS LUMINOSO/AMPLIO
→ más luminarias

MÁS FLUJO ANIMADO
→ más personas
```

Los tres canales visuales no deben competir de forma destructiva.

Prioridad visual:

1.  color de delitos;
2.  borde de luminarias;
3.  flujo de personas.

El flujo debe ser suficientemente visible, pero no debe convertir el
mapa en una animación caótica.

------------------------------------------------------------------------

# 17. No hacer

No:

-   modificar la lógica de cámara durante una sesión dedicada
    exclusivamente al shader;
-   cambiar los índices del dataset sin verificar;
-   asumir que `13` significa luminarias por km² sin revisar el
    encabezado;
-   utilizar población densa cuando el requisito es total de personas;
-   sumar categorías de delitos jerárquicas que generen doble conteo;
-   reemplazar todos los `Line2D` por rectángulos;
-   utilizar bounding boxes como sustituto del borde real;
-   implementar un efecto estático y llamarlo "flujo";
-   afirmar que el movimiento funciona solo porque el shader compila;
-   agregar dependencias innecesarias;
-   instalar plugins/librerías externas para resolver algo que Godot
    puede hacer nativamente;
-   reescribir scripts completos si solo hace falta una modificación
    localizada;
-   eliminar funcionalidades existentes sin justificarlo;
-   tocar la cámara para solucionar un problema puramente visual del
    shader.

------------------------------------------------------------------------

# 18. Verificación obligatoria

Después de implementar:

### Compilación

Debe cumplirse:

``` text
0 errores GDScript
0 errores de shader
0 warnings críticos relacionados con la implementación
```

### Datos

Comprobar al menos tres comunas con valores diferentes:

``` text
una con bajo valor
una con valor medio
una con valor alto
```

### Delitos

Verificar que:

``` text
mayor valor → más rojo
```

### Luminarias

Verificar que:

``` text
mayor valor → borde claramente más luminoso/extendido
```

### Personas

Verificar que:

``` text
mayor valor → flujo más intenso/denso
```

y que el movimiento sea visible en tiempo real.

### Cámara

Comprobar que siguen funcionando:

``` text
MAPA_COMPLETO
↓ click
ZOOM_COMUNA
↓ click
SOLO_COMUNA
↓ click derecho
ZOOM_COMUNA
↓ click derecho
MAPA_COMPLETO
```

La posición y zoom deben conservarse exactamente como antes.

------------------------------------------------------------------------

# 19. Estrategia de trabajo recomendada para OpenCode

Cuando una tarea sea compleja:

## Paso 1 --- Inspect

Leer los archivos relevantes.

## Paso 2 --- Plan

Explicar brevemente:

-   qué archivos cambiará;
-   por qué;
-   cómo se conectan los datos;
-   cómo se verificará.

## Paso 3 --- Implement

Modificar únicamente los archivos necesarios.

## Paso 4 --- Run

Ejecutar/validar el proyecto.

## Paso 5 --- Inspect result

Comprobar errores y comportamiento.

## Paso 6 --- Fix

Corregir solo lo necesario.

## Paso 7 --- Report

Entregar:

``` text
Archivos modificados:
- ...

Cambios:
- ...

Verificación:
- ...

Pendientes:
- ...
```

No llenar el contexto con explicaciones innecesarias.

------------------------------------------------------------------------

# 20. Política de cambios

Cada cambio debe tener una razón concreta.

Preferir:

``` text
cambio pequeño + verificable
```

sobre:

``` text
reescritura completa + difícil de depurar
```

Si se necesita reestructurar un componente, primero documentar por qué.

Si una implementación nueva entra en conflicto con una existente,
conservar la existente y proponer una migración controlada.

------------------------------------------------------------------------

# 21. Estado conceptual actual

El proyecto ya tiene:

-   mapa de Región Metropolitana;
-   comunas como polígonos;
-   interacción mediante `Area2D`;
-   click;
-   hover;
-   cámara;
-   panning por borde de pantalla;
-   primer zoom;
-   segundo zoom;
-   modo `SOLO_COMUNA`;
-   retorno mediante click derecho;
-   datos por comuna;
-   shader experimental;
-   análisis previo de relación entre delitos, luminarias y personas.

El foco actual NO es rehacer el mapa.

El foco actual es conseguir una **visualización integrada de tres
variables** mediante shaders/bordes:

``` text
DELITOS     = color
LUMINARIAS  = borde luminoso
PERSONAS    = flujo animado
```

------------------------------------------------------------------------

# 22. Resultados analíticos previos

Estos valores provienen de análisis realizados anteriormente y sirven
como contexto, no como sustituto del dataset actual.

Se observó:

``` text
Pearson:
densidad de luminarias vs densidad de delitos
≈ 0.807

R²:
≈ 0.651

Spearman:
≈ 0.816
```

También:

``` text
Pearson:
densidad de luminarias vs delitos totales
≈ 0.379

Pearson:
luminarias totales vs delitos totales
≈ 0.742
```

Por categoría:

``` text
vida/integridad ≈ 0.818
amenazas        ≈ 0.802
robos violentos ≈ 0.712
drogas          ≈ 0.695
```

Estos resultados describen asociación espacial observada y **no deben
interpretarse automáticamente como causalidad**.

El mapa es una herramienta de visualización, no una demostración causal.

------------------------------------------------------------------------

# 23. Decisiones visuales importantes

Se abandonó la idea de:

-   círculos de población;
-   burbujas difíciles de distinguir;
-   mapas bivariados demasiado difíciles de interpretar.

La estrategia elegida es:

``` text
INTERIOR
→ delitos

BORDE
→ luminarias

MOVIMIENTO INTERIOR
→ personas
```

Esta separación de canales visuales es deliberada.

------------------------------------------------------------------------

# 24. Primera tarea de programación

La primera sesión con el agente debe dedicarse exclusivamente al
**shader y su integración visual**, no a rediseñar la cámara.

Objetivo:

``` text
Implementar y validar:
1. color de delitos;
2. borde luminoso por luminarias;
3. flujo animado por personas.
```

Debe inspeccionar primero el proyecto y descubrir:

-   shader actual;
-   script que asigna el shader;
-   nodo `Polygon2D`;
-   nodo `Borde`;
-   fuente de datos;
-   nombre real del autoload;
-   renderer;
-   estructura de cada comuna.

Solo después debe modificar.

------------------------------------------------------------------------

# 25. Prompt maestro inicial para la sesión del shader

Usar el siguiente prompt en OpenCode:

------------------------------------------------------------------------

## PROMPT --- SESIÓN 1: SHADER MULTIVARIABLE DEL MAPA

Estamos trabajando en un proyecto **Godot 4.7.2** que representa la
Región Metropolitana de Chile mediante polígonos de comunas.

Quiero que implementes el sistema visual principal de tres variables:

### 1. DELITOS → COLOR INTERIOR

El interior de cada comuna debe representar la cantidad/densidad de
delitos.

Regla visual:

``` text
menos delitos → color claro/cálido
más delitos   → más rojo
```

Quiero una transición continua, no solo categorías discretas.

La intención final debe ser extremadamente fácil de leer:

> **mientras más roja está una comuna, más delitos representa.**

Los delitos generales utilizados previamente se calculan evitando doble
conteo de categorías:

``` text
índice 0 + índice 1 + índice 2 + índice 7
```

Pero **primero inspecciona el código y dataset real** para confirmar
cómo se está calculando actualmente el valor que recibe el shader.

No hardcodees valores si puedes obtenerlos del sistema existente.

------------------------------------------------------------------------

### 2. LUMINARIAS → BORDE LUMINOSO

La cantidad de luminarias debe representarse mediante el **borde real de
la comuna**.

Dato base:

``` text
índice 10 = Luminarias públicas
```

Primero verifica el encabezado real del dataset y cómo el proyecto está
accediendo actualmente a este dato.

Quiero este comportamiento:

``` text
pocas luminarias:
    borde fino
    brillo bajo
    halo pequeño

muchas luminarias:
    borde más grueso
    brillo alto
    halo más extendido
```

El borde debe parecer luminoso, no simplemente cambiar de color.

Idealmente utiliza:

``` text
borde principal
+
halo cercano
+
halo exterior
```

o una solución equivalente.

**IMPORTANTE:** debe utilizar la geometría real de la comuna. No
reemplaces el borde irregular por un rectángulo basado en el bounding
box.

La variación entre comunas debe ser visualmente evidente.

------------------------------------------------------------------------

### 3. PERSONAS → FLUJO ANIMADO

El total de personas está en:

``` text
índice 14 = Total Personas
```

No uses densidad de población.

Quiero un efecto de shader parecido a un **flujo/corriente animada**.

Visualmente debería parecer que pequeñas corrientes luminosas atraviesan
el territorio.

Debe existir:

-   movimiento continuo;
-   dirección;
-   trazos/corrientes;
-   variación de intensidad;
-   variación de cantidad;
-   relación directa con el total de personas.

Comportamiento:

``` text
menos personas
→ menos flujo
→ menos intensidad

más personas
→ más flujo
→ más intensidad
→ mayor presencia visual
```

No quiero círculos ni burbujas.

No quiero simplemente cambiar el color según personas.

Quiero **movimiento real generado por shader**.

Puedes utilizar técnicas como:

``` text
TIME
fract
smoothstep
noise procedural
ondas
distorsión
múltiples corrientes
```

pero elige la técnica que mejor funcione en el proyecto real.

------------------------------------------------------------------------

# 26. Restricciones críticas de esta sesión

NO modificar la lógica funcional de la cámara.

La cámara ya tiene tres estados:

``` text
MAPA_COMPLETO
ZOOM_COMUNA
SOLO_COMUNA
```

y ya funciona con:

-   primer zoom;
-   segundo zoom;
-   centrado antes del segundo zoom;
-   click derecho para volver;
-   panning por borde de pantalla;
-   cámara estática en SOLO_COMUNA.

No modificarla salvo que sea absolutamente necesario para que el shader
funcione.

Tampoco modificar:

-   dataset;
-   índices;
-   comportamiento de selección;
-   lógica de zoom;
-   lógica de navegación.

Si encuentras un problema que requiere modificar otra parte, primero
explica cuál es la dependencia.

------------------------------------------------------------------------

# 27. Proceso obligatorio

Antes de editar:

1.  inspecciona la estructura del proyecto;
2.  encuentra el shader actual;
3.  encuentra el script que asigna el shader;
4.  encuentra cómo se crean los `Line2D/Borde`;
5.  encuentra el autoload de datos;
6.  verifica los índices;
7.  identifica el renderer;
8.  ejecuta el proyecto si es posible y observa el estado actual.

Después:

1.  implementa;
2.  ejecuta;
3.  verifica que no existan errores;
4.  comprueba visualmente las tres variables;
5.  corrige los problemas de visibilidad.

No declares terminado el trabajo solo porque el shader compila.

------------------------------------------------------------------------

# 28. Criterios de aceptación

La implementación solo se considera correcta si:

### Delitos

Puedo mirar dos comunas y distinguir que:

``` text
comuna A menos roja
comuna B más roja
```

y eso corresponde a sus valores reales de delitos.

### Luminarias

Puedo mirar dos comunas y distinguir que:

``` text
borde A más tenue
borde B más luminoso/extendido
```

y eso corresponde a sus valores reales de luminarias.

### Personas

Puedo mirar dos comunas y distinguir que:

``` text
comuna A tiene poco flujo
comuna B tiene mucho flujo
```

y el flujo está realmente animado.

### Integración

Los tres efectos pueden verse simultáneamente:

``` text
COLOR      = DELITOS
BORDE      = LUMINARIAS
FLUJO      = PERSONAS
```

El color base no debe desaparecer debido al flujo.

El flujo no debe ocultar completamente la información de delitos.

El borde no debe confundirse con el flujo.

------------------------------------------------------------------------

# 29. Si el primer enfoque falla

No insistas indefinidamente en pequeños cambios de parámetros.

Diagnostica primero si el problema es:

-   material no asignado;
-   shader no aplicado al nodo correcto;
-   uniform no actualizado;
-   coordenadas incorrectas;
-   UV incorrectas;
-   escala incorrecta;
-   `TIME` no visible por diseño del patrón;
-   alpha demasiado bajo;
-   blend incorrecto;
-   Line2D incorrecto;
-   geometría del borde incorrecta;
-   zoom demasiado extremo.

Si el shader compila pero el movimiento no se ve, considera que **el
patrón visual puede estar mal diseñado**, no que necesariamente falte
una línea de código.

------------------------------------------------------------------------

# 30. Formato de respuesta del agente

Al terminar, responde de forma compacta:

``` text
## Cambios

- archivo:
  cambio

## Datos

- delitos:
  fuente/índice

- luminarias:
  fuente/índice

- personas:
  fuente/índice

## Shader

- color:
  implementación

- borde:
  implementación

- flujo:
  implementación

## Validación

- compilación:
- delitos:
- luminarias:
- flujo:
- cámara:

## Pendientes

- ...
```

No devolver bloques gigantes de código si no son necesarios. Los cambios
deben quedar realizados directamente en el proyecto.
