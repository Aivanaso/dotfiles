#!/bin/bash

set -e  # Salir si algo falla

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Backup con timestamp antes de sobrescribir cualquier fichero/symlink del
# usuario — convención del repo (ver Makefile: targets git/starship/kitty).
backup_if_exists() {
    local target="$1"
    local expected_source="${2:-}"
    # Si ya es un symlink al destino esperado no hay nada que preservar, y
    # copiar un backup en cada re-run llenaría ~/.local/bin (que está en el
    # PATH) de ficheros .bak.<ts>. Mismo criterio de skip que el Makefile.
    if [[ -n "$expected_source" && -L "$target" ]] \
        && [[ "$(readlink -f "$target")" == "$(readlink -f "$expected_source")" ]]; then
        return 0
    fi
    if [[ -e "$target" || -L "$target" ]]; then
        local backup="${target}.bak.$(date +%Y%m%d%H%M%S)"
        echo -e "${YELLOW}📦 Backup de $(basename "$target") → $backup${NC}"
        mv "$target" "$backup"
    fi
}

echo -e "${GREEN}📦 Instalando herramientas desde source...${NC}"

# ============================================
# FZF (Fuzzy Finder)
# ============================================
if [ ! -d "$HOME/.fzf" ]; then
    echo -e "${YELLOW}Instalando fzf...${NC}"
    git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf

    # Instalar sin preguntas interactivas
    # --all: habilita todo (key bindings, completion)
    # --no-bash: solo si NO quieres bash (en tu caso sí lo quieres por si acaso)
    # --no-zsh: solo si NO quieres zsh
    # --no-fish: no tienes fish
    # --no-update-rc: no tocar .bashrc/.zshrc — el sourcing se gestiona a mano
    #                 (ver shell/ en este mismo repo)
    ~/.fzf/install --all --no-fish --no-update-rc

    echo -e "${GREEN}✅ fzf instalado${NC}"
else
    echo -e "${YELLOW}fzf ya está instalado. Actualizando...${NC}"
    cd ~/.fzf && git pull && ./install --all --no-fish --no-update-rc
    echo -e "${GREEN}✅ fzf actualizado${NC}"
fi

# ============================================
# FNM (Fast Node Manager) - Opcional
# ============================================
read -p "¿Instalar fnm (Fast Node Manager)? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    if ! command -v fnm &> /dev/null; then
        echo -e "${YELLOW}Instalando fnm...${NC}"
        curl -fsSL https://fnm.vercel.app/install | bash
        echo -e "${GREEN}✅ fnm instalado${NC}"
    else
        echo -e "${YELLOW}fnm ya está instalado${NC}"
    fi
fi

# ============================================
# Kitty (terminal emulator) - Opcional
# ============================================
read -p "¿Instalar Kitty (terminal GPU-accelerated)? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    if ! command -v kitty &> /dev/null; then
        echo -e "${YELLOW}Instalando kitty desde el instalador oficial...${NC}"
        # --fail: sin esto, curl sale 0 en un 4xx/5xx y le pasa a `sh` el
        # cuerpo de error como si fuera el script. --retry/--connect-timeout/
        # --max-time: mismo criterio que scripts/install_fonts.sh para un
        # fichero pequeño (aquí, el propio instalador, no el binario que él
        # descarga por dentro). launch=n: el instalador por defecto ARRANCA
        # el binario recién descargado al terminar (ver `exec_kitty` en su
        # propio código) — sin esto, `make source` abriría una ventana de
        # terminal a mitad de un bootstrap no interactivo.
        # El subshell con `pipefail` es imprescindible: sin él, el código de
        # salida de curl se pierde en la tubería, `set -e` solo ve el de `sh`
        # y una descarga fallida se diagnosticaría como "el instalador no
        # dejó el binario" — o peor, con un kitty.app de un run anterior, se
        # re-enlazaría el binario obsoleto anunciando éxito.
        ( set -o pipefail; curl --fail --location --retry 3 --retry-delay 2 --connect-timeout 10 --max-time 60 https://sw.kovidgoyal.net/kitty/installer.sh | sh /dev/stdin launch=n )

        if [[ ! -x "$HOME/.local/kitty.app/bin/kitty" ]]; then
            echo -e "${RED}❌ El instalador oficial no dejó $HOME/.local/kitty.app/bin/kitty — abortando sin enlazar nada${NC}"
            exit 1
        fi

        # El instalador oficial NO enlaza el binario en el PATH ni instala
        # integración de escritorio (.desktop) — hay que hacerlo a mano.
        # Pasos documentados por el propio proyecto:
        # https://sw.kovidgoyal.net/kitty/binary/#linux-and-macos-binary-install
        echo -e "${YELLOW}Enlazando binarios en ~/.local/bin...${NC}"
        mkdir -p "$HOME/.local/bin"
        backup_if_exists "$HOME/.local/bin/kitty" "$HOME/.local/kitty.app/bin/kitty"
        backup_if_exists "$HOME/.local/bin/kitten" "$HOME/.local/kitty.app/bin/kitten"
        ln -sf "$HOME/.local/kitty.app/bin/kitty" "$HOME/.local/kitty.app/bin/kitten" "$HOME/.local/bin/"

        echo -e "${GREEN}✅ kitty instalado. Ejecuta 'make kitty' para enlazar su configuración.${NC}"
        echo -e "${YELLOW}Konsole se mantiene instalada — cambia el terminal por defecto a mano en Systemsettings si quieres usar kitty como predeterminado.${NC}"
        echo -e "${YELLOW}Abre una nueva sesión de shell para que 'kitty' esté en el PATH.${NC}"
    else
        echo -e "${YELLOW}kitty ya está instalado${NC}"
    fi

    # Integración de escritorio: idempotente POR SU CUENTA, independiente del
    # guard `command -v kitty` de arriba. Si una ejecución previa instaló el
    # binario pero falló/se interrumpió a mitad de este bloque, el `else` de
    # arriba nunca reintentaría los .desktop (kitty ya resuelve) — este
    # bloque se autorrepara comprobando la presencia real de los .desktop.
    # Se limita a instalaciones vía este instalador (kitty.app presente):
    # un kitty resuelto por otra vía (p.ej. apt) no tiene de dónde copiar
    # las plantillas .desktop.
    if [[ -x "$HOME/.local/kitty.app/bin/kitty" ]]; then
        # El gate mira presencia Y contenido: un fallo entre el `cp` y el
        # último `sed` deja los .desktop presentes pero con `Exec=kitty` sin
        # reescribir, y un gate por presencia sola nunca lo repararía.
        if [[ ! -f "$HOME/.local/share/applications/kitty.desktop" ]] \
            || [[ ! -f "$HOME/.local/share/applications/kitty-open.desktop" ]] \
            || grep -qE '^(Exec|TryExec)=kitty$' \
                "$HOME/.local/share/applications/kitty.desktop" \
                "$HOME/.local/share/applications/kitty-open.desktop" 2>/dev/null; then
            echo -e "${YELLOW}Instalando integración de escritorio (.desktop)...${NC}"
            mkdir -p "$HOME/.local/share/applications"
            backup_if_exists "$HOME/.local/share/applications/kitty.desktop"
            backup_if_exists "$HOME/.local/share/applications/kitty-open.desktop"
            cp "$HOME/.local/kitty.app/share/applications/kitty.desktop" "$HOME/.local/share/applications/"
            cp "$HOME/.local/kitty.app/share/applications/kitty-open.desktop" "$HOME/.local/share/applications/"
            # TryExec ANTES que Exec: la cadena "Exec=kitty" es substring
            # literal de "TryExec=kitty" (empieza justo tras "Try"). Si el
            # sed de Exec de abajo corriera primero, ya reescribiría también
            # la línea TryExec como efecto colateral, y el sed de TryExec
            # que sigue ya no encontraría el patrón original para sustituir
            # — corriendo TryExec primero la reescritura queda explícita en
            # vez de depender de ese efecto colateral.
            # Los dos ficheros por nombre, NUNCA por glob `kitty*.desktop`:
            # el glob alcanzaría ficheros del usuario (un kitty-custom.desktop
            # propio) que backup_if_exists no ha respaldado, reescribiéndolos
            # in situ.
            _KITTY_DESKTOPS=(
                "$HOME/.local/share/applications/kitty.desktop"
                "$HOME/.local/share/applications/kitty-open.desktop"
            )
            sed -i "s|TryExec=kitty|TryExec=$(readlink -f "$HOME")/.local/kitty.app/bin/kitty|g" "${_KITTY_DESKTOPS[@]}"
            sed -i "s|Icon=kitty|Icon=$(readlink -f "$HOME")/.local/kitty.app/share/icons/hicolor/256x256/apps/kitty.png|g" "${_KITTY_DESKTOPS[@]}"
            sed -i "s|Exec=kitty|Exec=$(readlink -f "$HOME")/.local/kitty.app/bin/kitty|g" "${_KITTY_DESKTOPS[@]}"

            if command -v update-desktop-database &> /dev/null; then
                update-desktop-database "$HOME/.local/share/applications/"
            fi
            echo -e "${GREEN}✅ Integración de escritorio instalada${NC}"
        fi
    fi
fi

echo -e "${GREEN}✅ Instalación desde source completa${NC}"
