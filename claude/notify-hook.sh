#!/usr/bin/env bash
# notify-hook.sh — Notificación "inteligente" para hooks de Claude Code.
#
# Solo dispara notify-send (y sonido) si la terminal que ejecuta Claude
# Code NO es la ventana activa. Si ya la estás mirando, no tiene sentido
# pingarte.
#
# Uso:
#   notify-hook.sh <title> <message> [urgency] [sound-file]
#
# Fallbacks:
#   - Sin X11 / sin xdotool / sin DISPLAY → notifica igualmente.
#   - Sin reproductor de audio → notifica sin sonido.

set -u

TITLE="${1:-Claude Code}"
MESSAGE="${2:-}"
URGENCY="${3:-normal}"
SOUND="${4:-}"

# Comprueba si nuestra terminal (algún ancestro del proceso) es la
# ventana activa. Solo X11 — Wayland cae al fallback (siempre notifica).
is_focused() {
    [[ "${XDG_SESSION_TYPE:-}" == "x11" ]] || return 1
    command -v xdotool >/dev/null 2>&1 || return 1
    [[ -n "${DISPLAY:-}" ]] || return 1

    local active_pid
    active_pid=$(xdotool getactivewindow getwindowpid 2>/dev/null) || return 1
    [[ "$active_pid" =~ ^[0-9]+$ ]] || return 1

    # Subimos por el árbol de procesos: si alguno coincide con la PID
    # de la ventana activa, nuestra terminal ES la enfocada.
    local pid=$PPID
    while [[ "$pid" =~ ^[0-9]+$ ]] && (( pid > 1 )); do
        if [[ "$pid" == "$active_pid" ]]; then
            return 0
        fi
        pid=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')
    done
    return 1
}

if is_focused; then
    exit 0
fi

# Reproductor de audio: pw-play (PipeWire) > paplay (PulseAudio) >
# canberra-gtk-play. Se ejecuta en background para no bloquear el hook.
play_sound() {
    local file="$1"
    [[ -n "$file" && -f "$file" ]] || return 0
    if command -v pw-play >/dev/null 2>&1; then
        pw-play "$file" >/dev/null 2>&1 &
    elif command -v paplay >/dev/null 2>&1; then
        paplay "$file" >/dev/null 2>&1 &
    elif command -v canberra-gtk-play >/dev/null 2>&1; then
        canberra-gtk-play -f "$file" >/dev/null 2>&1 &
    fi
}

play_sound "$SOUND"
