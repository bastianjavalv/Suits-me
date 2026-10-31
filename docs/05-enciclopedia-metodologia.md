# Hito 5 — Enciclopedia histórica: metodología

## Estructura

- **Fichas de tipología** (`game/data/enciclopedia/<era>.json`): conocimiento histórico verificable
  sobre un tipo de prenda, una técnica o un fenómeno (por ejemplo, «Hopalanda» o «Ropa de utilidad
  (CC41)»).
- **Ficha de cada prenda** (dentro de `game/data/prendas/<era>.json`, campo `ficha`): descripción
  del diseño del juego, tipo de pieza, atribución, materiales del modelo, silueta y uso. Se enlaza
  con sus tipologías mediante identificadores únicos (`tipologias`).
- **Fuentes** (`game/data/enciclopedia/fuentes.json`): una sola lista con identificador, autor o
  institución, título, URL, fecha de consulta y método.

La pantalla **HISTORIA DE LA PRENDA** compone las tres capas y numera las fuentes citadas.

## Estados de cada afirmación

| Estado | Significado | Requisito |
|---|---|---|
| ✔ verificado | La afirmación aparece en las fuentes citadas | Al menos una fuente |
| ⚠ discutido | Las fuentes discrepan o solo una lo afirma | Al menos una fuente y explicación |
| ◇ interpretación | Lectura del equipo, no un hecho documentado | Sin fuente, siempre marcada |

Los validadores (`encyclopedia.gd` y `tools/validate_data.py`) rechazan afirmaciones verificadas o
discutidas sin fuente, fuentes inexistentes, prendas sin ficha y atribuciones «documentadas» sin
fuente.

## Prendas del juego frente a piezas históricas

Todas las prendas jugables son **diseños originales inspirados en su época**
(`tipo_pieza: "interpretacion_de_epoca"`, `atribucion: "sin_atribucion"`). Cuando una prenda
evoca a una casa o diseñador documentado, se indica en `influencias` con el rótulo «no implica
autoría». Las piezas reales solo aparecen como **piezas de referencia** con su museo y su fuente.

Por respeto a derechos vigentes, el juego no reproduce motivos protegidos ni logotipos: no hay
langosta de Dalí, ni cierre de doble F, ni composiciones de Mondrian (el estampado de retícula es
genérico).

## Cómo se verificó

- Fecha: 30 de octubre de 2026.
- Método: buscador web restringido a dominios institucionales (Fashion Institute of Technology,
  The Metropolitan Museum of Art, Victoria and Albert Museum, Encyclopaedia Britannica, Imperial
  War Museums, Kyoto Costume Institute, Philadelphia Museum of Art y el archivo de la casa Dior).
- Limitación: la política de red del entorno de desarrollo impidió abrir las páginas
  directamente; la verificación se apoyó en los extractos del buscador. Por eso todas las fichas
  tienen `"revision_humana": false` hasta que una persona contraste cada fuente.

## Correcciones que la verificación obligó a hacer

| Dato previsto | Resultado de la verificación |
|---|---|
| Medias de nailon a la venta en 1939 | Britannica: hacia **1940**. Se corrigió y se trasladó a los años 40 |
| Delphos de Fortuny, 1907 | V&A: desde 1907; Met: invención en 1909 → **discutido** |
| Plisado del Delphos inventado por Fortuny | Patente de 1909 a su nombre, pero sus anotaciones reconocen a **Henriette Nigrin**; el V&A revisó su catálogo → **discutido** |
| Mary Quant inventó la minifalda | V&A: no hay pruebas concluyentes → **discutido** |
| 500 000 copias del vestido «Letty Lynton» | Una sola fuente → **discutido** |
| «Pop-over» de McCardell, 1942 | Una página del FIT dice 1940 → **discutido** |
| Bliaut | Solo se halló en una ficha de vestuario cinematográfico del FIT → nota de fuente secundaria |
| Tacón de aguja inventado por Vivier | Atribución frecuente pero no unánime → **discutido** |

## Cómo añadir o corregir una ficha

Ver la sección 12 del [tutorial](TUTORIAL.md). Tras editar los datos:

```bash
python tools/validate_data.py
```

```bash
python tools/gen_docs_eras.py
```

El segundo comando regenera `docs/eras/`, que la CI exige mantener al día.
