#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
check_offline.py - Garantiza que el juego funciona sin conexion: falla si el codigo o las escenas
de Godot usan clases o metodos de red, abren URLs o cargan complementos nativos de terceros.

Uso: python tools/check_offline.py [CARPETA_DEL_JUEGO]
"""
from __future__ import annotations

import re
import sys
from pathlib import Path
from typing import List, Optional

PROHIBIDO = [
    ("HTTPRequest", "peticiones HTTP"),
    ("HTTPClient", "cliente HTTP"),
    ("StreamPeerTCP", "conexiones TCP"),
    ("StreamPeerTLS", "conexiones TLS"),
    ("TCPServer", "servidor TCP"),
    ("PacketPeerUDP", "paquetes UDP"),
    ("UDPServer", "servidor UDP"),
    ("WebSocketPeer", "WebSocket"),
    ("WebSocketMultiplayerPeer", "WebSocket multijugador"),
    ("WebRTCPeerConnection", "WebRTC"),
    ("ENetMultiplayerPeer", "red multijugador"),
    ("ENetConnection", "red ENet"),
    ("MultiplayerAPI", "multijugador en red"),
    ("JavaScriptBridge", "puente con el navegador"),
    ("OS.shell_open", "apertura de URLs externas"),
    ("GDExtension", "extensiones nativas de terceros"),
]
EXTENSIONES = {".gd", ".tscn", ".tres", ".gdshader", ".cfg", ".godot", ".gdextension"}
EXCLUIR = {".godot", "tests"}


def revisar(raiz: Path) -> List[str]:
    problemas: List[str] = []
    for ruta in sorted(raiz.rglob("*")):
        if not ruta.is_file() or any(p in EXCLUIR for p in ruta.relative_to(raiz).parts):
            continue
        if ruta.suffix == ".gdextension":
            problemas.append("%s: extensión nativa (.gdextension)" % ruta.relative_to(raiz).as_posix())
            continue
        if ruta.suffix not in EXTENSIONES:
            continue
        for n, linea in enumerate(ruta.read_text(encoding="utf-8", errors="ignore").splitlines(), 1):
            codigo = linea.split("#", 1)[0] if ruta.suffix == ".gd" else linea
            for simbolo, motivo in PROHIBIDO:
                if re.search(r"\b%s\b" % re.escape(simbolo), codigo):
                    problemas.append("%s:%d: %s (%s)" % (ruta.relative_to(raiz).as_posix(), n, simbolo, motivo))
    return problemas


def main(argv: Optional[List[str]] = None) -> int:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    argv = sys.argv[1:] if argv is None else argv
    raiz = Path(argv[0]) if argv else Path(__file__).resolve().parents[1] / "game"
    problemas = revisar(raiz)
    if problemas:
        print("El juego usa funciones de red o externas (%d):" % len(problemas))
        for p in problemas:
            print("  - " + p)
        return 1
    print("Sin conexión: el juego no usa APIs de red, URLs externas ni extensiones nativas.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
