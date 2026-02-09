#!/bin/bash

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}📦 Instalando paquetes del sistema...${NC}"

# ============================================
# Paquetes apt
# ============================================
PACKAGES=(
    build-essential
    curl
    wget
    git
    jq
    htop
    unzip
    zip
    software-properties-common
    ca-certificates
    gnupg
    ripgrep
    bat
    eza
    fd-find
)

echo -e "${YELLOW}Actualizando repositorios...${NC}"
sudo apt-get update

echo -e "${YELLOW}Instalando paquetes...${NC}"
sudo apt-get install -y "${PACKAGES[@]}"

echo -e "${GREEN}✅ Paquetes base instalados${NC}"

# ============================================
# Docker (opcional, interactivo)
# ============================================
echo ""
read -p "¿Instalar Docker? (y/n) " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    if command -v docker &> /dev/null; then
        echo -e "${YELLOW}Docker ya está instalado — skip${NC}"
    else
        echo -e "${YELLOW}Instalando Docker...${NC}"

        # Añadir clave GPG oficial de Docker
        sudo install -m 0755 -d /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        sudo chmod a+r /etc/apt/keyrings/docker.gpg

        # Añadir repositorio
        echo \
            "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
            $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
            sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

        sudo apt-get update
        sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

        # Añadir usuario al grupo docker
        sudo usermod -aG docker "$USER"

        echo -e "${GREEN}✅ Docker instalado${NC}"
        echo -e "${YELLOW}⚠  Cierra sesión y vuelve a entrar para usar docker sin sudo${NC}"
    fi
fi

# ============================================
# Starship prompt
# ============================================
echo ""
if command -v starship &> /dev/null; then
    echo -e "${YELLOW}Starship ya está instalado — skip${NC}"
else
    echo -e "${YELLOW}Instalando Starship...${NC}"
    curl -sS https://starship.rs/install.sh | sh -s -- -y
    echo -e "${GREEN}✅ Starship instalado${NC}"
fi

# ============================================
# Resumen
# ============================================
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Instalación de paquetes completada${NC}"
echo -e "${GREEN}========================================${NC}"
