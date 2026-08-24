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
    zoxide
    tldr
    fontconfig
)

echo -e "${YELLOW}Actualizando repositorios...${NC}"
sudo apt-get update

echo -e "${YELLOW}Instalando paquetes...${NC}"
sudo apt-get install -y "${PACKAGES[@]}"

echo -e "${GREEN}✅ Paquetes base instalados${NC}"

# ============================================
# ~/.local/bin — destino de los symlinks bat/fd de abajo. Se crea una
# única vez aquí, antes de los dos bloques, para que ninguno dependa
# implícitamente del otro si se reordena, condiciona o retira uno de
# ellos (antes vivía dentro del bloque "bat" y el de "fd" lo usaba sin
# crearlo).
# ============================================
echo ""
mkdir -p "$HOME/.local/bin"

# ============================================
# Symlink bat -> batcat
# ============================================
# Ubuntu renombra el binario de "bat" a "batcat" por colisión de nombre con
# bacula-console. Enlazamos ~/.local/bin/bat -> batcat para poder usar "bat"
# directamente, sin pisar un "bat" real ya presente en el PATH — y sin pisar
# tampoco un "bat" real que ya viva en ~/.local/bin/bat pero que "command -v"
# no vea porque ese directorio aún no está en el PATH de esta sesión (p.ej.
# una instalación manual previa en una máquina recién configurada).
if command -v bat &> /dev/null; then
    echo -e "${YELLOW}↔  'bat' ya resuelve en el PATH ($(command -v bat)) — no se crea el symlink${NC}"
elif [ -e "$HOME/.local/bin/bat" ] && [ ! -L "$HOME/.local/bin/bat" ]; then
    echo -e "${YELLOW}⚠  ~/.local/bin/bat ya existe y es un fichero real — no se toca${NC}"
elif [ -L "$HOME/.local/bin/bat" ] && [ -e "$HOME/.local/bin/bat" ] \
    && [ "$(readlink -f "$HOME/.local/bin/bat")" != "$(readlink -f /usr/bin/batcat)" ]; then
    # Symlink del usuario a OTRO destino real: no es nuestro y no se pisa.
    # Un symlink colgante sí cae al `ln` de abajo y se repara.
    echo -e "${YELLOW}⚠  ~/.local/bin/bat apunta a $(readlink "$HOME/.local/bin/bat") — no se toca${NC}"
elif [ -x /usr/bin/batcat ]; then
    ln -sf "/usr/bin/batcat" "$HOME/.local/bin/bat"
    echo -e "${GREEN}✅ Symlink creado: ~/.local/bin/bat -> /usr/bin/batcat${NC}"
    echo -e "${YELLOW}⚠  'bat' resolverá solo si ~/.local/bin ya está en tu PATH — en una instalación"
    echo -e "   nueva puede no estarlo hasta que abras una sesión de shell nueva (ver shell/exports.sh)${NC}"
else
    echo -e "${YELLOW}⚠  /usr/bin/batcat no encontrado — no se crea el symlink${NC}"
fi

# ============================================
# Symlink fd -> fdfind
# ============================================
# Ubuntu renombra el binario de "fd-find" a "fdfind" por colisión de nombre con
# otro paquete. Enlazamos ~/.local/bin/fd -> fdfind para poder usar "fd"
# directamente, sin pisar un "fd" real ya presente en el PATH — mismo caso
# límite que "bat" arriba (un ~/.local/bin/fd real e instalado a mano, con
# ~/.local/bin todavía fuera del PATH), y mismo arreglo.
echo ""
if command -v fd &> /dev/null; then
    echo -e "${YELLOW}↔  'fd' ya resuelve en el PATH ($(command -v fd)) — no se crea el symlink${NC}"
elif [ -e "$HOME/.local/bin/fd" ] && [ ! -L "$HOME/.local/bin/fd" ]; then
    echo -e "${YELLOW}⚠  ~/.local/bin/fd ya existe y es un fichero real — no se toca${NC}"
elif [ -L "$HOME/.local/bin/fd" ] && [ -e "$HOME/.local/bin/fd" ] \
    && [ "$(readlink -f "$HOME/.local/bin/fd")" != "$(readlink -f /usr/bin/fdfind)" ]; then
    # Symlink del usuario a OTRO destino real (p.ej. ~/.cargo/bin/fd): no
    # es nuestro y no se pisa. Un symlink colgante sí cae al `ln` de abajo
    # y se repara, porque `-e` es falso sobre un enlace roto.
    echo -e "${YELLOW}⚠  ~/.local/bin/fd apunta a $(readlink "$HOME/.local/bin/fd") — no se toca${NC}"
elif [ -x /usr/bin/fdfind ]; then
    ln -sf "/usr/bin/fdfind" "$HOME/.local/bin/fd"
    echo -e "${GREEN}✅ Symlink creado: ~/.local/bin/fd -> /usr/bin/fdfind${NC}"
    echo -e "${YELLOW}⚠  'fd' resolverá solo si ~/.local/bin ya está en tu PATH — en una instalación"
    echo -e "   nueva puede no estarlo hasta que abras una sesión de shell nueva (ver shell/exports.sh)${NC}"
else
    echo -e "${YELLOW}⚠  /usr/bin/fdfind no encontrado — no se crea el symlink${NC}"
fi

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
