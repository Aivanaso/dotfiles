---
module: shell
project: dotfiles
repo: git@github.com:Aivanaso/dotfiles.git
last_updated: 2026-03-02
status: stable
depends_on: []
tags:
  - shell
  - bash
  - zsh
  - aliases
  - environment
---

## Purpose

Proporciona la configuración runtime del shell: variables de entorno, aliases, funciones de
utilidad y prompt. Se activa sourciando los 4 ficheros desde `.bashrc` / `.zshrc`.

## Decisions

- **4 ficheros separados por responsabilidad**: `exports.sh` (env/PATH), `aliases.sh` (shortcuts),
  `functions.sh` (lógica reutilizable), `prompt.sh` (inicialización de Starship). Separar permite
  sourcing selectivo y facilita el mantenimiento sin tocar ficheros no relacionados.
- **eza con fallback a ls/tree**: los aliases de listado usan `eza` si está disponible, con
  fallback automático a `ls`/`tree`. Así el mismo fichero funciona en máquinas sin `eza`.
- **`_add_to_path` helper en exports.sh**: evita duplicados en `$PATH` y comprueba que el
  directorio existe antes de añadirlo. Sin esto el PATH crece indefinidamente al re-sourcear.

## Structure

| Fichero | Responsabilidad |
|---|---|
| `shell/exports.sh` | Variables de entorno: `EDITOR`, `LANG`, `FZF_DEFAULT_OPTS`, y extensiones de `$PATH` |
| `shell/aliases.sh` | Aliases agrupados por categoría: Git, Docker, Node/pnpm, Sistema |
| `shell/functions.sh` | Funciones Bash reutilizables (actualmente: `install-deb`) |
| `shell/prompt.sh` | Guard + init de Starship prompt |

## Contracts

### `install-deb <file.deb>`

- **Input**: ruta a un fichero `.deb` existente
- **Output**: instala el paquete, repara dependencias con `apt-get install -f`, elimina el `.deb`
- **Rules**: falla si no se pasa argumento, si el fichero no existe, o si no tiene extensión `.deb`.
  El `.deb` se elimina solo en éxito — se preserva en error para debugging.

## Open Questions

- [ ] Evaluar si añadir soporte para Fish shell (actualmente solo bash/zsh)
