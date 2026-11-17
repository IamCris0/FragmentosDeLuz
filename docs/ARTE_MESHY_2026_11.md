# Integración artística del 17 de noviembre

Se recuperó el trabajo de noviembre que permanecía en el worktree de Claude:
el entorno del commit d83ea1a y los cuatro enemigos todavía sin commit.
La carpeta principal contiene ahora arco, árbol, columna, roca, Eco, Vigía,
Céfiro y Heraldo. Se conservaron los archivos originales y el worktree.

## Correcciones

- Los materiales individuales de enemigos sobreviven a la aplicación del estilo ambiental.
- La caché distingue materiales diferentes aunque compartan nombre.
- Árboles animados y runas luminosas también en las islas del capítulo II.
- Céfiro usa una malla continua con tres huesos, sin cortes en las alas.
  Tiene ciclos de vuelo, carga y recuperación; el diálogo detiene el aleteo.
  Editable: `blender/cefiro_demo.blend`. Constructor: `source_tools/build_meshy_enemies.py -- cefiro`.
- La cámara encuadra al Heraldo al entrar al combate y permite mirar más arriba con ratón o mando.
- Heraldo recibió texturas nuevas mediante Meshy, con soporte de mapas de material en el shader.
  La máscara resultó más oscura que la referencia marfil; queda pendiente valoración artística.

## Créditos y procedencia

Saldo consultado: 234. Tarea de retexturizado terminada: 10 créditos consumidos.
Saldo posterior verificado: **224** (144 mensuales y 80 permanentes).
No se regeneraron los ocho modelos anteriores. El manifiesto
`source_assets/meshy_manifest.json` conserva sus identificadores históricos y la nueva tarea.
La respuesta completa y la previsualización están en `artifacts/meshy_jobs/heraldo_retexture/`,
fuera de Git. El GLB nuevo se conserva en `source_assets/meshy_enemies/heraldo_retextured.glb`.

## Verificación

La batería visual completa pasó las 17 suites antes del último retexturizado
(`20261117T144533_220347Z`). La corrección de cámara pasó mando y Observatorio
(`20261117T145219_378552Z`). Las comprobaciones finales de texturas y combate se
guardan en la ejecución posterior de `artifacts/validation/`.

El caso `meshy` requiere `--visual`: verifica la deformación real de la piel,
los tres ciclos, aislamiento de materiales y texturas importadas. No es una
medición de rendimiento ni sustituye un recorrido manual de dificultad y sonido.

## Siguiente inversión recomendada

Conservar el modelo actual de Neri y pulir manos, contacto de pies y animación facial
antes de pagar por otro personaje. Revisar después la vegetación secundaria,
los faroles y las estructuras del Observatorio para igualar su detalle al arte nuevo.
Consultar de nuevo saldo y precio antes de cualquier generación futura.
