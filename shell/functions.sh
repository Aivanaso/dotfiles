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

# Aquí puedes añadir más funciones en el futuro
