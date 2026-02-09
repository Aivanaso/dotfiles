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

# Aquí puedes añadir más funciones en el futuro
