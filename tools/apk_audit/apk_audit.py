#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
apk_audit.py - Auditoria estructural de un APK de Android (solo lectura).

Uso:
    python apk_audit.py RUTA/AL/ARCHIVO.apk [--salida CARPETA] [--sin-redaccion]

Genera dos archivos en la carpeta de salida (por defecto ./informe_apk):
    informe_apk.json  - datos completos, legibles por maquina
    informe_apk.md    - informe en espanol para personas

Que hace:
    * Calcula SHA-256, SHA-1 y MD5 y verifica el CRC de cada entrada del ZIP.
    * Lee la firma (esquemas v1/v2/v3) y el certificado del firmante.
    * Decodifica el AndroidManifest.xml binario (paquete, version, SDK,
      permisos, componentes, meta-datos).
    * Identifica el motor (Unity, Unreal, Godot, Flutter, Cocos, etc.),
      su version cuando es posible, las ABIs y las bibliotecas nativas.
    * Inventaria los SDK de terceros a partir de los nombres de clase de
      los archivos DEX (sin decompilar codigo) y los hosts de red citados.
    * Clasifica los recursos por tipo y emite una evaluacion de viabilidad
      de portabilidad.

Que NO hace:
    * No modifica el APK (lo abre en modo lectura).
    * No extrae ni guarda texturas, modelos, audio ni codigo.
    * No decompila: solo lee tablas de nombres y cabeceras.

Solo usa la biblioteca estandar de Python 3.8+.
"""
from __future__ import annotations

import argparse
import datetime as _dt
import hashlib
import json
import re
import struct
import sys
import zipfile
import zlib
from collections import Counter
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

VERSION_HERRAMIENTA = "1.1.0"

# ---------------------------------------------------------------------------
# Utilidades generales
# ---------------------------------------------------------------------------


def _hashes_de_archivo(ruta: Path) -> Dict[str, str]:
    sha256 = hashlib.sha256()
    sha1 = hashlib.sha1()
    md5 = hashlib.md5()
    with ruta.open("rb") as f:
        for bloque in iter(lambda: f.read(1024 * 1024), b""):
            sha256.update(bloque)
            sha1.update(bloque)
            md5.update(bloque)
    return {"sha256": sha256.hexdigest(), "sha1": sha1.hexdigest(), "md5": md5.hexdigest()}


def _tam_legible(n: int) -> str:
    unidades = ["B", "KB", "MB", "GB"]
    valor = float(n)
    for u in unidades:
        if valor < 1024 or u == unidades[-1]:
            return f"{valor:.1f} {u}" if u != "B" else f"{int(valor)} B"
        valor /= 1024
    return f"{n} B"


def redactar(valor: str) -> str:
    """Oculta la parte central de identificadores o claves (para informes publicos)."""
    if valor is None:
        return valor
    s = str(valor)
    if len(s) <= 8:
        return "*" * len(s)
    return s[:4] + "*" * (len(s) - 8) + s[-4:]


# ---------------------------------------------------------------------------
# AndroidManifest.xml binario (AXML)
# ---------------------------------------------------------------------------

RES_STRING_POOL_TYPE = 0x0001
RES_XML_TYPE = 0x0003
RES_XML_START_NAMESPACE_TYPE = 0x0100
RES_XML_END_NAMESPACE_TYPE = 0x0101
RES_XML_START_ELEMENT_TYPE = 0x0102
RES_XML_END_ELEMENT_TYPE = 0x0103
RES_XML_CDATA_TYPE = 0x0104
RES_XML_RESOURCE_MAP_TYPE = 0x0180

UTF8_FLAG = 1 << 8

TYPE_NULL = 0x00
TYPE_REFERENCE = 0x01
TYPE_ATTRIBUTE = 0x02
TYPE_STRING = 0x03
TYPE_FLOAT = 0x04
TYPE_DIMENSION = 0x05
TYPE_FRACTION = 0x06
TYPE_INT_DEC = 0x10
TYPE_INT_HEX = 0x11
TYPE_INT_BOOLEAN = 0x12

# Atributos frecuentes por identificador de recurso de Android, para manifiestos
# ofuscados donde el nombre del atributo aparece vacio.
ATRIBUTOS_ANDROID = {
    0x01010001: "label",
    0x01010002: "icon",
    0x01010003: "name",
    0x01010006: "permission",
    0x0101000F: "debuggable",
    0x01010010: "exported",
    0x01010024: "value",
    0x01010025: "resource",
    0x0101021B: "versionCode",
    0x0101021C: "versionName",
    0x0101020C: "minSdkVersion",
    0x01010270: "targetSdkVersion",
    0x01010271: "maxSdkVersion",
    0x01010280: "allowBackup",
    0x0101028E: "required",
    0x01010281: "glEsVersion",
    0x010104EC: "usesCleartextTraffic",
    0x01010527: "networkSecurityConfig",
    0x0101057A: "extractNativeLibs",
    0x01010572: "compileSdkVersion",
    0x01010573: "compileSdkVersionCodename",
    0x0101058C: "isSplitRequired",
}


class AxmlError(ValueError):
    pass


def _leer_string_pool(datos: bytes, inicio: int) -> List[str]:
    tipo, tam_cab, tam = struct.unpack_from("<HHI", datos, inicio)
    if tipo != RES_STRING_POOL_TYPE:
        raise AxmlError("se esperaba un string pool")
    n_str, n_estilos, flags, ini_str, _ini_estilos = struct.unpack_from("<IIIII", datos, inicio + 8)
    es_utf8 = bool(flags & UTF8_FLAG)
    offsets = struct.unpack_from("<%dI" % n_str, datos, inicio + tam_cab) if n_str else ()
    base = inicio + ini_str
    cadenas: List[str] = []
    for off in offsets:
        p = base + off
        if es_utf8:
            # longitud en caracteres (1 o 2 bytes) y luego longitud en bytes (1 o 2 bytes)
            n = datos[p]
            p += 1
            if n & 0x80:
                p += 1
            nb = datos[p]
            p += 1
            if nb & 0x80:
                nb = ((nb & 0x7F) << 8) | datos[p]
                p += 1
            cadenas.append(datos[p:p + nb].decode("utf-8", errors="replace"))
        else:
            n = struct.unpack_from("<H", datos, p)[0]
            p += 2
            if n & 0x8000:
                n = ((n & 0x7FFF) << 16) | struct.unpack_from("<H", datos, p)[0]
                p += 2
            cadenas.append(datos[p:p + n * 2].decode("utf-16-le", errors="replace"))
    return cadenas


def _valor_tipado(tipo: int, dato: int, cadenas: List[str]) -> Any:
    if tipo == TYPE_STRING:
        return cadenas[dato] if 0 <= dato < len(cadenas) else ""
    if tipo == TYPE_INT_BOOLEAN:
        return dato != 0
    if tipo == TYPE_INT_DEC:
        return struct.unpack("<i", struct.pack("<I", dato))[0]
    if tipo == TYPE_INT_HEX:
        return "0x%08x" % dato
    if tipo == TYPE_REFERENCE:
        return "@0x%08x" % dato
    if tipo == TYPE_ATTRIBUTE:
        return "?0x%08x" % dato
    if tipo == TYPE_FLOAT:
        return struct.unpack("<f", struct.pack("<I", dato))[0]
    if tipo == TYPE_NULL:
        return None
    return "0x%08x" % dato


def parse_axml(datos: bytes) -> Dict[str, Any]:
    """Decodifica XML binario de Android y devuelve un arbol {tag, attrs, children}."""
    if len(datos) < 8:
        raise AxmlError("archivo demasiado corto")
    tipo, tam_cab, tam_total = struct.unpack_from("<HHI", datos, 0)
    if tipo != RES_XML_TYPE:
        raise AxmlError("no es XML binario de Android (tipo 0x%04x)" % tipo)
    cadenas: List[str] = []
    mapa_recursos: List[int] = []
    raiz: Dict[str, Any] = {"tag": "#document", "attrs": {}, "children": []}
    pila = [raiz]
    p = tam_cab
    fin = min(tam_total, len(datos))
    while p + 8 <= fin:
        t, hs, tam = struct.unpack_from("<HHI", datos, p)
        if tam < 8:
            raise AxmlError("fragmento corrupto en el desplazamiento %d" % p)
        if t == RES_STRING_POOL_TYPE:
            cadenas = _leer_string_pool(datos, p)
        elif t == RES_XML_RESOURCE_MAP_TYPE:
            n = (tam - hs) // 4
            mapa_recursos = list(struct.unpack_from("<%dI" % n, datos, p + hs))
        elif t == RES_XML_START_ELEMENT_TYPE:
            ext = p + hs
            _ns, nombre_idx, attr_ini, attr_tam, attr_n = struct.unpack_from("<IIHHH", datos, ext)
            nodo = {"tag": cadenas[nombre_idx] if nombre_idx < len(cadenas) else "?", "attrs": {}, "children": []}
            for i in range(attr_n):
                a = ext + attr_ini + i * attr_tam
                _ans, a_nombre, a_raw, _sz, _r0, a_tipo, a_dato = struct.unpack_from("<IIIHBBI", datos, a)
                nombre = cadenas[a_nombre] if a_nombre < len(cadenas) else ""
                if not nombre and a_nombre < len(mapa_recursos):
                    nombre = ATRIBUTOS_ANDROID.get(mapa_recursos[a_nombre], "attr_0x%08x" % mapa_recursos[a_nombre])
                if a_raw != 0xFFFFFFFF and a_raw < len(cadenas):
                    valor = cadenas[a_raw]
                else:
                    valor = _valor_tipado(a_tipo, a_dato, cadenas)
                nodo["attrs"][nombre] = valor
            pila[-1]["children"].append(nodo)
            pila.append(nodo)
        elif t == RES_XML_END_ELEMENT_TYPE:
            if len(pila) > 1:
                pila.pop()
        p += tam
    return raiz


def _iter_nodos(nodo: Dict[str, Any]):
    yield nodo
    for h in nodo.get("children", []):
        yield from _iter_nodos(h)


def resumir_manifiesto(arbol: Dict[str, Any]) -> Dict[str, Any]:
    manifiesto = next((n for n in _iter_nodos(arbol) if n["tag"] == "manifest"), None)
    if manifiesto is None:
        raise AxmlError("no se encontro el elemento <manifest>")
    res: Dict[str, Any] = {
        "paquete": manifiesto["attrs"].get("package"),
        "versionName": manifiesto["attrs"].get("versionName"),
        "versionCode": manifiesto["attrs"].get("versionCode"),
        "compileSdkVersion": manifiesto["attrs"].get("compileSdkVersion"),
        "platformBuildVersionName": manifiesto["attrs"].get("platformBuildVersionName"),
        "isSplitRequired": manifiesto["attrs"].get("isSplitRequired"),
        "minSdk": None,
        "targetSdk": None,
        "permisos": [],
        "caracteristicas": [],
        "aplicacion": {},
        "actividades": [],
        "actividad_principal": None,
        "servicios": [],
        "receptores": [],
        "proveedores": [],
        "meta_datos": [],
    }
    for n in _iter_nodos(manifiesto):
        a = n["attrs"]
        tag = n["tag"]
        if tag == "uses-sdk":
            res["minSdk"] = a.get("minSdkVersion")
            res["targetSdk"] = a.get("targetSdkVersion")
        elif tag in ("uses-permission", "uses-permission-sdk-23"):
            if a.get("name"):
                res["permisos"].append(a["name"])
        elif tag == "uses-feature":
            res["caracteristicas"].append({k: a.get(k) for k in ("name", "required", "glEsVersion") if k in a})
        elif tag == "application":
            res["aplicacion"] = {k: a.get(k) for k in (
                "name", "label", "debuggable", "allowBackup", "usesCleartextTraffic",
                "networkSecurityConfig", "extractNativeLibs") if k in a}
        elif tag in ("activity", "activity-alias"):
            res["actividades"].append(a.get("name"))
            for filtro in n["children"]:
                if filtro["tag"] != "intent-filter":
                    continue
                acciones = {c["attrs"].get("name") for c in filtro["children"] if c["tag"] == "action"}
                categorias = {c["attrs"].get("name") for c in filtro["children"] if c["tag"] == "category"}
                if "android.intent.action.MAIN" in acciones and "android.intent.category.LAUNCHER" in categorias:
                    res["actividad_principal"] = a.get("name")
        elif tag == "service":
            res["servicios"].append(a.get("name"))
        elif tag == "receiver":
            res["receptores"].append(a.get("name"))
        elif tag == "provider":
            res["proveedores"].append(a.get("name"))
        elif tag == "meta-data":
            valor = a.get("value", a.get("resource"))
            res["meta_datos"].append({"nombre": a.get("name"), "valor": valor})
    return res


# ---------------------------------------------------------------------------
# DEX: tablas de cadenas, tipos y clases definidas (sin decompilar)
# ---------------------------------------------------------------------------


class DexError(ValueError):
    pass


def _uleb128(datos: bytes, p: int) -> Tuple[int, int]:
    resultado = 0
    desplazamiento = 0
    while True:
        b = datos[p]
        p += 1
        resultado |= (b & 0x7F) << desplazamiento
        if b < 0x80:
            return resultado, p
        desplazamiento += 7


def parse_dex(datos: bytes) -> Dict[str, Any]:
    if len(datos) < 0x70 or not datos.startswith(b"dex\n"):
        raise DexError("cabecera DEX no valida")
    version = datos[4:7].decode("ascii", errors="replace")
    checksum = struct.unpack_from("<I", datos, 8)[0]
    checksum_ok = (zlib.adler32(datos[12:]) & 0xFFFFFFFF) == checksum
    (n_str, off_str, n_tipos, off_tipos) = struct.unpack_from("<IIII", datos, 0x38)
    (n_clases, off_clases) = struct.unpack_from("<II", datos, 0x60)
    cadenas: List[str] = []
    for i in range(n_str):
        off_dato = struct.unpack_from("<I", datos, off_str + i * 4)[0]
        _n, p = _uleb128(datos, off_dato)
        fin = datos.index(b"\x00", p)
        cadenas.append(datos[p:fin].decode("utf-8", errors="replace"))
    tipos = [cadenas[struct.unpack_from("<I", datos, off_tipos + i * 4)[0]] for i in range(n_tipos)]
    clases = []
    for i in range(n_clases):
        idx_tipo = struct.unpack_from("<I", datos, off_clases + i * 32)[0]
        if idx_tipo < len(tipos):
            clases.append(tipos[idx_tipo])
    return {"version": version, "checksum_ok": checksum_ok, "cadenas": cadenas, "tipos": tipos, "clases": clases}


# Prefijo de paquete -> (nombre del SDK, categoria)
FIRMAS_SDK: List[Tuple[str, str, str]] = [
    ("com/unity3d/player/", "Unity Player (motor)", "motor"),
    ("com/google/android/gms/ads/identifier/", "ID de publicidad de Google", "identificador publicitario"),
    ("com/google/android/gms/ads/", "Google Mobile Ads (AdMob)", "publicidad"),
    ("com/google/ads/mediation/", "Adaptadores de mediacion AdMob", "publicidad"),
    ("com/applovin/", "AppLovin / MAX", "publicidad"),
    ("com/ironsource/", "ironSource / Unity LevelPlay", "publicidad"),
    ("com/unity3d/mediation/", "Unity LevelPlay (mediacion)", "publicidad"),
    ("com/unity3d/ads/", "Unity Ads", "publicidad"),
    ("com/unity3d/services/", "Unity Ads (servicios)", "publicidad"),
    ("com/vungle/", "Vungle / Liftoff", "publicidad"),
    ("com/facebook/ads/", "Meta Audience Network", "publicidad"),
    ("com/mbridge/", "Mintegral", "publicidad"),
    ("com/bytedance/sdk/openadsdk/", "Pangle", "publicidad"),
    ("com/fyber/", "Digital Turbine / Fyber", "publicidad"),
    ("com/inmobi/", "InMobi", "publicidad"),
    ("com/chartboost/", "Chartboost", "publicidad"),
    ("com/adcolony/", "AdColony", "publicidad"),
    ("com/my/target/", "myTarget", "publicidad"),
    ("com/yandex/mobile/ads/", "Yandex Mobile Ads", "publicidad"),
    ("com/smaato/", "Smaato", "publicidad"),
    ("com/amazon/device/ads/", "Amazon Publisher Services", "publicidad"),
    ("com/moloco/", "Moloco", "publicidad"),
    ("sg/bigo/ads/", "BIGO Ads", "publicidad"),
    ("com/iab/omid/", "IAB Open Measurement", "medicion publicitaria"),
    ("com/appsflyer/", "AppsFlyer", "atribucion"),
    ("com/adjust/sdk/", "Adjust", "atribucion"),
    ("io/branch/", "Branch", "atribucion"),
    ("com/singular/", "Singular", "atribucion"),
    ("com/tenjin/", "Tenjin", "atribucion"),
    ("com/google/firebase/analytics/", "Firebase Analytics", "analitica"),
    ("com/google/android/gms/measurement/", "Google Analytics for Firebase (medicion)", "analitica"),
    ("com/google/firebase/crashlytics/", "Firebase Crashlytics", "errores"),
    ("com/google/firebase/messaging/", "Firebase Cloud Messaging", "notificaciones"),
    ("com/google/firebase/remoteconfig/", "Firebase Remote Config", "configuracion remota"),
    ("com/google/firebase/firestore/", "Cloud Firestore", "backend"),
    ("com/google/firebase/database/", "Firebase Realtime Database", "backend"),
    ("com/google/firebase/auth/", "Firebase Authentication", "cuentas"),
    ("com/google/firebase/storage/", "Firebase Storage", "backend"),
    ("com/google/firebase/dynamiclinks/", "Firebase Dynamic Links", "enlaces"),
    ("com/google/firebase/inappmessaging/", "Firebase In-App Messaging", "mensajeria"),
    ("com/gameanalytics/", "GameAnalytics", "analitica"),
    ("com/amplitude/", "Amplitude", "analitica"),
    ("com/mixpanel/", "Mixpanel", "analitica"),
    ("com/flurry/", "Flurry", "analitica"),
    ("com/devtodev/", "devtodev", "analitica"),
    ("io/sentry/", "Sentry", "errores"),
    ("com/bugsnag/", "Bugsnag", "errores"),
    ("com/onesignal/", "OneSignal", "notificaciones"),
    ("com/helpshift/", "Helpshift", "soporte"),
    ("zendesk/", "Zendesk", "soporte"),
    ("com/facebook/", "Facebook SDK", "social"),
    ("com/google/android/gms/games/", "Google Play Games Services", "plataforma"),
    ("com/google/android/gms/auth/", "Inicio de sesion de Google", "cuentas"),
    ("com/android/billingclient/", "Google Play Billing", "compras"),
    ("com/unity3d/purchasing/", "Unity IAP", "compras"),
    ("com/unity/purchasing/", "Unity IAP", "compras"),
    ("com/revenuecat/", "RevenueCat", "compras"),
    ("com/google/android/play/core/assetpacks/", "Play Asset Delivery", "distribucion de recursos"),
    ("com/google/android/play/core/review/", "Play In-App Review", "plataforma"),
    ("com/google/android/play/core/appupdate/", "Play In-App Updates", "plataforma"),
    ("com/google/android/play/", "Google Play Core", "plataforma"),
    ("com/google/android/ump/", "User Messaging Platform (consentimiento)", "privacidad"),
    ("com/playfab/", "PlayFab", "backend"),
    ("com/huawei/hms/", "Huawei Mobile Services", "plataforma"),
]


def detectar_sdks(clases: List[str]) -> List[Dict[str, Any]]:
    conteo: Dict[str, Dict[str, Any]] = {}
    for c in clases:
        nombre = c[1:] if c.startswith("L") else c
        for prefijo, sdk, categoria in FIRMAS_SDK:
            if nombre.startswith(prefijo):
                d = conteo.setdefault(sdk, {"sdk": sdk, "categoria": categoria, "prefijo": prefijo, "clases": 0})
                d["clases"] += 1
                break
    return sorted(conteo.values(), key=lambda d: (d["categoria"], d["sdk"]))


def paquetes_principales(clases: List[str], profundidad: int = 3, limite: int = 25) -> List[Tuple[str, int]]:
    c = Counter()
    for nombre in clases:
        partes = nombre.strip("L;").split("/")[:-1]
        if partes:
            c[".".join(partes[:profundidad])] += 1
    return c.most_common(limite)


# Hosts que identifican recursos propios de un proyecto (bases de datos, almacenamiento): en los
# informes publicos se oculta la parte que identifica el proyecto.
PATRONES_HOST_PROYECTO = [
    re.compile(r"^(?P<p>[^.]+)(?P<s>\.firebaseio\.com)$"),
    re.compile(r"^(?P<p>[^.]+)(?P<s>\.firebaseapp\.com)$"),
    re.compile(r"^(?P<p>[^.]+)(?P<s>\.web\.app)$"),
    re.compile(r"^(?P<p>[^.]+)(?P<s>\.appspot\.com)$"),
    re.compile(r"^(?P<p>[^.]+)(?P<s>\.cloudfunctions\.net)$"),
    re.compile(r"^(?P<p>.+?)(?P<s>\.s3[.-][a-z0-9.-]*amazonaws\.com)$"),
    re.compile(r"^(?P<p>[^.]+)(?P<s>\.blob\.core\.windows\.net)$"),
]


def redactar_host(host: str) -> str:
    for patron in PATRONES_HOST_PROYECTO:
        m = patron.match(host)
        if m:
            return "[proyecto]" + m.group("s")
    return host


RE_URL = re.compile(r"https?://([A-Za-z0-9.-]+\.[A-Za-z]{2,})(?::\d+)?")


def hosts_en_cadenas(cadenas: List[str]) -> List[str]:
    hosts = set()
    for s in cadenas:
        for m in RE_URL.finditer(s):
            h = m.group(1).lower().rstrip(".")
            if h not in ("schemas.android.com", "www.w3.org", "ns.adobe.com", "xmlpull.org", "apache.org"):
                hosts.add(h)
    return sorted(hosts)


# ---------------------------------------------------------------------------
# ELF y deteccion de motor
# ---------------------------------------------------------------------------

MAQUINAS_ELF = {0x03: "x86", 0x28: "ARM (32 bits)", 0x3E: "x86_64", 0xB7: "AArch64 (ARM 64 bits)"}


def info_elf(cabecera: bytes) -> Optional[Dict[str, Any]]:
    if len(cabecera) < 20 or not cabecera.startswith(b"\x7fELF"):
        return None
    clase = {1: 32, 2: 64}.get(cabecera[4])
    maquina = struct.unpack_from("<H", cabecera, 18)[0]
    return {"bits": clase, "maquina": MAQUINAS_ELF.get(maquina, "0x%x" % maquina)}


RE_VERSION_UNITY = re.compile(rb"\b((?:20[1-3]\d|6000|[5-9])\.\d{1,2}\.\d{1,3}[abfpx]\d{1,3})\b")

ARCHIVOS_VERSION_UNITY = [
    "assets/bin/Data/globalgamemanagers",
    "assets/bin/Data/data.unity3d",
    "assets/bin/Data/unity default resources",
    "assets/bin/Data/Resources/unity_builtin_extra",
    "assets/bin/Data/mainData",
    "assets/bin/Data/level0",
]

FIRMAS_MOTOR = [
    # (motor, patron sobre nombres de archivo, descripcion de la evidencia)
    ("Unity", re.compile(r"^lib/[^/]+/libunity\.so$"), "biblioteca libunity.so"),
    ("Unity", re.compile(r"^assets/bin/Data/"), "carpeta assets/bin/Data"),
    ("Unreal Engine", re.compile(r"^lib/[^/]+/libUE4\.so$|^lib/[^/]+/libUnreal\.so$"), "biblioteca libUE4/libUnreal"),
    ("Godot", re.compile(r"^lib/[^/]+/libgodot_android\.so$"), "biblioteca libgodot_android.so"),
    ("Godot", re.compile(r"^assets/[^/]+\.pck$"), "paquete .pck de Godot"),
    ("Flutter", re.compile(r"^lib/[^/]+/libflutter\.so$"), "biblioteca libflutter.so"),
    ("Cocos2d-x / Cocos Creator", re.compile(r"^lib/[^/]+/libcocos.*\.so$"), "biblioteca libcocos*"),
    ("React Native", re.compile(r"^lib/[^/]+/libreactnativejni\.so$|^assets/index\.android\.bundle$"), "React Native"),
    ("Xamarin / .NET MAUI", re.compile(r"^lib/[^/]+/libmonodroid\.so$"), "biblioteca libmonodroid.so"),
    ("Defold", re.compile(r"^lib/[^/]+/libdmengine\.so$"), "biblioteca libdmengine.so"),
    ("GameMaker", re.compile(r"^lib/[^/]+/libyoyo\.so$"), "biblioteca libyoyo.so"),
    ("Solar2D (Corona)", re.compile(r"^lib/[^/]+/libcorona\.so$"), "biblioteca libcorona.so"),
    ("libGDX", re.compile(r"^lib/[^/]+/libgdx\.so$"), "biblioteca libgdx.so"),
    ("Apache Cordova", re.compile(r"^assets/www/cordova\.js$"), "assets/www/cordova.js"),
]


def detectar_motor(nombres: List[str], leer) -> Dict[str, Any]:
    evidencias: Dict[str, List[str]] = {}
    for nombre in nombres:
        for motor, patron, descripcion in FIRMAS_MOTOR:
            if patron.search(nombre):
                lista = evidencias.setdefault(motor, [])
                if descripcion not in lista:
                    lista.append(descripcion)
    resultado: Dict[str, Any] = {"motor": None, "evidencias": evidencias, "detalles": {}}
    if not evidencias:
        hay_dex = any(re.match(r"^classes\d*\.dex$", n) for n in nombres)
        resultado["motor"] = "Aplicacion Android nativa (Java/Kotlin)" if hay_dex else "Desconocido"
        return resultado
    resultado["motor"] = max(evidencias, key=lambda m: len(evidencias[m]))
    if resultado["motor"] == "Unity":
        resultado["detalles"] = _detalles_unity(nombres, leer)
    return resultado


def _detalles_unity(nombres: List[str], leer) -> Dict[str, Any]:
    d: Dict[str, Any] = {}
    conjunto = set(nombres)
    # global-metadata.dat solo existe en compilaciones IL2CPP, aunque falten las bibliotecas nativas
    # (por ejemplo, en el APK base de una instalacion dividida de Google Play).
    il2cpp = any(re.match(r"^lib/[^/]+/libil2cpp\.so$", n) for n in nombres) or \
        "assets/bin/Data/Managed/Metadata/global-metadata.dat" in conjunto
    mono = any(re.match(r"^lib/[^/]+/libmono(bdwgc-2\.0)?\.so$", n) for n in nombres) or \
        "assets/bin/Data/Managed/Assembly-CSharp.dll" in conjunto
    d["backend_scripting"] = "IL2CPP" if il2cpp else ("Mono" if mono else "no determinado")
    meta = "assets/bin/Data/Managed/Metadata/global-metadata.dat"
    if meta in conjunto:
        cab = leer(meta, 8)
        if len(cab) >= 8:
            magia, version = struct.unpack_from("<Ii", cab, 0)
            d["il2cpp_metadata"] = {
                "magia_valida": magia == 0xFAB11BAF,
                "version": version,
                "nota": "Los nombres de clases y metodos estan en este archivo; no se lee su contenido.",
            }
    for candidato in ARCHIVOS_VERSION_UNITY:
        if candidato in conjunto:
            cab = leer(candidato, 4096)
            m = RE_VERSION_UNITY.search(cab)
            if m:
                d["version_unity"] = m.group(1).decode("ascii")
                d["version_fuente"] = candidato
                break
    if "version_unity" not in d:
        for n in nombres:
            if re.match(r"^lib/[^/]+/libunity\.so$", n):
                m = RE_VERSION_UNITY.search(leer(n, None))
                if m:
                    d["version_unity"] = m.group(1).decode("ascii")
                    d["version_fuente"] = n
                break
    d["addressables"] = any(n.startswith("assets/aa/") for n in nombres)
    d["streaming_assets"] = sum(1 for n in nombres if n.startswith("assets/") and not n.startswith("assets/bin/"))
    return d


# ---------------------------------------------------------------------------
# Firma del APK (v1 / v2 / v3) y certificado
# ---------------------------------------------------------------------------

ID_BLOQUES_FIRMA = {
    0x7109871A: "esquema v2",
    0xF05368C0: "esquema v3",
    0x1B93AD61: "esquema v3.1",
    0x42726577: "relleno (verity padding)",
    0x2B09189E: "sello de origen v1",
    0x6DFF800D: "sello de origen v2",
    0x504B4453: "metadatos de dependencias",
    0x2146444E: "metadatos de Google Play (frosting)",
}

OID_NOMBRES = {
    "2.5.4.3": "CN",
    "2.5.4.6": "C",
    "2.5.4.7": "L",
    "2.5.4.8": "ST",
    "2.5.4.10": "O",
    "2.5.4.11": "OU",
}


def _der_leer(datos: bytes, p: int) -> Tuple[int, int, int, int]:
    """Devuelve (etiqueta, inicio_contenido, longitud, fin)."""
    etiqueta = datos[p]
    p += 1
    largo = datos[p]
    p += 1
    if largo & 0x80:
        n = largo & 0x7F
        largo = int.from_bytes(datos[p:p + n], "big")
        p += n
    return etiqueta, p, largo, p + largo


def _der_hijos(datos: bytes, inicio: int, fin: int) -> List[Tuple[int, int, int, int]]:
    hijos = []
    p = inicio
    while p < fin:
        h = _der_leer(datos, p)
        hijos.append(h)
        p = h[3]
    return hijos


def _der_oid(b: bytes) -> str:
    if not b:
        return ""
    partes = [b[0] // 40, b[0] % 40]
    valor = 0
    for x in b[1:]:
        valor = (valor << 7) | (x & 0x7F)
        if not x & 0x80:
            partes.append(valor)
            valor = 0
    return ".".join(str(x) for x in partes)


def _der_nombre(datos: bytes, inicio: int, fin: int) -> str:
    partes = []
    for _et, ini_set, _l, fin_set in _der_hijos(datos, inicio, fin):
        for _et2, ini_seq, _l2, fin_seq in _der_hijos(datos, ini_set, fin_set):
            elementos = _der_hijos(datos, ini_seq, fin_seq)
            if len(elementos) >= 2:
                oid = _der_oid(datos[elementos[0][1]:elementos[0][3]])
                valor = datos[elementos[1][1]:elementos[1][3]].decode("utf-8", errors="replace")
                partes.append("%s=%s" % (OID_NOMBRES.get(oid, oid), valor))
    return ", ".join(partes)


def _der_tiempo(etiqueta: int, b: bytes) -> str:
    s = b.decode("ascii", errors="replace")
    try:
        if etiqueta == 0x17:  # UTCTime
            anio = int(s[0:2])
            anio += 2000 if anio < 50 else 1900
            return "%04d-%s-%s" % (anio, s[2:4], s[4:6])
        return "%s-%s-%s" % (s[0:4], s[4:6], s[6:8])
    except ValueError:
        return s


def analizar_certificado(der: bytes) -> Dict[str, Any]:
    info: Dict[str, Any] = {"huella_sha256": hashlib.sha256(der).hexdigest()}
    try:
        _e, ini, _l, fin = _der_leer(der, 0)
        tbs = _der_hijos(der, ini, fin)[0]
        campos = _der_hijos(der, tbs[1], tbs[3])
        i = 1 if campos and campos[0][0] == 0xA0 else 0
        # numero de serie, algoritmo, emisor, validez, sujeto
        emisor = campos[i + 2]
        validez = campos[i + 3]
        sujeto = campos[i + 4]
        info["emisor"] = _der_nombre(der, emisor[1], emisor[3])
        info["sujeto"] = _der_nombre(der, sujeto[1], sujeto[3])
        tiempos = _der_hijos(der, validez[1], validez[3])
        if len(tiempos) == 2:
            info["valido_desde"] = _der_tiempo(tiempos[0][0], der[tiempos[0][1]:tiempos[0][3]])
            info["valido_hasta"] = _der_tiempo(tiempos[1][0], der[tiempos[1][1]:tiempos[1][3]])
    except (IndexError, ValueError) as exc:
        info["error"] = "no se pudo leer el certificado: %s" % exc
    return info


def _certificados_pkcs7(der: bytes) -> List[bytes]:
    """Extrae certificados de un SignedData PKCS#7 (firma v1)."""
    certs: List[bytes] = []
    try:
        _e, ini, _l, fin = _der_leer(der, 0)
        content_info = _der_hijos(der, ini, fin)
        explicito = content_info[1]  # [0] EXPLICIT
        signed_data = _der_hijos(der, explicito[1], explicito[3])[0]
        for et, c_ini, _c_l, c_fin in _der_hijos(der, signed_data[1], signed_data[3]):
            if et == 0xA0:  # [0] IMPLICIT certificates
                p = c_ini
                while p < c_fin:
                    h = _der_leer(der, p)
                    certs.append(der[p:h[3]])
                    p = h[3]
    except (IndexError, ValueError):
        pass
    return certs


def leer_bloque_firma(ruta: Path) -> Dict[str, Any]:
    res: Dict[str, Any] = {"presente": False, "bloques": [], "certificados": []}
    with ruta.open("rb") as f:
        f.seek(0, 2)
        tam = f.tell()
        leer = min(tam, 65536 + 22)
        f.seek(tam - leer)
        cola = f.read(leer)
        pos = cola.rfind(b"PK\x05\x06")
        if pos < 0:
            res["error"] = "no se encontro el fin del directorio central del ZIP"
            return res
        off_cd = struct.unpack_from("<I", cola, pos + 16)[0]
        if off_cd < 24:
            return res
        f.seek(off_cd - 24)
        pie = f.read(24)
        if pie[8:] != b"APK Sig Block 42":
            return res
        tam_bloque = struct.unpack_from("<Q", pie, 0)[0]
        f.seek(off_cd - tam_bloque - 8)
        bloque = f.read(tam_bloque + 8)
    res["presente"] = True
    p = 8
    fin = len(bloque) - 24
    while p + 12 <= fin:
        largo = struct.unpack_from("<Q", bloque, p)[0]
        id_ = struct.unpack_from("<I", bloque, p + 8)[0]
        valor = bloque[p + 12:p + 8 + largo]
        nombre = ID_BLOQUES_FIRMA.get(id_, "desconocido 0x%08x" % id_)
        res["bloques"].append(nombre)
        if id_ in (0x7109871A, 0xF05368C0, 0x1B93AD61) and not res["certificados"]:
            res["certificados"] = [analizar_certificado(c) for c in _certificados_v2(valor)]
        p += 8 + largo
    return res


def _certificados_v2(valor: bytes) -> List[bytes]:
    certs: List[bytes] = []
    try:
        p = 4  # longitud de la secuencia de firmantes
        largo_firmante = struct.unpack_from("<I", valor, p)[0]
        firmante = valor[p + 4:p + 4 + largo_firmante]
        largo_datos = struct.unpack_from("<I", firmante, 0)[0]
        datos = firmante[4:4 + largo_datos]
        largo_digests = struct.unpack_from("<I", datos, 0)[0]
        q = 4 + largo_digests
        largo_certs = struct.unpack_from("<I", datos, q)[0]
        q += 4
        fin = q + largo_certs
        while q + 4 <= fin:
            lc = struct.unpack_from("<I", datos, q)[0]
            certs.append(datos[q + 4:q + 4 + lc])
            q += 4 + lc
    except struct.error:
        pass
    return certs


# ---------------------------------------------------------------------------
# Inventario de recursos
# ---------------------------------------------------------------------------

CATEGORIAS_EXT = {
    "codigo Android (DEX)": {".dex"},
    "textura/imagen": {".png", ".jpg", ".jpeg", ".webp", ".ktx", ".ktx2", ".astc", ".pvr", ".dds", ".tga", ".exr"},
    "modelo 3D": {".fbx", ".obj", ".glb", ".gltf", ".dae", ".mesh"},
    "audio": {".ogg", ".mp3", ".wav", ".m4a", ".aac", ".bank", ".wem", ".bnk", ".resource"},
    "video": {".mp4", ".webm", ".mkv", ".usm"},
    "fuente tipografica": {".ttf", ".otf", ".ttc", ".fnt"},
    "datos/configuracion": {".json", ".xml", ".txt", ".csv", ".yaml", ".yml", ".bytes", ".dat", ".bin", ".hash",
                            ".arsc", ".properties"},
    "paquete Unity (AssetBundle/serializado)": {".bundle", ".unity3d", ".assets", ".ress", ".resS", ".ab"},
    "codigo/script": {".dll", ".lua", ".js", ".so", ".gz"},
    "shader": {".shader", ".glsl", ".spv", ".metal"},
}


def categoria_de(nombre: str) -> str:
    if nombre.endswith("/global-metadata.dat"):
        return "metadatos IL2CPP"
    base = nombre.rsplit("/", 1)[-1]
    ext = ("." + base.rsplit(".", 1)[-1]) if "." in base else ""
    for categoria, exts in CATEGORIAS_EXT.items():
        if ext in exts or ext.lower() in {e.lower() for e in exts}:
            return categoria
    if nombre.startswith("assets/bin/Data/") and ext == "":
        return "paquete Unity (AssetBundle/serializado)"
    return "otros"


# ---------------------------------------------------------------------------
# Analisis principal
# ---------------------------------------------------------------------------


def analizar_apk(ruta: Path, redaccion: bool = True) -> Dict[str, Any]:
    ruta = Path(ruta)
    informe: Dict[str, Any] = {
        "herramienta": {"nombre": "apk_audit", "version": VERSION_HERRAMIENTA},
        "fecha_analisis": _dt.datetime.now(_dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "archivo": {"nombre": ruta.name, "tamano_bytes": ruta.stat().st_size},
        "advertencias": [],
    }
    informe["archivo"].update(_hashes_de_archivo(ruta))

    try:
        zf = zipfile.ZipFile(ruta)
    except zipfile.BadZipFile as exc:
        informe["integridad"] = {"zip_valido": False, "error": str(exc)}
        informe["viabilidad"] = evaluar_viabilidad(informe)
        return informe

    with zf:
        entradas = zf.infolist()
        nombres = [e.filename for e in entradas]
        malas = []
        for e in entradas:
            try:
                with zf.open(e) as h:
                    while h.read(1024 * 1024):
                        pass
            except (zipfile.BadZipFile, zlib.error, EOFError) as exc:
                malas.append({"entrada": e.filename, "error": str(exc)})
        informe["integridad"] = {
            "zip_valido": not malas,
            "entradas": len(entradas),
            "entradas_con_error_crc": malas[:50],
            "tamano_descomprimido_bytes": sum(e.file_size for e in entradas),
        }

        def leer(nombre: str, limite: Optional[int]) -> bytes:
            with zf.open(nombre) as h:
                return h.read() if limite is None else h.read(limite)

        # Firma
        firma = leer_bloque_firma(ruta)
        firmas_v1 = [n for n in nombres if re.match(r"^META-INF/[^/]+\.(RSA|DSA|EC)$", n)]
        firma["v1_archivos"] = firmas_v1
        if firmas_v1 and not firma["certificados"]:
            firma["certificados"] = [analizar_certificado(c) for c in _certificados_pkcs7(leer(firmas_v1[0], None))]
        informe["firma"] = firma

        # Manifiesto
        if "AndroidManifest.xml" in nombres:
            try:
                arbol = parse_axml(leer("AndroidManifest.xml", None))
                manifiesto = resumir_manifiesto(arbol)
                if redaccion:
                    for md in manifiesto["meta_datos"]:
                        v = md.get("valor")
                        if isinstance(v, str) and not v.startswith("@") and len(v) > 12:
                            md["valor"] = redactar(v)
                            md["redactado"] = True
                informe["manifiesto"] = manifiesto
            except (AxmlError, struct.error, IndexError) as exc:
                informe["manifiesto"] = {"error": str(exc)}
        else:
            informe["manifiesto"] = {"error": "AndroidManifest.xml no encontrado"}
            informe["advertencias"].append("El archivo no contiene AndroidManifest.xml: puede no ser un APK.")

        # ABIs y bibliotecas nativas
        libs = []
        abis = set()
        for e in entradas:
            m = re.match(r"^lib/([^/]+)/([^/]+\.so)$", e.filename)
            if m:
                abis.add(m.group(1))
                elf = info_elf(leer(e.filename, 64))
                libs.append({"abi": m.group(1), "nombre": m.group(2), "tamano_bytes": e.file_size, "elf": elf})
        informe["abis"] = sorted(abis)
        informe["bibliotecas_nativas"] = sorted(libs, key=lambda d: (-d["tamano_bytes"], d["nombre"]))

        # Motor
        informe["motor"] = detectar_motor(nombres, leer)

        # DEX
        dex_info = {"archivos": [], "clases_definidas": 0, "sdks": [], "paquetes_principales": [], "hosts": []}
        todas_clases: List[str] = []
        todas_cadenas: List[str] = []
        for n in sorted(x for x in nombres if re.match(r"^classes\d*\.dex$", x)):
            try:
                d = parse_dex(leer(n, None))
                dex_info["archivos"].append({"nombre": n, "version_dex": d["version"],
                                             "checksum_ok": d["checksum_ok"], "clases": len(d["clases"])})
                todas_clases.extend(d["clases"])
                todas_cadenas.extend(d["cadenas"])
            except (DexError, struct.error, IndexError, ValueError) as exc:
                dex_info["archivos"].append({"nombre": n, "error": str(exc)})
        dex_info["clases_definidas"] = len(todas_clases)
        dex_info["sdks"] = detectar_sdks(todas_clases)
        dex_info["paquetes_principales"] = paquetes_principales(todas_clases)
        informe["dex"] = dex_info

        # Hosts de red (DEX + configuraciones de texto pequenas)
        cadenas_cfg: List[str] = []
        for e in entradas:
            if e.file_size <= 2 * 1024 * 1024 and re.search(r"\.(json|xml|txt|cfg|ini|properties)$", e.filename, re.I) \
                    and e.filename != "AndroidManifest.xml" and not e.filename.startswith("res/"):
                cadenas_cfg.append(leer(e.filename, None).decode("utf-8", errors="ignore"))
        hosts = hosts_en_cadenas(todas_cadenas + cadenas_cfg)
        informe["hosts_red"] = sorted({redactar_host(h) for h in hosts}) if redaccion else hosts

        # Recursos
        por_categoria: Dict[str, Dict[str, int]] = {}
        por_carpeta: Counter = Counter()
        for e in entradas:
            cat = categoria_de(e.filename)
            d = por_categoria.setdefault(cat, {"archivos": 0, "bytes": 0})
            d["archivos"] += 1
            d["bytes"] += e.file_size
            partes = e.filename.split("/")
            por_carpeta["/".join(partes[:2]) if len(partes) > 2 else partes[0]] += e.file_size
        informe["recursos"] = {
            "por_categoria": dict(sorted(por_categoria.items(), key=lambda kv: -kv[1]["bytes"])),
            "carpetas_mas_pesadas": [{"carpeta": k, "bytes": v} for k, v in por_carpeta.most_common(15)],
            "archivos_mas_grandes": [{"nombre": e.filename, "bytes": e.file_size}
                                     for e in sorted(entradas, key=lambda x: -x.file_size)[:20]],
        }

    # Advertencias sobre APK incompleto (Android App Bundle)
    man = informe.get("manifiesto", {})
    nombres_meta = {m.get("nombre") for m in man.get("meta_datos", [])} if isinstance(man, dict) else set()
    if man.get("isSplitRequired") or "com.android.vending.splits.required" in nombres_meta:
        informe["advertencias"].append(
            "El manifiesto indica que la app requiere APK divididos (splits): este archivo puede no "
            "contener todas las bibliotecas o recursos del juego.")
    if not informe["abis"] and informe["motor"].get("motor") not in (None, "Desconocido",
                                                                    "Aplicacion Android nativa (Java/Kotlin)"):
        informe["advertencias"].append(
            "No hay bibliotecas nativas en el APK aunque el motor las necesita: faltan los APK de configuración de ABI.")

    informe["viabilidad"] = evaluar_viabilidad(informe)
    return informe


# ---------------------------------------------------------------------------
# Evaluacion de viabilidad del port
# ---------------------------------------------------------------------------


def evaluar_viabilidad(inf: Dict[str, Any]) -> Dict[str, Any]:
    conclusiones: List[str] = []
    requisitos: List[str] = []
    motor = (inf.get("motor") or {}).get("motor")
    detalles = (inf.get("motor") or {}).get("detalles", {})
    sdks = (inf.get("dex") or {}).get("sdks", [])
    categorias = sorted({s["categoria"] for s in sdks if s["categoria"] != "motor"})

    conclusiones.append(
        "Un APK contiene el juego ya compilado para Android. Nintendo Switch no ejecuta APK ni el entorno "
        "de Android, por lo que el archivo no puede instalarse ni convertirse directamente.")
    if motor == "Unity":
        backend = detalles.get("backend_scripting", "no determinado")
        version = detalles.get("version_unity", "no determinada")
        conclusiones.append(
            "Motor: Unity %s (backend de scripts: %s)." % (version, backend))
        if backend == "IL2CPP":
            conclusiones.append(
                "Con IL2CPP el código C# del juego está traducido a C++ y compilado como código máquina ARM "
                "dentro de libil2cpp.so. Ese binario está enlazado al runtime de Android y no puede "
                "recompilarse para otra plataforma: el código fuente no está en el APK.")
        elif backend == "Mono":
            conclusiones.append(
                "Con Mono el APK incluye ensamblados .NET; aun así no contiene el proyecto de Unity "
                "(escenas, prefabs y recursos en formato de editor) necesario para compilar en otra plataforma.")
        conclusiones.append(
            "Unity permite compilar para Nintendo Switch, pero solo desde el proyecto original y con el "
            "módulo de plataforma que Unity entrega a desarrolladores autorizados por Nintendo.")
        requisitos += [
            "Proyecto fuente de Unity del titular de los derechos (no recuperable desde el APK).",
            "Licencia o acuerdo escrito del titular de los derechos para portar el juego y sus recursos.",
            "Alta como desarrollador en el Nintendo Developer Portal y acceso al SDK y kits de desarrollo.",
            "Módulo de compilación de Unity para Nintendo Switch (se obtiene tras la autorización de Nintendo).",
        ]
    elif motor:
        conclusiones.append("Motor detectado: %s." % motor)
        requisitos += [
            "Código fuente y proyecto original del titular de los derechos.",
            "Licencia o acuerdo escrito del titular de los derechos.",
            "Alta como desarrollador en el Nintendo Developer Portal.",
        ]
    if categorias:
        conclusiones.append(
            "Dependencias de servicios externos detectadas (%s): en una versión sin conexión deben "
            "eliminarse o sustituirse por sistemas locales." % ", ".join(categorias))
    man = inf.get("manifiesto") or {}
    nombres_meta = {m.get("nombre") for m in man.get("meta_datos", [])} if isinstance(man, dict) else set()
    if "com.android.vending.splits.required" in nombres_meta and not inf.get("abis"):
        conclusiones.append(
            "Este archivo es el APK base de una instalacion dividida de Google Play (Android App Bundle): "
            "no incluye los APK de configuracion con las bibliotecas nativas, asi que ni siquiera se "
            "ejecutaria por si solo en Android.")
    veredicto = "port directo no viable desde el APK"
    if not motor or motor == "Desconocido":
        veredicto = "indeterminado (no se pudo identificar el motor)"
    return {"veredicto": veredicto, "conclusiones": conclusiones, "requisitos_externos": requisitos}


# ---------------------------------------------------------------------------
# Informe Markdown
# ---------------------------------------------------------------------------


def _o_no_declarado(valor: Any) -> Any:
    return "no declarado" if valor is None else valor


def _fila(*celdas: Any) -> str:
    return "| " + " | ".join(str(c).replace("|", "\\|") for c in celdas) + " |"


def informe_markdown(inf: Dict[str, Any]) -> str:
    a = inf["archivo"]
    l: List[str] = []
    l.append("# Informe de auditoría del APK: %s" % a["nombre"])
    l.append("")
    l.append("Generado por `apk_audit` %s el %s (UTC). Análisis de solo lectura: no se extrajo ni se "
             "modificó ningún recurso." % (inf["herramienta"]["version"], inf["fecha_analisis"]))
    l.append("")
    l.append("## 1. Identificación e integridad")
    l.append("")
    l.append(_fila("Campo", "Valor"))
    l.append(_fila("---", "---"))
    l.append(_fila("Tamaño", "%s (%d bytes)" % (_tam_legible(a["tamano_bytes"]), a["tamano_bytes"])))
    l.append(_fila("SHA-256", "`%s`" % a["sha256"]))
    l.append(_fila("SHA-1", "`%s`" % a["sha1"]))
    l.append(_fila("MD5", "`%s`" % a["md5"]))
    integ = inf.get("integridad", {})
    l.append(_fila("ZIP válido (CRC de todas las entradas)", "sí" if integ.get("zip_valido") else "NO"))
    if "entradas" in integ:
        l.append(_fila("Entradas", integ["entradas"]))
        l.append(_fila("Tamaño descomprimido", _tam_legible(integ["tamano_descomprimido_bytes"])))
    firma = inf.get("firma", {})
    esquemas = []
    if firma.get("v1_archivos"):
        esquemas.append("v1 (JAR)")
    esquemas += [b for b in firma.get("bloques", []) if b.startswith("esquema")]
    l.append(_fila("Esquemas de firma", ", ".join(esquemas) or "ninguno detectado"))
    for i, c in enumerate(firma.get("certificados", [])[:3]):
        l.append(_fila("Certificado %d - sujeto" % (i + 1), c.get("sujeto", "?")))
        l.append(_fila("Certificado %d - emisor" % (i + 1), c.get("emisor", "?")))
        l.append(_fila("Certificado %d - validez" % (i + 1), "%s a %s" % (c.get("valido_desde", "?"),
                                                                         c.get("valido_hasta", "?"))))
        l.append(_fila("Certificado %d - huella SHA-256" % (i + 1), "`%s`" % c.get("huella_sha256")))
    l.append("")
    for adv in inf.get("advertencias", []):
        l.append("> **Advertencia:** %s" % adv)
        l.append("")

    m = inf.get("manifiesto", {})
    l.append("## 2. Manifiesto")
    l.append("")
    if "error" in m:
        l.append("No se pudo leer: %s" % m["error"])
    else:
        l.append(_fila("Campo", "Valor"))
        l.append(_fila("---", "---"))
        for k in ("paquete", "versionName", "versionCode", "minSdk", "targetSdk", "compileSdkVersion",
                  "actividad_principal"):
            l.append(_fila(k, _o_no_declarado(m.get(k))))
        for k, v in (m.get("aplicacion") or {}).items():
            l.append(_fila("application." + k, v))
        l.append("")
        l.append("**Permisos (%d):** %s" % (len(m["permisos"]), ", ".join("`%s`" % p for p in m["permisos"]) or "ninguno"))
        l.append("")
        l.append("**Componentes:** %d actividades, %d servicios, %d receptores, %d proveedores." % (
            len(m["actividades"]), len(m["servicios"]), len(m["receptores"]), len(m["proveedores"])))
        l.append("")
        if m["meta_datos"]:
            l.append("**Meta-datos** (valores largos redactados para no publicar identificadores):")
            l.append("")
            for md in m["meta_datos"]:
                l.append("- `%s` = `%s`" % (md.get("nombre"), md.get("valor")))
            l.append("")

    l.append("## 3. Motor, arquitecturas y bibliotecas nativas")
    l.append("")
    mot = inf.get("motor", {})
    l.append("**Motor detectado:** %s" % mot.get("motor"))
    l.append("")
    for motor, ev in (mot.get("evidencias") or {}).items():
        l.append("- Evidencias de %s: %s" % (motor, "; ".join(ev)))
    for k, v in (mot.get("detalles") or {}).items():
        l.append("- %s: %s" % (k, json.dumps(v, ensure_ascii=False) if isinstance(v, dict) else v))
    l.append("")
    l.append("**ABIs:** %s" % (", ".join(inf.get("abis", [])) or "ninguna"))
    l.append("")
    libs = inf.get("bibliotecas_nativas", [])
    if libs:
        l.append(_fila("ABI", "Biblioteca", "Tamaño", "Arquitectura ELF"))
        l.append(_fila("---", "---", "---", "---"))
        for b in libs[:40]:
            elf = b.get("elf") or {}
            l.append(_fila(b["abi"], b["nombre"], _tam_legible(b["tamano_bytes"]), elf.get("maquina", "?")))
        l.append("")

    dx = inf.get("dex", {})
    l.append("## 4. Código Java/Kotlin (DEX) y SDK de terceros")
    l.append("")
    l.append("Archivos DEX: %d. Clases definidas: %d. (Solo se leyeron las tablas de nombres.)" % (
        len(dx.get("archivos", [])), dx.get("clases_definidas", 0)))
    l.append("")
    if dx.get("sdks"):
        l.append(_fila("SDK", "Categoría", "Clases"))
        l.append(_fila("---", "---", "---"))
        for s in dx["sdks"]:
            l.append(_fila(s["sdk"], s["categoria"], s["clases"]))
        l.append("")
    if dx.get("paquetes_principales"):
        l.append("Paquetes con más clases: " + ", ".join("`%s` (%d)" % (p, n) for p, n in dx["paquetes_principales"][:15]))
        l.append("")

    l.append("## 5. Dependencias de red citadas")
    l.append("")
    hosts = inf.get("hosts_red", [])
    if hosts:
        l.append("Dominios encontrados en tablas de cadenas y archivos de configuración (%d):" % len(hosts))
        l.append("")
        l.append(", ".join("`%s`" % h for h in hosts[:200]))
    else:
        l.append("No se encontraron dominios.")
    l.append("")

    r = inf.get("recursos", {})
    l.append("## 6. Recursos")
    l.append("")
    if r:
        l.append(_fila("Categoría", "Archivos", "Tamaño"))
        l.append(_fila("---", "---", "---"))
        for cat, d in r["por_categoria"].items():
            l.append(_fila(cat, d["archivos"], _tam_legible(d["bytes"])))
        l.append("")
        l.append("Ubicaciones más pesadas (carpeta o archivo de primer nivel): " + ", ".join("`%s` (%s)" % (c["carpeta"], _tam_legible(c["bytes"]))
                                                    for c in r["carpetas_mas_pesadas"][:10]))
        l.append("")

    v = inf.get("viabilidad", {})
    l.append("## 7. Evaluación de viabilidad del port")
    l.append("")
    l.append("**Veredicto:** %s." % v.get("veredicto"))
    l.append("")
    for c in v.get("conclusiones", []):
        l.append("- %s" % c)
    l.append("")
    if v.get("requisitos_externos"):
        l.append("**Requisitos externos para un port oficial:**")
        l.append("")
        for q in v["requisitos_externos"]:
            l.append("- %s" % q)
        l.append("")
    l.append("## 8. Limitaciones del análisis")
    l.append("")
    l.append("- Análisis estático de estructura: no se ejecuta la aplicación ni se observa su tráfico de red.")
    l.append("- Los SDK se identifican por prefijos de paquete; el código ofuscado o renombrado puede no detectarse.")
    l.append("- Si el juego descarga contenido adicional (paquetes de recursos o descargas en línea), "
             "ese contenido no está en este archivo.")
    l.append("")
    return "\n".join(l)


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------


def main(argv: Optional[List[str]] = None) -> int:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    p = argparse.ArgumentParser(description="Auditoria estructural de solo lectura de un APK.")
    p.add_argument("apk", type=Path, help="ruta al archivo .apk")
    p.add_argument("--salida", type=Path, default=Path("informe_apk"), help="carpeta de salida")
    p.add_argument("--sin-redaccion", action="store_true",
                   help="no ocultar valores de meta-datos (solo para uso local, no publicar)")
    args = p.parse_args(argv)
    if not args.apk.is_file():
        print("No existe el archivo: %s" % args.apk, file=sys.stderr)
        return 2
    informe = analizar_apk(args.apk, redaccion=not args.sin_redaccion)
    args.salida.mkdir(parents=True, exist_ok=True)
    (args.salida / "informe_apk.json").write_text(json.dumps(informe, ensure_ascii=False, indent=2), encoding="utf-8")
    (args.salida / "informe_apk.md").write_text(informe_markdown(informe), encoding="utf-8")
    a = informe["archivo"]
    print("APK: %s" % a["nombre"])
    print("SHA-256: %s" % a["sha256"])
    print("ZIP válido: %s" % ("sí" if informe.get("integridad", {}).get("zip_valido") else "NO"))
    print("Motor: %s" % (informe.get("motor") or {}).get("motor"))
    print("Veredicto: %s" % informe["viabilidad"]["veredicto"])
    print("Informe: %s" % (args.salida / "informe_apk.md"))
    return 0


if __name__ == "__main__":
    sys.exit(main())
