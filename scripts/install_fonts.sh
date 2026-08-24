#!/bin/bash

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# ============================================
# Nerd Font: JetBrains Mono
# ============================================
# Variables de entorno:
#   NERD_FONT_VERSION - tag de release de ryanoasis/nerd-fonts a instalar
#                        (por defecto, la versión pinneada abajo)
#   NERD_FONT_FORCE    - "1" para forzar la reinstalación aunque la fuente
#                        ya esté presente, en la misma versión
NERD_FONT_PINNED_VERSION="v3.5.1"
NERD_FONT_VERSION="${NERD_FONT_VERSION:-$NERD_FONT_PINNED_VERSION}"
NERD_FONT_FORCE="${NERD_FONT_FORCE:-0}"

# SHA-256 de JetBrainsMono.zip para NERD_FONT_PINNED_VERSION, fijado en el
# propio repo. El release publica su propio SHA-256.txt en el mismo origen y
# por el mismo canal (HTTPS a github.com) que el zip — eso cierra corrupción
# y truncamiento, pero no un proxy que intercepte TLS y sirva un zip y un
# SHA-256.txt manipulados a la vez (p.ej. un proxy corporativo). Verificar
# contra una constante que vive en este script, en vez de contra ese
# fichero descargado, cierra ese hueco: un MITM no puede alterar el
# contenido de este repo.
# *** ACTUALIZA ESTA CONSTANTE JUNTO CON NERD_FONT_PINNED_VERSION cada vez
# que subas la versión pinneada *** — recalcúlala desde un canal en el que
# confíes (idealmente distinto de la red que quieres proteger), p.ej.:
#   curl -sL "https://github.com/ryanoasis/nerd-fonts/releases/download/<tag>/SHA-256.txt" | grep JetBrainsMono.zip
# o contrástala con el campo `digest` de la API de releases de GitHub:
#   curl -s "https://api.github.com/repos/ryanoasis/nerd-fonts/releases/tags/<tag>" | jq -r '.assets[] | select(.name=="JetBrainsMono.zip") | .digest'
EXPECTED_SHA256_PINNED="fab782a66f7d3019da64f6572db9fc5d3a4bcb19f9fa13e2d8a62e3693d6396e"

FONT_NAME="JetBrainsMono"
FONT_DIR="$HOME/.local/share/fonts/${FONT_NAME}NerdFont"
# Marker de integridad: fichero concreto que la extracción debe dejar en disco.
FONT_MARKER="$FONT_DIR/${FONT_NAME}NerdFontMono-Regular.ttf"
# Marker de idempotencia: codifica la versión instalada, para que subir
# NERD_FONT_VERSION sobre una instalación existente dispare una reinstalación
# en vez de un no-op silencioso.
VERSION_MARKER="$FONT_DIR/.nerd-font-version"

echo -e "${GREEN}🔤 Instalando ${FONT_NAME} Nerd Font (${NERD_FONT_VERSION})...${NC}"

# ============================================
# Validación de dependencias
# ============================================
for cmd in curl unzip sha256sum; do
    if ! command -v "$cmd" &> /dev/null; then
        echo -e "${RED}❌ '$cmd' no está instalado — instálalo primero (ver scripts/install_packages.sh)${NC}"
        exit 1
    fi
done

if ! command -v fc-cache &> /dev/null; then
    echo -e "${RED}❌ 'fc-cache' no está instalado (paquete fontconfig) — instálalo antes de continuar${NC}"
    exit 1
fi

# ============================================
# Idempotencia
# ============================================
# Comprobamos tanto el sello de versión como la presencia real del fichero de
# fuente: si el sello sobrevive pero el usuario borró $FONT_DIR (o solo el
# .ttf), un skip basado solo en el sello reportaría "ya instalado" sin que
# la fuente exista — el script debe autorrepararse en ese caso, no confiar
# ciegamente en el marker.
if [[ -f "$VERSION_MARKER" && "$(cat "$VERSION_MARKER")" == "$NERD_FONT_VERSION" && -f "$FONT_MARKER" && "$NERD_FONT_FORCE" != "1" ]]; then
    echo -e "${YELLOW}${FONT_NAME} Nerd Font ${NERD_FONT_VERSION} ya está instalada — skip (usa NERD_FONT_FORCE=1 para reinstalar)${NC}"
    exit 0
fi

# ============================================
# Descarga
# ============================================
echo -e "${YELLOW}Descargando ${FONT_NAME} Nerd Font ${NERD_FONT_VERSION}...${NC}"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

# Timeouts + reintentos: una conexión colgada no debe bloquear "make all"
# indefinidamente. --speed-limit/--speed-time corta la descarga si el
# throughput cae por debajo de 1 KiB/s durante 30s seguidos — detecta
# cuelgues sin penalizar una conexión lenta pero viva. Deliberadamente NO
# hay --max-time en la descarga del zip (~130 MiB): un techo absoluto de
# tiempo mataría precisamente la conexión lenta-pero-viva que
# --speed-limit/--speed-time están para tolerar, y --retry reinicia la
# descarga desde cero en cada reintento (no hay resume), así que un límite
# bajo puede impedir terminar incluso una conexión sana. Es el fichero de
# sumas (unos pocos KiB) el que sí lleva un --max-time corto, porque a ese
# tamaño cualquier conexión viva lo resuelve en segundos.
CURL_COMMON_OPTS=(--fail --location --retry 3 --retry-delay 2 --connect-timeout 10 --speed-limit 1024 --speed-time 30)

DOWNLOAD_URL="https://github.com/ryanoasis/nerd-fonts/releases/download/${NERD_FONT_VERSION}/${FONT_NAME}.zip"
CHECKSUMS_URL="https://github.com/ryanoasis/nerd-fonts/releases/download/${NERD_FONT_VERSION}/SHA-256.txt"
ZIP_PATH="$TMP_DIR/${FONT_NAME}.zip"
CHECKSUMS_PATH="$TMP_DIR/SHA-256.txt"

if ! curl "${CURL_COMMON_OPTS[@]}" -o "$ZIP_PATH" "$DOWNLOAD_URL"; then
    echo -e "${RED}❌ Descarga fallida: $DOWNLOAD_URL${NC}"
    exit 1
fi

# ============================================
# Verificación de integridad (ANTES de descomprimir)
# ============================================
echo -e "${YELLOW}Verificando integridad SHA-256...${NC}"

if [[ "$NERD_FONT_VERSION" == "$NERD_FONT_PINNED_VERSION" ]]; then
    # Ruta por defecto: verificamos contra el hash fijado arriba, en el
    # propio repo — cierra también el brazo MITM (ver comentario junto a la
    # constante).
    if ! printf '%s  %s\n' "$EXPECTED_SHA256_PINNED" "$ZIP_PATH" | sha256sum --status -c -; then
        echo -e "${RED}❌ Verificación de integridad SHA-256 fallida para ${FONT_NAME}.zip (contra el hash fijado en el repo) — abortando sin descomprimir${NC}"
        exit 1
    fi
    echo -e "${GREEN}✅ Integridad SHA-256 verificada contra el hash fijado en el repo${NC}"
else
    # NERD_FONT_VERSION fue sobreescrita a una versión distinta de la
    # pinneada — no existe constante en el repo para ella. Recurrimos al
    # SHA-256.txt que publica el propio release: cierra corrupción y
    # truncamiento, pero NO cierra un MITM que intercepte también ese
    # fichero (mismo origen y mismo canal que el zip).
    echo -e "${YELLOW}⚠️  NERD_FONT_VERSION=${NERD_FONT_VERSION} no coincide con la versión pinneada (${NERD_FONT_PINNED_VERSION}) — verificando contra el SHA-256.txt del release, que NO protege frente a un MITM que intercepte también ese fichero${NC}"

    if ! curl "${CURL_COMMON_OPTS[@]}" --max-time 60 -o "$CHECKSUMS_PATH" "$CHECKSUMS_URL"; then
        echo -e "${RED}❌ No se pudo descargar el fichero de sumas SHA-256 ($CHECKSUMS_URL) — abortando sin descomprimir${NC}"
        exit 1
    fi

    EXPECTED_LINE="$(grep -i -F "${FONT_NAME}.zip" "$CHECKSUMS_PATH")" || EXPECTED_LINE=""
    if [[ -z "$EXPECTED_LINE" ]]; then
        echo -e "${RED}❌ El fichero de sumas no contiene una entrada para ${FONT_NAME}.zip — abortando sin descomprimir${NC}"
        exit 1
    fi

    if ! (cd "$TMP_DIR" && printf '%s\n' "$EXPECTED_LINE" | sha256sum --status -c -); then
        echo -e "${RED}❌ Verificación de integridad SHA-256 fallida para ${FONT_NAME}.zip — abortando sin descomprimir${NC}"
        exit 1
    fi

    echo -e "${GREEN}✅ Integridad SHA-256 verificada contra el SHA-256.txt del release${NC}"
fi

# ============================================
# Extracción selectiva (a un directorio temporal, nunca directo al destino)
# ============================================
# El zip completo trae todas las variantes (Complete/Mono/Propo, con y sin
# ligaduras) para cada peso — decenas de ficheros y cientos de MiB. Para uso
# en terminal solo hace falta la variante "Mono" (glyphs de iconos con el
# mismo ancho que los caracteres — evita descuadres en el prompt) en los 4
# estilos básicos, más el fichero de licencia (OFL — el release NO publica
# un LICENSE.txt propio, solo OFL.txt; un patrón que no exista en el zip
# hace que unzip termine con exit 11 aunque el resto de patrones sí
# extraigan).
EXTRACT_PATTERNS=(
    "${FONT_NAME}NerdFontMono-Regular.ttf"
    "${FONT_NAME}NerdFontMono-Bold.ttf"
    "${FONT_NAME}NerdFontMono-Italic.ttf"
    "${FONT_NAME}NerdFontMono-BoldItalic.ttf"
    "OFL.txt"
)

EXTRACT_DIR="$TMP_DIR/extracted"
mkdir -p "$EXTRACT_DIR"

set +e
# Deliberadamente SIN -q/-qq: en esta build de info-zip (UnZip 6.00, Debian)
# el flag de silencio rebaja a 0 el exit 1 con el que unzip avisa de haber
# saneado entradas de ruta RELATIVA ("../"); las de ruta absoluta devuelven 1
# con y sin -q (ambos casos medidos en esta build). Ese exit 1 es justo el que
# este script no puede permitirse tragar, así que el ruido se silencia
# redirigiendo stdout desde el shell, no con -q, para no tocar la semántica
# del código de salida.
unzip -o "$ZIP_PATH" -d "$EXTRACT_DIR" "${EXTRACT_PATTERNS[@]}" > /dev/null
UNZIP_EXIT=$?
set -e

if [[ "$UNZIP_EXIT" -ne 0 ]]; then
    # Cualquier código de salida distinto de 0 aborta — nunca se traga, ni
    # siquiera "para simplificar". info-zip devuelve 11 en cuanto CUALQUIER
    # patrón de la lista no encuentra coincidencia (no solo cuando todos
    # fallan), así que exit-code-only ya es un gate de extracción completa,
    # no solo de "algo se extrajo". El control efectivo frente a zip-slip no
    # es este código de salida sino la selección por patrón literal de
    # EXTRACT_PATTERNS: una entrada con nombre de traversal nunca llega a
    # seleccionarse (verificado con un zip que llevaba "../../pwned.txt" y
    # "/tmp/pwned.txt" — extracción limpia, cero ficheros fuera del destino).
    # El código 1 queda como alarma secundaria, y por eso tampoco se descarta
    # silenciosamente ni se trata como benigno.
    echo -e "${RED}❌ unzip terminó con código ${UNZIP_EXIT} al extraer ${FONT_NAME}.zip — abortando (código 1 puede indicar saneamiento de entradas por path traversal; código 11, un patrón sin coincidencia)${NC}"
    exit 1
fi

EXTRACTED_MARKER="$EXTRACT_DIR/$(basename "$FONT_MARKER")"
if [[ ! -f "$EXTRACTED_MARKER" ]]; then
    echo -e "${RED}❌ La extracción no generó el fichero esperado ($(basename "$FONT_MARKER")) — instalación incompleta${NC}"
    exit 1
fi

# Solo ahora, con la extracción ya validada en un directorio temporal,
# sustituimos el destino: una extracción fallida o el assert de arriba ya
# habrían abortado el script SIN tocar $FONT_DIR, así que una instalación
# anterior que funcionaba nunca se pierde por culpa de una reinstalación
# fallida.
rm -rf "$FONT_DIR"
mkdir -p "$(dirname "$FONT_DIR")"
mv "$EXTRACT_DIR" "$FONT_DIR"

echo -e "${YELLOW}Refrescando la caché de fuentes...${NC}"
fc-cache -f "$FONT_DIR" > /dev/null

# El sello de versión se escribe SOLO tras un fc-cache correcto: si
# fc-cache fallara antes, la instalación quedaría registrada como completa
# y el script no la reintentaría nunca en una ejecución posterior.
echo "$NERD_FONT_VERSION" > "$VERSION_MARKER"

echo -e "${GREEN}✅ ${FONT_NAME} Nerd Font instalada en ${FONT_DIR}${NC}"
