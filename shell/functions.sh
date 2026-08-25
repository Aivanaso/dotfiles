#!/bin/bash

# Instalar .deb y borrar archivo después
install-deb() {
    if [ -z "$1" ]; then
        echo "❌ Uso: install-deb archivo.deb"
        return 1
    fi

    local DEB_FILE="$1"

    if [ ! -f "$DEB_FILE" ]; then
        echo "❌ Error: El archivo '$DEB_FILE' no existe"
        return 1
    fi

    if [[ ! "$DEB_FILE" =~ \.deb$ ]]; then
        echo "❌ Error: '$DEB_FILE' no es un archivo .deb"
        return 1
    fi

    echo "📦 Instalando $DEB_FILE..."
    sudo dpkg -i "$DEB_FILE"

    if [ $? -eq 0 ]; then
        echo "✅ Instalación exitosa"
        echo "🗑️  Borrando $DEB_FILE..."
        rm "$DEB_FILE"
        echo "✅ Archivo borrado"
        echo "🔧 Verificando dependencias..."
        sudo apt-get install -f
    else
        echo "❌ Error en la instalación. El archivo NO se ha borrado."
        return 1
    fi
}

# Buscar texto en ficheros y abrir el resultado en el editor
# rg (contenido) → fzf (selección + preview) → $EDITOR en la línea exacta
find-in-files() {
    if [ -z "$1" ]; then
        echo "❌ Uso: find-in-files <texto_a_buscar>"
        return 1
    fi

    if ! command -v rg &> /dev/null || ! command -v fzf &> /dev/null; then
        echo "❌ Error: find-in-files necesita rg y fzf"
        return 1
    fi

    # Ubuntu renombra el binario de bat a batcat (colisión con bacula-console)
    local BAT_BIN PREVIEW
    BAT_BIN="$(command -v bat || command -v batcat)"
    if [ -n "$BAT_BIN" ]; then
        PREVIEW="$BAT_BIN --color=always --style=numbers --highlight-line={2} -- {1}"
    else
        PREVIEW="cat {1}"
    fi

    rg --line-number --no-heading --color=always --smart-case -- "$1" | \
        fzf --ansi \
            --delimiter=":" \
            --preview="$PREVIEW" \
            --preview-window="right:60%:wrap:+{2}/2" \
            --bind="enter:become(${EDITOR:-vim} +{2} {1})"
}

# Historial de git navegable — fzf con preview del commit
# Enter abre el commit completo, Ctrl-Y copia el hash
git-log-interactive() {
    if ! git rev-parse --git-dir &> /dev/null; then
        echo "❌ Error: no estás en un repositorio git"
        return 1
    fi

    local -a BINDS=( --bind="enter:execute(git show --color=always {1} | less -R)" )

    if command -v wl-copy &> /dev/null; then
        BINDS+=( --bind="ctrl-y:execute-silent(echo -n {1} | wl-copy)" )
    elif command -v xclip &> /dev/null; then
        BINDS+=( --bind="ctrl-y:execute-silent(echo -n {1} | xclip -selection clipboard)" )
    fi

    git log --oneline --color=always "$@" | \
        fzf --ansi \
            --no-sort \
            --preview="git show --color=always {1}" \
            --preview-window="right:60%:wrap" \
            "${BINDS[@]}"
}

# Cambiar de rama y traer los cambios remotos: git switch <rama> && git pull
# Reenvia "$@" entero, no solo "$1", para que lo que el completado ofrece
# (los flags propios de `git switch`) llegue de verdad a git.
git-switch-pull() {
    if [ -z "$1" ]; then
        echo "❌ Uso: git-switch-pull <rama>"
        return 1
    fi

    git switch "$@" && git pull
}

# Completado de nombres de rama para git-switch-pull y su alias gsp
# (ver aliases.sh) — reutiliza el completado que bash-completion ya
# trae para `git switch`. _git_switch y __git_complete viven en el
# fichero de completado de git, que bash-completion carga de forma
# perezosa (al pulsar TAB sobre `git` por primera vez), no al arrancar
# la shell — así que aquí se fuerza esa carga si todavía no ha
# ocurrido. Se registra solo en shell interactiva (no tiene sentido ni
# coste en una no interactiva) y solo si esa maquinaria de git existe
# en la máquina: si no (p.ej. en un equipo sin bash-completion), este
# bloque se salta en silencio — la función y el alias siguen
# funcionando igual, simplemente sin completado de ramas.
if [[ $- == *i* ]]; then
    if ! declare -F __git_complete &> /dev/null && declare -F _completion_loader &> /dev/null; then
        _completion_loader git &> /dev/null
    fi

    if declare -F __git_complete &> /dev/null && declare -F _git_switch &> /dev/null; then
        __git_complete git-switch-pull _git_switch
        __git_complete gsp _git_switch
    fi
fi

# Añadir un alias a ~/.dotfiles.local (override: $DOTFILES_LOCAL) y
# dejarlo activo en el acto, sin abrir otra shell.
# Uso: mkalias <nombre> <comando>
# Solo añade: nunca reescribe nada que ya exista. Falla si el nombre ya
# está en uso — como alias activo en esta shell (puede venir de
# shell/aliases.sh, no solo del fichero local), como función ya
# definida en esta shell (declare -F no distingue las de este repo de
# las que carga otra herramienta, p.ej. `z` de zoxide) o como línea ya
# escrita en el fichero local (aunque esté indentada, p.ej. dentro de
# un if/fi) — mostrando lo que ya hay y saliendo con error, para que el
# usuario decida y edite ~/.dotfiles.local a mano si quiere cambiarlo.
mkalias() {
    if [ -z "$1" ] || [ -z "$2" ]; then
        echo "❌ Uso: mkalias <nombre> <comando>"
        return 1
    fi

    local nombre="$1"
    shift
    local comando="$*"

    if [[ ! "$nombre" =~ ^[a-zA-Z_][a-zA-Z0-9_-]*$ ]]; then
        echo "❌ Error: '$nombre' no es un nombre de alias válido"
        return 1
    fi

    # `alias` es el único nombre que el regex acepta y que rompe el
    # fichero entero: `alias alias=...` se expande en posición de
    # comando, así que TODA línea que mkalias añada por debajo muere al
    # sourcear y escupe basura en cada shell interactiva.
    if [ "$nombre" = "alias" ]; then
        echo "❌ Error: 'alias' no puede usarse como nombre de alias"
        echo "   Rompería todas las líneas que se añadan al fichero por debajo"
        return 1
    fi

    local dotfiles_local="${DOTFILES_LOCAL:-$HOME/.dotfiles.local}"

    # Enlace simbólico roto (su destino no existe: disco sin montar,
    # repo privado sin clonar…) — ni se escribe a través de él ni se
    # reescribe. `make local` trata este mismo caso como "ya hay algo
    # ahí" y se limita a saltar con un aviso (Makefile, target local);
    # mkalias no puede hacer lo mismo porque SIEMPRE tiene que escribir
    # de verdad, así que aborta en vez de crear el fichero real, a
    # través del enlace, con el modo de la umask y sin la plantilla.
    if [ -L "$dotfiles_local" ] && [ ! -e "$dotfiles_local" ]; then
        echo "❌ Error: $dotfiles_local es un enlace simbólico roto (su destino no existe)"
        echo "   Repáralo a mano (monta el disco, clona el repo…) antes de usar mkalias"
        return 1
    fi

    local activo="" en_fichero="" es_funcion=0
    activo="$(alias "$nombre" 2>/dev/null)"
    declare -F "$nombre" &>/dev/null && es_funcion=1
    if [ -f "$dotfiles_local" ]; then
        # Admite espacios/tabuladores iniciales: un alias indentado
        # dentro de un if/fi hecho a mano también cuenta como "ya
        # existe" — no solo el que empieza en columna 0.
        # Se separa el grep del tail para no perder su código de
        # salida en la tubería: 0 = encontrado, 1 = no está, y
        # cualquier otro valor es un ERROR de lectura. Ante ese error
        # se falla CERRADO — dar por bueno "no existe" acabaría
        # añadiendo una segunda definición a un fichero que no se pudo
        # leer.
        local coincidencias="" grep_rc=0
        coincidencias="$(grep "^[[:space:]]*alias $nombre=" "$dotfiles_local" 2>/dev/null)" || grep_rc=$?
        if [ "$grep_rc" -gt 1 ]; then
            echo "❌ Error: no se pudo leer $dotfiles_local para comprobar si '$nombre' ya existe"
            return 1
        fi
        en_fichero="$(printf '%s' "$coincidencias" | tail -n1)"
    fi

    if [ -n "$activo" ] || [ -n "$en_fichero" ] || [ "$es_funcion" -eq 1 ]; then
        if [ -n "$activo" ] || [ -n "$en_fichero" ]; then
            echo "❌ '$nombre' ya existe: ${activo:-$en_fichero}"
        else
            echo "❌ '$nombre' ya existe como función en esta shell — lo ensombrearías"
        fi
        echo "   Edita $dotfiles_local a mano si quieres cambiar su definición"
        return 1
    fi

    # Si el fichero local todavía no existe de verdad (ni fichero ni
    # enlace — el enlace roto ya se descartó arriba), se crea con los
    # mismos permisos (600) que `make local` le daría, a partir de la
    # misma plantilla, para que dé igual cuál de los dos caminos use el
    # usuario primero. Cada escritura se comprueba: un fallo aquí no
    # debe terminar en un "✅" que no es verdad.
    if [ ! -e "$dotfiles_local" ] && [ ! -L "$dotfiles_local" ]; then
        local func_dir
        func_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
        if [ -n "$func_dir" ] && [ -f "$func_dir/dotfiles.local.example" ]; then
            cp "$func_dir/dotfiles.local.example" "$dotfiles_local" || {
                echo "❌ Error: no se pudo crear $dotfiles_local desde la plantilla"
                return 1
            }
        else
            : > "$dotfiles_local" || {
                echo "❌ Error: no se pudo crear $dotfiles_local"
                return 1
            }
        fi
        chmod 600 "$dotfiles_local" || {
            echo "❌ Error: no se pudo ajustar el modo de $dotfiles_local a 600"
            return 1
        }
        echo "📄 $dotfiles_local creado (no existía)"
    fi

    local linea
    printf -v linea 'alias %s=%q' "$nombre" "$comando"

    # Asegura el salto de línea final antes de añadir: si la última
    # línea del fichero no termina en \n (p.ej. editado a mano), el
    # append de abajo fundiría esa línea con la nueva, corrompiendo
    # ambas — la variable/línea previa y el alias recién añadido.
    # El código de salida de `tail` se comprueba aparte: si la lectura
    # falla, se aborta en vez de dar por hecho que el fichero ya
    # termina en \n — esa suposición es justo la que fundiría las dos
    # líneas.
    if [ -s "$dotfiles_local" ]; then
        local ultimo_byte
        if ! ultimo_byte="$(tail -c1 "$dotfiles_local" 2>/dev/null)"; then
            echo "❌ Error: no se pudo leer $dotfiles_local para comprobar su última línea"
            return 1
        fi
        if [ -n "$ultimo_byte" ]; then
            printf '\n' >> "$dotfiles_local" || {
                echo "❌ Error: no se pudo asegurar el salto de línea final en $dotfiles_local"
                return 1
            }
        fi
    fi

    printf '%s\n' "$linea" >> "$dotfiles_local" || {
        echo "❌ Error: no se pudo añadir la línea a $dotfiles_local"
        return 1
    }

    eval "$linea"

    echo "✅ alias $nombre añadido a $dotfiles_local y activo en esta shell"
}

# Aquí puedes añadir más funciones en el futuro
