# Circuito de arte: del procedural a la producción

## Situación actual

El maniquí, las 86 prendas y los 10 escenarios se generan por código. Los tejidos son PBR
(albedo, normales procedurales, rugosidad, metalicidad, anisotropía, brillo de borde y capa de
barniz) y distinguen seda, satén, crepé, georgette, algodón, lino, lana, gabardina, tweed, punto,
denim, cuero, ante, terciopelo, brocado, lamé, lentejuelas, encaje, tul, gasa, flecos, vinilo y
más (`game/data/tejidos.json`). Las prendas muestran costuras laterales y traseras, pespuntes en
el bajo, pliegues, caída y vaivén al girar.

Es una base jugable y coherente, pero no alcanza el realismo de un juego comercial con cuerpos
escaneados y prendas simuladas. Para llegar ahí hace falta un equipo de arte.

## Producción recomendada

| Recurso | Herramientas habituales | Entrega |
|---|---|---|
| Cuerpos y rostros realistas | Escultura y retopología, rigging con esqueleto humanoide | glTF 2.0 (`.glb`) con esqueleto |
| Prendas | Software de patronaje y simulación de tejidos con licencia | glTF por prenda, ajustada al cuerpo base, con pesos de piel |
| Texturas | Pintura o escaneo de tejidos | Albedo, normal, ORM (oclusión, rugosidad, metalicidad) |
| Peinados | Tarjetas de pelo con transparencia | glTF + texturas |

Solo se pueden usar recursos propios o con licencia que permita su uso comercial en consola.

## Presupuestos por prenda

| Perfil | Triángulos por prenda | Texturas | Materiales |
|---|---|---|---|
| Sobremesa | hasta 12 000 (límite comprobado por `test_meshes.gd`) | 1024² por mapa | 1–2 |
| Portátil | LOD a ~65 % | 512² por mapa | 1–2 |

Usar compresión ASTC (activada en el proyecto) y el sistema de LOD de Godot.

## Organización y control de versiones

- Archivos pesados (`.glb`, `.blend`, `.psd`, `.exr`, `.tif`, `.wav`, `.ogg`…) se gestionan con
  **Git LFS** (`.gitattributes` ya lo configura). Ejecutar `git lfs install` una vez.
- Estructura sugerida: `game/assets/prendas/<era>/<id>/<id>.glb` y sus texturas.
- `tools/check_repo.py` bloquea archivos de más de 5 MB que no estén en LFS.

## Integración futura en los datos

Hoy cada prenda declara `"modelo": {"generador": "...", "params": {...}}`. La extensión prevista
(no implementada) es un generador `"gltf"` con `"params": {"ruta": "res://assets/…/x.glb"}` que
`GarmentBuilder` cargaría en lugar de construir la malla. Hasta que exista, las prendas
procedurales siguen funcionando.
