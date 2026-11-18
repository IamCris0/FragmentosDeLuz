# Fragmentos de Luz

Aventura 3D de exploracion, puzles y combate ligero. Dos capitulos jugables en
cuatro islas: Auralia, Grutas Prismaticas, Picos del Cefiro y Observatorio Estelar.

**Demo en desarrollo.** Neri utiliza el diseño aprobado, una textura pintada 2K,
un esqueleto nuevo de 24 huesos y once estados de animación.

Actualización de noviembre: ocho modelos Meshy integrados, Céfiro con alas articuladas,
materiales del Heraldo renovados y cámara de combate corregida.
Consulta [la revisión artística](docs/ARTE_MESHY_2026_11.md).

## Jugar o editar

1. Instala Godot; esta revision se ha probado con **Godot 4.7.2**, renderizador Forward+.
2. Importa `godot/project.godot` en Godot y ejecuta el proyecto.
3. En Windows puedes usar `Abrir_demo.cmd` o `Abrir_editor.cmd`. El lanzador busca
   `GODOT_EXE`, Godot en PATH y, finalmente, la instalacion local conocida.
   En otra maquina configura `GODOT_EXE` con la ruta del ejecutable.

La primera apertura importa los recursos. No hace falta Blender para jugar.
`Ver_prologo.cmd` reproduce el comic y regresa al menu sin borrar la partida.
No se incluye todavia un ejecutable independiente ni las plantillas de exportacion.

Controles: WASD, Espacio para saltar, Shift para correr, E para interactuar,
Q para el pulso, C para esquivar, J para el diario, K para las habilidades,
Esc para pausa. Camara con boton derecho y rueda. Tambien hay soporte de mando.

## Comprobar la demo

Desde la raiz del repositorio, con Python 3 y la ruta de Godot:

```powershell
python source_tools/validate_demo.py --godot "$env:GODOT_EXE"
python source_tools/validate_demo.py --godot "$env:GODOT_EXE" --visual
```

Las pruebas no leen ni escriben la partida del jugador. Cada ejecucion produce
informes nuevos en `artifacts/validation/`, fuera de Git. Comprueban guardados,
viajes, combate, las cuatro islas, habilidades, menus, prologo y el personaje.
`--visual` abre ventanas temporales y captura imagenes; `--repeat 3` repite los casos.
Estas pruebas aceleran la simulacion: **no son una medicion de rendimiento**.

## Modelo editable de Neri

- El concepto, el modelo, el rig y las animaciones originales están en `source_assets/neri_redesign/`.
- Abre `blender/neri_redesigned.blend` para editar el personaje y sus animaciones.
- Consulta las medidas y duraciones verificadas en `blender/neri_redesigned_metrics.json`.

```powershell
& 'C:\Program Files\Blender Foundation\Blender 5.2\blender.exe' --background --python-exit-code 1 --python source_tools/build_neri_redesign.py
```

Godot carga `neri_redesigned.glb`. Los archivos del modelo anterior se conservan como referencia.

## Estado y procedencia

Consultar [LEEME.md](LEEME.md) para el recorrido y los controles completos,
[DESARROLLO.md](DESARROLLO.md) para el historial y
[la estabilizacion de la demo](docs/DEMO_0_7_1.md) para cambios y limites.

El nuevo Neri y sus movimientos proceden de Meshy. Los recursos históricos
de Universal Animation Library conservan sus licencias en `source_assets/quaternius/`.
