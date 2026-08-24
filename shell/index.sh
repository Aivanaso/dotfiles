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
    local mode gid
    # Sin permisos legibles no se puede decidir: se falla CERRADO, nunca
    # sourceando a ciegas.
    if ! read -r mode gid < <(stat -c '%a %g' "$f" 2>/dev/null) || [ -z "$mode" ]; then
        _dotfiles_warn "no se pudieron leer los permisos de $f — NO se sourcea"
        return 1
    fi
    if [ $((0${mode} & 0002)) -ne 0 ]; then
        _dotfiles_warn "$f es escribible por otros — NO se sourcea (chmod o-w \"$f\")"
        return 1
    fi
    # El bit de escritura de GRUPO (020) solo es un vector real cuando el
    # grupo propietario es COMPARTIDO. Debian/Ubuntu crea por defecto
    # (USERGROUPS=yes) un grupo PRIVADO por usuario cuyo GID coincide con
    # el GID primario del usuario y que no tiene ningún otro miembro — un
    # 664 propiedad de ESE grupo (el `~/.fzf.bash` real de esta máquina es
    # "664 ivan ivan") no es escribible por nadie más que el propio
    # usuario, exactamente igual que si fuera 600. Se comprueban las dos
    # condiciones por separado y SIEMPRE contra el resultado de una
    # syscall, nunca contra `$UID`/`$GID`: bash solo inicializa esas
    # variables de forma protegida cuando las calcula él mismo al
    # arrancar — si ya venían puestas en el entorno heredado de un
    # proceso ancestro, bash conserva ese valor tal cual (variable
    # exportada normal, no de solo lectura), así que serían falseables
    # desde fuera. `id -g` sí llama a getgid(2) y no se puede suplantar
    # así.
    if [ $((0${mode} & 0020)) -ne 0 ]; then
        local my_gid
        my_gid="$(id -g 2>/dev/null)"
        if [ -z "$my_gid" ] || [ "$gid" != "$my_gid" ]; then
            _dotfiles_warn "$f es escribible por un grupo compartido — NO se sourcea (chmod g-w \"$f\")"
            return 1
        fi
        # El GID coincide con el propio, pero eso no basta para llamarlo
        # "privado": un grupo ampliado después de crearlo (`usermod -aG`)
        # o un grupo COMPARTIDO cuyo GID coincida por casualidad con el
        # del usuario (esquemas no-Debian, LDAP/SSSD) también pasarían la
        # comprobación anterior. Se exige además que el grupo no tenga
        # NINGÚN otro miembro listado — y si `getent group` no puede
        # confirmarlo, se falla CERRADO (se trata como compartido).
        # El cuarto campo de `getent group` lista los miembros
        # SUPLEMENTARIOS. Vacío es el caso Debian típico (`ivan:x:1000:`),
        # pero bajo LDAP/SSSD el propio usuario aparece listado en su
        # grupo primario (`ivan:x:1000:ivan`): eso sigue siendo un grupo
        # privado y rechazarlo sería un falso positivo. Cualquier otro
        # contenido — un miembro distinto, o varios — es grupo compartido.
        local group_entry group_members
        group_entry="$(getent group "$my_gid" 2>/dev/null)"
        group_members="${group_entry##*:}"
        if [ -n "$group_members" ] && [ "$group_members" = "$(id -un 2>/dev/null)" ]; then
            group_members=""
        fi
        if [ -z "$group_entry" ] || [ -n "$group_members" ]; then
            _dotfiles_warn "$f es escribible por un grupo compartido — NO se sourcea (chmod g-w \"$f\")"
            return 1
        fi
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
