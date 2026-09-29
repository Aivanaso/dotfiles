#!/bin/bash

# Inicializar Starship prompt si está instalado
if command -v starship &> /dev/null; then
    eval "$(starship init bash)"
fi

# zoxide — navegación inteligente de directorios (`z <patrón>`).
# Va DESPUÉS de Starship a propósito: `starship init bash` mueve el
# PROMPT_COMMAND existente a STARSHIP_PROMPT_COMMAND y deja el suyo
# (starship_precmd) como único contenido. zoxide >= 0.9.8 comprueba que
# __zoxide_hook esté en PROMPT_COMMAND, así que iniciado antes de
# Starship imprime "detected a possible configuration issue" en cada `z`.
if command -v zoxide &> /dev/null; then
    eval "$(zoxide init bash)"
fi
