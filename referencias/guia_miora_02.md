# Fragmentos de Luz — Guía Técnica de Producción de Assets

## Índice

1. [Visión General del Proyecto](#1-visión-general-del-proyecto)
2. [Estilo Visual y Paleta de Color](#2-estilo-visual-y-paleta-de-color)
3. [Descripción Técnica: Personaje Principal](#3-descripción-técnica-personaje-principal)
4. [Descripción Técnica: Escenario — Isla Flotante](#4-descripción-técnica-escenario--isla-flotante)
5. [Descripción Técnica: Props (7 elementos)](#5-descripción-técnica-props-7-elementos)
6. [Descripción Técnica: UI / HUD](#6-descripción-técnica-ui--hud)
7. [Pipeline de Producción en Blender → Godot](#7-pipeline-de-producción-en-blender--godot)
8. [Escalas de Referencia](#8-escalas-de-referencia)
9. [Checklist de Validación por Asset](#9-checklist-de-validación-por-asset)
10. [Problemas Comunes y Soluciones](#10-problemas-comunes-y-soluciones)

---

## 1. Visión General del Proyecto

| Campo | Valor |
|---|---|
| **Nombre** | Fragmentos de Luz |
| **Género** | Aventura / Exploración 3D en tercera persona |
| **Plataforma objetivo** | PC (Windows / Linux / macOS), exportable a consola |
| **Engine** | Godot 4.x |
| **Herramienta de modelado** | Blender 3.6+ / 4.x |
| **Formato de assets** | glTF 2.0 (.glb) |

### Scope del paquete visual

Este documento cubre la totalidad de los assets visuales necesarios para una demo jugable completa:

- **Personaje principal:** malla, rig, texturas y set de animaciones base
- **Escenario principal:** isla flotante modular, 4 zonas diferenciadas
- **Props interactivos:** 7 elementos con comportamiento y señales de juego
- **UI / HUD:** 3 elementos de interfaz con árbol de nodos y scripts de gestión

### Estilo visual

**3D Stylized** con referentes en aventura fantástica, ruinas flotantes y tecnología antigua. Los pilares estéticos son:

- **Formas claras y siluetas reconocibles:** geometría low-poly con contornos definidos, sin detalle hiperrealista que sature a resoluciones de juego
- **Color vibrante sobre neutro oscuro:** superficies de piedra oscura (#3D3530–#6B5B4E) como base, con cristales teal-cyan y detalles dorados como puntos de interés
- **Luminiscencia mágica:** emisivos teal en cristales y ruinas activas comunican interactividad sin iconos adicionales
- **Cielo fantástico:** gradiente atardecer cálido (#FF6B6B) → púrpura frío (#845EC2) que enmarca la isla y refuerza la atmósfera de mundo suspendido

---

## 2. Estilo Visual y Paleta de Color

### Paleta de color

| Nombre | Hex | Uso |
|---|---|---|
| Cristal Primario | `#4ECDC4` | Cristales, barra de energía UI |
| Cristal Secundario | `#88F0B0` | Vegetación mágica, detalles secundarios |
| Portal | `#7B5EA7` | Portales, efectos de magia |
| Piedra Oscura | `#3D3530` | Base de rocas y ruinas |
| Piedra Media | `#6B5B4E` | Pilares, plataformas, suelo |
| Acento Dorado | `#F9C74F` | Fragmentos coleccionables, UI contador |
| Cielo Cálido | `#FF6B6B` | Cielo base (zona de atardecer) |
| Cielo Frío | `#845EC2` | Gradiente superior del cielo |
| Blanco UI | `#FFFFFF` | Texto del HUD |
| Fondo UI | `#1A1A2E` | Paneles del HUD (75% opacidad) |

### Reglas de contraste

- **Elementos interactivos** deben usar teal (`#4ECDC4`) o dorado (`#F9C74F`) sobre superficie oscura (`#3D3530` / `#1A1A2E`) — ratio de contraste mínimo 4.5:1
- **Props neutros** (columnas rotas, plataformas inactivas) se mantienen en la gama piedra oscura/media para no competir visualmente con los interactivos
- **Estado activo vs. inactivo:** la diferencia visual debe ser evidente sin depender del color exclusivamente (añadir animación de brillo o partículas para accesibilidad)

### Guía de materiales emisivos

Todos los materiales con emisivo en Godot usan `StandardMaterial3D`:

```
emission_enabled = true
emission = Color(#4ECDC4)        # o el color correspondiente al asset
emission_energy = 1.5            # mínimo visible en escena con iluminación general
emission_energy = 2.0            # máximo para cristales en primer plano
```

- **No superar** `emission_energy = 2.5` para evitar bloom excesivo con el `WorldEnvironment` por defecto
- El canal de textura emisiva (256×256 px) define qué zonas del mesh emiten; el resto del albedo queda sin emisión

### Luces WorldEnvironment

| Tipo | Configuración | Propósito |
|---|---|---|
| `WorldEnvironment` | Sky: procedural, sky_top `#845EC2`, sky_horizon `#FF6B6B`, ambient: `#2A2035` | Atmósfera base de la isla |
| `DirectionalLight3D` | Color `#FFF0CC`, energy 1.2, angle 45°, shadow enabled | Sol cálido de atardecer |
| `OmniLight3D` (por grupo de cristales) | Color `#4ECDC4`, energy 1.5, range 2–3m | Fill local en cristales activos |
| `ReflectionProbe` (por zona) | Resolution 256, interior mode | Reflexiones en superficies de piedra pulida y portales |

---

## 3. Descripción Técnica: Personaje Principal

### Información visual

- **Arquetipo:** Joven aventurero/a de 16–19 años, género andrógino, expresión neutral amigable
- **Silueta:** Cabeza ligeramente grande, hombros definidos, proporciones heroicas estilizadas — **7 cabezas de alto** (1.75m total)
- **Outfit:** Túnica corta con patrón geométrico teal, pantalón ajustado gris-oscuro, botas teal con suela gruesa, guantes sin dedos
- **Accesorios:** Mochila con viales de cristal visibles lateralmente; escáner de muñeca con núcleo azul luminiscente
- **Lectura desde cámara cenital (tercera persona):** cabello con volumen lateral claramente reconocible + mochila visible en espalda — la silueta es unívoca desde 4–5m de distancia de cámara

### Especificaciones técnicas

| Parte | Triángulos |
|---|---|
| Cabeza | ~800 tri |
| Cuerpo | ~1,200 tri |
| Ropa / capas | ~800 tri |
| Accesorios (mochila, escáner) | ~600 tri |
| Manos / pies | ~400 tri |
| **Total** | **3,000–5,000 tri** |

- **Texturas:** Diffuse 1024×1024 px | Normal Map 512×512 px | Emisivo (accesorios) 256×256 px
- **Rig:** 28 huesos — espina ×5, cadera ×1, hombros ×2, brazos ×4, manos ×4, piernas ×4, pies ×2, cabeza ×1, cuello ×1, cola-mochila ×2
- **Peso de pintado:** máximo 4 influences por vértice

### Animaciones base

| Animación | Duración | Notas |
|---|---|---|
| `idle` | 2s loop | Respiración sutil, parpadeo ocasional |
| `walk` | 1.2s loop | Root motion habilitado |
| `run` | 0.8s loop | Root motion habilitado |
| `jump_start` | — | Frame de salto (pose contraída) |
| `jump_air` | — | Frame de vuelo (pose extendida) |
| `jump_land` | — | Frame de aterrizaje (absorción de impacto) |
| `examine` | 1.5s | Mirar objeto — dobla torso y cuello hacia adelante |
| `activate` | 1.2s | Extender brazo con escáner hacia interactable |

### Nodo Godot 4

```
CharacterBody3D (protagonist)
├── CollisionShape3D (CapsuleShape3D h:1.8m r:0.3m)
├── MeshInstance3D (body_mesh)
├── Skeleton3D
│   └── BoneAttachment3D → MeshInstance3D (backpack)
├── AnimationPlayer / AnimationTree
│   └── AnimationStateMachine (Idle → Walk → Run, Jump branch)
├── Camera3D (offset: 0, 2, -4 — tercera persona)
├── SpringArm3D (length: 4m, collision mask: escenario)
└── InteractionRayCast (RayCast3D, 2m frente, layer: interactables)
```

### GDScript: Controlador de movimiento

```gdscript
extends CharacterBody3D

@export var speed: float = 5.0
@export var run_speed: float = 9.0
@export var jump_velocity: float = 5.5
@onready var anim_tree: AnimationTree = $AnimationTree

const GRAVITY = -12.0

func _physics_process(delta: float) -> void:
    if not is_on_floor():
        velocity.y += GRAVITY * delta

    var input_dir = Vector3(
        Input.get_axis("ui_left", "ui_right"),
        0,
        Input.get_axis("ui_up", "ui_down")
    ).normalized()

    var is_running = Input.is_action_pressed("run")
    var target_speed = run_speed if is_running else speed

    velocity.x = input_dir.x * target_speed
    velocity.z = input_dir.z * target_speed

    if Input.is_action_just_pressed("ui_accept") and is_on_floor():
        velocity.y = jump_velocity

    anim_tree["parameters/blend_position"] = velocity.length() / run_speed
    move_and_slide()
```

---

## 4. Descripción Técnica: Escenario — Isla Flotante

### Visual

- **Dimensiones generales:** ≈60×40m, flotando en cielo fantástico
- **Bordes:** irregulares naturales de roca, con zonas planas habilitadas como superficie de juego
- **Ruinas:** pilares, arcos de piedra tallada, puertas con marcos, murallas parciales con vegetación
- **Cristales:** emergiendo de grietas y montículos — comunicación visual de energía y puntos de interés
- **Tecnología antigua:** engranajes decorativos, conductos de energía grabados en piedra, mecanismos visibles en paredes

### Especificaciones técnicas

- **Sistema modular:** chunks de 8×8m para occlusion culling en Godot (`OccluderInstance3D` por chunk)
- **LOD:** 3 niveles por chunk — High ≤8k tri, Mid ≤3k tri, Far ≤800 tri
- **Colliders:** `CollisionShape3D` simples (`BoxShape3D` / `ConvexPolygonShape3D`); **nunca** usar la malla completa como collider
- **UV2:** Mapa secundario para lightmap baking — bake con `WorldEnvironment` + `ReflectionProbe` por zona antes de integrar
- **Iluminación:** `DirectionalLight3D` (sol, 45°, sombras ON) + `OmniLight3D` teal por grupo de cristales

### Variantes de zona

| Zona | Área | Elemento clave | Iluminación dominante |
|---|---|---|---|
| Entrada | 20×20m | Arco de bienvenida, camino claro al interior | Luz solar directa, sombras largas |
| Puzzle | 15×15m | Cristales activables + paneles de suelo reactivos | Emisivo teal intenso, sin luz solar directa |
| Zona Elevada | Puente 5×30m | Plataformas flotantes escalonadas sobre vacío | Azul frío, neblina volumétrica leve |
| Portal Final | 25×25m | Portal 3m de diámetro + altar central | Teal-púrpura dramático, OmniLight púrpura fuerte |

---

## 5. Descripción Técnica: Props (7 elementos)

### 5.1 Cristal de Energía

- **Visual:** Prisma hexagonal facetado, translúcido azul-cyan, con núcleo brillante interno diferenciado del exterior
- **Dimensiones:** Ø20cm × 80cm de alto
- **Triángulos:** 120–200 tri (muy low-poly, facetas planas sin suavizado)
- **Material:** `StandardMaterial3D` — albedo `#88D8E0`, transparencia ALPHA_DEPTH_PRE_PASS, `emission_enabled = true`, emission `#4ECDC4`, `emission_energy = 2.0`
- **Nodo Godot:**
  ```
  StaticBody3D
  ├── MeshInstance3D (crystal_hex)
  └── OmniLight3D (range: 2m, color: #4ECDC4, energy: 1.5)
  ```
- **Prompt de generación:** `"Stylized low-poly hexagonal crystal, faceted cyan gem, glowing inner core, translucent with emissive teal light, simple geometry, game prop, white background"`

---

### 5.2 Portal Circular

- **Visual:** Anillo de piedra de 3m de diámetro con runas grabadas en relieve; vórtice azul-violeta activo en el centro
- **Dimensiones:** 3m Ø × 0.4m de profundidad, base de piedra 0.5m de alto
- **Triángulos:** 800–1,200 tri (anillo con detalle de runas) + plano del vórtice: 2 tri (gestionado por shader)
- **Material anillo:** Piedra grabada, roughness 0.8, normal map de runas
- **Material vórtice:** Shader spatial con noise animado (ver código)

**Shader vórtice (Godot 4):**

```gdscript
shader_type spatial;
uniform float time : hint_range(0, 100) = 0.0;

void fragment() {
    vec2 uv = UV - 0.5;
    float r = length(uv);
    float angle = atan(uv.y, uv.x) + time * 2.0;
    float swirl = sin(angle * 6.0 + r * 20.0 - time * 3.0);
    ALBEDO = mix(vec3(0.48, 0.37, 0.65), vec3(0.30, 0.80, 0.78), swirl * 0.5 + 0.5);
    EMISSION = ALBEDO * 1.5;
    ALPHA = smoothstep(0.5, 0.3, r);
}
```

- **Nodo Godot:**
  ```
  Node3D "Portal"
  ├── MeshInstance3D (ring)
  ├── MeshInstance3D (vortex_plane)
  ├── AnimationPlayer (rota parámetro time del shader)
  ├── Area3D (trigger de zona)
  │   └── CollisionShape3D (CylinderShape3D r:1.4m h:0.5m)
  └── OmniLight3D (color: #7B5EA7, energy: 2.0, range: 4m)
  ```
- **Prompt de generación:** `"Stylized ancient stone circular portal, 3-meter ring with carved runes, glowing blue-purple energy vortex swirling in center, magical fantasy game prop, dramatic light emanating from portal"`

---

### 5.3 Cofre Reliquia

- **Visual:** Cofre de piedra de 60cm, bandas de cobre-dorado en aristas, símbolo geométrico grabado en tapa
- **Dimensiones:** 60×40×35cm (largo × ancho × alto)
- **Triángulos:** 300–500 tri
- **Estados:**
  - **Cerrado:** tapa horizontal, sin emisión
  - **Abierto:** tapa rotada 110° hacia atrás, interior con emisión dorada suave (`#F9C74F`, energy 1.0)
- **Nodo Godot:**
  ```
  StaticBody3D
  ├── MeshInstance3D (chest_body)
  ├── MeshInstance3D (chest_lid)
  ├── AnimationPlayer (animaciones: open, close)
  └── Area3D (pickup trigger)
      └── CollisionShape3D (BoxShape3D)
  ```
- **Prompt de generación:** `"Stylized stone chest with gold metal band trim, geometric lock symbol on lid, ancient fantasy game prop, weathered stone texture, copper accents"`

---

### 5.4 Interruptor / Palanca

- **Visual:** Palanca con mango en T de piedra integrada en pared; panel de indicador rúnico por encima con estado on/off
- **Dimensiones:** Palanca 15×8cm, panel indicador 30cm alto
- **Triángulos:** 150–250 tri
- **Estados:**
  - **Off:** runa gris apagada, palanca inclinada a la izquierda
  - **On:** runa teal brillante (`emission_energy = 2.0`), palanca inclinada a la derecha + sonido click
- **Nodo Godot:**
  ```
  StaticBody3D
  ├── MeshInstance3D (lever_body)
  ├── MeshInstance3D (rune_indicator)
  ├── AnimationPlayer (animaciones: pull_lever_on, pull_lever_off)
  └── Area3D (interaction trigger)
      └── CollisionShape3D (BoxShape3D)
  ```
- **Prompt de generación:** `"Stylized ancient stone wall lever switch, T-bar handle, glowing rune indicator panel above, tech-ancient aesthetic, game interactable prop"`

---

### 5.5 Plataforma Móvil

- **Visual:** Losa de piedra 2×2m, superficie superior lisa, runas teal grabadas en la cara inferior (efecto de levitación)
- **Dimensiones:** 2.0×0.3×2.0m (largo × alto × profundo)
- **Triángulos:** 200–400 tri
- **Movimiento:** `AnimationPlayer` con oscilación en Y ±2m, duración 2s, curva ease-in-out
- **Nodo Godot:**
  ```
  AnimatableBody3D
  ├── MeshInstance3D (platform_slab)
  │   └── Material inferior: emission #4ECDC4, energy 1.5
  ├── CollisionShape3D (BoxShape3D 2×0.3×2m)
  └── AnimationPlayer (animación: float_up_down)
  ```
- **Prompt de generación:** `"Stylized ancient stone platform tile, 2-meter square slab, smooth flat top, teal glowing levitation runes on underside, floating game prop"`

---

### 5.6 Columna Rota

- **Visual:** Pilar de 1.5m restante, fractura limpia en el corte superior, bandas decorativas horizontales, musgo suave en base y grietas
- **Dimensiones:** Ø40cm × 1.5m de alto
- **Triángulos:** 300–500 tri
- **Variantes:** 2 meshes — fractura recta (corte perpendicular) / fractura diagonal (corte a 30°)
- **Nodo Godot:**
  ```
  StaticBody3D
  ├── MeshInstance3D (column_broken)
  └── CollisionShape3D (CylinderShape3D r:0.2m h:1.5m)
  ```
- **Prompt de generación:** `"Stylized broken ancient stone column, 1.5 meters tall, clean fracture at top, carved decorative bands, subtle moss, stylized game environment prop"`

---

### 5.7 Fragmento Coleccionable

- **Visual:** Esquirla de cristal de ~10cm, emisivo dorado-blanco, rodeado de aura de partículas doradas
- **Dimensiones:** ~10cm (escala relativa al personaje: 0.06×)
- **Triángulos:** 60–100 tri (icosaedro simplificado, sin suavizado)
- **Comportamiento:** Rotación Y continua + bob up-down sinusoidal; `GPUParticles3D` de destello al recoger
- **Nodo Godot:**
  ```
  Area3D "Fragment"
  ├── MeshInstance3D (crystal_shard)
  │   └── Material: emission #F9C74F, energy 2.0
  ├── OmniLight3D (color: #F9C74F, energy: 1.0, range: 0.5m)
  ├── GPUParticles3D (burst al recoger, 0.2s)
  ├── AnimationPlayer (animación: spin_bob — loop)
  └── CollisionShape3D (SphereShape3D r:0.15m)
  ```

**GDScript — Fragmento Coleccionable:**

```gdscript
extends Area3D

signal fragment_collected(fragment: Area3D)

func _ready():
    body_entered.connect(_on_collected)

func _on_collected(body: Node3D) -> void:
    if body.is_in_group("player"):
        fragment_collected.emit(self)
        $GPUParticles3D.emitting = true
        $AnimationPlayer.play("collect_burst")
        await $AnimationPlayer.animation_finished
        queue_free()
```

- **Prompt de generación:** `"Stylized tiny crystal shard collectible, 10cm golden-white glowing gem fragment, sparkle particle aura, floating pose, fantasy game pickup item, clean white background"`

---

## 6. Descripción Técnica: UI / HUD

### Elementos del HUD

| Elemento | Posición | Anchor | Tamaño | Nodo Godot |
|---|---|---|---|---|
| EnergyBar | Superior izquierda | `TOP_LEFT` | 220×28px | `TextureProgressBar` |
| FragmentCounter | Superior derecha | `TOP_RIGHT` | 120×40px | `HBoxContainer` |
| InteractionPrompt | Centro inferior | `BOTTOM_CENTER` | 260×50px | `Panel` |

### Árbol de nodos completo

```
CanvasLayer (layer: 1)
└── HUD (Control, full_rect)
    ├── TopBar (Panel, anchor: top-full, fondo #1A1A2E @ 75% opacidad)
    │   ├── EnergySection (HBoxContainer, margin_left: 16)
    │   │   ├── EnergyIcon (TextureRect, 24×24px, crystal_icon.png)
    │   │   ├── EnergyBar (TextureProgressBar, 200×20px, fill color #4ECDC4)
    │   │   └── EnergyLabel (Label, "ENERGÍA", Rajdhani 12px, #FFFFFF)
    │   └── FragmentSection (HBoxContainer, margin_right: 16)
    │       ├── CrystalIcon (TextureRect, 20×20px, fragment_icon.png)
    │       └── CountLabel (Label, "3 / 7", Rajdhani Bold 18px, #F9C74F)
    └── InteractionPrompt (Panel, anchor: bottom_center, visible: false)
        └── HBoxContainer
            ├── KeyLabel (Label, "[E]", Orbitron Bold 14px, color: #4ECDC4)
            └── ActionLabel (Label, "Activar Portal", Rajdhani 14px, color: #FFFFFF)
```

**Fuentes recomendadas:**
- `Rajdhani` (Google Fonts, libre): texto general del HUD — legible a tamaño pequeño
- `Orbitron` (Google Fonts, libre): teclas y acentos — refuerza la estética tecnología-antigua

### GDScript — HUD Manager

```gdscript
extends CanvasLayer

@onready var energy_bar: TextureProgressBar = $HUD/TopBar/EnergySection/EnergyBar
@onready var count_label: Label = $HUD/TopBar/FragmentSection/CountLabel
@onready var prompt_panel: Panel = $HUD/InteractionPrompt
@onready var action_label: Label = $HUD/InteractionPrompt/HBoxContainer/ActionLabel

func update_energy(current: float, maximum: float) -> void:
    energy_bar.value = (current / maximum) * 100.0

func update_fragments(collected: int, total: int) -> void:
    count_label.text = "%d / %d" % [collected, total]

func show_interaction_prompt(action_text: String) -> void:
    action_label.text = action_text
    prompt_panel.visible = true

func hide_interaction_prompt() -> void:
    prompt_panel.visible = false
```

---

## 7. Pipeline de Producción en Blender → Godot

### 7.1 Configuración de Blender

- **Unidades:** Meters, `scene unit scale = 1.0` — 1 Blender Unit = 1 metro en Godot
- **Estilo de modelado:** Subdivisión baja + Shade Smooth selectivo en caras curvas; la mayoría de caras planas permanece con flat shading para mantener el look low-poly
- **UV:** Smart UV Project como base + ajuste manual en elementos clave (cara del personaje, runas en portal)
- **Materiales en Blender:** Solo Principled BSDF con Diffuse/Roughness — sin nodos complejos que no exportan a glTF. Los materiales emisivos se configuran directamente en Godot tras importar

### 7.2 Exportación desde Blender (GLB)

```
File → Export → glTF 2.0 (.glb / .gltf)

Opciones recomendadas:
  ✅ Include: Selected Objects
  ✅ Transform: Y Forward, Z Up → DESACTIVAR (Godot gestiona la conversión automáticamente)
  ✅ Geometry: Apply Modifiers
  ✅ Geometry: UVs
  ✅ Geometry: Normals
  ✅ Geometry: Vertex Colors
  ✅ Armatures: Export Deformation Bones Only (solo para el personaje)
  ✅ Animation: Group by NLA Track
  ✅ Animation: Always Export Action (personaje)
  ❌ Compression (Draco): OFF — Godot tiene su propio sistema de compresión en importación
```

> **Truco:** Aplicar `Ctrl+A → All Transforms` antes de exportar para evitar el bug de escala 100× en Godot.

### 7.3 Importación en Godot 4

**Configuración global en Project Settings → Import Defaults → 3D Scene:**
```
Root Type: Node3D
Root Name: [nombre del archivo .glb]
Animation: Import All
Animation: Store in: AnimationLibrary (separada del .glb)
```

**Configuración por asset en Inspector → Import tab:**

| Asset | Opciones clave |
|---|---|
| Personaje | Meshes → Generate LODs: ON | Animation → Import: ON, FPS: 30, Store in AnimationLibrary |
| Props | Meshes → Generate LODs: ON | Physics → Generate: ON (StaticBody3D automático) |
| Escenario (chunks) | Meshes → Lightmap UV2: ON (para bake posterior) | Physics → Generate: ON |

### 7.4 Estructura de Carpetas del Proyecto Godot

```
res://
├── assets/
│   ├── characters/
│   │   ├── protagonist/
│   │   │   ├── protagonist.glb
│   │   │   ├── protagonist.tscn
│   │   │   ├── textures/
│   │   │   │   ├── diffuse.png
│   │   │   │   └── normal.png
│   │   │   └── animations/  (AnimationLibrary .res)
│   │   └── [otros personajes]
│   ├── environment/
│   │   ├── island_main/
│   │   │   ├── chunks/  (chunk_00_00.glb … chunk_07_04.glb)
│   │   │   ├── textures/
│   │   │   └── lightmaps/
│   │   └── zones/
│   │       ├── entrance.tscn
│   │       ├── puzzle.tscn
│   │       ├── elevated.tscn
│   │       └── portal.tscn
│   ├── props/
│   │   ├── crystal_energy.glb       + crystal_energy.tscn
│   │   ├── portal_circular.glb      + portal_circular.tscn
│   │   ├── chest_relic.glb          + chest_relic.tscn
│   │   ├── lever_switch.glb         + lever_switch.tscn
│   │   ├── platform_mobile.glb      + platform_mobile.tscn
│   │   ├── column_broken.glb        + column_broken.tscn
│   │   └── fragment_collectible.glb + fragment_collectible.tscn
│   └── ui/
│       ├── hud.tscn
│       ├── textures/  (crystal_icon.png, fragment_icon.png, panel_ninepatch.png)
│       └── fonts/     (Rajdhani.ttf, Orbitron.ttf)
├── scripts/
│   ├── player/
│   │   ├── player_controller.gd
│   │   └── player_interaction.gd
│   ├── props/
│   │   ├── fragment.gd
│   │   ├── lever.gd
│   │   ├── platform.gd
│   │   └── portal.gd
│   └── ui/
│       ├── hud.gd
│       └── game_events.gd
└── scenes/
    ├── main_island.tscn
    └── game_manager.tscn
```

### 7.5 Sistema de Señales Global (Autoload)

Registrar `game_events.gd` como Autoload con el nombre `GameEvents` en `Project → Project Settings → Globals → Autoload`.

```gdscript
# scripts/ui/game_events.gd  (Autoload: "GameEvents")
extends Node

signal fragment_collected(fragment_id: String, total: int)
signal energy_changed(current: float, maximum: float)
signal portal_activated(portal_id: String)
signal interaction_available(action_text: String)
signal interaction_unavailable

# Emisión (desde props/scripts de juego):
#   GameEvents.fragment_collected.emit("frag_01", 3)
#
# Suscripción (desde HUD, en _ready):
#   GameEvents.fragment_collected.connect(hud.update_fragments)
#   GameEvents.energy_changed.connect(hud.update_energy)
#   GameEvents.interaction_available.connect(hud.show_interaction_prompt)
#   GameEvents.interaction_unavailable.connect(hud.hide_interaction_prompt)
```

---

## 8. Escalas de Referencia

| Objeto | Altura / Dimensión | Escala relativa al personaje |
|---|---|---|
| Personaje | 1.75m | 1.0× |
| Puerta antigua | 2.8m | 1.6× |
| Portal circular | 3.0m Ø | 1.7× |
| Cristal de energía | 0.8m alto | 0.46× |
| Plataforma móvil | 2.0×2.0m | — |
| Columna rota | 1.5m alto | 0.86× |
| Cofre reliquia | 0.6m ancho | 0.34× |
| Fragmento coleccionable | 0.10m | 0.06× |
| Cámara (tercera persona) | offset (0, 2.0, −4.0) | SpringArm3D 4m de longitud |

---

## 9. Checklist de Validación por Asset

Completar antes de integrar cada asset en la escena de Godot:

- [ ] Triángulos dentro del presupuesto establecido para ese asset
- [ ] Sin vértices duplicados — ejecutar `Merge by Distance` en Blender antes de exportar
- [ ] Normales orientadas hacia afuera — verificar con `Face Orientation` overlay (todo azul)
- [ ] UV sin solapamientos, excepto piezas simétricas deliberadas con UVs compartidos
- [ ] Origen del objeto en punto lógico: base para props verticales, centro para cristales y fragmentos
- [ ] Nombre del objeto y de la malla descriptivos — prohibido "Cube.001", "Material.003"
- [ ] GLB importado correctamente — abrir en viewport de Godot y verificar escala, orientación y materiales
- [ ] `CollisionShape3D` asignada en `.tscn` como forma primitiva — **no usar la malla como collider**
- [ ] Material emisivo configurado con `emission_energy` en rango correcto (1.5–2.0)
- [ ] Script de comportamiento conectado — señales verificadas en output del debugger
- [ ] LOD generado para props con >500 tri (Import tab → Generate LODs: ON)
- [ ] Animaciones verificadas en `AnimationTree` del personaje — todos los estados transicionan correctamente

---

## 10. Problemas Comunes y Soluciones

| Problema | Causa probable | Solución |
|---|---|---|
| Asset aparece 100× más grande en Godot | Escala de Blender sin aplicar al exportar | `Ctrl+A → Apply All Transforms` antes de exportar GLB |
| Animación no importa en Godot | Sin NLA Track activo en Blender | `Action Editor → Push Down` para enviar acción a NLA |
| Colores diferentes en Godot vs. Blender | Espacio de color incorrecto en importación | Texturas a `sRGB` en Import Settings de Godot; datos (normal maps) a `Linear` |
| Emisivo no se ve en escena | `emission_energy` demasiado baja o property no activada | Activar `emission_enabled = true` y subir a 1.5–2.0 en `StandardMaterial3D` |
| Colisiones extrañas o el personaje se atasca | Mesh compleja usada como collider | Reemplazar por `CapsuleShape3D` / `BoxShape3D` simples |
| Shader del portal no compila | Sintaxis de Godot 3 en proyecto Godot 4 | Usar `shader_type spatial;` (no `canvas_item`) y sintaxis GDShader 4.x |
| Fragmento no emite señal al recoger | Señal no conectada al Autoload GameEvents | Verificar que `GameEvents` está registrado en `Project Settings → Autoload` |
| Plataforma atraviesa al personaje | `AnimatableBody3D` sin sincronización de física | Confirmar que el body usa `sync_to_physics = true` y no `move_and_collide` manual |
| LOD pop-in visible a corta distancia | Distancias de LOD demasiado cortas | `GeometryInstance3D → LOD Bias` → aumentar; o ajustar distancias en Import |
| UI no escala en resoluciones distintas | `Control` raíz sin anchors configurados | Usar `full_rect` en el HUD raíz + anchors + margins en todos los hijos |

---

*Generado para producción indie — Fragmentos de Luz © 2025*
*Engine: Godot 4.x | Modelado: Blender 3.6+ | Estilo: 3D Stylized*
