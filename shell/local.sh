#!/bin/bash

# ============================================
# Configuración local de máquina (NO versionada)
# ============================================
# Sourcea ~/.dotfiles.local si existe; no falla si no existe. Este es
# el hueco donde vive todo lo que es específico de UNA máquina y NO
# debe estar en el repo de dotfiles.
#
# Antes de sourcear se comprueba que el fichero pertenece al usuario
# actual y no es escribible por grupo/otros (_dotfiles_safe_source,
# shell/index.sh) — si no cumple alguna de las dos, se avisa por
# stderr y NO se sourcea, en vez de ejecutar código de dueño/permisos
# dudosos en cada shell interactiva.
#
# shell/index.sh carga este fichero EL ÚLTIMO, así que cualquier
# variable, alias o función definida en ~/.dotfiles.local sobreescribe
# lo que ponga el repo.
#
# Qué va en ~/.dotfiles.local (ejemplos reales):
#   - Inicialización de SDKMAN (debe ir al final de todo, requisito del
#     propio SDKMAN)
#   - JAVA_HOME u otras variables *_HOME específicas de esta máquina
#   - OLLAMA_MODELS
#   - Proxy corporativo (http_proxy, https_proxy, no_proxy)
#   - Registry npm privado / credenciales de empresa
#
# Qué NO va aquí:
#   - Nada que aplique igual a todas tus máquinas — eso va en el repo
#     (shell/exports.sh, shell/aliases.sh, shell/functions.sh,
#     shell/options.sh)
#   - Secretos en texto plano si se puede evitar — usa un gestor de
#     secretos siempre que sea posible

# _dotfiles_safe_source (definida en index.sh) comprueba propiedad y
# permisos de grupo/otros antes de sourcear — ver shell/index.sh
_dotfiles_safe_source "$HOME/.dotfiles.local"
