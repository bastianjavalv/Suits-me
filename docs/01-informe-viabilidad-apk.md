# Hito 1 — Informe de viabilidad del port de SUITSME a Nintendo Switch

**Estado:** completo. El análisis técnico se hizo con [`tools/apk_audit`](../tools/apk_audit/LEEME.md)
sobre el APK original, en la computadora del propietario del repositorio, porque la red del entorno
en la nube bloquea los servicios de descarga. El informe técnico íntegro está en
[`apk/informe_apk.md`](apk/informe_apk.md).

## Veredicto

**El port directo no es viable a partir del APK.** El juego está hecho con **Unity 6 (6000.0.58f2)**
y su código C# está compilado con **IL2CPP** a código máquina para Android. El APK no contiene el
proyecto fuente, y además es solo la parte *base* de una instalación dividida de Google Play: le
faltan las bibliotecas nativas. Un port real a Switch solo puede hacerlo **Zirafit Limited** (o un
estudio con su licencia), desde su proyecto de Unity y dentro del programa de desarrolladores de
Nintendo.

## 1. Recepción e integridad

| Dato | Valor | Verificación |
|---|---|---|
| Archivo | `SUITSME-0.13272.apk` | Nombre en Google Drive |
| Tamaño | 117 436 851 bytes (112,0 MB) | Drive y `apk_audit` coinciden |
| SHA-256 | `1a89f20fd4ebef41918338cdaa66aeb57fcdde2d69ad4964bfc61709cf27bd83` | `apk_audit` |
| SHA-1 | `9bdd16fc6c8d870edb79a45205327f7c90af4594` | `apk_audit` |
| ZIP | 1673 entradas, CRC correcto en todas (132,1 MB descomprimido) | `apk_audit` |
| DEX | 11 archivos (formato 038), suma de control correcta en todos | `apk_audit` |
| Firma | Esquemas v2 y v3, sello de origen v2 y bloque de metadatos de Google Play | `apk_audit` |
| Certificado | `CN=Android, OU=Android, O=Google Inc., L=Mountain View, ST=California, C=US`, válido 2020-11-26 a 2050-11-26, huella SHA-256 `1fbffe85…b033a2` | `apk_audit` |

**Procedencia.** El sujeto del certificado coincide con el de las claves que genera Google Play App
Signing, y los meta-datos `com.android.stamp.*` y `com.android.vending.derived.apk.id` indican un
APK derivado por Google Play a partir de un Android App Bundle. Es coherente con una copia obtenida
de Google Play (interpretación: la firma del sello no se verificó criptográficamente).

**El archivo original no se modificó**: la herramienta solo lo abre en modo lectura.

## 2. Identificación

| Campo | Valor |
|---|---|
| Paquete | `com.style.fashion.game.suitsme` |
| Versión | 0.13272 (código 13272) |
| Android mínimo / objetivo | API 26 (Android 8.0) / API 36 |
| Actividad principal | `com.unity3d.player.UnityPlayerActivity` |
| Componentes | 96 actividades, 19 servicios, 18 receptores, 16 proveedores |
| Gráficos | Requiere OpenGL ES 3.0; pantalla táctil declarada como no obligatoria |

## 3. Arquitectura técnica

- **Motor:** Unity 6, versión `6000.0.58f2` (leída en la cabecera de `data.unity3d` y confirmada por
  el meta-dato `com.google.unity.ads.UNITY_VERSION`).
- **Backend de scripts:** IL2CPP. `global-metadata.dat` (19,7 MB, versión de metadatos 31) solo existe
  en compilaciones IL2CPP. El código del juego se convierte a C++ y se compila a código máquina ARM.
- **APK dividido:** el manifiesto exige *splits* (`com.android.vending.splits.required`) y el archivo
  no contiene ninguna carpeta `lib/`. Las bibliotecas `libil2cpp.so` y `libunity.so` viajan en APK de
  configuración aparte. Este archivo, por sí solo, ni siquiera se ejecutaría en Android.
- **Datos del juego en el APK:** unos 48 MB en `assets/bin`, de los cuales 26,6 MB son
  `data.unity3d` (escenas y recursos comprimidos) y 3,7 MB recursos por defecto de Unity. Hay 44
  archivos fuera de `assets/bin` (recursos web de SDK de publicidad, entre otros).
- **Código Java/Kotlin:** 61 717 clases en 11 DEX, casi todas de SDK de terceros.

**Contenido en línea (inferencia, no verificada).** El APK contiene relativamente pocos datos del
juego para un catálogo amplio de prendas en 3D, y su código cita un almacenamiento de recursos en
Amazon S3 y una base de datos en tiempo real de Firebase propias del proyecto (hosts ocultos en el
anexo). Es probable que buena parte de las prendas se descargue en línea; confirmarlo exigiría
ejecutar la aplicación y observar su tráfico, cosa que no se hizo.

## 4. Dependencias en línea y monetización

| Función | SDK detectados (por nombres de clase) | En una versión sin conexión |
|---|---|---|
| Publicidad y mediación | AppLovin MAX (con SafeDK), ironSource / Unity LevelPlay, Unity Ads, Google AdMob, Meta Audience Network, Mintegral, Pangle, InMobi, Liftoff/Vungle, Digital Turbine/Fyber; además paquetes de BidMachine | Se eliminan: sin anuncios |
| Medición publicitaria | IAB Open Measurement, ID de publicidad (`AD_ID`) y APIs de Privacy Sandbox (`ACCESS_ADSERVICES_*`) | Se eliminan |
| Atribución | AppsFlyer | Se elimina |
| Analítica y errores | Firebase / Google Analytics, Crashlytics | Se elimina (registro local opcional) |
| Configuración remota y pruebas A/B | Firebase Remote Config | Configuración local en archivos de datos |
| Cuentas | Firebase Authentication, inicio de sesión de Google, Facebook SDK | Partida local sin cuenta |
| Notificaciones | Firebase Cloud Messaging (`POST_NOTIFICATIONS`) | Se eliminan |
| Compras | Google Play Billing 9.0.0 (`BILLING`) | Economía local ilimitada, sin pagos |
| Consentimiento | Google User Messaging Platform | No aplica: no se recogen datos |
| Backend propio | Base de datos en tiempo real de Firebase y almacenamiento en S3 del proyecto | Todo el contenido instalado localmente |

En total se citan 150 dominios (lista en el anexo). Permisos destacables: `INTERNET`,
`READ_PHONE_STATE`, `AD_ID`, `BILLING`, `CHECK_LICENSE`, `POST_NOTIFICATIONS` y permisos de
insignias de varios lanzadores.

## 5. Recursos recuperables

| Recurso | ¿Está en el APK? | ¿Se puede reutilizar aquí? |
|---|---|---|
| Código del juego | Solo como metadatos IL2CPP; el binario va en otro APK | No: compilado y sin licencia |
| Proyecto de Unity (escenas, prefabs, scripts) | No | No existe en el APK |
| Modelos, texturas y animaciones | Parte, dentro de `data.unity3d` (comprimido) | No sin licencia de Zirafit |
| Prendas descargables | Probablemente no (ver inferencia) | No |
| Tipografías | 2 archivos (52,9 KB) | No sin verificar su licencia |
| Marca, personajes e interfaz | Sí | No: propiedad de Zirafit |

Técnicamente existen herramientas que extraen recursos de paquetes de Unity, pero usarlos en otro
juego sin licencia infringiría los derechos de Zirafit; por eso no se extrajo ni se publicó nada.

## 6. Qué se puede saber de las mecánicas

El análisis estático no revela las mecánicas: están en el código IL2CPP y en los datos de Unity. Lo
que sí indican los componentes y permisos es la presencia de anuncios, compras integradas, inicio de
sesión, notificaciones y configuración remota. Las descripciones públicas del juego hablan de vestir
modelos 3D, maquillaje y peinados, desafíos de estilo y un armario amplio (fuentes públicas
consultadas con el buscador, sin acceso directo a la ficha de la tienda). Ver
[`04-mejoras-de-jugadores.md`](04-mejoras-de-jugadores.md).

## 7. Vías de portabilidad evaluadas

| Vía | Viable | Motivo |
|---|---|---|
| Instalar o emular el APK en Switch | No | Switch no ejecuta Android; además faltan las bibliotecas nativas |
| Recompilar a partir del APK | No | IL2CPP: no hay código C# ni proyecto de Unity que compilar |
| Extraer recursos y reconstruir el juego | No | Requiere licencia; el contenido descargable no está en el APK |
| **Port oficial de Zirafit** | **Sí** | Unity permite compilar para Switch desde el proyecto original con el módulo de plataforma para desarrolladores autorizados |

**Requisitos externos para un port oficial:** proyecto fuente de Unity y autorización de Zirafit
Limited; alta en el Nintendo Developer Portal con acceso al SDK, kits de desarrollo y certificación;
módulo de Unity para Switch; sustitución de todos los SDK de la sección 4.

## 8. Decisión adoptada

El propietario del repositorio eligió construir un **juego original** (*Atelier de las Eras*, título
provisional) con sus propios requisitos de diseño, sin código, arte, personajes, marca ni interfaz de
SUITSME. Es una obra nueva del mismo género, no un port ni una reconstrucción. Su estrategia técnica
está en [`02-estrategia-tecnica.md`](02-estrategia-tecnica.md).

## 9. Limitaciones

- Análisis estático: no se ejecutó la aplicación ni se observó su tráfico de red.
- Los SDK se identifican por prefijos de nombres de clase; algo ofuscado o renombrado puede faltar.
- La versión 1.0.0 de la herramienta clasificó los DEX como «otros» y no dedujo IL2CPP sin las
  bibliotecas nativas; ambas cosas se corrigieron en la 1.1.0 y se reflejan en el anexo.
