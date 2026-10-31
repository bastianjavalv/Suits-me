#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
check_repo.py - Impide que entren al repositorio material propietario o credenciales.

Revisa los archivos versionados y los nuevos no ignorados (git ls-files) o, si no hay git, todos
los archivos de la carpeta:
    * extensiones prohibidas (APK, DEX, bibliotecas nativas, paquetes de Unity, almacenes de claves)
    * firmas binarias (ZIP con AndroidManifest/classes.dex, DEX, ELF, UnityFS, metadatos IL2CPP)
    * patrones de credenciales en archivos de texto
    * archivos grandes que no estan gestionados por Git LFS

Uso: python tools/check_repo.py [RAIZ]
Devuelve 0 si no hay problemas y 1 si encuentra alguno.
"""
from __future__ import annotations

import re
import subprocess
import sys
import zipfile
from pathlib import Path
from typing import Iterable, List, Optional, Tuple

EXT_PROHIBIDAS = {
    ".apk": "paquete Android",
    ".apks": "paquete Android",
    ".xapk": "paquete Android",
    ".aab": "Android App Bundle",
    ".obb": "expansion de Android",
    ".dex": "codigo Android compilado",
    ".so": "biblioteca nativa",
    ".unity3d": "paquete de Unity",
    ".ress": "datos de Unity",
    ".keystore": "almacen de claves",
    ".jks": "almacen de claves",
    ".p12": "certificado con clave privada",
    ".pfx": "certificado con clave privada",
    ".pem": "clave o certificado PEM",
    ".key": "clave privada",
    ".nsp": "paquete de consola",
    ".xci": "imagen de cartucho",
    ".nca": "contenido de consola",
    ".nro": "ejecutable homebrew compilado (lo genera la CI)",
    ".nso": "ejecutable de consola",
    ".keys": "claves de consola",
}
NOMBRES_PROHIBIDOS = {"global-metadata.dat": "metadatos IL2CPP", ".env": "variables de entorno",
                      "prod.keys": "claves de consola", "title.keys": "claves de consola"}

PATRONES_SECRETOS: List[Tuple[str, re.Pattern]] = [
    ("clave privada PEM", re.compile(r"-----BEGIN (?:RSA |EC |DSA |OPENSSH |ENCRYPTED )?PRIVATE KEY-----")),
    ("clave de AWS", re.compile(r"\bAKIA[0-9A-Z]{16}\b")),
    ("clave de API de Google", re.compile(r"\bAIza[0-9A-Za-z_\-]{35}\b")),
    ("token de GitHub", re.compile(r"\bgh[pousr]_[A-Za-z0-9]{36,}\b")),
    ("token de Slack", re.compile(r"\bxox[baprs]-[A-Za-z0-9-]{10,}\b")),
    ("ID de aplicacion AdMob", re.compile(r"\bca-app-pub-\d{16}~\d{10}\b")),
]

LIMITE_SIN_LFS = 5 * 1024 * 1024
EXT_TEXTO = {".md", ".txt", ".json", ".gd", ".gdshader", ".tscn", ".tres", ".cfg", ".py", ".yml", ".yaml",
             ".toml", ".ini", ".godot", ".csv", ".svg", ".html", ".js", ".sh", ".ps1"}


def archivos_versionados(raiz: Path) -> List[Path]:
    try:
        salida = subprocess.run(["git", "ls-files", "-z", "--cached", "--others", "--exclude-standard"],
                                cwd=raiz, capture_output=True, check=True).stdout
        return [raiz / p for p in salida.decode("utf-8").split("\0") if p]
    except (OSError, subprocess.CalledProcessError):
        return [p for p in raiz.rglob("*") if p.is_file() and ".git" not in p.parts]


def gestionado_por_lfs(raiz: Path, ruta: Path) -> bool:
    try:
        rel = ruta.relative_to(raiz).as_posix()
        salida = subprocess.run(["git", "check-attr", "filter", "--", rel], cwd=raiz,
                                capture_output=True, check=True, text=True).stdout
        return salida.strip().endswith(": lfs")
    except (OSError, subprocess.CalledProcessError, ValueError):
        return False


def firma_binaria(ruta: Path) -> Optional[str]:
    try:
        with ruta.open("rb") as f:
            cab = f.read(16)
    except OSError:
        return None
    if cab.startswith(b"dex\n"):
        return "archivo DEX de Android"
    if cab.startswith(b"\x7fELF"):
        return "binario ELF (biblioteca nativa o ejecutable)"
    if cab.startswith(b"UnityFS"):
        return "paquete UnityFS"
    if cab[:4] == b"\xaf\x1b\xb1\xfa":
        return "metadatos IL2CPP"
    if cab[:4] == b"\xfe\xed\xfe\xed":
        return "almacen de claves Java (JKS)"
    if cab.startswith(b"PK\x03\x04"):
        try:
            with zipfile.ZipFile(ruta) as zf:
                nombres = set(zf.namelist())
            if "AndroidManifest.xml" in nombres or "classes.dex" in nombres:
                return "paquete Android dentro de un ZIP"
        except zipfile.BadZipFile:
            pass
    return None


def revisar(raiz: Path, archivos: Optional[Iterable[Path]] = None) -> List[str]:
    raiz = raiz.resolve()
    problemas: List[str] = []
    for ruta in archivos if archivos is not None else archivos_versionados(raiz):
        if not ruta.is_file():
            continue
        rel = ruta.relative_to(raiz).as_posix() if ruta.is_absolute() else ruta.as_posix()
        ext = ruta.suffix.lower()
        if ext in EXT_PROHIBIDAS:
            problemas.append("%s: extension prohibida (%s)" % (rel, EXT_PROHIBIDAS[ext]))
            continue
        if ruta.name in NOMBRES_PROHIBIDOS:
            problemas.append("%s: archivo prohibido (%s)" % (rel, NOMBRES_PROHIBIDOS[ruta.name]))
            continue
        firma = firma_binaria(ruta)
        if firma:
            problemas.append("%s: contenido prohibido (%s)" % (rel, firma))
            continue
        tam = ruta.stat().st_size
        if tam > LIMITE_SIN_LFS and not gestionado_por_lfs(raiz, ruta):
            problemas.append("%s: %.1f MB sin Git LFS (limite %d MB)" % (rel, tam / 1048576, LIMITE_SIN_LFS // 1048576))
        if ext in EXT_TEXTO and tam <= 2 * 1024 * 1024:
            texto = ruta.read_text(encoding="utf-8", errors="ignore")
            for nombre, patron in PATRONES_SECRETOS:
                if patron.search(texto):
                    problemas.append("%s: posible credencial (%s)" % (rel, nombre))
    return problemas


def main(argv: Optional[List[str]] = None) -> int:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    argv = sys.argv[1:] if argv is None else argv
    raiz = Path(argv[0]) if argv else Path(__file__).resolve().parents[1]
    problemas = revisar(raiz)
    if problemas:
        print("Se encontraron %d problema(s):" % len(problemas))
        for p in problemas:
            print("  - " + p)
        return 1
    print("Repositorio limpio: sin material propietario ni credenciales detectadas.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
