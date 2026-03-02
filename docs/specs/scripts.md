---
module: scripts
project: dotfiles
repo: git@github.com:Aivanaso/dotfiles.git
last_updated: 2026-03-02
status: stable
depends_on: []
tags:
  - bash
  - installation
  - bootstrap
  - makefile
  - idempotent
---

## Purpose

Automatiza el bootstrapping completo del entorno de desarrollo: instalación de paquetes del
sistema, herramientas desde source, y despliegue de toda la configuración mediante symlinks.
El Makefile es el único punto de entrada — los scripts no se invocan directamente.

## Decisions

- **Makefile como orquestador único**: agrupa todos los targets con `make help` autodocumentado
  (comentarios `##`). La alternativa (un único script monolítico) dificultaría ejecutar partes
  individuales del setup.
- **Idempotencia en todos los scripts**: todos comprueban el estado antes de actuar (si ya existe
  el symlink correcto, si el tool ya está instalado, etc.). Permite re-ejecutar sin efectos
  secundarios — crucial en máquinas ya configuradas parcialmente.
- **Backup con timestamp antes de sobreescribir**: `install_claude.sh` guarda `.bak.<timestamp>`
  si ya existe un fichero en el destino. Evita pérdida accidental de config personalizada.
- **Docker e FNM son opcionales e interactivos**: ambos requieren confirmación del usuario antes
  de instalar porque tienen impacto significativo en el sistema (grupos, PATH global).

## Structure

| Fichero | Responsabilidad |
|---|---|
| `Makefile` | Orquestador: targets `all`, `packages`, `source`, `claude`, `git`, `starship`, `shell`, `help` |
| `scripts/install_packages.sh` | Paquetes apt (build tools, CLI tools), Docker (opcional), Starship |
| `scripts/install_from_source.sh` | FZF (siempre) y FNM (opcional) instalados desde source/curl |
| `scripts/install_claude.sh` | Symlinks de `claude/` a `~/.claude/` y generación de `.mdc` para Cursor |
| `git/.gitconfig` | Config global de git — symlinkeada a `~/.gitconfig` por `make git` |
| `git/.gitconfig.local.example` | Plantilla para identidad local (name/email) — no se versiona el real |
| `config/starship.toml` | Config del prompt — symlinkeada a `~/.config/starship.toml` por `make starship` |

## Contracts

### `make all`

- **Efecto**: ejecuta en orden: `packages` → `source` → `claude` → `git` → `starship` → `shell`
- **Rules**: requiere `sudo` para `packages`. El resto no requiere privilegios elevados.

### `make claude` / `scripts/install_claude.sh`

- **Efecto**: crea symlinks `~/.claude/{CLAUDE.md,settings.json,skills/,output-styles/}` → repo.
  Genera opcionalmente `~/.cursor/rules/*.mdc` para Cursor.
- **Rules**: backup automático si el destino existe y no es el symlink correcto. Idempotente.

### `make git`

- **Efecto**: symlink `~/.gitconfig` → `git/.gitconfig`
- **Rules**: requiere crear `~/.gitconfig.local` manualmente con `name` y `email` (no incluido
  en el repo por privacidad). El `.gitconfig` principal lo incluye con `[include]`.
