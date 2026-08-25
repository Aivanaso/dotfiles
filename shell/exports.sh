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
# Paleta Japanesque, derivada del bloque "Tema" de config/kitty/kitty.conf
# (que a su vez sale de `kitten themes --dump-theme Japanesque`) para que
# terminal y fzf compartan esquema. Cada color de fzf toma el rol
# equivalente en kitty: fg/bg el par foreground/background, bg+ el
# selection_background, hl el magenta (color5), info el azul (color4),
# prompt el cian base (color6), marker el verde (color2), spinner el mismo
# magenta que hl.
# TRES desviaciones deliberadas de ese mapeo, todas por contraste sobre el
# teal oscuro de bg+ (#165776), no por descuido:
#   1. hl+ usa el cian claro #76bbca (color14) en vez del base #389aac,
#      porque tiene que leerse SOBRE bg+, no sobre el fondo.
#   2. pointer usa el ámbar #eccf4f — el color que kitty da al cursor, el
#      acento más fuerte del tema — porque el magenta #a57fc4 sobre bg+
#      queda apagado.
#   3. fg+ se queda claro (#f7f6ec) sobre bg+, al contrario que la selección
#      de kitty, que el tema define oscura (#1d1d1d sobre #165776): en kitty
#      eso marca texto seleccionado puntualmente, mientras que en fzf marca
#      la línea bajo el cursor, que se lee de continuo — ahí gana la
#      legibilidad.
export FZF_DEFAULT_OPTS='--reverse --height 40% --border --color=fg:#f7f6ec,bg:#1d1d1d,hl:#a57fc4,fg+:#f7f6ec,bg+:#165776,hl+:#76bbca,info:#4c99d3,prompt:#389aac,pointer:#eccf4f,marker:#7bb75b,spinner:#a57fc4'

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
