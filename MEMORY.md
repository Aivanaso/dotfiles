---
project: dotfiles
repo: git@github.com:Aivanaso/dotfiles.git
stack:
  shell: bash/zsh
  prompt: starship
  tools: [fzf, fnm, eza, ripgrep, bat, docker]
  ai: claude-code
last_updated: 2026-03-02
---

## Architecture

Repositorio de dotfiles personal estructurado en bounded contexts independientes: configuración
de shell runtime, configuración del asistente de IA (Claude Code + Cursor), y scripts de
instalación/bootstrapping. Todo se despliega mediante symlinks gestionados por `Makefile` y
scripts Bash idempotentes.

El principio central es que cada fichero de la raíz del repo se puede activar de forma
independiente — no hay dependencias ocultas entre `shell/`, `claude/` y `git/`.

## Specs Index

- [shell](docs/specs/shell.md) — Configuración runtime de shell: aliases, exports, funciones y prompt
- [claude](docs/specs/claude.md) — Configuración de Claude Code y Cursor: persona, skills, permisos
- [scripts](docs/specs/scripts.md) — Automatización de instalación y bootstrapping del entorno

## Active Decisions

- **Symlinks en lugar de copy**: los ficheros en `~/.claude/`, `~/.gitconfig`, etc. son symlinks
  al repo, no copias. Así cualquier `git pull` actualiza el entorno sin reinstalar.
- **Idempotencia en todos los scripts**: todos los scripts de instalación son seguros de ejecutar
  múltiples veces — comprueban antes de actuar.
- **Makefile como orquestador**: el punto de entrada único para instalar cualquier parte del
  entorno es `make <target>`, no los scripts directamente.

## Conventions

- Scripts Bash con `set -e` y salida con colores (`$GREEN`, `$YELLOW`, `$RED`, `$NC`)
- Comentarios bilingües aceptables (español/inglés)
- Commits semánticos: `feat:`, `fix:`, `refactor:`, `docs:`, `chore:`
- Ramas descriptivas: `feat/`, `fix:`, `refactor/`
