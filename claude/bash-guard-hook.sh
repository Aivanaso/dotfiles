#!/bin/bash

# PreToolUse guard para comandos Bash — deniega los dos patrones que el
# harness de Claude Code NUNCA puede auto-aprobar (heurísticas hardcoded,
# ninguna allow rule las cubre), devolviendo al modelo el motivo para que
# reescriba el comando solo, sin prompt manual para el usuario:
#
#   1. `cd` combinado con redirección (>, >>, 2>, <) — "path resolution bypass"
#   2. Bucles for/while con variables — la variable de loop es inanalizable
#      ("simple_expansion"). OJO: un $var/$(...)  suelto en un comando con
#      prefijo allowlisted SÍ se auto-aprueba (verificado 2026-06-07) — por
#      eso el guard solo dispara cuando hay constructo de bucle de por medio.
#
# Se registra en settings.json como hooks.PreToolUse con matcher "Bash".
# Cubre también a los sub-agentes (sdd-*, etc.): los hooks son harness-level
# y disparan en cada llamada Bash, venga de la sesión principal o delegada.
#
# Fail-open: ante cualquier error (jq ausente, JSON inesperado) sale != 0
# sin bloquear — el flujo de permisos estándar sigue su curso.

set -euo pipefail

cmd="$(jq -r '.tool_input.command // empty')"
if [[ -z "$cmd" ]]; then
    exit 0
fi

deny() {
    jq -cn --arg reason "$1" \
        '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $reason}}'
    exit 0
}

# Los literales no cuentan como expansión: fuera segmentos entre comillas
# simples y dólares escapados antes de evaluar los patrones.
stripped="$(printf '%s' "$cmd" | sed -e "s/'[^']*'//g" -e 's/\\\$//g')"

re_cd='(^|[;&|[:space:]])cd[[:space:]]'
re_redir='[0-9]?[<>]'
re_loop='(^|[;&|[:space:]])(for|while)[[:space:]]'
re_expansion='\$[A-Za-z_{(]'

if [[ "$stripped" =~ $re_cd ]] && [[ "$stripped" =~ $re_redir ]]; then
    deny "dotfiles guard: 'cd' combined with a redirection is hardcoded to require manual approval (path-resolution bypass guard) — no allow rule can ever cover it. Rewrite without cd: pass absolute paths to the tools themselves (rg/grep/ls/cat <abs-path>, git -C <abs-path>). If cd is truly unavoidable (e.g. ./gradlew), remove every redirection from that command."
fi

if [[ "$stripped" =~ $re_loop ]] && [[ "$stripped" =~ $re_expansion ]]; then
    deny "dotfiles guard: for/while loops over shell variables never match allow rules (the loop variable is statically unanalyzable — \"Contains simple_expansion\") and always force a manual prompt. Unroll the loop: pass the globs/paths directly as arguments in a single command (e.g. grep -H <pattern> <glob1> <glob2>), or use the Grep/Glob tools."
fi

exit 0
