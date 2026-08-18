#!/bin/bash
# Wrapper para ejecutar Claude Code en modo headless (cron / automatización)
# usando el perfil de configuración aislado ~/.claude-headless, vía
# CLAUDE_CONFIG_DIR. No lee el perfil interactivo (~/.claude) durante la
# ejecución de claude; la única excepción es la reparación automática del
# symlink de credenciales tras un refresh OAuth (ver más abajo), que SÍ
# puede escribir sobre el destino previo del symlink si detecta que se
# desincronizó — solo cuando el perfil vive en la ruta por defecto
# ($HOME/.claude-headless); con CLAUDE_HEADLESS_DIR sobreescrito, la
# reparación se salta.
#
# Wrapper to run Claude Code headless (cron/automation) against the
# isolated ~/.claude-headless profile via CLAUDE_CONFIG_DIR. Does not read
# the interactive profile (~/.claude) while claude runs; the one exception
# is the automatic credentials-symlink repair after an OAuth refresh (see
# below), which CAN write over the symlink's prior target if it detects
# the two profiles diverged — only when the profile lives at the default
# path ($HOME/.claude-headless); with CLAUDE_HEADLESS_DIR overridden, the
# repair is skipped.
#
# Uso / usage:
#   claude-headless.sh [-C <workdir>] "<prompt>" [flags extra de claude...]

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

HEADLESS_DIR="${CLAUDE_HEADLESS_DIR:-$HOME/.claude-headless}"

usage() {
    echo "Uso: $(basename "$0") [-C <workdir>] \"<prompt>\" [flags extra de claude...]"
}

# ============================================
# Parseo de argumentos
# ============================================

WORKDIR=""
while getopts ":C:" opt; do
    case "$opt" in
        C) WORKDIR="$OPTARG" ;;
        \?) echo -e "${RED}❌ Opción desconocida: -$OPTARG${NC}" >&2; usage; exit 1 ;;
        :) echo -e "${RED}❌ -C requiere un directorio${NC}" >&2; usage; exit 1 ;;
    esac
done
shift $((OPTIND - 1))

PROMPT="${1:-}"
if [[ -z "$PROMPT" ]]; then
    echo -e "${RED}❌ Falta el prompt${NC}" >&2
    usage
    exit 1
fi
if [[ "$PROMPT" == -* ]]; then
    echo -e "${RED}❌ El prompt no puede empezar por '-' — orden correcto:${NC}" >&2
    echo -e "${YELLOW}   $(basename "$0") [-C dir] \"prompt\" [flags extra]${NC}" >&2
    usage
    exit 1
fi
shift

# ============================================
# Resolución robusta del binario claude
# ============================================
# cron no fuente .bashrc/.zshrc, así que el PATH mínimo por defecto no
# suele incluir ~/.local/bin (donde vive `claude` en instalaciones vía
# npm/curl típicas). Se resuelve explícitamente en vez de confiar en el
# PATH heredado del entorno que invoca este script.

CLAUDE_BIN="${CLAUDE_BIN:-$(command -v claude || true)}"
if [[ -z "$CLAUDE_BIN" ]]; then
    CLAUDE_BIN="$HOME/.local/bin/claude"
fi
if [[ ! -x "$CLAUDE_BIN" ]]; then
    echo -e "${RED}❌ No se encuentra un binario 'claude' ejecutable (CLAUDE_BIN=$CLAUDE_BIN)${NC}" >&2
    echo -e "${YELLOW}   Exporta CLAUDE_BIN=/ruta/a/claude o añade claude a PATH${NC}" >&2
    exit 1
fi

# ============================================
# Validaciones del perfil headless
# ============================================

if [[ ! -f "$HEADLESS_DIR/settings.json" ]]; then
    echo -e "${RED}❌ No existe $HEADLESS_DIR/settings.json — ejecuta 'make claude' primero${NC}" >&2
    exit 1
fi

if [[ ! -f "$HEADLESS_DIR/.credentials.json" ]]; then
    echo -e "${RED}❌ No existe $HEADLESS_DIR/.credentials.json${NC}" >&2
    echo -e "${YELLOW}   Haz login con Claude Code normal ('claude' en interactivo) y vuelve${NC}" >&2
    echo -e "${YELLOW}   a ejecutar 'make claude': enlaza ~/.claude/.credentials.json →${NC}" >&2
    echo -e "${YELLOW}   $HEADLESS_DIR/.credentials.json automáticamente.${NC}" >&2
    exit 1
fi

# Aislamiento: reemplaza POR COMPLETO el user scope de Claude Code
# (settings.json, CLAUDE.md, hooks, credenciales) — nada de ~/.claude
# se lee cuando esta variable está exportada.
export CLAUDE_CONFIG_DIR="$HEADLESS_DIR"

# Cambiar de directorio de trabajo si se pidió -C, antes de ejecutar
if [[ -n "$WORKDIR" ]]; then
    cd "$WORKDIR"
fi

# ============================================
# Ejecución con logging
# ============================================

LOG_FILE="$HEADLESS_DIR/logs/$(date +%Y%m%d-%H%M%S)-$$.log"

# Pre-flight: crea logs/ (por si hiciera falta) y el propio fichero de
# log ANTES de invocar claude, bajo una umask restrictiva acotada a
# este subshell — nunca global (una umask global se heredaría por
# claude y por todo lo que este cree en el workdir, no solo por el
# log). Si falla (permisos, disco lleno...) es un error propio del
# wrapper: claude ni siquiera llega a ejecutarse, así que nunca debe
# reportarse como si fuera su exit code.
if ! ( umask 077; mkdir -p "$HEADLESS_DIR/logs" && touch "$LOG_FILE" ); then
    echo -e "${RED}❌ No se puede crear $LOG_FILE — revisa permisos de $HEADLESS_DIR/logs${NC}" >&2
    exit 1
fi

# Rotación simple: borrar logs de más de 30 días. Se hace ANTES de
# invocar claude para que un fallo aquí (p.ej. `find` compitiendo con
# otra ejecución de cron concurrente) nunca enmascare el exit code de
# claude, que es lo que este script debe preservar.
find "$HEADLESS_DIR/logs" -name '*.log' -mtime +30 -delete || true

# Estado del symlink de credenciales ANTES de invocar claude — necesario
# para distinguir, después de la ejecución, un refresh OAuth que rompió
# el symlink (reparable) de un login headless deliberadamente distinto
# al interactivo (no debe tocarse — ver reparación más abajo). Si es
# symlink, se captura también su destino REAL con `readlink -f`: la
# reparación restaura ESE destino, nunca asume ~/.claude/.credentials.json
# a ciegas (evita re-homear un enlace que apuntaba a otro sitio).
HEADLESS_CREDS="$HEADLESS_DIR/.credentials.json"
CREDS_WAS_SYMLINK=0
CREDS_LINK_TARGET=""
if [[ -L "$HEADLESS_CREDS" ]]; then
    CREDS_WAS_SYMLINK=1
    CREDS_LINK_TARGET="$(readlink -f "$HEADLESS_CREDS" || true)"
fi

# Prune de backups de credenciales de más de 7 días — mismo estilo que
# la rotación de logs de arriba (incondicional, ANTES de invocar
# claude, para que corra siempre y no solo cuando la reparación de
# abajo se dispara). Solo si el perfil vive en la ruta por defecto,
# igual que la reparación misma (ver más abajo).
if [[ "$HEADLESS_DIR" == "$HOME/.claude-headless" ]] && [[ -n "$CREDS_LINK_TARGET" ]]; then
    find "$(dirname "$CREDS_LINK_TARGET")" -maxdepth 1 \
        -name "$(basename "$CREDS_LINK_TARGET").bak.*" -mtime +7 -delete 2>/dev/null || true
fi

set +e
"$CLAUDE_BIN" -p "$PROMPT" --output-format json --max-turns "${CLAUDE_MAX_TURNS:-25}" "$@" > "$LOG_FILE" 2>&1
EXIT_CODE=$?
set -e

# ============================================
# Reparación del symlink de credenciales tras refresh OAuth
# ============================================
# Claude Code refresca el token OAuth reemplazando .credentials.json con
# un rename atómico, lo que rompe el symlink al perfil que apuntaba y
# divorcia los dos perfiles en silencio. Si el fichero ERA un symlink
# antes de esta ejecución y ya NO lo es, propagamos el fichero nuevo al
# destino capturado ANTES del run (con validación y backup) y
# recreamos el enlace. Envuelta en una función invocada con `|| true`:
# ningún paso de aquí dentro — incluido `ln` — puede abortar el script
# ni pisar el exit code de claude, que ya quedó capturado en
# EXIT_CODE. `set -e` se ignora mientras se evalúa el lado izquierdo de
# un `||`, y eso se propaga a toda función invocada ahí.
repair_credentials_symlink() {
    if [[ "$CREDS_WAS_SYMLINK" -ne 1 ]] || [[ ! -f "$HEADLESS_CREDS" ]] || [[ -L "$HEADLESS_CREDS" ]]; then
        return 0
    fi

    # Los denys de claude/headless/settings.json que protegen este
    # perfil están anclados a la ruta por defecto ($HOME/.claude-headless).
    # Si CLAUDE_HEADLESS_DIR la sobreescribió, esos denys ya no cubren
    # $HEADLESS_DIR — la reparación se salta en vez de propagar
    # credenciales fuera del perímetro que el perfil documenta.
    if [[ "$HEADLESS_DIR" != "$HOME/.claude-headless" ]]; then
        echo -e "${YELLOW}⚠  CLAUDE_HEADLESS_DIR sobreescribe el perfil por defecto — reparación de credenciales omitida (los denys del perfil no cubren esta ruta)${NC}" >&2
        return 0
    fi

    if ! command -v jq >/dev/null 2>&1; then
        echo -e "${RED}❌ jq no disponible — no se puede validar el .credentials.json desincronizado, reparación omitida${NC}" >&2
        return 0
    fi

    local target="${CREDS_LINK_TARGET:-$HOME/.claude/.credentials.json}"

    # Validación de contenido antes de propagar: no vacío y JSON válido.
    # Sin esto, un fichero corrupto o truncado (p.ej. un refresh
    # interrumpido a mitad) se propagaría al destino como si fuera un
    # token válido.
    if [[ ! -s "$HEADLESS_CREDS" ]] || ! jq empty "$HEADLESS_CREDS" >/dev/null 2>&1; then
        echo -e "${RED}❌ .credentials.json desincronizado pero no es JSON válido o está vacío — no se propaga, revísalo a mano${NC}" >&2
        return 0
    fi

    if [[ -f "$target" ]]; then
        local backup="${target}.bak.$(date +%Y%m%d%H%M%S)"
        if ! cp "$target" "$backup" 2>/dev/null; then
            echo -e "${RED}❌ No se pudo hacer backup de $target — no se sobrescribe, revísalo a mano${NC}" >&2
            return 0
        fi
        chmod 600 "$backup" 2>/dev/null || true
    fi

    if cp "$HEADLESS_CREDS" "$target" 2>/dev/null; then
        chmod 600 "$target" 2>/dev/null || true
        if ln -sfn "$target" "$HEADLESS_CREDS"; then
            echo -e "${YELLOW}⚠  .credentials.json se había desincronizado (refresh OAuth) — reparado y re-enlazado a $target${NC}" >&2
        else
            echo -e "${RED}❌ Credenciales propagadas a $target pero no se pudo re-enlazar $HEADLESS_CREDS — revísalo a mano${NC}" >&2
        fi
    else
        echo -e "${RED}❌ No se pudo reparar .credentials.json desincronizado — revísalo a mano${NC}" >&2
    fi
}

repair_credentials_symlink || true

if [[ "$EXIT_CODE" -eq 0 ]]; then
    echo -e "${GREEN}📄 Log: $LOG_FILE (exit $EXIT_CODE)${NC}"
else
    echo -e "${RED}📄 Log: $LOG_FILE (exit $EXIT_CODE)${NC}"
fi

exit "$EXIT_CODE"
