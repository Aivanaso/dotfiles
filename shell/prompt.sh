#!/bin/bash

# Inicializar Starship prompt si está instalado
if command -v starship &> /dev/null; then
    eval "$(starship init bash)"
fi
