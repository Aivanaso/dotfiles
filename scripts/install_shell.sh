#!/bin/bash

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Directorio del repo de dotfiles (relativo al script)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Fichero rc destino — override con DOTFILES_RC (esto es lo que hace el
# script testeable sin tocar el HOME real del usuario)
RC_FILE="${DOTFILES_RC:-$HOME/.bashrc}"

BLOCK_START="# >>> dotfiles >>>"
BLOCK_END="# <<< dotfiles <<<"

echo -e "${GREEN}🐚 Instalando el punto de entrada de shell en $RC_FILE...${NC}"

# El rc puede no existir todavía (máquina nueva) — se crea vacío. Se
# recuerda con CREATED_BY_US para no hacer luego un backup absurdo de
# un fichero que nunca existió (ver más abajo).
CREATED_BY_US=0
if [ ! -f "$RC_FILE" ]; then
    touch "$RC_FILE"
    CREATED_BY_US=1
fi

# ============================================
# Escapado de metacaracteres ERE para interpolar rutas en [[ =~ ]] —
# carácter a carácter para no depender de la ambigüedad de bash al
# anidar llaves dentro de ${var//patrón/reemplazo}
# ============================================
_regex_escape() {
    local s="$1" out="" c
    local -i idx
    for ((idx = 0; idx < ${#s}; idx++)); do
        c="${s:idx:1}"
        case "$c" in
            .|\^|\$|\*|+|\?|\(|\)|\[|\]|\{|\}|\||\\)
                out+="\\$c"
                ;;
            *)
                out+="$c"
                ;;
        esac
    done
    printf '%s' "$out"
}

# ============================================
# Formas aceptadas de "ruta a este repo" que el scrub debe reconocer.
# El sourcing legacy real observado usa tanto la ruta absoluta como
# "$HOME/Proyectos/dotfiles" en texto literal — ambas se anclan aquí
# para no depender de una única forma.
# ============================================
_ANCHOR_FORMS=("$(_regex_escape "$DOTFILES_DIR")")
case "$DOTFILES_DIR" in
    "$HOME"/*)
        _REL="${DOTFILES_DIR#"$HOME"/}"
        _ANCHOR_FORMS+=("$(_regex_escape "\$HOME/$_REL")")
        _ANCHOR_FORMS+=("$(_regex_escape "~/$_REL")")
        ;;
esac
ANCHOR_ALT="$(IFS='|'; echo "${_ANCHOR_FORMS[*]}")"
unset _REL

# ============================================
# Reconocimiento de sourcing legacy a limpiar — SIEMPRE anclado a
# ANCHOR_ALT (este repo), nunca a "cualquier proyecto con shell/*.sh"
# ============================================
# Líneas sueltas: `source`/`.` apuntando a shell/{exports,aliases,
# functions,prompt}.sh, con o sin comillas, con comentario final opcional.
_is_legacy_source_line() {
    [[ "$1" =~ ^[[:space:]]*(source|\.)[[:space:]]+[\"\']?($ANCHOR_ALT)/shell/(exports|aliases|functions|prompt)\.sh[\"\']?[[:space:]]*(\#.*)?$ ]]
}

# Apertura de un guard `if [ -f <ruta/shell/X.sh> ]; then` (o `[[ ]]`)
# que envuelve una de esas mismas rutas.
_is_legacy_if_guard_open() {
    [[ "$1" =~ ^[[:space:]]*if[[:space:]]+\[+[[:space:]]+-f[[:space:]]+[\"\']?($ANCHOR_ALT)/shell/(exports|aliases|functions|prompt)\.sh[\"\']?[[:space:]]+\]+[[:space:]]*\;?[[:space:]]*then[[:space:]]*$ ]]
}

_is_fi_line() {
    [[ "$1" =~ ^[[:space:]]*fi[[:space:]]*$ ]]
}

# Forma de una sola línea: `[ -f X ] && source X` (o `&& . X`)
_is_legacy_oneliner_guard() {
    [[ "$1" =~ ^[[:space:]]*\[+[[:space:]]+-f[[:space:]]+[\"\']?($ANCHOR_ALT)/shell/(exports|aliases|functions|prompt)\.sh[\"\']?[[:space:]]+\]+[[:space:]]*\&\&[[:space:]]+(source|\.)[[:space:]]+[\"\']?($ANCHOR_ALT)/shell/(exports|aliases|functions|prompt)\.sh[\"\']?[[:space:]]*(\#.*)?$ ]]
}

# ============================================
# Pre-escaneo de balance de marcadores del bloque delimitado — ANTES de
# tocar nada. Un `# >>> dotfiles >>>` sin su `# <<< dotfiles <<<` (rc
# truncado, edición manual a medias, interrupción previa) NO se trata
# como "el bloque llega hasta EOF": se aborta sin escribir nada.
# ============================================
mapfile -t RC_LINES < "$RC_FILE"
TOTAL=${#RC_LINES[@]}

_scan_marker_balance() {
    local depth=0
    local ln=0
    local start_ln=0
    local idx
    for ((idx = 0; idx < TOTAL; idx++)); do
        ln=$((idx + 1))
        if [ "${RC_LINES[$idx]}" = "$BLOCK_START" ]; then
            if [ "$depth" -ne 0 ]; then
                echo "$ln"
                return 1
            fi
            depth=1
            start_ln=$ln
        elif [ "${RC_LINES[$idx]}" = "$BLOCK_END" ]; then
            if [ "$depth" -ne 1 ]; then
                echo "$ln"
                return 1
            fi
            depth=0
        fi
    done
    # Bloque abierto y nunca cerrado: la línea útil para el usuario es la
    # del marcador de APERTURA, no la última del fichero.
    if [ "$depth" -ne 0 ]; then
        echo "$start_ln"
        return 1
    fi
    return 0
}

if ! BAD_LINE="$(_scan_marker_balance)"; then
    echo -e "${RED}❌ Error: $RC_FILE tiene un marcador del bloque de dotfiles desbalanceado (línea $BAD_LINE).${NC}" >&2
    echo -e "${RED}   No se ha modificado nada. Repara el fichero a mano (revisa '$BLOCK_START' / '$BLOCK_END') y vuelve a ejecutar.${NC}" >&2
    exit 1
fi

# ============================================
# Construir el contenido "limpio": el rc actual sin el bloque delimitado
# de una instalación previa (se reescribe a continuación) ni el sourcing
# legacy suelto/envuelto en guard de ESTE repo
# ============================================
KEPT=()
i=0
in_dotfiles_block=0
just_removed=0
REMOVED_LINES=0
while [ "$i" -lt "$TOTAL" ]; do
    line="${RC_LINES[$i]}"

    if [ "$in_dotfiles_block" -eq 1 ]; then
        if [ "$line" = "$BLOCK_END" ]; then
            in_dotfiles_block=0
            just_removed=1
        fi
        REMOVED_LINES=$((REMOVED_LINES + 1))
        i=$((i + 1))
        continue
    fi

    if [ "$line" = "$BLOCK_START" ]; then
        in_dotfiles_block=1
        just_removed=1
        REMOVED_LINES=$((REMOVED_LINES + 1))
        i=$((i + 1))
        continue
    fi

    if _is_legacy_if_guard_open "$line" \
        && [ $((i + 2)) -lt "$TOTAL" ] \
        && _is_legacy_source_line "${RC_LINES[$((i + 1))]}" \
        && _is_fi_line "${RC_LINES[$((i + 2))]}"; then
        i=$((i + 3))
        REMOVED_LINES=$((REMOVED_LINES + 3))
        just_removed=1
        # Comentario huérfano: solo se retira si queda inmediatamente
        # huérfano tras esta eliminación (la línea siguiente al guard
        # es blanca o EOF) — ante la duda, se deja.
        if [ "${#KEPT[@]}" -gt 0 ] && [[ "${KEPT[-1]}" =~ ^[[:space:]]*\#[^!] ]] \
            && { [ "$i" -ge "$TOTAL" ] || [ -z "${RC_LINES[$i]}" ]; }; then
            unset 'KEPT[-1]'
        fi
        continue
    fi

    if _is_legacy_oneliner_guard "$line"; then
        i=$((i + 1))
        REMOVED_LINES=$((REMOVED_LINES + 1))
        just_removed=1
        if [ "${#KEPT[@]}" -gt 0 ] && [[ "${KEPT[-1]}" =~ ^[[:space:]]*\#[^!] ]] \
            && { [ "$i" -ge "$TOTAL" ] || [ -z "${RC_LINES[$i]}" ]; }; then
            unset 'KEPT[-1]'
        fi
        continue
    fi

    if _is_legacy_source_line "$line"; then
        i=$((i + 1))
        REMOVED_LINES=$((REMOVED_LINES + 1))
        just_removed=1
        if [ "${#KEPT[@]}" -gt 0 ] && [[ "${KEPT[-1]}" =~ ^[[:space:]]*\#[^!] ]] \
            && { [ "$i" -ge "$TOTAL" ] || [ -z "${RC_LINES[$i]}" ]; }; then
            unset 'KEPT[-1]'
        fi
        continue
    fi

    # Colapsar líneas en blanco consecutivas, PERO solo en los huecos
    # que la eliminación de arriba acaba de abrir — nunca en el resto
    # del fichero (una tanda de blancas del usuario sin relación con el
    # legacy se deja intacta, ver fixture T4).
    if [ -z "$line" ] && [ "$just_removed" -eq 1 ] && [ "${#KEPT[@]}" -gt 0 ] && [ -z "${KEPT[-1]}" ]; then
        i=$((i + 1))
        continue
    fi

    KEPT+=("$line")
    i=$((i + 1))
    if [ -n "$line" ]; then
        just_removed=0
    fi
done

# ============================================
# Contenido deseado: lo limpio + un bloque fresco. El separador en
# blanco solo se añade si hace falta (KEPT no termina ya en blanco) —
# así una segunda ejecución sobre su propio resultado no varía ni una
# línea (idempotencia sin recorte incondicional de finales de fichero).
# ============================================
DESIRED=()
DESIRED+=("${KEPT[@]}")
if [ "${#KEPT[@]}" -gt 0 ] && [ -n "${KEPT[-1]}" ]; then
    DESIRED+=("")
fi
DESIRED+=(
    "$BLOCK_START"
    "# Punto de entrada único de la configuración de shell (bash-only)."
    "# Gestionado por scripts/install_shell.sh — no editar a mano."
    "[ -f \"$DOTFILES_DIR/shell/index.sh\" ] && source \"$DOTFILES_DIR/shell/index.sh\""
    "$BLOCK_END"
)

DESIRED_CONTENT="$(printf '%s\n' "${DESIRED[@]}")"
CURRENT_CONTENT="$(cat "$RC_FILE")"

if [ "$DESIRED_CONTENT" = "$CURRENT_CONTENT" ]; then
    echo -e "${YELLOW}↔  $RC_FILE ya tiene el bloque de dotfiles al día — skip${NC}"
    exit 0
fi

# ============================================
# Resolver el destino real ANTES de escribir — si $RC_FILE es un
# symlink, se preserva como tal: se sobreescribe el contenido de su
# destino, nunca el propio enlace.
# ============================================
REAL_RC="$(readlink -f "$RC_FILE" 2>/dev/null || echo "$RC_FILE")"
ORIG_MODE="$(stat -c '%a' "$REAL_RC" 2>/dev/null || echo 644)"

# ============================================
# Backup con timestamp antes de modificar — salvo que el rc lo hayamos
# creado nosotros mismos en esta misma ejecución (backup de un fichero
# que nunca existió no aporta nada)
# ============================================
if [ "$CREATED_BY_US" -ne 1 ]; then
    BACKUP="${RC_FILE}.bak.$(date +%Y%m%d%H%M%S)"
    cp "$REAL_RC" "$BACKUP"
    echo -e "${YELLOW}📦 Backup de $(basename "$RC_FILE") → $BACKUP${NC}"

    # Poda de backups de más de 30 días — misma ventana que los logs de
    # scripts/claude-headless.sh. El backup del rc es la ÚNICA red de
    # recuperación de un scrub destructivo, así que no se le da la ventana
    # corta (7 días) que ese script reserva a las credenciales.
    find "$(dirname "$RC_FILE")" -maxdepth 1 -name "$(basename "$RC_FILE").bak.*" -mtime +30 -delete 2>/dev/null || true
fi

# ============================================
# Escritura atómica: fichero temporal en el mismo directorio + rename,
# nunca `>` directo sobre el rc — una interrupción a mitad no debe
# dejar al usuario con una shell rota.
# ============================================
TMP_FILE="$(mktemp "$(dirname "$REAL_RC")/.$(basename "$REAL_RC").XXXXXX")"
trap '[ -n "${TMP_FILE:-}" ] && rm -f "$TMP_FILE"' EXIT
printf '%s\n' "${DESIRED[@]}" > "$TMP_FILE"
chmod "$ORIG_MODE" "$TMP_FILE" 2>/dev/null || true
mv -f "$TMP_FILE" "$REAL_RC"

echo -e "${GREEN}✅ $RC_FILE actualizado — un único source a shell/index.sh (${REMOVED_LINES} líneas legacy eliminadas)${NC}"
echo -e "${YELLOW}   Abre una nueva sesión de shell (o \`source $RC_FILE\`) para aplicar los cambios${NC}"

# Aviso, sin reordenar nada: si el rc ya contenía una línea tipo
# "#THIS MUST BE AT THE END OF THE FILE..." (p.ej. SDKMAN), el bloque
# nuevo se ha añadido DESPUÉS de ella, invalidando ese requisito.
if grep -qi 'MUST BE AT THE END' "$REAL_RC" 2>/dev/null; then
    echo -e "${YELLOW}⚠️  $RC_FILE contiene una línea del tipo \"MUST BE AT THE END\" (p.ej. SDKMAN) y el bloque de dotfiles ha quedado por debajo — puede que necesites reordenar esas líneas a mano (o moverlas a ~/.dotfiles.local, ver shell/local.sh).${NC}"
fi
