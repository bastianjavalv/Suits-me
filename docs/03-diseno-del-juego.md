# Hito 3 — Diseño del juego

## Bucle principal

1. Elegir una época en **Eras de la Moda** (o entrar al vestidor libre).
2. Vestir el maniquí: probar prendas del armario, combinarlas y girar o acercar la vista.
3. Consultar la **Historia de la prenda** de cualquier pieza.
4. Guardar el look, hacer una foto o presentarlo a un **desafío**.
5. Leer la evaluación desglosada, mejorar y volver a presentar alternativas.

## Modos

| Modo | Qué ofrece |
|---|---|
| Vestidor | Armario por categorías y filtros, conjunto actual, poses, escenarios, modo foto |
| Eras de la Moda | Nueve capítulos con escenario, resumen, etapas y prendas propias |
| Desafíos | 27 de época (recreación histórica y creativos) y 3 libres |
| Mis looks | Looks guardados, borradores editables, historial de atuendos, papelera |
| Galería | Fotos de looks con opción de recrear el conjunto |
| Enciclopedia | 40 fichas con 105 afirmaciones verificadas, discutidas o interpretativas |

## Prendas y ranuras

Catorce categorías: vestido, parte de arriba, parte de abajo, abrigo, calzado, tocado, peinado,
maquillaje, joyería, guantes, bolso, cinturón, gafas y complemento de mano. Un vestido sustituye a
las partes de arriba y abajo y viceversa. Volver a elegir una prenda puesta la quita. Un abrigo
con mangas oculta las mangas de la ropa interior para que no la atraviesen.

## Economía local ilimitada

- Monedas y gemas se muestran como **∞**; toda compra se aprueba y nunca se descuenta saldo.
- Probar una prenda la añade gratis al armario; también se puede añadir toda la colección desde
  Opciones.
- El modo se configura en `game/data/config/economia.json` (`"modo": "ilimitado"`). Si el archivo
  de configuración dice «ilimitado», ninguna partida antigua puede volver a limitar el saldo.
- No hay micropagos, anuncios, temporizadores ni moneda «premium» real.

## Evaluación local transparente

| Criterio | Puntos | Cómo se calcula |
|---|---|---|
| Coherencia temática | 40 | 70 % prendas de la época pedida + 30 % prendas con el estilo del desafío; −8 por cada prenda que incumple una norma (por ejemplo, la ley suntuaria de 1322) |
| Armonía cromática | 25 | Esquema de color (monocromático, análogo, complementario, triádico…), penaliza 3+ colores muy saturados, premia neutros; si hay paleta sugerida, 40 % de cercanía perceptual (ΔE en CIELAB) |
| Completitud | 15 | 10 por categorías obligatorias y 5 por sugeridas; en «Cruce de épocas», mínimo de épocas distintas |
| Creatividad | 20 | 10 por complementos (hasta 3 tipos) + 10 por originalidad frente a tus entregas anteriores |

Estrellas: 60, 75 y 90 puntos. Cada criterio explica su puntuación con frases concretas. La
pantalla de resultado indica siempre: *«Evaluación local sin conexión: la calcula el juego con
reglas fijas y públicas. No es una votación de otros jugadores.»*

## Guardado y estabilidad

- Autoguardado 1,5 s después de cada cambio, al cerrar y al perder el foco o suspender.
- Escritura atómica con verificación: se escribe un temporal, se relee, se comprueba su SHA-256 y
  solo entonces sustituye a la partida.
- Copias de seguridad rotativas (hasta 10) y recuperación automática si la partida está dañada.
- Recuperación del conjunto en curso tras un cierre inesperado.
- Las prendas adquiridas nunca se pierden, ni siquiera si un archivo de datos se daña (se guardan
  como «huérfanas» hasta que vuelvan a existir).

## Accesibilidad y controles

Tamaño de texto (100/115/130 %), disposición de botones (automática, Nintendo o Xbox), giro
invertible y sensibilidad, vibración opcional, reasignación de controles, navegación completa con
mando, táctil, ratón o teclado. Detalle en [06-nintendo-switch.md](06-nintendo-switch.md).
