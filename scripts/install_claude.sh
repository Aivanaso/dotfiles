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

echo -e "${GREEN}🔧 Instalando configuración de Claude Code...${NC}"

# ============================================
# Funciones auxiliares
# ============================================

# Crear symlink con backup si es necesario
create_symlink() {
    local source="$1"
    local target="$2"
    local name="$3"

    # Si ya es un symlink correcto, skip
    if [[ -L "$target" ]] && [[ "$(readlink -f "$target")" == "$(readlink -f "$source")" ]]; then
        echo -e "${YELLOW}↔  $name ya está enlazado correctamente — skip${NC}"
        return 0
    fi

    # Si existe algo (fichero, directorio o symlink roto), hacer backup
    if [[ -e "$target" ]] || [[ -L "$target" ]]; then
        local backup="${target}.bak.$(date +%Y%m%d%H%M%S)"
        echo -e "${YELLOW}📦 Backup de $name existente → $backup${NC}"
        mv "$target" "$backup"
    fi

    # Crear symlink
    ln -sf "$source" "$target"
    echo -e "${GREEN}✅ $name enlazado${NC}"
}

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

# Crear fichero real con @import al fichero del repo.
# Útil para CLAUDE.md: aplicaciones (Claude Code, etc) que escriben en
# ~/.claude/CLAUDE.md modificarían el repo si fuera symlink. Con un
# fichero real que sólo contiene "@<ruta>", el contenido del repo se
# inyecta vía import y los cambios externos quedan en local.
create_import_file() {
    local source="$1"
    local target="$2"
    local name="$3"
    local import_line="@$source"

    # Si ya es un fichero real (no symlink) cuya primera línea no vacía es el import, skip
    if [[ -f "$target" && ! -L "$target" ]]; then
        local first_line
        first_line=$(grep -v '^$' "$target" | head -1)
        if [[ "$first_line" == "$import_line" ]]; then
            echo -e "${YELLOW}↔  $name ya tiene el import — skip${NC}"
            return 0
        fi
    fi

    # Si existe algo (symlink, fichero, dir), backup
    if [[ -e "$target" ]] || [[ -L "$target" ]]; then
        local backup="${target}.bak.$(date +%Y%m%d%H%M%S)"
        echo -e "${YELLOW}📦 Backup de $name existente → $backup${NC}"
        mv "$target" "$backup"
    fi

    # Crear fichero con import
    echo "$import_line" > "$target"
    echo -e "${GREEN}✅ $name creado con import → $source${NC}"
}
# ============================================
# Claude Code — Symlinks
# ============================================

echo ""
echo -e "${GREEN}=== Claude Code ===${NC}"

# Crear directorio ~/.claude si no existe
mkdir -p "$CLAUDE_HOME"

# CLAUDE.md como fichero con @import (no symlink) — evita que apps que
# escriben en ~/.claude/CLAUDE.md ensucien el repo
create_import_file "$CLAUDE_DIR/CLAUDE.md" "$CLAUDE_HOME/CLAUDE.md" "CLAUDE.md"

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
echo -e "    ${YELLOW}~/.claude/CLAUDE.md${NC}                → @import al repo (apps escriben en local)"
echo -e "    ${YELLOW}~/.claude/settings.json${NC}            → merge JSON (repo manda, claves locales únicas se preservan)"
echo -e "    ${YELLOW}~/.claude/statusline-command.sh${NC}    → copiado del repo (no symlink)"
echo -e "    ${YELLOW}~/.claude/notify-hook.sh${NC}           → copiado del repo (notificación inteligente)"
echo -e "    ${YELLOW}~/.claude/bash-guard-hook.sh${NC}       → copiado del repo (guard PreToolUse de Bash)"
echo -e "    ${YELLOW}~/.claude/output-styles/${NC}           → copiado del repo (no symlink)"
echo -e "    ${YELLOW}~/.claude/skills/${NC}                  → no gestionado (usar 'npx autoskills' por proyecto)"

echo ""
echo -e "${GREEN}🎉 ¡Todo listo!${NC}"
