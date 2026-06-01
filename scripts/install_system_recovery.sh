#!/bin/bash

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}🛟 Configurando resiliencia del sistema (anti-cuelgues)...${NC}"

# ============================================
# 1. SysRq + swappiness (sysctl)
# ============================================
echo -e "${YELLOW}Configurando sysctl (sysrq + swappiness)...${NC}"

sudo tee /etc/sysctl.d/99-sysrq.conf > /dev/null <<'EOF'
# Magic SysRq: 1 = habilita todas las funciones del kernel SysRq.
# Permite recuperar un sistema colgado sin apagar a lo bruto con la
# secuencia REISUB: Alt+SysRq y, despacio, R - E - I - S - U - B.
kernel.sysrq = 1
EOF

sudo tee /etc/sysctl.d/99-zram.conf > /dev/null <<'EOF'
# Con zram (swap comprimido en RAM) conviene un swappiness alto: el kernel
# prefiere comprimir páginas en RAM antes de paginar al disco, que es lento.
vm.swappiness = 180
EOF

sudo sysctl --system > /dev/null
echo -e "${GREEN}✅ sysctl aplicado (sysrq=1, swappiness=180)${NC}"

# ============================================
# 2. zram-tools → swap comprimido en RAM
# ============================================
# Absorbe los picos de memoria en RAM comprimida (rápida) en lugar de
# paginar a disco, evitando el thrashing que deja el sistema colgado.
echo -e "${YELLOW}Instalando y configurando zram-tools...${NC}"
sudo apt-get install -y zram-tools

sudo tee /etc/default/zramswap > /dev/null <<'EOF'
# Algoritmo de compresión (zstd: mejor ratio con buen rendimiento)
ALGO=zstd
# Porcentaje de RAM dedicado a zram (50% ≈ 15G de colchón en una máquina de 31G)
PERCENT=50
# Prioridad alta: zram se usa antes que el swapfile de disco (prioridad -2)
PRIORITY=100
EOF

sudo systemctl enable zramswap
sudo systemctl restart zramswap
echo -e "${GREEN}✅ zram activo (zstd, 50% RAM, prio 100)${NC}"

# ============================================
# 3. earlyoom → evita el cuelgue por OOM
# ============================================
# Mata el proceso desbocado ANTES de que el sistema entre en thrashing total
# (rompe el livelock). Perfil "aguanta": umbrales bajos, corta como último recurso.
echo -e "${YELLOW}Instalando y configurando earlyoom...${NC}"
sudo apt-get install -y earlyoom

sudo tee /etc/default/earlyoom > /dev/null <<'EOF'
# -m 5  → actúa cuando la RAM libre baja del 5%
# -s 5  → ...y a la vez el swap (zram) libre baja del 5%
# -r 60 → informe del uso de memoria cada 60s en el journal
# Perfil "aguanta": umbrales bajos = da tiempo a que el proceso termine solo.
EARLYOOM_ARGS="-m 5 -s 5 -r 60"
EOF

sudo systemctl enable earlyoom
sudo systemctl restart earlyoom
echo -e "${GREEN}✅ earlyoom activo (-m 5 -s 5)${NC}"

# ============================================
# Resumen
# ============================================
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Resiliencia del sistema configurada${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "  sysrq      = 1    (recuperación: Alt+SysRq+R-E-I-S-U-B)"
echo -e "  swappiness = 180"
echo -e "  zram       = 50% RAM (zstd, prio 100)"
echo -e "  earlyoom   = -m 5 -s 5"
echo ""
echo -e "${YELLOW}Verifica con: swapon --show ; zramctl ; systemctl status earlyoom${NC}"
