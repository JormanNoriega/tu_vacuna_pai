---
name: Tu Vacuna PAI
description: Registro y consulta de vacunacion para equipos de salud en campo
colors:
  primary: "#135BEC"
  background-light: "#FFFFFF"
  background-medium: "#F8F9FA"
  background-dark: "#101622"
  card: "#FFFFFF"
  text-primary: "#111318"
  text-secondary: "#616F89"
  text-hint: "#9CA3AF"
  border: "#DBDFE6"
  input-background: "#FAFAFA"
  success: "#10B981"
  error: "#EF4444"
  warning: "#F59E0B"
typography:
  display:
    fontFamily: "Roboto, sans-serif"
    fontWeight: 700
  body:
    fontFamily: "Roboto, sans-serif"
    fontWeight: 400
    fontSize: "16sp"
  label:
    fontFamily: "Roboto, sans-serif"
    fontWeight: 500
rounded:
  sm: "8dp"
  md: "12dp"
  lg: "16dp"
spacing:
  sm: "8dp"
  md: "16dp"
  lg: "24dp"
components:
  button-primary:
    backgroundColor: "{colors.primary}"
    textColor: "{colors.background-light}"
    rounded: "{rounded.md}"
    height: "56dp"
  card:
    backgroundColor: "{colors.card}"
    rounded: "{rounded.lg}"
    padding: "16dp"
---

# Design System: Tu Vacuna PAI

## Overview

**Creative North Star: "La Estacion de Confianza"**

Este sistema visual se extrae de la app anterior y se conserva como punto de partida: una herramienta clinica clara, luminosa y directa para personal de salud que necesita registrar informacion con rapidez. La interfaz usa una superficie blanca y gris muy suave para reducir ruido, y reserva el azul intenso para acciones, seleccion y orientacion.

La prioridad es operar con seguridad, no decorar. La nueva implementacion debe mantener la familiaridad de los flujos heredados, pero expresarlos con componentes Material 3, estados completos y comportamiento adaptativo para movil y tablet.

**Key Characteristics:**
- Azul primario unico para accion y navegacion.
- Superficies claras, bordes discretos y profundidad ambiental.
- Tarjetas amplias para resumen y acciones frecuentes.
- Jerarquia tipografica fuerte y copy operativo en espanol.

## Colors

La paleta observada es restrained: neutrales claros mas un azul de accion, con colores semanticos para estados y categorias de datos.

### Primary
- **Azul de confianza** (`#135BEC`): acciones primarias, seleccion, foco, iconografia activa y estados de progreso.

### Secondary
- **Verde de confirmacion** (`#10B981`): exito y datos positivos.
- **Ambar de atencion** (`#F59E0B`): advertencias y acciones pendientes de revision.
- **Rojo de recuperacion** (`#EF4444`): errores y validaciones fallidas.

### Neutral
- **Blanco clinico** (`#FFFFFF`): fondo principal y superficies de contenido.
- **Gris niebla** (`#F8F9FA`): fondo de dashboard y zonas de separacion.
- **Tinta** (`#111318`): titulos, datos y contenido primario.
- **Pizarra suave** (`#616F89`): contenido secundario y metadatos.
- **Gris auxiliar** (`#9CA3AF`): hints y timestamps.
- **Linea** (`#DBDFE6`): bordes y divisores.

### Named Rules
**The Blue Signal Rule.** El azul primario comunica una accion o estado real; no se usa como decoracion dispersa.

## Typography

**Display Font:** Roboto (system fallback)

**Body Font:** Roboto (system fallback)

**Character:** Tipografia Material sobria y legible, con peso para separar decisiones y datos sin depender de mayusculas decorativas.

### Hierarchy
- **Display** (700, 28sp o mayor): titulos de acceso y encabezados principales.
- **Headline** (700, 22-24sp): secciones de dashboard y contexto de pantalla.
- **Title** (600-700, 16-20sp): nombres, tarjetas y elementos de lista.
- **Body** (400, 14-16sp): instrucciones, subtitulos y contenido operativo.
- **Label** (500-700, 11-13sp): metadatos y estados; el uppercase solo se conserva para etiquetas de estadistica donde aporta escaneabilidad.

## Layout

La app usa SafeArea y scroll vertical para formularios y dashboards. En movil el contenido parte de 16dp laterales; en tablet usa 24-32dp. Las estadisticas se organizan en una columna estrecha y en una grilla de tres columnas cuando hay espacio. Las acciones frecuentes usan una grilla de dos columnas en compacto y hasta cuatro en ancho expandido.

La navegacion debe adaptarse al ancho: barra inferior Material en compacto y NavigationRail o NavigationDrawer en superficies expandidas. Los objetivos tactiles no deben ser menores de 48dp en Android ni 44pt en iOS.

## Elevation & Depth

La app anterior usa profundidad ambiental sobre tarjetas blancas: sombras suaves, desplazamiento vertical pequeno y blur amplio. En la reconstruccion se prioriza la elevacion tonal de Material 3 y se reserva la sombra para superficies que realmente flotan, dialogs y la accion primaria.

### Shadow Vocabulary
- **Surface lift** (`black 6%`, blur 12, y 4): tarjetas de resumen y paneles de dashboard.
- **Primary action lift** (`primary 30%`, blur 16, y 8): solo la accion principal destacada.
- **Divider**: preferir borde de 1dp o divisor tonal antes que una sombra.

## Shapes

El lenguaje heredado usa radios de 8, 12 y 16dp. Los campos usan 8dp, botones y controles destacados 12dp, y tarjetas 16dp. Las formas son rectangulares redondeadas, no pill, salvo chips y pequenos estados. Los campos tienen fondo casi blanco, borde visible en reposo y borde azul de 2dp en foco.

## Components

### Buttons
- **Shape:** radio 12dp, minimo 48dp de alto; las acciones heredadas principales miden 56dp.
- **Primary:** fondo azul de confianza, texto blanco, icono opcional y peso 700.
- **Hover / Focus:** en movil se expresa como pressed/focus; aumentar contraste y mostrar anillo de foco sin depender de hover.
- **Secondary / Ghost / Tertiary:** superficie tonal, outlined o text button para acciones no destructivas y secundarias.

### Cards / Containers
- **Corner Style:** 16dp para paneles y acciones; 12dp para bloques internos.
- **Stat Card:** icono semantico en contenedor tonal, valor grande y etiqueta breve; no agregar metricas inventadas.
- **Action Card:** una accion clara, icono grande, titulo y subtitulo opcional. La accion primaria usa la superficie azul completa.

### Inputs
- **Shape:** campo filled con radio 8dp y borde 1dp.
- **States:** reposo, foco azul 2dp, error rojo 2dp, disabled con contraste reducido pero legible.
- **Behavior:** labels y errores describen la accion y la recuperacion; password permite revelar el valor.

### Navigation
- **Compact:** NavigationBar con 3-5 destinos principales y etiquetas visibles.
- **Expanded:** NavigationRail o drawer; nunca estirar una barra inferior de telefono sobre tablet.
- **Context:** Top app bar con titulo de pantalla, acciones de refresh o estadisticas solo donde el contexto las necesita.

### Feedback
- **Transient:** Snackbars para confirmaciones y errores recuperables.
- **Blocking:** dialogs solo para decisiones destructivas, desbloqueo o confirmaciones que requieran atencion.
- **Loading / Empty:** siempre comunicar que ocurre y cual es el siguiente paso; evitar pantallas en blanco.

## Do's and Don'ts

- **Do:** conservar la claridad azul/blanco de la app anterior mientras se corrigen sus inconsistencias.
- **Do:** usar roles Material 3 y colores semanticos para soportar tema oscuro y alto contraste.
- **Do:** disenar estados de conectividad, sincronizacion, carga, error y vacio como parte del flujo.
- **Don't:** copiar acceso directo de widgets a SQLite, GetX o SQL de la app anterior.
- **Don't:** usar sombras, gradientes o tarjetas como decoracion sin una funcion de jerarquia.
- **Don't:** ocultar acciones criticas detras de iconos ambiguos o targets pequenos.
