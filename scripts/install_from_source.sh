#!/bin/bash

set -e  # Salir si algo falla

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}📦 Instalando herramientas desde source...${NC}"

# ============================================
# FZF (Fuzzy Finder)
# ============================================
if [ ! -d "$HOME/.fzf" ]; then
    echo -e "${YELLOW}Instalando fzf...${NC}"
    git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf

    # Instalar sin preguntas interactivas
    # --all: habilita todo (key bindings, completion, actualizar shell config)
    # --no-bash: solo si NO quieres bash (en tu caso sí lo quieres por si acaso)
    # --no-zsh: solo si NO quieres zsh
    # --no-fish: no tienes fish
    ~/.fzf/install --all --no-fish

    echo -e "${GREEN}✅ fzf instalado${NC}"
else
    echo -e "${YELLOW}fzf ya está instalado. Actualizando...${NC}"
    cd ~/.fzf && git pull && ./install --all --no-fish
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

echo -e "${GREEN}✅ Instalación desde source completa${NC}"
