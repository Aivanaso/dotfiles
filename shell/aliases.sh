#!/bin/bash

# ============================================
# Git
# ============================================
alias gs='git status'
alias ga='git add'
alias gaa='git add --all'
alias gc='git commit'
alias gcm='git commit -m'
alias gca='git commit --amend'
alias gp='git push'
alias gpl='git pull'
alias gf='git fetch --all --prune'
alias gd='git diff'
alias gds='git diff --staged'
alias gl='git log --oneline --graph --decorate -20'
alias gco='git checkout'
alias gcb='git checkout -b'
alias gb='git branch'
alias gst='git stash'
alias gstp='git stash pop'
alias gcp='git cherry-pick'
alias gsp='git-switch-pull'

# ============================================
# Docker
# ============================================
alias d='docker'
alias dc='docker compose'
alias dps='docker ps'
alias dpsa='docker ps -a'
alias dcu='docker compose up -d'
alias dcd='docker compose down'
alias dcl='docker compose logs -f'
alias dcr='docker compose restart'
alias dcb='docker compose build'

# ============================================
# Node / pnpm
# ============================================
alias p='pnpm'
alias pi='pnpm install'
alias pd='pnpm dev'
alias pb='pnpm build'
alias pt='pnpm test'
alias px='pnpx'
alias nr='npm run'

# ============================================
# Sistema
# ============================================

# eza con fallback a ls/tree
if command -v eza &> /dev/null; then
    alias ll='eza -la --icons --group-directories-first'
    alias la='eza -a --icons'
    alias lt='eza --tree --level=2 --icons'
else
    alias ll='ls -la'
    alias la='ls -a'
    alias lt='tree -L 2'
fi

# bat con fallback a cat — Ubuntu instala el binario como `batcat`
# (colisión de nombre con bacula-console); scripts/install_packages.sh
# ya crea ~/.local/bin/bat como symlink, así que se comprueba primero
if command -v bat &> /dev/null; then
    alias cat='bat'
elif command -v batcat &> /dev/null; then
    alias cat='batcat'
fi

# tldr en vez de man/help resumido
if command -v tldr &> /dev/null; then
    alias help='tldr'
fi

# Navegación
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

# Utilidades
alias mkd='mkdir -p'
alias cls='clear'

# Búsqueda y navegación interactivas (funciones definidas en functions.sh)
alias fif='find-in-files'
alias glf='git-log-interactive'
