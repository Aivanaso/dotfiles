#!/bin/bash

# ============================================
# Editor
# ============================================
export EDITOR=vim
export VISUAL=vim

# ============================================
# Locale
# ============================================
export LANG=es_ES.UTF-8
export LC_ALL=es_ES.UTF-8

# ============================================
# PATH — añadir solo si el directorio existe y no está ya en PATH
# ============================================
_add_to_path() {
    if [[ -d "$1" ]] && [[ ":$PATH:" != *":$1:"* ]]; then
        export PATH="$1:$PATH"
    fi
}

_add_to_path "$HOME/.local/bin"
_add_to_path "$HOME/.config/composer/vendor/bin"
_add_to_path "$HOME/.npm-global/bin"
_add_to_path "$HOME/.cargo/bin"
_add_to_path "/usr/local/go/bin"
_add_to_path "$HOME/go/bin"

unset -f _add_to_path

# ============================================
# FZF
# ============================================
export FZF_DEFAULT_OPTS='--reverse --height 40% --border --color=fg:#c0caf5,bg:#1a1b26,hl:#bb9af7,fg+:#c0caf5,bg+:#283457,hl+:#7dcfff,info:#7aa2f7,prompt:#7dcfff,pointer:#bb9af7,marker:#9ece6a,spinner:#bb9af7'
