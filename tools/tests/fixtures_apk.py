# -*- coding: utf-8 -*-
"""Constructores de APK sinteticos para probar apk_audit sin usar archivos propietarios."""
from __future__ import annotations

import hashlib
import struct
import zipfile
import zlib
from pathlib import Path
from typing import Dict, List, Optional, Sequence, Tuple

# ---------------------------------------------------------------------------
# AXML (XML binario de Android)
# ---------------------------------------------------------------------------

TYPE_STRING = 0x03
TYPE_INT_DEC = 0x10
TYPE_INT_BOOLEAN = 0x12
TYPE_REFERENCE = 0x01


class _Pool:
    def __init__(self) -> None:
        self.cadenas: List[str] = []

    def idx(self, s: str) -> int:
        if s not in self.cadenas:
            self.cadenas.append(s)
        return self.cadenas.index(s)

    def bytes_utf16(self) -> bytes:
        offsets = []
        datos = b""
        for s in self.cadenas:
            offsets.append(len(datos))
            cod = s.encode("utf-16-le")
            datos += struct.pack("<H", len(s)) + cod + b"\x00\x00"
        while len(datos) % 4:
            datos += b"\x00"
        tam_cab = 28
        ini_str = tam_cab + 4 * len(offsets)
        cuerpo = b"".join(struct.pack("<I", o) for o in offsets) + datos
        cab = struct.pack("<HHIIIIII", 0x0001, tam_cab, tam_cab + len(cuerpo), len(self.cadenas), 0, 0, ini_str, 0)
        return cab + cuerpo


def construir_axml(elementos: Sequence[Tuple[str, str, Dict[str, object]]], ns_android: bool = True) -> bytes:
    """elementos: lista de ("start"|"end", tag, attrs). Valores: str, bool, int o ("ref", n)."""
    pool = _Pool()
    uri = "http://schemas.android.com/apk/res/android"
    pool.idx("android")
    pool.idx(uri)
    cuerpo = b""
    if ns_android:
        cuerpo += struct.pack("<HHIIIII", 0x0100, 16, 24, 1, 0xFFFFFFFF, pool.idx("android"), pool.idx(uri))
    for tipo, tag, attrs in elementos:
        if tipo == "start":
            datos_attr = b""
            for nombre, valor in attrs.items():
                ns = 0xFFFFFFFF if nombre == "package" else pool.idx(uri)
                n_idx = pool.idx(nombre)
                if isinstance(valor, bool):
                    raw, t, d = 0xFFFFFFFF, TYPE_INT_BOOLEAN, 0xFFFFFFFF if valor else 0
                elif isinstance(valor, int):
                    raw, t, d = 0xFFFFFFFF, TYPE_INT_DEC, valor & 0xFFFFFFFF
                elif isinstance(valor, tuple) and valor[0] == "ref":
                    raw, t, d = 0xFFFFFFFF, TYPE_REFERENCE, valor[1]
                else:
                    s = pool.idx(str(valor))
                    raw, t, d = s, TYPE_STRING, s
                datos_attr += struct.pack("<IIIHBBI", ns, n_idx, raw, 8, 0, t, d)
            ext = struct.pack("<IIHHHHHH", 0xFFFFFFFF, pool.idx(tag), 0x14, 0x14, len(attrs), 0, 0, 0)
            tam = 16 + len(ext) + len(datos_attr)
            cuerpo += struct.pack("<HHIII", 0x0102, 16, tam, 1, 0xFFFFFFFF) + ext + datos_attr
        else:
            cuerpo += struct.pack("<HHIIIII", 0x0103, 16, 24, 1, 0xFFFFFFFF, 0xFFFFFFFF, pool.idx(tag))
    if ns_android:
        cuerpo += struct.pack("<HHIIIII", 0x0101, 16, 24, 1, 0xFFFFFFFF, pool.idx("android"), pool.idx(uri))
    sp = pool.bytes_utf16()
    total = 8 + len(sp) + len(cuerpo)
    return struct.pack("<HHI", 0x0003, 8, total) + sp + cuerpo


def manifiesto_ejemplo(paquete: str = "com.ejemplo.juego", version_name: str = "1.2.3", version_code: int = 42,
                       permisos: Sequence[str] = ("android.permission.INTERNET",),
                       meta: Optional[Dict[str, str]] = None, split_required: bool = False) -> bytes:
    els: List[Tuple[str, str, Dict[str, object]]] = []
    attrs_man: Dict[str, object] = {"package": paquete, "versionCode": version_code, "versionName": version_name}
    if split_required:
        attrs_man["isSplitRequired"] = True
    els.append(("start", "manifest", attrs_man))
    els.append(("start", "uses-sdk", {"minSdkVersion": 23, "targetSdkVersion": 34}))
    els.append(("end", "uses-sdk", {}))
    for p in permisos:
        els.append(("start", "uses-permission", {"name": p}))
        els.append(("end", "uses-permission", {}))
    els.append(("start", "application", {"label": ("ref", 0x7F0E0001), "allowBackup": False, "debuggable": False}))
    els.append(("start", "activity", {"name": "com.unity3d.player.UnityPlayerActivity", "exported": True}))
    els.append(("start", "intent-filter", {}))
    els.append(("start", "action", {"name": "android.intent.action.MAIN"}))
    els.append(("end", "action", {}))
    els.append(("start", "category", {"name": "android.intent.category.LAUNCHER"}))
    els.append(("end", "category", {}))
    els.append(("end", "intent-filter", {}))
    els.append(("end", "activity", {}))
    els.append(("start", "service", {"name": "com.ejemplo.Servicio"}))
    els.append(("end", "service", {}))
    for k, v in (meta or {}).items():
        els.append(("start", "meta-data", {"name": k, "value": v}))
        els.append(("end", "meta-data", {}))
    els.append(("end", "application", {}))
    els.append(("end", "manifest", {}))
    return construir_axml(els)


# ---------------------------------------------------------------------------
# DEX minimo
# ---------------------------------------------------------------------------


def _uleb(n: int) -> bytes:
    out = b""
    while True:
        b = n & 0x7F
        n >>= 7
        if n:
            out += bytes([b | 0x80])
        else:
            return out + bytes([b])


def construir_dex(clases: Sequence[str], cadenas_extra: Sequence[str] = ()) -> bytes:
    """Crea un DEX con las clases indicadas (descriptores tipo 'Lcom/x/Y;')."""
    cadenas = sorted(set(list(clases) + list(cadenas_extra)))
    n_str = len(cadenas)
    n_tipos = len(clases)
    off_str_ids = 0x70
    off_type_ids = off_str_ids + 4 * n_str
    off_class_defs = off_type_ids + 4 * n_tipos
    off_datos = off_class_defs + 32 * len(clases)
    datos = b""
    offs_str = []
    for s in cadenas:
        offs_str.append(off_datos + len(datos))
        datos += _uleb(len(s)) + s.encode("utf-8") + b"\x00"
    str_ids = b"".join(struct.pack("<I", o) for o in offs_str)
    type_ids = b"".join(struct.pack("<I", cadenas.index(c)) for c in clases)
    class_defs = b"".join(struct.pack("<IIIIIIII", i, 1, 0xFFFFFFFF, 0, 0xFFFFFFFF, 0, 0, 0) for i in range(len(clases)))
    tam = off_datos + len(datos)
    cab = bytearray(0x70)
    cab[0:8] = b"dex\n035\x00"
    struct.pack_into("<I", cab, 0x20, tam)
    struct.pack_into("<I", cab, 0x24, 0x70)
    struct.pack_into("<I", cab, 0x28, 0x12345678)
    struct.pack_into("<IIII", cab, 0x38, n_str, off_str_ids, n_tipos, off_type_ids)
    struct.pack_into("<II", cab, 0x60, len(clases), off_class_defs)
    struct.pack_into("<II", cab, 0x68, len(datos), off_datos)
    cuerpo = bytes(cab) + str_ids + type_ids + class_defs + datos
    firma = hashlib.sha1(cuerpo[32:]).digest()
    cuerpo = cuerpo[:12] + firma + cuerpo[32:]
    checksum = zlib.adler32(cuerpo[12:]) & 0xFFFFFFFF
    return cuerpo[:8] + struct.pack("<I", checksum) + cuerpo[12:]


# ---------------------------------------------------------------------------
# DER / certificado / bloque de firma v2
# ---------------------------------------------------------------------------


def _der(etiqueta: int, contenido: bytes) -> bytes:
    n = len(contenido)
    if n < 0x80:
        largo = bytes([n])
    else:
        b = n.to_bytes((n.bit_length() + 7) // 8, "big")
        largo = bytes([0x80 | len(b)]) + b
    return bytes([etiqueta]) + largo + contenido


def _oid(texto: str) -> bytes:
    partes = [int(x) for x in texto.split(".")]
    out = bytes([partes[0] * 40 + partes[1]])
    for p in partes[2:]:
        trozo = [p & 0x7F]
        p >>= 7
        while p:
            trozo.insert(0, 0x80 | (p & 0x7F))
            p >>= 7
        out += bytes(trozo)
    return _der(0x06, out)


def _nombre(pares: Sequence[Tuple[str, str]]) -> bytes:
    rdns = b"".join(_der(0x31, _der(0x30, _oid(oid) + _der(0x0C, v.encode()))) for oid, v in pares)
    return _der(0x30, rdns)


def certificado_falso(cn: str = "Estudio Ejemplo", o: str = "Ejemplo S.A.") -> bytes:
    alg = _der(0x30, _oid("1.2.840.113549.1.1.11") + b"\x05\x00")
    tbs = _der(0x30,
               _der(0xA0, _der(0x02, b"\x02")) +
               _der(0x02, b"\x01\x23") +
               alg +
               _nombre([("2.5.4.6", "MX"), ("2.5.4.10", o), ("2.5.4.3", cn)]) +
               _der(0x30, _der(0x17, b"200101000000Z") + _der(0x17, b"491231235959Z")) +
               _nombre([("2.5.4.6", "MX"), ("2.5.4.10", o), ("2.5.4.3", cn)]) +
               _der(0x30, alg + _der(0x03, b"\x00\x01\x02")))
    return _der(0x30, tbs + alg + _der(0x03, b"\x00\xAA"))


def _lp(b: bytes) -> bytes:
    return struct.pack("<I", len(b)) + b


def bloque_firma_v2(cert: bytes) -> bytes:
    digests = _lp(b"")
    certs = _lp(_lp(cert))
    signed_data = digests + certs + _lp(b"")
    firmante = _lp(signed_data) + _lp(b"") + _lp(b"")
    valor = _lp(_lp(firmante))
    par = struct.pack("<Q", len(valor) + 4) + struct.pack("<I", 0x7109871A) + valor
    tam = len(par) + 8 + 16
    return struct.pack("<Q", tam) + par + struct.pack("<Q", tam) + b"APK Sig Block 42"


def insertar_bloque_firma(ruta: Path, bloque: bytes) -> None:
    """Inserta un bloque de firma antes del directorio central de un ZIP existente."""
    datos = ruta.read_bytes()
    pos = datos.rfind(b"PK\x05\x06")
    off_cd = struct.unpack_from("<I", datos, pos + 16)[0]
    nuevo = datos[:off_cd] + bloque + datos[off_cd:]
    pos_nueva = pos + len(bloque)
    nuevo = bytearray(nuevo)
    struct.pack_into("<I", nuevo, pos_nueva + 16, off_cd + len(bloque))
    ruta.write_bytes(bytes(nuevo))


# ---------------------------------------------------------------------------
# ELF y APK completos
# ---------------------------------------------------------------------------


def elf_stub(maquina: int = 0xB7, bits64: bool = True, extra: bytes = b"") -> bytes:
    cab = bytearray(64)
    cab[0:4] = b"\x7fELF"
    cab[4] = 2 if bits64 else 1
    cab[5] = 1
    struct.pack_into("<H", cab, 18, maquina)
    return bytes(cab) + extra


def crear_apk(ruta: Path, archivos: Dict[str, bytes], firma_v2: Optional[bytes] = None) -> Path:
    with zipfile.ZipFile(ruta, "w", compression=zipfile.ZIP_DEFLATED) as zf:
        for nombre, datos in archivos.items():
            zf.writestr(nombre, datos)
    if firma_v2 is not None:
        insertar_bloque_firma(ruta, bloque_firma_v2(firma_v2))
    return ruta


def apk_unity_il2cpp(ruta: Path, version_unity: str = "2022.3.21f1", meta: Optional[Dict[str, str]] = None,
                     split_required: bool = False) -> Path:
    unityfs = b"UnityFS\x00" + struct.pack(">I", 8) + b"5.x.x\x00" + version_unity.encode() + b"\x00" + b"\x00" * 64
    metadata = struct.pack("<Ii", 0xFAB11BAF, 29) + b"\x00" * 32
    dex = construir_dex(
        ["Lcom/unity3d/player/UnityPlayerActivity;", "Lcom/google/firebase/analytics/FirebaseAnalytics;",
         "Lcom/applovin/sdk/AppLovinSdk;", "Lcom/android/billingclient/api/BillingClient;",
         "Lcom/appsflyer/AppsFlyerLib;", "Lcom/ejemplo/juego/Principal;"],
        cadenas_extra=["https://api.ejemplo-backend.com/v1/config", "http://schemas.android.com/apk/res/android"])
    archivos = {
        "AndroidManifest.xml": manifiesto_ejemplo(meta=meta, split_required=split_required,
                                                  permisos=("android.permission.INTERNET",
                                                            "com.android.vending.BILLING")),
        "classes.dex": dex,
        "lib/arm64-v8a/libunity.so": elf_stub(0xB7),
        "lib/arm64-v8a/libil2cpp.so": elf_stub(0xB7),
        "lib/arm64-v8a/libmain.so": elf_stub(0xB7),
        "lib/armeabi-v7a/libunity.so": elf_stub(0x28, bits64=False),
        "assets/bin/Data/data.unity3d": unityfs,
        "assets/bin/Data/Managed/Metadata/global-metadata.dat": metadata,
        "assets/bin/Data/sharedassets0.assets": b"\x00" * 128,
        "assets/aa/settings.json": b'{"url": "https://cdn.ejemplo-contenido.net/bundles"}',
        "assets/fonts/Display.ttf": b"\x00\x01\x00\x00",
        "res/drawable/icono.png": b"\x89PNG\r\n\x1a\n",
        "META-INF/MANIFEST.MF": b"Manifest-Version: 1.0\n",
    }
    return crear_apk(ruta, archivos, firma_v2=certificado_falso())
