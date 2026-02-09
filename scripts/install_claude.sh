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
CURSOR_RULES_DIR="$HOME/.cursor/rules"

echo -e "${GREEN}🔧 Instalando configuración de Claude Code y Cursor...${NC}"

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

# Obtener globs de Cursor para un skill
get_cursor_globs() {
    local skill_name="$1"
    case "$skill_name" in
        nestjs)
            echo '"**/*.module.ts", "**/*.controller.ts", "**/*.service.ts"'
            ;;
        symfony)
            echo '"**/*.php", "config/**/*.yaml"'
            ;;
        php-8)
            echo '"**/*.php"'
            ;;
        typescript)
            echo '"**/*.ts", "**/*.tsx"'
            ;;
        react)
            echo '"**/*.tsx", "**/*.jsx"'
            ;;
        tailwind)
            echo '"**/*.css", "tailwind.config.*"'
            ;;
        testing)
            echo '"**/*.test.*", "**/*.spec.*", "**/tests/**"'
            ;;
        *)
            echo ""
            ;;
    esac
}

# Generar fichero .mdc para Cursor
generate_mdc() {
    local source_file="$1"
    local output_file="$2"
    local description="$3"
    local globs="$4"
    local always_apply="$5"

    {
        echo "---"
        echo "description: \"$description\""
        if [[ -n "$globs" ]]; then
            echo "globs: [$globs]"
        fi
        echo "alwaysApply: $always_apply"
        echo "---"
        echo ""
        cat "$source_file"
    } > "$output_file"
}

# ============================================
# Claude Code — Symlinks
# ============================================

echo ""
echo -e "${GREEN}=== Claude Code ===${NC}"

# Crear directorio ~/.claude si no existe
mkdir -p "$CLAUDE_HOME"

# Enlazar CLAUDE.md
create_symlink "$CLAUDE_DIR/CLAUDE.md" "$CLAUDE_HOME/CLAUDE.md" "CLAUDE.md"

# Enlazar settings.json
create_symlink "$CLAUDE_DIR/settings.json" "$CLAUDE_HOME/settings.json" "settings.json"

# Enlazar directorio skills/
create_symlink "$CLAUDE_DIR/skills" "$CLAUDE_HOME/skills" "skills/"

# Enlazar directorio output-styles/
create_symlink "$CLAUDE_DIR/output-styles" "$CLAUDE_HOME/output-styles" "output-styles/"

echo ""
echo -e "${GREEN}✅ Claude Code configurado${NC}"

# ============================================
# Cursor — Generación de reglas .mdc
# ============================================

echo ""
read -p "¿Instalar reglas de Cursor? (y/n) " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${GREEN}=== Cursor ===${NC}"

    mkdir -p "$CURSOR_RULES_DIR"

    # Regla global desde CLAUDE.md
    generate_mdc \
        "$CLAUDE_DIR/CLAUDE.md" \
        "$CURSOR_RULES_DIR/global-rules.mdc" \
        "Reglas globales — Arquitecto senior, estilo España, buenas prácticas" \
        "" \
        "true"
    echo -e "${GREEN}✅ global-rules.mdc generado${NC}"

    # Generar .mdc para cada skill
    for skill_dir in "$CLAUDE_DIR"/skills/*/; do
        skill_name="$(basename "$skill_dir")"
        skill_file="$skill_dir/SKILL.md"

        if [[ ! -f "$skill_file" ]]; then
            echo -e "${YELLOW}⚠  $skill_name — SKILL.md no encontrado, skip${NC}"
            continue
        fi

        # Extraer descripción del frontmatter
        description=$(sed -n 's/^description: *"\(.*\)"/\1/p' "$skill_file" | head -1)
        if [[ -z "$description" ]]; then
            description="Skill: $skill_name"
        fi

        # Obtener globs y determinar alwaysApply
        globs=$(get_cursor_globs "$skill_name")
        if [[ -n "$globs" ]]; then
            always_apply="false"
        else
            # Skills sin globs: pr-review es always, el resto no
            if [[ "$skill_name" == "pr-review" ]]; then
                always_apply="true"
            else
                always_apply="false"
            fi
        fi

        generate_mdc \
            "$skill_file" \
            "$CURSOR_RULES_DIR/${skill_name}.mdc" \
            "$description" \
            "$globs" \
            "$always_apply"

        echo -e "${GREEN}✅ ${skill_name}.mdc generado${NC}"
    done

    echo ""
    echo -e "${GREEN}✅ Cursor configurado${NC}"
else
    echo -e "${YELLOW}Cursor — skip${NC}"
fi

# ============================================
# Resumen
# ============================================

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Instalación completada${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "  Claude Code:"
echo -e "    ${YELLOW}~/.claude/CLAUDE.md${NC}       → prompt principal"
echo -e "    ${YELLOW}~/.claude/settings.json${NC}   → permisos"
echo -e "    ${YELLOW}~/.claude/skills/${NC}          → skills"
echo -e "    ${YELLOW}~/.claude/output-styles/${NC}   → estilos de respuesta"

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    echo -e "  Cursor:"
    echo -e "    ${YELLOW}~/.cursor/rules/*.mdc${NC}    → reglas generadas"
fi

echo ""
echo -e "${GREEN}🎉 ¡Todo listo!${NC}"
