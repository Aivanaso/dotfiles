#!/bin/bash

# ============================================
# Editor
# ============================================
export EDITOR=vim
export VISUAL=vim

# ============================================
# Locale
# ============================================
# Solo forzamos es_ES.UTF-8 si esa locale está generada en el sistema:
# forzarla sin estarlo (probable en una máquina nueva, p.ej. la del
# trabajo) produce warnings de perl y de locale en cada comando.
# Si no está generada, caemos a una UTF-8 que SIEMPRE existe en un
# glibc moderno (C.UTF-8, sin locale-gen) — este repo emite emojis y
# caracteres de caja en su propia salida (scripts/install_*.sh,
# shell/functions.sh) que necesitan un LANG UTF-8, nunca C/POSIX puro.
# Solo se exporta LANG en el fallback, LC_ALL se deja sin definir para
# no pisar overrides por categoría (LC_TIME, LC_COLLATE, ...).
_dotfiles_locales="$(locale -a 2>/dev/null)"
if printf '%s\n' "$_dotfiles_locales" | grep -qiE '^es_es\.(utf-?8)$'; then
    export LANG=es_ES.UTF-8
    export LC_ALL=es_ES.UTF-8
elif printf '%s\n' "$_dotfiles_locales" | grep -qiE '^c\.(utf-?8)$'; then
    export LANG=C.UTF-8
elif printf '%s\n' "$_dotfiles_locales" | grep -qiE '^en_us\.(utf-?8)$'; then
    export LANG=en_US.UTF-8
fi
unset _dotfiles_locales

# ============================================
# PATH — añadir solo si el directorio existe y no está ya en PATH
# ============================================
# _add_to_path ANTEPONE su argumento, así que la ÚLTIMA llamada es la
# que queda con más prioridad — por eso "$HOME/.local/bin" (el
# directorio que curamos a mano, y donde vive p.ej. el symlink de
# `bat` que crea scripts/install_packages.sh) va DELIBERADAMENTE el
# último, para ganarle la precedencia a los directorios que pueblan
# gestores de paquetes de terceros (composer, npm, cargo, go, fnm).
_add_to_path() {
    if [[ -d "$1" ]] && [[ ":$PATH:" != *":$1:"* ]]; then
        export PATH="$1:$PATH"
    fi
}

_add_to_path "$HOME/.config/composer/vendor/bin"
_add_to_path "$HOME/.npm-global/bin"
_add_to_path "$HOME/.cargo/bin"
_add_to_path "/usr/local/go/bin"
_add_to_path "$HOME/go/bin"
_add_to_path "$HOME/.local/share/fnm"
_add_to_path "$HOME/.local/bin"

unset -f _add_to_path

# ============================================
# FZF
# ============================================
export FZF_DEFAULT_OPTS='--reverse --height 40% --border --color=fg:#c0caf5,bg:#1a1b26,hl:#bb9af7,fg+:#c0caf5,bg+:#283457,hl+:#7dcfff,info:#7aa2f7,prompt:#7dcfff,pointer:#bb9af7,marker:#9ece6a,spinner:#bb9af7'

# ============================================
# FNM (Fast Node Manager) — instalado por scripts/install_from_source.sh
# ============================================
if command -v fnm &> /dev/null; then
    eval "$(fnm env)"
fi

# ============================================
# zoxide — navegación inteligente de directorios (`z <patrón>`)
# ============================================
if command -v zoxide &> /dev/null; then
    eval "$(zoxide init bash)"
fi

# ============================================
# Cargo (Rust)
# ============================================
if [ -f "$HOME/.cargo/env" ]; then
    source "$HOME/.cargo/env"
fi
