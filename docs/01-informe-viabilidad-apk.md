# Hito 1 — Informe de viabilidad del port de SUITSME a Nintendo Switch

**Estado del informe:** preliminar. La auditoría técnica del APK está **pendiente** porque el archivo
no pudo descargarse en el entorno de desarrollo (motivo abajo). Las secciones marcadas como
*pendiente* se completarán con el resultado de [`tools/apk_audit`](../tools/apk_audit/LEEME.md).

## 1. Recepción del APK

| Dato | Valor | Cómo se verificó |
|---|---|---|
| Nombre | `SUITSME-0.13272.apk` | Metadatos de Google Drive (conector autenticado) |
| Tamaño | 117 436 851 bytes (112,0 MB) | Metadatos de Google Drive |
| Ubicación | Carpeta de Drive “Suits-me apk” del propietario del repositorio | Conector de Google Drive |
| Versión aparente | 0.13272 | Solo por el nombre del archivo: **pendiente de confirmar en el manifiesto** |
| SHA-256 | **pendiente** | Requiere el archivo completo |

### Por qué no se pudo descargar

1. El conector de Google Drive solo descarga archivos de hasta 10 MB.
2. La política de red del entorno en la nube bloquea (HTTP 403 en el túnel del proxy) los dominios
   `drive.google.com`, `drive.usercontent.google.com`, `www.mediafire.com` y `ufile.io`.

Dos alternativas válidas:

- **Ejecutar la auditoría en una PC** con [`tools/apk_audit/apk_audit.py`](../tools/apk_audit/LEEME.md)
  (Python 3, sin dependencias) y añadir el informe generado a `docs/apk/informe_apk.md`.
- **Permitir un dominio de descarga** en la configuración de red del entorno (*Network access →
  Allowed domains*) y repetir la descarga en una sesión nueva.

En ningún caso se sube el APK al repositorio: es público y el archivo es propiedad de Zirafit Limited.

## 2. Datos públicos del juego (no verificados contra el APK)

Según páginas públicas encontradas con el buscador (BlueStacks, App Store), el juego *SUITSME:
Fashion Dress Up Game* lo publica **Zirafit Limited**, con el identificador de paquete
`com.style.fashion.game.suitsme`, y es gratuito con compras integradas. Estos datos deben
contrastarse con el manifiesto real.

## 3. Análisis técnico del APK — *pendiente*

Se completará con: integridad (SHA-256 y CRC de todas las entradas), firma y certificado, manifiesto
(paquete, versión, SDK, permisos), motor y versión, ABIs y bibliotecas nativas, SDK de terceros
(publicidad, analítica, compras), dominios de red y tipos de recursos.

## 4. Viabilidad: conclusiones que no dependen del contenido del APK

Estas conclusiones son válidas para cualquier APK, sea cual sea su motor:

1. **Switch no ejecuta Android.** Un APK contiene bytecode Dalvik (DEX) y bibliotecas nativas
   enlazadas a Android. Nintendo Switch usa su propio sistema operativo; no hay forma autorizada de
   instalar o convertir un APK.
2. **El APK no incluye el proyecto fuente.** Incluso cuando el motor tiene soporte oficial para Switch
   (Unity, Unreal, Godot mediante terceros), la compilación se hace desde el proyecto original: escenas,
   scripts y recursos en formato de editor. Eso no se puede reconstruir fielmente a partir de un
   APK compilado.
3. **Se necesita la autorización del titular.** Reutilizar código, modelos, texturas, personajes,
   marca o interfaz de SUITSME exige licencia de Zirafit Limited.
4. **Se necesita la autorización de Nintendo.** Para compilar y publicar en Switch hace falta
   registrarse en el Nintendo Developer Portal, obtener el SDK, kits de desarrollo y superar la
   certificación de Nintendo.

**Veredicto preliminar:** el port directo **no es viable desde el APK**. Un port oficial solo puede
hacerlo Zirafit o un estudio con su licencia, partiendo del proyecto original y dentro del programa
de desarrolladores de Nintendo.

## 5. Decisión tomada para este repositorio

El propietario del repositorio eligió construir, en lugar del port, un **juego original** que
implementa sus propios requisitos de diseño: *Eras de la Moda* (nueve capítulos), la enciclopedia
**Historia de la prenda**, juego sin conexión, monedas y gemas ilimitadas, las mejoras inspiradas en
las críticas habituales de jugadores del género y la adaptación a Switch (sobremesa, portátil,
Joy-Con, Pro Controller y pantalla táctil).

Ese juego **no es un port ni una reconstrucción de SUITSME**: tiene otro nombre, arte propio y
ningún recurso de Zirafit. La estrategia técnica se documenta en
[`02-estrategia-tecnica.md`](02-estrategia-tecnica.md).
