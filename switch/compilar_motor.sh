#!/bin/sh
# Compila el motor de Godot del port homebrew de Switch (un ELF) en el entorno devkitA64: la imagen
# devkitpro/devkita64 fijada por digest en .github/workflows/ci.yml.
#
#   switch/compilar_motor.sh <carpeta de trabajo> [argumentos extra de scons]
#
# Descarga Godot en la etiqueta de motor/GODOT_VERSION, comprueba que el commit sea el oficial
# (motor/GODOT_COMMIT), aplica motor/patches y copia motor/platform/switch. Necesita DEVKITPRO, git y
# SCons 4.4 o posterior (SCONS permite indicar otra orden, p. ej. "python3 -m SCons").
# Resultado: <carpeta de trabajo>/godot/bin/godot.switch.template_release.arm64
set -eu
RAIZ=$(cd "$(dirname "$0")" && pwd)
[ $# -ge 1 ] || { echo "uso: $0 <carpeta de trabajo> [argumentos de scons]" >&2; exit 2; }
TRABAJO=$1
shift
: "${DEVKITPRO:?falta DEVKITPRO: ejecuta este script en el entorno devkitA64}"
ETIQUETA=$(cat "$RAIZ/motor/GODOT_VERSION")
COMMIT=$(cat "$RAIZ/motor/GODOT_COMMIT")
FUENTE="$TRABAJO/godot"

if [ ! -d "$FUENTE/.git" ]; then
	mkdir -p "$TRABAJO"
	git clone --quiet --depth 1 --branch "$ETIQUETA" https://github.com/godotengine/godot.git "$FUENTE"
fi
REAL=$(git -C "$FUENTE" rev-parse HEAD)
if [ "$REAL" != "$COMMIT" ]; then
	echo "commit de Godot inesperado: $REAL (se esperaba $COMMIT)" >&2
	exit 1
fi

if [ ! -f "$FUENTE/.parches-switch" ]; then
	for p in "$RAIZ"/motor/patches/*.patch; do
		echo "aplicando $(basename "$p")"
		git -C "$FUENTE" apply "$p"
	done
	touch "$FUENTE/.parches-switch"
fi
rm -rf "$FUENTE/platform/switch"
cp -a "$RAIZ/motor/platform/switch" "$FUENTE/platform/switch"

cd "$FUENTE"
${SCONS:-scons} platform=switch target=template_release -j"${TRABAJOS:-$(nproc)}" "$@"
echo "motor: $FUENTE/bin/godot.switch.template_release.arm64"
