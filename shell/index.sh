#!/bin/bash

# ============================================
# Punto de entrada único de la configuración de shell (bash-only)
# ============================================
# Sustituye a los `source` sueltos que antes iban directamente en
# ~/.bashrc — scripts/install_shell.sh instala UN solo `source` a este
# fichero. Orden de carga obligatorio, cada paso guardado por
# existencia de fichero o `command -v`:
#
#   exports.sh -> ~/.fzf.bash (si existe) -> aliases.sh -> functions.sh
#   -> options.sh -> prompt.sh -> local.sh
#
# local.sh va el ÚLTIMO para que la configuración de máquina
# (~/.dotfiles.local) pueda sobreescribir cualquier cosa del repo.

_DOTFILES_SHELL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)" || {
    echo "dotfiles: no puedo resolver el directorio de shell/ — configuración NO cargada" >&2
    return 1 2>/dev/null || exit 1
}

# Comprueba que un fichero auto-sourceado (fuera del propio repo, por
# tanto no controlado por git) pertenece al usuario actual y no es
# escribible por grupo/otros antes de sourcearlo. Usado tanto para
# ~/.fzf.bash como, en local.sh, para ~/.dotfiles.local.
# Los avisos solo se emiten en shell interactiva: en una no interactiva
# (un script que sourcee el rc) ensuciarían stderr sin que nadie los lea.
_dotfiles_warn() {
    case $- in
        *i*) echo "dotfiles: $*" >&2 ;;
    esac
}

_dotfiles_safe_source() {
    local f="$1"
    [ -f "$f" ] || return 0
    if [ ! -O "$f" ]; then
        _dotfiles_warn "$f no pertenece al usuario actual — NO se sourcea"
        return 1
    fi
    local mode
    # Sin permisos legibles no se puede decidir: se falla CERRADO, nunca
    # sourceando a ciegas.
    if ! mode="$(stat -c '%a' "$f" 2>/dev/null)" || [ -z "$mode" ]; then
        _dotfiles_warn "no se pudieron leer los permisos de $f — NO se sourcea"
        return 1
    fi
    if [ $((0${mode} & 0022)) -ne 0 ]; then
        _dotfiles_warn "$f es escribible por grupo/otros — NO se sourcea (chmod go-w \"$f\")"
        return 1
    fi
    source "$f"
}

# Variables de entorno y PATH
[ -f "$_DOTFILES_SHELL_DIR/exports.sh" ] && source "$_DOTFILES_SHELL_DIR/exports.sh"

# Key bindings (Ctrl-R, Ctrl-T, Alt-C) y completado de fzf.
# scripts/install_from_source.sh instala fzf con --no-update-rc, así
# que nadie más sourcea ~/.fzf.bash — lo asume este repo.
_dotfiles_safe_source "$HOME/.fzf.bash"

# Alias
[ -f "$_DOTFILES_SHELL_DIR/aliases.sh" ] && source "$_DOTFILES_SHELL_DIR/aliases.sh"

# Funciones
[ -f "$_DOTFILES_SHELL_DIR/functions.sh" ] && source "$_DOTFILES_SHELL_DIR/functions.sh"

# Opciones de bash interactivo (shopt, historial)
[ -f "$_DOTFILES_SHELL_DIR/options.sh" ] && source "$_DOTFILES_SHELL_DIR/options.sh"

# Prompt (Starship)
[ -f "$_DOTFILES_SHELL_DIR/prompt.sh" ] && source "$_DOTFILES_SHELL_DIR/prompt.sh"

# Configuración local de máquina — SIEMPRE el último paso, ver local.sh
[ -f "$_DOTFILES_SHELL_DIR/local.sh" ] && source "$_DOTFILES_SHELL_DIR/local.sh"

unset _DOTFILES_SHELL_DIR
unset -f _dotfiles_safe_source
