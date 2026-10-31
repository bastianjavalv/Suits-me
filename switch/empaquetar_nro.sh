#!/bin/sh
# Empaqueta el juego como NRO de homebrew para Switch: el motor (ELF) más una romfs con game.pck,
# el icono y los metadatos NACP.
#
#   switch/empaquetar_nro.sh --motor <ELF> --pck <game.pck> --icono <icono.jpg> --salida <juego.nro>
#                            [--titulo T] [--autor A] [--version V] [--carpeta C]
#
# Necesita nacptool y elf2nro (switch-tools, incluidos en el entorno devkitA64). --carpeta es la
# carpeta de la tarjeta SD que usa el juego: sdmc:/switch/<carpeta>/ (partida, registro, args.txt).
# La versión predeterminada es la de game/project.godot.
set -eu
RAIZ=$(cd "$(dirname "$0")/.." && pwd)
TITULO="Atelier de las Eras"
AUTOR="Proyecto Atelier de las Eras"
VERSION=""
CARPETA="AtelierDeLasEras"
MOTOR=""
PCK=""
ICONO=""
SALIDA=""
while [ $# -gt 0 ]; do
	[ $# -ge 2 ] || { echo "falta el valor de $1" >&2; exit 2; }
	case "$1" in
		--motor) MOTOR=$2 ;;
		--pck) PCK=$2 ;;
		--icono) ICONO=$2 ;;
		--salida) SALIDA=$2 ;;
		--titulo) TITULO=$2 ;;
		--autor) AUTOR=$2 ;;
		--version) VERSION=$2 ;;
		--carpeta) CARPETA=$2 ;;
		*) echo "opción desconocida: $1" >&2; exit 2 ;;
	esac
	shift 2
done
for f in "$MOTOR" "$PCK" "$ICONO"; do
	[ -f "$f" ] || { echo "no existe: '$f' (se necesitan --motor, --pck e --icono)" >&2; exit 2; }
done
[ -n "$SALIDA" ] || { echo "falta --salida" >&2; exit 2; }
case "$CARPETA" in
	*[!A-Za-z0-9._-]*|.*|"") echo "--carpeta solo admite letras, cifras, '.', '-' y '_': $CARPETA" >&2; exit 2 ;;
esac
[ -n "$VERSION" ] || VERSION=$(sed -n 's/^config\/version="\(.*\)"$/\1/p' "$RAIZ/game/project.godot")
HERRAMIENTAS="${DEVKITPRO:?falta DEVKITPRO: ejecuta este script en el entorno devkitA64}/tools/bin"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
mkdir "$TMP/romfs"
# El motor busca romfs:/game.pck y toma el nombre de la carpeta de la SD de romfs:/app.id.
cp "$PCK" "$TMP/romfs/game.pck"
printf '%s\n' "$CARPETA" > "$TMP/romfs/app.id"
"$HERRAMIENTAS/nacptool" --create "$TITULO" "$AUTOR" "$VERSION" "$TMP/app.nacp"
"$HERRAMIENTAS/elf2nro" "$MOTOR" "$TMP/juego.nro" --icon="$ICONO" --nacp="$TMP/app.nacp" --romfsdir="$TMP/romfs"
mkdir -p "$(dirname "$SALIDA")"
cp "$TMP/juego.nro" "$SALIDA"
echo "NRO: $SALIDA ($TITULO $VERSION, carpeta sdmc:/switch/$CARPETA/)"
