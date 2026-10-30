# Informe de auditoría del APK: SUITSME-0.13272.apk

> **Procedencia:** informe generado con `apk_audit` 1.0.0 en la computadora del propietario del repositorio y regenerado con la versión 1.1.0 a partir de su JSON: se ocultaron los hosts propios del proyecto (base de datos y almacenamiento) y se corrigió el backend de scripts (IL2CPP, deducido de `global-metadata.dat`). En la tabla de recursos, la categoría «otros» corresponde casi por completo a los 12 archivos DEX (unos 77 MB), que la versión 1.0.0 no clasificaba.

Generado por `apk_audit` 1.0.0 el 2026-10-30T21:31:50Z (UTC). Análisis de solo lectura: no se extrajo ni se modificó ningún recurso.

## 1. Identificación e integridad

| Campo | Valor |
| --- | --- |
| Tamaño | 112.0 MB (117436851 bytes) |
| SHA-256 | `1a89f20fd4ebef41918338cdaa66aeb57fcdde2d69ad4964bfc61709cf27bd83` |
| SHA-1 | `9bdd16fc6c8d870edb79a45205327f7c90af4594` |
| MD5 | `2b66340475ea2fcc39b216d462fbfa91` |
| ZIP válido (CRC de todas las entradas) | sí |
| Entradas | 1673 |
| Tamaño descomprimido | 132.1 MB |
| Esquemas de firma | esquema v2, esquema v3 |
| Certificado 1 - sujeto | C=US, ST=California, L=Mountain View, O=Google Inc., OU=Android, CN=Android |
| Certificado 1 - emisor | C=US, ST=California, L=Mountain View, O=Google Inc., OU=Android, CN=Android |
| Certificado 1 - validez | 2020-11-26 a 2050-11-26 |
| Certificado 1 - huella SHA-256 | `1fbffe85907e4d4748f5e99173ac61a269e5463f9bdce6f5766d5b4a10b033a2` |

> **Advertencia:** El manifiesto indica que la app requiere APK divididos (splits): este archivo puede no contener todas las bibliotecas o recursos del juego.

> **Advertencia:** No hay bibliotecas nativas en el APK aunque el motor las necesita: faltan los APK de configuración de ABI.

## 2. Manifiesto

| Campo | Valor |
| --- | --- |
| paquete | com.style.fashion.game.suitsme |
| versionName | 0.13272 |
| versionCode | 13272 |
| minSdk | 26 |
| targetSdk | 36 |
| compileSdkVersion | 36 |
| actividad_principal | com.unity3d.player.UnityPlayerActivity |
| application.name | com.safedk.android.SafeDKApplication |
| application.label | @0x7f120026 |
| application.allowBackup | True |
| application.extractNativeLibs | True |

**Permisos (38):** `com.sec.android.provider.badge.permission.READ`, `com.sec.android.provider.badge.permission.WRITE`, `com.htc.launcher.permission.READ_SETTINGS`, `com.htc.launcher.permission.UPDATE_SHORTCUT`, `com.sonyericsson.home.permission.BROADCAST_BADGE`, `com.sonymobile.home.permission.PROVIDER_INSERT_BADGE`, `com.anddoes.launcher.permission.UPDATE_COUNT`, `com.majeur.launcher.permission.UPDATE_BADGE`, `com.huawei.android.launcher.permission.CHANGE_BADGE`, `com.huawei.android.launcher.permission.READ_SETTINGS`, `com.huawei.android.launcher.permission.WRITE_SETTINGS`, `android.permission.READ_APP_BADGE`, `com.oppo.launcher.permission.READ_SETTINGS`, `com.oppo.launcher.permission.WRITE_SETTINGS`, `com.google.android.gms.permission.AD_ID`, `android.permission.INTERNET`, `android.permission.ACCESS_NETWORK_STATE`, `android.permission.READ_PHONE_STATE`, `android.permission.ACCESS_WIFI_STATE`, `com.google.android.c2dm.permission.RECEIVE`, `android.permission.WAKE_LOCK`, `com.suitsme.club.suitsme.permission.C2D_MESSAGE`, `com.style.fashion.game.suitsme.permission.C2D_MESSAGE`, `android.permission.POST_NOTIFICATIONS`, `android.permission.VIBRATE`, `android.permission.ACCESS_ADSERVICES_AD_ID`, `android.permission.ACCESS_ADSERVICES_ATTRIBUTION`, `android.permission.ACCESS_ADSERVICES_TOPICS`, `android.permission.FOREGROUND_SERVICE`, `android.permission.ACCESS_ADSERVICES_CUSTOM_AUDIENCE`, `com.amazon.privacypass.ATTEST`, `com.android.vending.CHECK_LICENSE`, `com.android.vending.BILLING`, `com.google.android.finsky.permission.BIND_GET_INSTALL_REFERRER_SERVICE`, `com.google.android.providers.gsf.permission.READ_GSERVICES`, `com.style.fashion.game.suitsme.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION`, `com.samsung.android.mapsagent.permission.READ_APP_INFO`, `com.huawei.appmarket.service.commondata.permission.GET_COMMON_DATA`

**Componentes:** 96 actividades, 19 servicios, 18 receptores, 16 proveedores.

**Meta-datos** (valores largos redactados para no publicar identificadores):

- `com.google.firebase.messaging.default_notification_icon` = `@0x7f080208`
- `com.tapjoy.appstore` = `Google`
- `com.google.android.gms.version` = `@0x7f0b000e`
- `com.google.android.gms.ads.flag.OPTIMIZE_INITIALIZATION` = `True`
- `com.google.android.gms.ads.flag.OPTIMIZE_AD_LOADING` = `True`
- `com.facebook.sdk.ApplicationId` = ` 130********1066`
- `com.facebook.sdk.ClientToken` = `3fea************************774a`
- `com.facebook.sdk.AutoLogAppEventsEnabled` = `True`
- `com.facebook.sdk.AdvertiserIDCollectionEnabled` = `True`
- `unity.notification.default_activity` = `com.******************************vity`
- `unity.splash-mode` = `0`
- `unity.splash-enable` = `True`
- `unity.launch-fullscreen` = `True`
- `unity.render-outside-safearea` = `True`
- `notch.config` = `port**********cape`
- `unity.auto-report-fully-drawn` = `True`
- `unity.strip-engine-code` = `True`
- `unity.auto-set-game-state` = `True`
- `unityplayer.UnityActivity` = `True`
- `notch_support` = `True`
- `android.support.FILE_PROVIDER_PATHS` = `@0x7f150006`
- `applovin.sdk.verbose_logging` = `True`
- `com.google.android.gms.ads.APPLICATION_ID` = `ca-a******************************1200`
- `androidx.lifecycle.ProcessLifecycleInitializer` = `andr********rtup`
- `com.unity3d.services.core.configuration.AdsSdkInitializer` = `andr********rtup`
- `androidx.work.WorkManagerInitializer` = `andr********rtup`
- `androidx.profileinstaller.ProfileInstallerInitializer` = `andr********rtup`
- `com.google.android.gms.cloudmessaging.FINISHED_AFTER_HANDLED` = `True`
- `com.google.firebase.components:com.google.firebase.messaging.FirebaseMessagingKtxRegistrar` = `com.*****************************************trar`
- `com.google.firebase.components:com.google.firebase.messaging.FirebaseMessagingRegistrar` = `com.*****************************************trar`
- `com.google.firebase.components:com.google.firebase.auth.FirebaseAuthRegistrar` = `com.*****************************************trar`
- `com.google.firebase.components:com.google.firebase.iid.Registrar` = `com.*****************************************trar`
- `com.google.firebase.components:com.google.firebase.remoteconfig.FirebaseRemoteConfigKtxRegistrar` = `com.*****************************************trar`
- `com.google.firebase.components:com.google.firebase.remoteconfig.RemoteConfigRegistrar` = `com.*****************************************trar`
- `com.google.firebase.components:com.google.firebase.crashlytics.ndk.CrashlyticsNdkRegistrar` = `com.*****************************************trar`
- `com.google.firebase.components:com.google.firebase.analytics.connector.internal.AnalyticsConnectorRegistrar` = `com.*****************************************trar`
- `com.google.firebase.components:com.google.firebase.crashlytics.FirebaseCrashlyticsKtxRegistrar` = `com.*****************************************trar`
- `com.google.firebase.components:com.google.firebase.crashlytics.CrashlyticsRegistrar` = `com.*****************************************trar`
- `com.google.firebase.components:com.google.firebase.sessions.FirebaseSessionsRegistrar` = `com.*****************************************trar`
- `com.google.firebase.components:com.google.firebase.installations.FirebaseInstallationsKtxRegistrar` = `com.*****************************************trar`
- `com.google.firebase.components:com.google.firebase.installations.FirebaseInstallationsRegistrar` = `com.*****************************************trar`
- `com.google.firebase.components:com.google.firebase.ktx.FirebaseCommonLegacyRegistrar` = `com.*****************************************trar`
- `com.google.firebase.components:com.google.firebase.FirebaseCommonKtxRegistrar` = `com.*****************************************trar`
- `com.google.firebase.components:com.google.firebase.abt.component.AbtRegistrar` = `com.*****************************************trar`
- `com.google.firebase.components:com.google.firebase.datatransport.TransportRegistrar` = `com.*****************************************trar`
- `com.google.android.play.billingclient.version` = `9.0.0`
- `androidx.credentials.CREDENTIAL_PROVIDER_KEY` = `andr************************************************************Impl`
- `com.bytedance.sdk.pangle.version` = `8.1.0.3`
- `android.support.FILE_PROVIDER_PATHS` = `@0x7f150007`
- `com.unity.androidnotifications.exact_scheduling` = `0`
- `com.google.unity.ads.UNITY_VERSION` = `6000.0.58f2`
- `android.webkit.WebView.EnableSafeBrowsing` = `True`
- `backend:com.google.android.datatransport.cct.CctBackendFactory` = `cct`
- `com.android.vending.splits.required` = `True`
- `com.android.stamp.source` = `http*********************tore`
- `com.android.stamp.type` = `STAM*******************_APK`
- `com.android.vending.splits` = `@0x7f150008`
- `com.android.vending.derived.apk.id` = `3`

## 3. Motor, arquitecturas y bibliotecas nativas

**Motor detectado:** Unity

- Evidencias de Unity: carpeta assets/bin/Data
- backend_scripting: IL2CPP
- il2cpp_metadata: {"magia_valida": true, "version": 31, "nota": "Los nombres de clases y metodos estan en este archivo; no se lee su contenido."}
- version_unity: 6000.0.58f2
- version_fuente: assets/bin/Data/data.unity3d
- addressables: False
- streaming_assets: 44

**ABIs:** ninguna

## 4. Código Java/Kotlin (DEX) y SDK de terceros

Archivos DEX: 11. Clases definidas: 61717. (Solo se leyeron las tablas de nombres.)

| SDK | Categoría | Clases |
| --- | --- | --- |
| Firebase Analytics | analitica | 36 |
| Google Analytics for Firebase (medicion) | analitica | 459 |
| AppsFlyer | atribucion | 455 |
| Google Play Billing | compras | 255 |
| Firebase Remote Config | configuracion remota | 111 |
| Firebase Authentication | cuentas | 213 |
| Inicio de sesion de Google | cuentas | 232 |
| Firebase Crashlytics | errores | 394 |
| ID de publicidad de Google | identificador publicitario | 5 |
| IAB Open Measurement | medicion publicitaria | 910 |
| Unity Player (motor) | motor | 199 |
| Firebase Cloud Messaging | notificaciones | 132 |
| Google Play Core | plataforma | 249 |
| User Messaging Platform (consentimiento) | privacidad | 19 |
| Adaptadores de mediacion AdMob | publicidad | 7 |
| AppLovin / MAX | publicidad | 1927 |
| Digital Turbine / Fyber | publicidad | 1658 |
| Google Mobile Ads (AdMob) | publicidad | 653 |
| InMobi | publicidad | 1938 |
| Meta Audience Network | publicidad | 171 |
| Mintegral | publicidad | 3577 |
| Pangle | publicidad | 2440 |
| Unity Ads | publicidad | 1276 |
| Unity Ads (servicios) | publicidad | 1133 |
| Unity LevelPlay (mediacion) | publicidad | 43 |
| Vungle / Liftoff | publicidad | 719 |
| ironSource / Unity LevelPlay | publicidad | 3264 |
| Facebook SDK | social | 1266 |

Paquetes con más clases: `com.google.android` (13506), `com.mbridge.msdk` (3577), `com.bytedance.sdk` (3091), `io.bidmachine.media3` (2630), `com.google.common` (2133), `com.inmobi.media` (1851), `com.ironsource` (1748), `com.fyber.inneractive` (1623), `com.google.firebase` (1410), `com.unity3d.ads` (1276), `com.unity3d.services` (1133), `com.applovin.impl` (1132), `androidx.media3.exoplayer` (1131), `com.ironsource.adqualitysdk` (1051), `com.explorestack.protobuf` (964)

## 5. Dependencias de red citadas

Dominios encontrados en tablas de cadenas y archivos de configuración (150):

`.facebook.com`, `[proyecto].firebaseio.com`, `[proyecto].s3.eu-central-1.amazonaws.com`, `a.applovin.com`, `a.applvn.com`, `accounts.google.com`, `admob-gmats.uc.r.appspot.com`, `ads.inmobi.com`, `adx.ads.vungle.com`, `analytics.us.tiktok.com`, `aomedia.org`, `api.bidmachine.io`, `api.tapresearch.com`, `api16-access-sg.pangle.io`, `api16-access-ttp.tiktokpangle.us`, `app-measurement.com`, `applovin.com`, `apps.apple.com`, `assets.applovin.com`, `b.applovin.com`, `cdn2.inner-active.mobi`, `cdnjs.cloudflare.com`, `compliance.iabtechnologylab.com`, `config.ads.vungle.com`, `config.inmobi.com`, `config.safedk.com`, `crash-metrics.sdk.inmobi.com`, `csi.gstatic.com`, `d.applovin.com`, `d.applvn.com`, `dash.applovin.com`, `dashif.org`, `default.url`, `dev.tapjoy.com`, `developer.android.com`, `developer.apple.com`, `developers.facebook.com`, `developers.google.com`, `edge.safedk.com`, `events.ads.vungle.com`, `fabu.care`, `fabu.onelink.me`, `facebook.com`, `fb.gg`, `firebase-settings.crashlytics.com`, `firebase.google.com`, `firebaseremoteconfig.googleapis.com`, `firebaseremoteconfigrealtime.googleapis.com`, `fonts.googleapis.com`, `fundingchoicesmessages.google.com`, `g.co`, `gateway-b.offerwall.unity3d.com`, `gateway.unityads.unity3d.com`, `gist.github.com`, `github.com`, `goo.gl`, `goo.gle`, `google.com`, `googleads.g.doubleclick.net`, `hoth.tapresearch.com`, `i-sdk.mediation.unity3d.com`, `iabtechlab.com`, `imasdk.googleapis.com`, `img.applovin.com`, `init-mp.fyber.com`, `instagram.com`, `issuetracker.google.com`, `lf-static.tiktokpangle-cdn-us.com`, `local.com`, `log-activity.templates.inmobi.com`, `login.live.com`, `login.yahoo.com`, `logs.ads.vungle.com`, `maps.app.goo.gl`, `md.applovin.com`, `md.applvn.com`, `mediation.goog`, `monetization-support.applovin.com`, `ms.applovin.com`, `ms.applvn.com`, `o-crash.mediation.unity3d.com`, `o-ext.mediation.unity3d.com`, `o-sdk.mediation.unity3d.com`, `p.applov.in`, `pagead2.googlesyndication.com`, `pdn.applovin.com`, `play.google.com`, `privacy-sandbox.appsflyersdk.com`, `privacy.vungle.com`, `prod-a.applovin.com`, `pubads.g.doubleclick.net`, `res.applovin.com`, `res1.applovin.com`, `res2.applovin.com`, `res3.applovin.com`, `rt.applovin.com`, `rt.applvn.com`, `scar.unityads.unity3d.com`, `schemas.applovin.com`, `schemas.microsoft.com`, `sdk-orchestrator-hoth.tapresearch.com`, `sdk-orchestrator.tapresearch.com`, `sf16-static.i18n-pglstatp.com`, `spadsync.com`, `stage-assets.applovin.com`, `stage-img.applovin.com`, `stage-pdn.applovin.com`, `stage-vid.applovin.com`, `sts.applovin.com`, `supply.inmobicdn.net`, `support.axon.ai`, `support.google.com`, `tally.so`, `telemetry.sdk.inmobi.com`, `tizen.org`, `tools.iabtechlab.com`, `twitter.com`, `u.appl.vn`, `unif-id.ssp.inmobi.com`, `vastproxy.brand.inmobi.com`, `vid.applovin.com`, `webview.unityads.unity3d.com`, `whatwg.org`, `www.123.com`, `www.amazon.com`, `www.apache.org`, `www.applovin.com`, `www.example.com`, `www.facebook.com`, `www.fyber.com`, `www.google.com`, `www.googleadservices.com`, `www.googleapis.com`, `www.googletagmanager.com`, `www.inmobi.com`, `www.linkedin.com`, `www.pangleglobal.com`, `www.paypal.com`, `www.pinterest.com`, `www.recaptcha.net`, `www.samsungapps.com`, `www.suitsme.live`, `www.supersonicads.com`, `www.tapresearch.com`, `www.tiktok.com`, `www.youtube.com`, `x.blueduckredapple.com`, `x.everestop.io`, `x.thecatmachine.com`, `youtrack.jetbrains.com`

## 6. Recursos

| Categoría | Archivos | Tamaño |
| --- | --- | --- |
| otros | 203 | 79.1 MB |
| paquete Unity (AssetBundle/serializado) | 3 | 28.9 MB |
| datos/configuracion | 615 | 20.4 MB |
| textura/imagen | 843 | 2.1 MB |
| codigo/script | 7 | 1.6 MB |
| fuente tipografica | 2 | 52.9 KB |

Ubicaciones más pesadas (carpeta o archivo de primer nivel): `assets/bin` (48.3 MB), `classes6.dex` (8.0 MB), `classes9.dex` (7.8 MB), `classes7.dex` (7.6 MB), `classes3.dex` (7.6 MB), `classes8.dex` (7.5 MB), `classes5.dex` (7.5 MB), `classes4.dex` (7.4 MB), `classes.dex` (7.0 MB), `classes2.dex` (7.0 MB)

## 7. Evaluación de viabilidad del port

**Veredicto:** port directo no viable desde el APK.

- Un APK contiene el juego ya compilado para Android. Nintendo Switch no ejecuta APK ni el entorno de Android, por lo que el archivo no puede instalarse ni convertirse directamente.
- Motor: Unity 6000.0.58f2 (backend de scripts: IL2CPP).
- Con IL2CPP el código C# del juego está traducido a C++ y compilado como código máquina ARM dentro de libil2cpp.so. Ese binario está enlazado al runtime de Android y no puede recompilarse para otra plataforma: el código fuente no está en el APK.
- Unity permite compilar para Nintendo Switch, pero solo desde el proyecto original y con el módulo de plataforma que Unity entrega a desarrolladores autorizados por Nintendo.
- Dependencias de servicios externos detectadas (analitica, atribucion, compras, configuracion remota, cuentas, errores, identificador publicitario, medicion publicitaria, notificaciones, plataforma, privacidad, publicidad, social): en una versión sin conexión deben eliminarse o sustituirse por sistemas locales.
- Este archivo es el APK base de una instalacion dividida de Google Play (Android App Bundle): no incluye los APK de configuracion con las bibliotecas nativas, asi que ni siquiera se ejecutaria por si solo en Android.

**Requisitos externos para un port oficial:**

- Proyecto fuente de Unity del titular de los derechos (no recuperable desde el APK).
- Licencia o acuerdo escrito del titular de los derechos para portar el juego y sus recursos.
- Alta como desarrollador en el Nintendo Developer Portal y acceso al SDK y kits de desarrollo.
- Módulo de compilación de Unity para Nintendo Switch (se obtiene tras la autorización de Nintendo).

## 8. Limitaciones del análisis

- Análisis estático de estructura: no se ejecuta la aplicación ni se observa su tráfico de red.
- Los SDK se identifican por prefijos de paquete; el código ofuscado o renombrado puede no detectarse.
- Si el juego descarga contenido adicional (paquetes de recursos o descargas en línea), ese contenido no está en este archivo.
