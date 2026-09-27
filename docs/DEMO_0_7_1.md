# Demo 0.7.1: estabilizacion

Revision del 27 de septiembre de 2026. Se conserva el contenido de las fases
anteriores; esta entrega prioriza continuidad de partida y el personaje nuevo.

## Neri texturizado

El GLB nuevo contiene 113.906 triangulos y tres mapas de 2048 x 2048: color,
normal y metal/rugosidad. No contiene esqueleto ni animaciones. Se alinea con el
modelo previamente riggeado en reposo, transfiere sus pesos y exporta 40.000
triangulos, 65 huesos y once clips. La cara mantiene mas detalle que el cuerpo.
Los pesos se limitan a cuatro influencias normalizadas por vertice.

El constructor verifica la proximidad de ambas superficies antes de transferir
pesos y falla si una futura fuente cambia demasiado de forma o de pose. Conserva
UVs, mapas PBR y fuentes originales. Corrige los pesos de la cabeza, coloca las
suelas sobre el origen del jugador y ajusta la altura de los clips terrestres.
Las colisiones y la velocidad del jugador no dependen de ese ajuste visual.

No hay animacion facial ni IK de pies sobre pendientes. La topologia sigue siendo
generada; manos, articulaciones y ropa pueden necesitar un retoque artistico.

## Correcciones de continuidad

- Repetir el prologo vuelve al menu y no borra la marca de historia vista.
- Saltarlo al continuar respeta la isla guardada, en lugar de cargar Auralia siempre.
- Un fallo al guardar cancela el viaje y restaura el estado anterior.
- El mapa bloquea acciones que quedan debajo del comic, dialogo o habilidades.
- Al terminar el comic se guarda la marca y se devuelve el foco al boton de viaje.
- Las postales responden a cambios de tamano sin tener que seleccionar otra isla.
- Destellos, escudo y brujula quedan detras del diario y de las ventanas modales.
- El Heraldo pausa movimiento, barrido y exposicion mientras el jugador esta bloqueado.
- Las corrientes laterales liberan la columna invisible que antes quedaba huerfana.
- Todos los modos QA quedan aislados de los guardados reales, incluso sin `--qa` base.

## Comprobaciones reproducibles

`source_tools/validate_demo.py` importa primero y exige un informe nuevo por caso,
salida correcta del proceso y ausencia de errores de ejecucion. Un informe antiguo
no puede convertir en exitosa una prueba que no termino. Cualquier `ERROR` de Godot,
tambien durante el cierre, hace fallar la validacion. Las pruebas detienen el audio
y dan tiempo real al hilo de sonido para liberar los reproductores antes de salir.

La bateria incluye guardado/migraciones, regresiones de la demo, ruta de Auralia,
combate, guardian, mando, memorias, las tres islas siguientes, habilidades, avatar,
menu, mapa, arte opcional y prologo. El avatar se comprueba con deformacion real
de la malla, no solo contando huesos o detectando que un clip se reproduce.
El bucle de musica del prologo se mide con tiempo real, no con el reloj acelerado
de las pruebas. Se revisan capturas a 1440 x 900 y pantallas compactas a 800 x 640.

Los informes y capturas quedan en `artifacts/validation/<fecha>/`. No se modifican
los archivos de partida del jugador ni las capturas historicas de otras fases.

Resultados locales del 27 de septiembre:

- Pasada grafica completa: 16 baterias y 510 comprobaciones correctas,
  `20260927T141039_477046Z`.
- Tres repeticiones sin ventana, despues de unificar el cierre del audio:
  33 baterias y 1.098 comprobaciones correctas, `20260927T194443_808682Z`.
- Revalidacion visual del personaje, regresiones, prologo, arte, menu, mapa y
  habilidades: siete baterias correctas, `20260927T194921_591734Z`.
- Ultimo ajuste de orden del HUD: avatar (65) y habilidades (39), correctos,
  `20260927T195230_412998Z`.

Estas pasadas finales no registraron errores ni advertencias de Godot. Las
capturas verificadas incluyen el personaje de frente/espalda y sus once clips,
diario compacto, prologo, menus y habilidades. La captura del README procede
del juego ejecutandose, no de una ilustracion ni de un render externo.

## Pendiente antes de distribuir

- Recorrido manual completo con teclado y mando fisico; las pruebas automatizadas
  no sustituyen la valoracion de dificultad, sonido y sensacion de control.
- Medir rendimiento en otros equipos y revisar pendientes/contactos de pies.
- Confirmar derechos del modelo Meshy y completar los creditos de distribucion.
- Crear un ejecutable con las plantillas de exportacion correspondientes a Godot.
- Completar las ilustraciones opcionales del PDF. Sus sustitutos actuales permiten jugar.

No se han anadido nuevos capitulos ni se declara esta revision como version final.
