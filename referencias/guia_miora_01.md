# Fragmentos de Luz — Guía Técnica de Producción de Assets

**Versión:** 1.0  
**Público objetivo:** Desarrollador/a indie — Blender 3.x / 4.x + Godot 4.x  
**Idioma:** Español  

---

## Índice

1. [Visión General del Proyecto](#1-visión-general-del-proyecto)
2. [Estilo Visual y Paleta de Color](#2-estilo-visual-y-paleta-de-color)
3. [Descripción Técnica de Cada Elemento](#3-descripción-técnica-de-cada-elemento)
   - 3.1 Personaje Principal
   - 3.2 Escenario: Isla Flotante
   - 3.3 Variantes de Zona
   - 3.4 Props
   - 3.5 Interfaz de Usuario (UI)
4. [Pipeline de Producción](#4-pipeline-de-producción)
5. [Convenciones de Nomenclatura y Estructura de Archivos](#5-convenciones-de-nomenclatura-y-estructura-de-archivos)
6. [Integración en Godot 4.x](#6-integración-en-godot-4x)
7. [Checklist de Validación por Asset](#7-checklist-de-validación-por-asset)
8. [Problemas Comunes y Soluciones](#8-problemas-comunes-y-soluciones)

---

## 1. Visión General del Proyecto

### Descripción del juego

**Fragmentos de Luz** es una aventura / exploración 3D en tercera persona. El jugador encarna a un personaje joven que despierta en una isla flotante antigua repleta de ruinas, cristales luminosos y máquinas olvidadas. La mecánica central consiste en explorar el entorno, resolver puzzles ambientales, recoger fragmentos de energía dispersos y activar portales para progresar.

### Estilo visual

| Dimensión | Criterio |
|---|---|
| Renderizado | 3D stylized, no fotorrealista |
| Geometría | Low-poly / mid-poly con siluetas claras |
| Color | Paleta vibrante mágica; colores saturados y complementarios |
| Iluminación | Baked ambient + luces dinámicas puntuales (emisivos) |
| Sombras | Suaves, proyección estilizada (no hiperrealista) |
| Efectos | Partículas simples, shaders de emisión, outline opcional |

### Scope del paquete de assets

Este documento cubre la producción completa de:

- **1 personaje** principal jugable con rig y animaciones base
- **1 escenario** base (isla flotante) con 4 variantes de zona
- **7 props** interactivos y decorativos
- **3 elementos de UI** (barra energía, contador fragmentos, prompt interacción)

### Plataforma objetivo

| Parámetro | Valor |
|---|---|
| Motor | Godot 4.x (Forward+ o Mobile renderer) |
| Plataformas | PC (Windows/Linux/macOS), posible port web (HTML5) |
| Resolución base | 1920×1080 (escala descendente a 1280×720) |
| Frame rate objetivo | 60 fps en hardware mid-range |
| Presupuesto de draw calls | ≤ 200 por frame en escena principal |

---

## 2. Estilo Visual y Paleta de Color

### Paleta principal

| Nombre | Hex | Uso principal |
|---|---|---|
| Cristal Primario | `#4ECDC4` | Cristales de energía, barra de energía (UI) |
| Cristal Secundario | `#88F0B0` | Vegetación mágica, detalles decorativos |
| Portal | `#7B5EA7` | Portales, efectos de magia, highlights mágicos |
| Piedra Oscura | `#3D3530` | Base de rocas, suelo de ruinas |
| Piedra Media | `#6B5B4E` | Pilares, plataformas, columnas |
| Acento Dorado | `#F9C74F` | Fragmentos coleccionables, contador UI |
| Cielo Cálido | `#FF6B6B` | Cielo base (tono atardecer) |
| Cielo Frío | `#845EC2` | Gradiente superior del cielo |
| Blanco UI | `#FFFFFF` | Texto del HUD, iconos |
| Fondo UI | `#1A1A2E` | Paneles del HUD (opacidad 75 %) |

### Reglas de contraste

- **Elementos interactivos** (cristales, portales, fragmentos): usar Cristal Primario o Acento Dorado como color dominante. Deben tener al menos 4.5:1 de contraste sobre el entorno de piedra.
- **Elementos decorativos** (ruinas de fondo, columnas rotas): mantener en gama Piedra Oscura / Piedra Media; no usar emisivos de alta intensidad para no competir con los interactivos.
- **Regla del 70/20/10:** 70 % tonos neutros de piedra, 20 % verdes y cianos mágicos, 10 % dorado y púrpura de énfasis.
- Los elementos interactivos deben reconocerse incluso en modo daltónico: usa forma y brillo diferencial además del color.

### Guía de materiales emisivos en Godot

```gdscript
# Ejemplo: material emisivo para cristal en Godot 4.x
var mat = StandardMaterial3D.new()
mat.albedo_color = Color("#4ECDC4")
mat.emission_enabled = true
mat.emission = Color("#4ECDC4")
mat.emission_energy_multiplier = 1.5   # Ajustar según intensidad deseada
mat.roughness = 0.15
mat.metallic = 0.0
```

- Usa `emission_energy_multiplier` entre **1.0 y 2.5** para cristales. Valores superiores requieren bloom activado.
- Activa **Glow** en el `Environment` del WorldEnvironment: `glow_enabled = true`, `glow_strength = 0.8`, `glow_bloom = 0.1`.
- Para fragmentos coleccionables, anima `emission_energy_multiplier` en un rango 1.0–2.0 con un `AnimationPlayer` o un shader sencillo para efecto de pulsación.

### Recomendaciones de iluminación

| Tipo de luz | Parámetros recomendados | Uso |
|---|---|---|
| DirectionalLight3D (sol) | Energy 1.2, Shadow enabled, shadow_bias 0.05 | Iluminación global de la isla |
| OmniLight3D (cristal) | Energy 2.0, Range 3–5 m, Color Cristal Primario | Halo local alrededor de cristales |
| OmniLight3D (portal) | Energy 3.0, Range 6 m, Color Portal | Iluminación dramática del portal |
| SpotLight3D (fragmento) | Energy 1.5, Angle 30°, Color Acento Dorado | Señalización de coleccionables |
| WorldEnvironment (ambient) | Ambient Energy 0.3, Sky shader con gradiente Cielo Cálido → Cielo Frío | Luz ambiental base |

---

## 3. Descripción Técnica de Cada Elemento

### 3.1 Personaje Principal

#### Descripción visual

Joven andrógin@ de entre 16–20 años aparentes, complexión ligera y ágil. Viste una túnica corta de explorador con capucha, detalles de tela desgastada y un pequeño cinturón con bolsillos. Los ojos brillan levemente en tono Cristal Primario (`#4ECDC4`), sugiriendo conexión con la energía de la isla. Cabello corto con mechones libres. La paleta de ropa combina tierra y toques de acento dorado en botones y bordados.

#### Silueta y legibilidad

- **Vista trasera (tercera persona):** silueta en forma de triángulo invertido suave (hombros > cintura). Capucha y mochila pequeña refuerzan el perfil superior.
- **Vista desde arriba:** cabeza claramente diferenciada del cuerpo; evitar geometría plana en la cabeza.
- **A distancia (>15 m en juego):** la silueta debe reconocerse a 64×64 px efectivos; no añadir detalles que desaparezcan a esa distancia.

#### Presupuesto de polígonos

| Parte | Triángulos |
|---|---|
| Cabeza y cuello | 600–800 |
| Torso y ropa | 800–1,200 |
| Brazos y manos | 400–600 |
| Piernas y pies | 600–800 |
| Accesorios (cinturón, mochila) | 200–400 |
| **Total** | **3,000–5,000** |

#### Texturas

| Mapa | Resolución | Formato | Notas |
|---|---|---|---|
| Diffuse / Albedo | 1024×1024 | PNG / WebP | Color plano sin sombras baked |
| Normal Map | 512×512 | PNG (OpenGL) | Opcional; principalmente para ropa |
| Emission Mask | 256×256 | PNG | Sólo ojos y detalles brillantes |

- Usa atlas de textura única para el personaje completo (evita múltiples materiales).
- El color de emisión de los ojos se controla desde GDScript para poder animarlo.

#### Rig

- **~28 huesos** humanoides compatibles con el estándar de Godot (`Skeleton3D`).
- Jerarquía de referencia:

```
Root
└── Hips
    ├── Spine → Chest → Neck → Head
    │   ├── Shoulder.L → UpperArm.L → LowerArm.L → Hand.L → Fingers.L (x3)
    │   └── Shoulder.R → UpperArm.R → LowerArm.R → Hand.R → Fingers.R (x3)
    ├── UpperLeg.L → LowerLeg.L → Foot.L → Toe.L
    └── UpperLeg.R → LowerLeg.R → Foot.R → Toe.R
```

- Agrega huesos auxiliares para capa y capucha si se requiere simulación simple.
- Exporta el armature con **escala 1.0** antes de exportar a `.glb`.

#### Animaciones base

| Nombre | Duración ref. | Root Motion | Notas |
|---|---|---|---|
| `idle` | 2–3 s (loop) | No | Respiración sutil, parpadeo |
| `walk` | 0.8 s/ciclo (loop) | Sí | Desplazamiento a ~3 m/s |
| `run` | 0.5 s/ciclo (loop) | Sí | Desplazamiento a ~7 m/s |
| `jump_start` | 0.3 s | No | Despegue del suelo |
| `jump_air` | variable (loop) | No | Flotación en el aire |
| `land` | 0.35 s | No | Impacto en suelo |
| `examine` | 1.5 s | No | El personaje observa un objeto |
| `activate` | 1.2 s | No | Pulsa interruptor / activa portal |

- Exporta cada animación como acción separada en Blender con el prefijo del personaje (p. ej. `PC_idle`).
- En Godot, configura un `AnimationTree` con `AnimationStateMachine` para transiciones suaves.

#### Nodo en Godot 4.x

```
CharacterBody3D (player.tscn)
├── CollisionShape3D        → CapsuleShape3D h:1.8m r:0.3m
├── MeshInstance3D          → player.glb > Mesh
├── Skeleton3D              → (contenido en el .glb)
├── AnimationPlayer         → animaciones importadas
├── AnimationTree           → StateMachine con blend de locomoción
├── Camera3D (SpringArm3D)  → Tercera persona, arm_length 4m
├── RayCast3D               → Detección de interacción (alcance 2m)
└── AudioStreamPlayer3D     → Pasos, voz, efectos
```

**Script de referencia (GDScript):**

```gdscript
extends CharacterBody3D

const WALK_SPEED  = 3.0
const RUN_SPEED   = 7.0
const JUMP_FORCE  = 6.0
const GRAVITY     = -20.0

@onready var anim_tree: AnimationTree = $AnimationTree

func _physics_process(delta: float) -> void:
    if not is_on_floor():
        velocity.y += GRAVITY * delta

    var dir := _get_input_direction()
    var speed := RUN_SPEED if Input.is_action_pressed("run") else WALK_SPEED
    velocity.x = dir.x * speed
    velocity.z = dir.z * speed

    if Input.is_action_just_pressed("jump") and is_on_floor():
        velocity.y = JUMP_FORCE

    move_and_slide()
    _update_animation(dir)

func _get_input_direction() -> Vector3:
    var raw := Input.get_vector("move_left","move_right","move_forward","move_back")
    return (transform.basis * Vector3(raw.x, 0, raw.y)).normalized()

func _update_animation(dir: Vector3) -> void:
    var speed_blend := velocity.length() / RUN_SPEED
    anim_tree.set("parameters/locomotion/blend_position", speed_blend)
```

---

### 3.2 Escenario: Isla Flotante

#### Descripción visual

Isla de roca antigua de forma irregular (aproximadamente elíptica, ~80×60 m de diámetro jugable). La parte inferior presenta estalactitas de roca y raíces expuestas; la superficie superior está cubierta de plataformas de piedra, ruinas de columnas, vegetación mágica bioluminiscente y cristales emergentes.

#### Estructura modular

La isla se construye a partir de módulos reutilizables que se ensamblan en Godot:

| Módulo | Descripción | Tamaño approx. |
|---|---|---|
| `tile_floor_flat` | Loseta de suelo plana | 4×4 m |
| `tile_floor_cracked` | Loseta agrietada | 4×4 m |
| `tile_edge` | Borde de isla con derrumbe | 4×2 m |
| `rock_cliff_A/B/C` | Paredes de acantilado (3 variantes) | 4×6 m |
| `ruin_arch` | Arco de ruina | 3×4 m |
| `ruin_wall_segment` | Segmento de muro | 4×3 m |
| `stalactite_A/B` | Estalactitas inferiores | 1–3 m |

#### Presupuesto de polígonos (escenario completo)

| Grupo | Triángulos |
|---|---|
| Geometría base (tiles + acantilados) | ~15,000 |
| Ruinas y muros | ~8,000 |
| Vegetación mágica | ~4,000 |
| Cristales ambientales | ~3,000 |
| Decoración adicional | ~2,000 |
| **Total escenario** | **~32,000** |

#### Texturas de escenario

- Usa un **texture atlas** de 2048×2048 para toda la geometría de piedra/ruina.
- Cristales y vegetación pueden tener su propia textura 512×512 con canal emisivo.
- Aplica **triplanar mapping** en Godot para superficies irregulares de roca.

#### Iluminación del escenario

- Bake de luces estáticas con **LightmapGI** para geometría inmóvil (tiles, ruinas).
- Luces dinámicas solo para cristales y portal (máximo 4 luces dinámicas simultáneas).
- El cielo se implementa como `ProceduralSkyMaterial` con los colores Cielo Cálido y Cielo Frío.

---

### 3.3 Variantes de Zona

Cada zona es una sección del escenario con composición, iluminación y densidad de props específicas.

#### Zona 1 — Entrada

| Parámetro | Valor |
|---|---|
| Propósito | Tutorial implícito, presentación del personaje y mundo |
| Ambientación | Luz cálida de atardecer, pocos cristales, vegetación abundante |
| Props presentes | Columna Rota ×2, Cristal ×1 (tutorial), Fragmento ×1 |
| Dificultad visual | Baja — entorno abierto, pocas oclusiones |
| Nodos Godot | `Area3D` de trigger de tutorial, `Label3D` de hints |

#### Zona 2 — Puzzle

| Parámetro | Valor |
|---|---|
| Propósito | Introducción de mecánica de interruptores y plataformas móviles |
| Ambientación | Luz fría azul-verde, cristales más densos, sombras pronunciadas |
| Props presentes | Interruptor ×2, Plataforma Móvil ×3, Fragmento ×2, Cofre ×1 |
| Dificultad visual | Media — oclusiones parciales con muros de ruina |
| Nodos Godot | `AnimationPlayer` en plataformas, `Signal` en interruptores |

#### Zona 3 — Zona Elevada

| Parámetro | Valor |
|---|---|
| Propósito | Platforming, recolección de fragmentos opcionales |
| Ambientación | Cielo más visible, viento simulado en vegetación, luz directa fuerte |
| Props presentes | Plataforma Móvil ×4, Fragmento ×3, Cristal ×3 |
| Dificultad visual | Media-alta — plataformas a distinta altura, perspectiva de cámara más abierta |
| Nodos Godot | `Path3D` + `PathFollow3D` para plataformas circulares |

#### Zona 4 — Portal Final

| Parámetro | Valor |
|---|---|
| Propósito | Clímax narrativo; activación del portal para avanzar |
| Ambientación | Luz púrpura intensa, partículas densas, todos los cristales al máximo emisivo |
| Props presentes | Portal Circular ×1 (principal), Cristal ×6, Fragmento ×1 (último), Cofre Reliquia ×1 |
| Dificultad visual | Alta — contraste dramático, bloom intenso |
| Nodos Godot | `GPUParticles3D`, `AnimationPlayer` de activación del portal, `SceneTree.change_scene_to_file` |

---

### 3.4 Props

#### 1. Cristal de Energía

| Aspecto | Detalle |
|---|---|
| Descripción | Cristal hexagonal emergente del suelo, translúcido, con luz interna pulsante |
| Triángulos | 80–150 |
| Textura | 256×256, albedo + emisión (canal R) |
| Material | `StandardMaterial3D`, albedo `#4ECDC4`, emisión activada, roughness 0.1 |
| Variantes | S (0.3 m), M (0.7 m), L (1.2 m) — escalar la misma malla |
| Nodo Godot | `StaticBody3D` + `MeshInstance3D`; luz `OmniLight3D` hija |
| Interacción | `Area3D` para detección de proximidad del jugador |

#### 2. Portal Circular

| Aspecto | Detalle |
|---|---|
| Descripción | Arco toroidal de piedra antigua con inscripciones; interior con efecto de vórtice energético |
| Triángulos | 400–600 (marco) + quad central para shader |
| Textura | 512×512 para el marco; shader procedural para el interior |
| Material | Marco: `StandardMaterial3D` Piedra Oscura; interior: `ShaderMaterial` personalizado |
| Nodo Godot | `Area3D` de activación + `AnimationPlayer` (rotación interna, pulso de emisión) |
| Estados | `inactive`, `activating` (animado), `active` (loop de vórtice) |

**Shader básico del interior del portal:**

```glsl
shader_type spatial;
render_mode unshaded, cull_back;

uniform float time_scale : hint_range(0.1, 5.0) = 1.0;
uniform vec4 color_a : source_color = vec4(0.482, 0.369, 0.655, 1.0); // #7B5EA7
uniform vec4 color_b : source_color = vec4(0.306, 0.804, 0.769, 1.0); // #4ECDC4

void fragment() {
    vec2 uv = UV - 0.5;
    float angle = atan(uv.y, uv.x);
    float radius = length(uv);
    float spiral = fract(angle / TAU + TIME * time_scale * 0.3 - radius * 2.0);
    vec4 col = mix(color_a, color_b, spiral);
    col.a = smoothstep(0.5, 0.45, radius);
    ALBEDO = col.rgb;
    EMISSION = col.rgb * 2.0;
    ALPHA = col.a;
}
```

#### 3. Cofre Reliquia

| Aspecto | Detalle |
|---|---|
| Descripción | Cofre de madera antigua reforzado con metal oxidado y runas doradas incisas |
| Triángulos | 200–350 |
| Textura | 512×512 diffuse, 256×256 normal map |
| Material | `StandardMaterial3D`, mezcla Piedra Oscura + Acento Dorado en detalles |
| Nodo Godot | `StaticBody3D`; `AnimationPlayer` para apertura (tapa se rota en Y) |
| Estados | `closed`, `opening` (animado 0.8 s), `open` |

#### 4. Interruptor / Palanca

| Aspecto | Detalle |
|---|---|
| Descripción | Palanca de piedra con cabeza de cristal; al activarse, el cristal cambia de color y la palanca se inclina |
| Triángulos | 100–180 |
| Textura | 256×256 (compartir atlas con cofre) |
| Nodo Godot | `StaticBody3D` + `Area3D`; `AnimationPlayer` para inclinación (30°) |
| Estados | `off` (cristal gris neutro), `on` (cristal Cristal Primario, emisión activa) |
| Señal | `lever_toggled(state: bool)` emitida al cambiar estado |

#### 5. Plataforma Móvil

| Aspecto | Detalle |
|---|---|
| Descripción | Loseta de piedra antigua que se desplaza en un eje (horizontal o vertical) de forma cíclica |
| Triángulos | 80–120 |
| Textura | Compartir atlas de suelo |
| Nodo Godot | `AnimatableBody3D` (necesario para que el personaje se mueva con la plataforma) + `AnimationPlayer` |
| Configuración | Exportar posición A y B en el inspector; velocidad configurable mediante `@export var speed: float` |

```gdscript
# plataforma_movil.gd
extends AnimatableBody3D

@export var point_a: Vector3 = Vector3.ZERO
@export var point_b: Vector3 = Vector3(4, 0, 0)
@export var speed: float = 2.0

var _t := 0.0
var _dir := 1.0

func _physics_process(delta: float) -> void:
    _t += delta * speed * _dir
    if _t >= 1.0 or _t <= 0.0:
        _dir *= -1.0
        _t = clampf(_t, 0.0, 1.0)
    global_position = point_a.lerp(point_b, _t)
```

#### 6. Columna Rota

| Aspecto | Detalle |
|---|---|
| Descripción | Columna de piedra clásica en dos piezas (base intacta, fuste roto a media altura con fractura expuesta) |
| Triángulos | 150–250 (dos partes separadas para variación) |
| Textura | Atlas 2048×2048 del escenario |
| Nodo Godot | `StaticBody3D` (decorativo, sin interacción); la parte superior puede omitir `CollisionShape3D` |
| Variantes | Alta (1.8 m), baja (0.8 m) — dos meshes distintos |

#### 7. Fragmento Coleccionable

| Aspecto | Detalle |
|---|---|
| Descripción | Pequeño romboedro de cristal dorado translúcido que flota y rota lentamente |
| Triángulos | 50–80 |
| Textura | 128×128; color plano Acento Dorado con canal emisivo |
| Nodo Godot | `Area3D` + `MeshInstance3D`; `AnimationPlayer` para rotación y bob (subir/bajar 0.1 m) |
| Recolección | Señal `fragment_collected(id: int)`; desaparece con `queue_free()` tras animación de recogida |

```gdscript
# fragmento.gd
extends Area3D

@export var fragment_id: int = 0
signal fragment_collected(id: int)

func _ready() -> void:
    body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
    if body.is_in_group("player"):
        fragment_collected.emit(fragment_id)
        # Animación de recogida y luego queue_free
        $AnimationPlayer.play("collect")
        await $AnimationPlayer.animation_finished
        queue_free()
```

---

### 3.5 Interfaz de Usuario (UI)

#### Principios de diseño UI

- **Minimalista y no invasiva:** el HUD ocupa menos del 15 % del área de pantalla.
- **Fondo semitransparente:** `#1A1A2E` al 75 % de opacidad para paneles.
- **Tipografía:** fuente geométrica sans-serif, tamaño mínimo 18 px a 1080p.
- Los elementos UI son `CanvasLayer` en Godot para renderizado 2D sobre la escena 3D.

#### Barra de Energía

| Parámetro | Valor |
|---|---|
| Posición | Esquina inferior izquierda, 24 px del borde |
| Tamaño | 200×20 px (1080p) |
| Color de relleno | `#4ECDC4` (Cristal Primario) |
| Color de fondo | `#1A1A2E` al 75 % |
| Borde | 2 px, `#FFFFFF` al 40 % |
| Nodo Godot | `TextureProgressBar` o `ProgressBar` con estilo personalizado (`StyleBoxFlat`) |
| Animación | Parpadeo en rojo (`#FF6B6B`) cuando energía < 20 % |

```gdscript
# hud.gd — actualizar barra de energía
func update_energy(current: float, max_energy: float) -> void:
    energy_bar.value = (current / max_energy) * 100.0
    if current / max_energy < 0.2:
        _start_blink_animation()
    else:
        _stop_blink_animation()
```

#### Contador de Fragmentos

| Parámetro | Valor |
|---|---|
| Posición | Esquina superior derecha, 24 px del borde |
| Contenido | Icono de fragmento (sprite 32×32 px) + `Label` "X / Y" |
| Color de texto | `#F9C74F` (Acento Dorado) |
| Fondo | Panel `#1A1A2E` al 75 %, bordes redondeados 6 px |
| Nodo Godot | `HBoxContainer` > `TextureRect` + `Label` |
| Actualización | Señal global `GameEvents.fragment_collected` → actualiza texto |

```gdscript
# fragmento_counter.gd
@onready var label: Label = $HBoxContainer/Label

func _ready() -> void:
    GameEvents.fragment_collected.connect(_on_fragment_collected)
    _refresh()

func _on_fragment_collected(_id: int) -> void:
    _refresh()

func _refresh() -> void:
    var total   = GameState.total_fragments
    var current = GameState.collected_fragments
    label.text  = "%d / %d" % [current, total]
```

#### Prompt de Interacción

| Parámetro | Valor |
|---|---|
| Posición | Centro inferior de pantalla, 80 px desde el borde inferior |
| Contenido | Icono de tecla/botón + texto de acción (p. ej. "E — Activar") |
| Color de texto | `#FFFFFF` |
| Fondo | `#1A1A2E` al 75 %, padding 8×12 px |
| Visibilidad | Aparece/desaparece con `tween` de 0.2 s (fade in/out) |
| Nodo Godot | `Panel` > `HBoxContainer` > `TextureRect` + `Label`; inicialmente `visible = false` |

```gdscript
# interaction_prompt.gd
@onready var label: Label = $Panel/HBoxContainer/Label
@onready var tween: Tween

func show_prompt(action_text: String) -> void:
    label.text = action_text
    if tween: tween.kill()
    tween = create_tween()
    tween.tween_property(self, "modulate:a", 1.0, 0.2)
    visible = true

func hide_prompt() -> void:
    if tween: tween.kill()
    tween = create_tween()
    tween.tween_property(self, "modulate:a", 0.0, 0.2)
    await tween.finished
    visible = false
```

---

## 4. Pipeline de Producción

### Flujo por asset

```
Concepto / Referencia visual
        │
        ▼
  Blender: Modelado (low-poly, normals out)
        │
        ▼
  Blender: UV Unwrap (Smart UV o manual)
        │
        ▼
  Texturizado (Blender Shader → bake / o Krita / Affinity)
        │
        ▼
  Blender: Rig + Skinning  (solo personaje y props animados)
        │
        ▼
  Blender: Animación + NLA export
        │
        ▼
  Export GLB  (File → Export → glTF 2.0 / .glb)
        │
        ▼
  Godot: Import + ajuste de ImportSettings
        │
        ▼
  Godot: Escena (.tscn) + Script + ColisionShape
        │
        ▼
  Prueba en Godot (jugar en editor)
        │
        ▼
  ✓ Validación checklist (ver §7)
```

### Configuración de exportación GLB en Blender

```
File → Export → glTF 2.0 (.glb)
  ☑ Include: Selected Objects  (o Scene)
  ☑ Transform: Y Forward, Z Up  → marcar "+Y Up" para Godot
  ☑ Geometry: Apply Modifiers
  ☑ Armature: Export Deformation Bones Only
  ☑ Animation: Export (NLA Tracks, Group by NLA Track)
  ☑ Compress: desactivado (para debug); activar al final si el tamaño importa
```

### Configuración de importación en Godot 4.x

En el panel **Import** de Godot, para cada `.glb`:

| Setting | Valor recomendado |
|---|---|
| Meshes → Generate LODs | Off (low-poly no lo necesita) |
| Meshes → Create Shadow Meshes | On |
| Animation → Import | On |
| Animation → FPS | 30 |
| Skins → Use Named Skins | On |
| Materials → Storage | Files (.tres) — para editar materiales externamente |

---

## 5. Convenciones de Nomenclatura y Estructura de Archivos

### Nomenclatura de archivos

| Tipo | Patrón | Ejemplo |
|---|---|---|
| Malla personaje | `ch_<nombre>.glb` | `ch_protagonista.glb` |
| Prop | `prop_<nombre>.glb` | `prop_cristal_energia.glb` |
| Escenario módulo | `env_<nombre>.glb` | `env_tile_floor_flat.glb` |
| Textura | `<asset>_<tipo>.png` | `ch_protagonista_diffuse.png` |
| Escena Godot | `<nombre>.tscn` | `player.tscn`, `prop_portal.tscn` |
| Script | `<nombre>.gd` | `player.gd`, `fragmento.gd` |

### Estructura de directorios del proyecto Godot

```
res://
├── assets/
│   ├── characters/
│   │   ├── ch_protagonista.glb
│   │   └── textures/
│   ├── environment/
│   │   ├── modules/
│   │   └── textures/
│   ├── props/
│   │   ├── prop_cristal_energia.glb
│   │   ├── prop_portal.glb
│   │   └── ...
│   └── ui/
│       ├── icons/
│       └── fonts/
├── scenes/
│   ├── player.tscn
│   ├── world/
│   │   ├── zone_entrada.tscn
│   │   ├── zone_puzzle.tscn
│   │   ├── zone_elevada.tscn
│   │   └── zone_portal.tscn
│   └── props/
│       ├── prop_cristal.tscn
│       └── ...
├── scripts/
│   ├── player.gd
│   ├── game_state.gd
│   ├── game_events.gd
│   └── ui/
│       ├── hud.gd
│       └── interaction_prompt.gd
└── shaders/
    └── portal_interior.gdshader
```

---

## 6. Integración en Godot 4.x

### Autoloads recomendados

| Autoload | Ruta | Propósito |
|---|---|---|
| `GameState` | `res://scripts/game_state.gd` | Estado global (fragmentos, energía, progreso) |
| `GameEvents` | `res://scripts/game_events.gd` | Bus de señales global desacoplado |

```gdscript
# game_events.gd — Bus de señales global
extends Node

signal fragment_collected(id: int)
signal energy_changed(current: float, max_val: float)
signal portal_activated(zone_id: int)
signal interaction_available(action_text: String)
signal interaction_unavailable()
```

### Grupos de Godot utilizados

| Grupo | Nodos que pertenecen | Uso |
|---|---|---|
| `"player"` | `CharacterBody3D` del protagonista | Detección en `Area3D.body_entered` |
| `"collectible"` | `Area3D` de fragmentos y cofres | Interacción genérica |
| `"interactive"` | Interruptores, portal, cofres | `RayCast3D` del jugador |
| `"platform"` | `AnimatableBody3D` de plataformas | Lógica de puzzle |

### Configuración de física

```
Project Settings → Physics → 3D
  Gravity Vector: (0, -20, 0)    # Más pesado que defecto para sensación ágil
  Layer 1: world_static           # Geometría estática (suelo, muros)
  Layer 2: player                 # CharacterBody3D del personaje
  Layer 3: interactables          # Props con Area3D
  Layer 4: collectibles           # Fragmentos
```

### LightmapGI (bake de iluminación)

1. Añadir `LightmapGI` al nodo raíz de la zona.
2. Marcar como **Static** todos los `MeshInstance3D` de geometría fija.
3. Configurar `texel_size = 0.2` (balance calidad/tiempo de bake).
4. Ejecutar **Bake Lightmaps** desde el menú 3D del editor.
5. El bake se guarda en `res://scenes/world/.godot/lightmaps/`.

---

## 7. Checklist de Validación por Asset

### Geometría (Blender)

- [ ] Normales apuntando hacia afuera (Overlay → Face Orientation: todo azul)
- [ ] Sin geometría duplicada (Mesh → Merge by Distance)
- [ ] Sin n-gons en mallas de personaje (solo tris/quads)
- [ ] Escala aplicada (`Ctrl+A → Scale`)
- [ ] Origen del objeto en posición semánticamente correcta (base del objeto o centro de masa)
- [ ] Triángulos dentro del presupuesto definido en §3

### UV y textura

- [ ] UVs dentro del rango 0–1 (sin tiles no intencionados)
- [ ] Sin superposiciones en UV islands del mismo objeto (excepto partes simétricas intencionadas)
- [ ] Textura exportada en el tamaño correcto (ver tabla §3.1)
- [ ] Canal Alpha correcto en texturas con transparencia
- [ ] Sin artefactos de compresión visibles en vista de engine

### Rig y animación (personaje)

- [ ] Escala del armature = 1.0 antes de exportar
- [ ] Skinning sin vértices con peso 0 en todas las mallas
- [ ] Todas las animaciones listadas en §3.1 presentes y con nombre correcto
- [ ] Animaciones con root motion exportan correctamente el desplazamiento de `Hips`
- [ ] Prueba de animación en Godot sin deformaciones inesperadas

### Integración Godot

- [ ] Escena `.tscn` creada con jerarquía correcta (ver §3.1 y §3.4)
- [ ] `CollisionShape3D` ajustada a la geometría visible
- [ ] Materiales con emisión configurados correctamente
- [ ] Señales conectadas y probadas en editor
- [ ] Frame rate ≥ 60 fps en escena de prueba (F6 → monitor de rendimiento)
- [ ] Sin errores ni warnings en la consola de Godot al iniciar escena

---

## 8. Problemas Comunes y Soluciones

| Problema | Causa probable | Solución |
|---|---|---|
| Malla oscura o negra en Godot | Normales invertidas | En Blender: `Mesh → Normals → Flip`; reexportar |
| Personaje se "hunde" al importar | Escala incorrecta en armature | `Ctrl+A → All Transforms` en Blender; reimportar |
| Animación no aparece en Godot | NLA Track no activo al exportar | En Blender, pushdown todas las acciones al NLA antes de exportar |
| Plataforma no arrastra al jugador | `RigidBody3D` en vez de `AnimatableBody3D` | Cambiar a `AnimatableBody3D`; reconfigurar capas de física |
| Bloom no visible en cristales | Glow desactivado en Environment | En `WorldEnvironment → Environment → Glow`, activar y ajustar `glow_strength` |
| UI borrosa en pantallas grandes | `CanvasLayer` con escala incorrecta | Configurar `Project Settings → Display → Stretch Mode = canvas_items` |
| Fragmento no se recoge | Capa de física no coincide | Verificar que el `Area3D` del fragmento monitorea la capa del `"player"` |
| Sombras con aliasing fuerte | `shadow_bias` mal configurado | En `DirectionalLight3D`, ajustar `shadow_bias = 0.05` y `shadow_normal_bias = 1.0` |
| GLB muy pesado (>10 MB) | Texturas sin comprimir incluidas | Usar `KTX2 / ETC2` en la exportación de Blender o comprimir texturas antes |
| Shader portal visible por detrás | `cull_back` no configurado | Asegurarse de `render_mode cull_back` en el shader; añadir quad doble cara si es necesario |

---

*Guía generada para el paquete de assets de "Fragmentos de Luz" — versión 1.0. Actualizar según evolución del proyecto.*
