#!/bin/bash

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Directorio del repo de dotfiles (relativo al script)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CLAUDE_DIR="$DOTFILES_DIR/claude"

CLAUDE_HOME="$HOME/.claude"

# Marcas del bloque que este script gestiona dentro de ~/.claude/CLAUDE.md.
# El fichero es compartido con otros instaladores (ai-team usa
# "<!-- ai-team:orchestrator -->"), así que se delimita lo propio.
BLOCK_START="<!-- dotfiles:import -->"
BLOCK_END="<!-- /dotfiles:import -->"

echo -e "${GREEN}🔧 Instalando configuración de Claude Code...${NC}"

# ============================================
# Funciones auxiliares
# ============================================

# Merge JSON con jq: repo manda en las claves que define, el local
# conserva las que el repo no toca. Útil para settings.json:
# permissions/statusLine/hooks vienen del repo (fuente de
# verdad); claves runtime que apps escriben en local (enabledPlugins,
# effortLevel, advisorModel...) se preservan intactas por exclusión.
merge_json_repo_wins() {
    local source="$1"
    local target="$2"
    local name="$3"

    if ! command -v jq >/dev/null 2>&1; then
        echo -e "${RED}❌ jq no instalado — no se puede mergear $name${NC}"
        return 1
    fi

    # Si no existe local, copia simple
    if [[ ! -f "$target" ]] && [[ ! -L "$target" ]]; then
        cp "$source" "$target"
        echo -e "${GREEN}✅ $name copiado desde repo (no existía local)${NC}"
        return 0
    fi

    # Si es symlink, romper antes (un symlink no es un local "real")
    if [[ -L "$target" ]]; then
        local backup="${target}.bak.$(date +%Y%m%d%H%M%S)"
        echo -e "${YELLOW}📦 Backup de symlink $name → $backup${NC}"
        mv "$target" "$backup"
        cp "$source" "$target"
        echo -e "${GREEN}✅ $name copiado desde repo (era symlink)${NC}"
        return 0
    fi

    # Backup del local antes del merge
    local backup="${target}.bak.$(date +%Y%m%d%H%M%S)"
    cp "$target" "$backup"

    # Merge: local + repo, repo gana en conflictos (el segundo argumento
    # de `*` sobrescribe). Claves que solo están en el local (hooks,
    # enabledPlugins, etc.) se preservan por exclusión. Arrays se
    # reemplazan, no se concatenan: el repo es la fuente de verdad
    # para permissions/statusLine.
    local tmp
    tmp="$(mktemp)"
    if jq -s '.[1] * .[0]' "$source" "$target" > "$tmp"; then
        mv "$tmp" "$target"
        echo -e "${GREEN}✅ $name merged — repo manda, claves locales únicas se preservan${NC}"
        echo -e "${YELLOW}   Backup: $backup${NC}"
    else
        rm -f "$tmp"
        echo -e "${RED}❌ Error en merge JSON de $name — conservado original${NC}"
        return 1
    fi
}

# Copiar directorio del repo a ~/.claude (no symlink).
# Útil para output-styles/: aplicaciones (Claude Code, etc) pueden
# escribir en ~/.claude/output-styles/ y con symlink ensuciarían el
# repo. Con copia, los cambios externos quedan en local. Re-ejecutar
# el install actualiza desde el repo (sobrescribe con backup).
copy_directory() {
    local source="$1"
    local target="$2"
    local name="$3"

    # Si ya existe (symlink, dir o fichero), backup
    if [[ -e "$target" ]] || [[ -L "$target" ]]; then
        local backup="${target}.bak.$(date +%Y%m%d%H%M%S)"
        echo -e "${YELLOW}📦 Backup de $name existente → $backup${NC}"
        mv "$target" "$backup"
    fi

    # Copiar recursivamente
    cp -r "$source" "$target"
    echo -e "${GREEN}✅ $name copiado desde repo${NC}"
}

# Copiar fichero individual del repo a destino, con backup si existe.
# Útil para statusline-command.sh: el script vive en el repo pero se
# copia (no symlink) para que apps externas puedan modificarlo en local
# sin ensuciar el repo. Re-ejecutar el install sobrescribe con backup.
copy_file() {
    local source="$1"
    local target="$2"
    local name="$3"

    # Si ya existe (symlink, fichero), backup
    if [[ -e "$target" ]] || [[ -L "$target" ]]; then
        local backup="${target}.bak.$(date +%Y%m%d%H%M%S)"
        echo -e "${YELLOW}📦 Backup de $name existente → $backup${NC}"
        mv "$target" "$backup"
    fi

    cp "$source" "$target"
    echo -e "${GREEN}✅ $name copiado desde repo${NC}"
}

# Instalar el @import al CLAUDE.md del repo como BLOQUE DELIMITADO dentro
# de ~/.claude/CLAUDE.md, no como fichero completo.
#
# El fichero destino es compartido: otros instaladores escriben sus propios
# bloques ahí (ai-team inyecta "<!-- ai-team:orchestrator -->"), y las apps
# que escriben en ~/.claude/CLAUDE.md ensuciarían el repo si fuera symlink.
# Reescribirlo entero en cada reinstall se llevaría por delante todo eso, así
# que aquí solo se toca lo que hay entre las marcas de dotfiles.
install_import_block() {
    local source="$1"
    local target="$2"
    local name="$3"
    local import_line="@$source"

    local block
    block="$(printf '%s\n%s\n%s' "$BLOCK_START" "$import_line" "$BLOCK_END")"

    # Un symlink no es un fichero local "real": se respalda y se rompe el
    # enlace antes de escribir, para no modificar el repo a través de él
    if [[ -L "$target" ]]; then
        local link_backup="${target}.bak.$(date +%Y%m%d%H%M%S)"
        echo -e "${YELLOW}📦 Backup de symlink $name → $link_backup${NC}"
        mv "$target" "$link_backup"
    fi

    if [[ ! -f "$target" ]]; then
        printf '%s\n' "$block" > "$target"
        echo -e "${GREEN}✅ $name creado con el bloque de import${NC}"
        return 0
    fi

    # Marcas descuadradas (bloque abierto sin cerrar) = no se puede recortar
    # sin arriesgarse a borrar todo lo que venga detrás. Se aborta sin tocar
    # el fichero en vez de adivinar dónde acaba el bloque.
    local n_start n_end
    n_start=$(grep -c -F -x "$BLOCK_START" "$target" || true)
    n_end=$(grep -c -F -x "$BLOCK_END" "$target" || true)
    if [[ "$n_start" != "$n_end" ]]; then
        echo -e "${RED}❌ $name tiene las marcas de dotfiles descuadradas ($n_start de apertura, $n_end de cierre)${NC}"
        echo -e "${RED}   Arréglalo a mano antes de reinstalar — no se ha tocado el fichero${NC}"
        return 1
    fi

    # Resto del fichero = todo menos el bloque de dotfiles y menos la línea
    # de import suelta que instalaban las versiones anteriores de este script
    # (sin quitarla quedaría debajo del bloque nuevo y el CLAUDE.md del repo
    # se cargaría dos veces). Lo demás se conserva intacto, bloque de ai-team
    # incluido.
    #
    # Dos ajustes de espaciado para que reinstalar no engorde el fichero: se
    # descarta la línea en blanco que seguía a lo recortado (era su separador,
    # ya no separa nada) y las líneas en blanco iniciales que quedan al
    # quitar algo que estaba arriba del todo.
    local rest
    rest="$(awk -v s="$BLOCK_START" -v e="$BLOCK_END" -v imp="$import_line" '
        $0 == s   { skip = 1; next }
        $0 == e   { skip = 0; drop_blank = 1; next }
        skip      { next }
        $0 == imp { drop_blank = 1; next }
        drop_blank && $0 ~ /^[[:space:]]*$/ { drop_blank = 0; next }
        { drop_blank = 0 }
        !started && $0 ~ /^[[:space:]]*$/ { next }
        { started = 1; print }
    ' "$target")"

    local desired
    if [[ -n "$rest" ]]; then
        desired="$(printf '%s\n\n%s' "$block" "$rest")"
    else
        desired="$block"
    fi

    # Ya está como debe: ni backup ni escritura (mismo patrón que los
    # targets de symlink del Makefile)
    if [[ "$desired" == "$(cat "$target")" ]]; then
        echo -e "${YELLOW}↔  $name ya tiene el bloque de import — skip${NC}"
        return 0
    fi

    local backup="${target}.bak.$(date +%Y%m%d%H%M%S)"
    cp "$target" "$backup"
    printf '%s\n' "$desired" > "$target"
    echo -e "${GREEN}✅ $name actualizado — bloque de dotfiles reescrito, el resto intacto${NC}"
    echo -e "${YELLOW}   Backup: $backup${NC}"
}

# ============================================
# Claude Code
# ============================================

echo ""
echo -e "${GREEN}=== Claude Code ===${NC}"

# Crear directorio ~/.claude si no existe
mkdir -p "$CLAUDE_HOME"

# CLAUDE.md: bloque delimitado con un @import al del repo (no symlink) —
# evita que apps que escriben en ~/.claude/CLAUDE.md ensucien el repo, y
# deja intacto lo que otros instaladores hayan puesto en ese fichero
install_import_block "$CLAUDE_DIR/CLAUDE.md" "$CLAUDE_HOME/CLAUDE.md" "CLAUDE.md"

# settings.json: merge con jq (repo manda, claves locales únicas
# se preservan). El repo es fuente de verdad para permissions/
# statusLine/hooks; claves runtime que escribe Claude Code en local
# (enabledPlugins, effortLevel, advisorModel...) no las define el
# repo, así que el merge no las toca.
merge_json_repo_wins "$CLAUDE_DIR/settings.json" "$CLAUDE_HOME/settings.json" "settings.json"

# statusline-command.sh: script que pinta la status line de Claude Code.
# Se copia (no symlink) para que apps externas puedan modificarlo en
# local sin ensuciar el repo.
copy_file "$CLAUDE_DIR/statusline-command.sh" "$CLAUDE_HOME/statusline-command.sh" "statusline-command.sh"

# notify-hook.sh: notificación "inteligente" para hooks Stop/Notification.
# Solo dispara notify-send si la terminal NO está enfocada.
copy_file "$CLAUDE_DIR/notify-hook.sh" "$CLAUDE_HOME/notify-hook.sh" "notify-hook.sh"
chmod +x "$CLAUDE_HOME/notify-hook.sh"

# bash-guard-hook.sh: guard PreToolUse que deniega patrones Bash que el
# harness nunca puede auto-aprobar (cd+redirección, expansiones $var),
# con feedback para que el modelo reescriba el comando sin prompt manual.
copy_file "$CLAUDE_DIR/bash-guard-hook.sh" "$CLAUDE_HOME/bash-guard-hook.sh" "bash-guard-hook.sh"
chmod +x "$CLAUDE_HOME/bash-guard-hook.sh"

# skills/ NO se gestiona desde aquí. Las skills globales viven en
# ~/.claude/skills/ como ficheros reales (incluyendo las del SDD/ai-team).
# Para skills de stack (nestjs, react, symfony...): `npx autoskills`
# dentro del proyecto — solo se cargan donde aplican.

# Copiar directorio output-styles/ (no symlink: apps externas pueden
# escribir aquí y ensuciarían el repo)
copy_directory "$CLAUDE_DIR/output-styles" "$CLAUDE_HOME/output-styles" "output-styles/"

echo ""
echo -e "${GREEN}✅ Claude Code configurado${NC}"

# ============================================
# Resumen
# ============================================

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Instalación completada${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "  Claude Code:"
echo -e "    ${YELLOW}~/.claude/CLAUDE.md${NC}                → bloque delimitado con @import (el resto del fichero, intacto)"
echo -e "    ${YELLOW}~/.claude/settings.json${NC}            → merge JSON (repo manda, claves locales únicas se preservan)"
echo -e "    ${YELLOW}~/.claude/statusline-command.sh${NC}    → copiado del repo (no symlink)"
echo -e "    ${YELLOW}~/.claude/notify-hook.sh${NC}           → copiado del repo (notificación inteligente)"
echo -e "    ${YELLOW}~/.claude/bash-guard-hook.sh${NC}       → copiado del repo (guard PreToolUse de Bash)"
echo -e "    ${YELLOW}~/.claude/output-styles/${NC}           → copiado del repo (no symlink)"
echo -e "    ${YELLOW}~/.claude/skills/${NC}                  → no gestionado (usar 'npx autoskills' por proyecto)"

echo ""
echo -e "${GREEN}🎉 ¡Todo listo!${NC}"
