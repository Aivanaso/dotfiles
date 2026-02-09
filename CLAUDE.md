# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a personal dotfiles repository for managing shell configurations, development environment setup, and AI coding assistant configuration. The codebase is organized into these directories:

- **scripts/** - Installation and setup automation
- **shell/** - Runtime shell functions, aliases, exports, and prompt
- **claude/** - Claude Code and Cursor configuration (persona, skills, permissions, output styles)
- **git/** - Git global configuration
- **config/** - Application configs (Starship prompt)
- **Makefile** - Orchestrator for all installation targets

## Key Commands

### Setup and Installation

```bash
# Install everything (packages, tools, configs, symlinks)
make all

# Or run individual targets
make packages    # System packages + Docker + Starship
make source      # FZF + FNM from source
make claude      # Claude Code + Cursor config
make git         # Symlink .gitconfig
make starship    # Symlink starship.toml
make shell       # Show shell sourcing instructions
make help        # List all targets
```

**install_from_source.sh:**
- Installs/updates FZF (fuzzy finder) from source to `~/.fzf`
- Prompts for optional FNM (Fast Node Manager) installation
- Is idempotent (safe to run multiple times)
- Uses `set -e` so exits on any error

**install_claude.sh:**
- Creates symlinks from `claude/` to `~/.claude/` (CLAUDE.md, settings.json, skills/, output-styles/)
- Optionally generates `.mdc` rule files for Cursor in `~/.cursor/rules/`
- Backs up existing files with `.bak` timestamp before overwriting
- Is idempotent (safe to run multiple times)

### Shell Configuration

All shell files must be sourced in your `.bashrc` or `.zshrc`:

```bash
source ~/Proyectos/dotfiles/shell/exports.sh
source ~/Proyectos/dotfiles/shell/aliases.sh
source ~/Proyectos/dotfiles/shell/functions.sh
source ~/Proyectos/dotfiles/shell/prompt.sh
```

Available functions:
- `install-deb <file.deb>` - Installs a .deb package, fixes dependencies, and removes the file on success

Key aliases (see `shell/aliases.sh` for full list):
- **Git:** `gs`, `ga`, `gc`, `gcm`, `gp`, `gpl`, `gd`, `gl`, `gco`, `gcb`
- **Docker:** `d`, `dc`, `dcu`, `dcd`, `dcl`, `dcr`
- **Node/pnpm:** `p`, `pi`, `pd`, `pb`, `pt`, `px`
- **System:** `ll`, `la`, `lt` (eza with ls fallback), `..`, `...`, `cls`

## Architecture

### scripts/install_from_source.sh

Purpose: Automate installation of development tools from source

**FZF Installation Flow:**
1. Check if `~/.fzf` directory exists
2. If not: shallow clone from GitHub, run `~/.fzf/install --all --no-fish`
3. If exists: pull updates and reinstall

**FNM Installation Flow:**
1. Interactive prompt asking user if they want FNM
2. Check if `fnm` command exists
3. If not: curl install script from fnm.vercel.app and execute

**Key characteristics:**
- Color-coded output (GREEN for success, YELLOW for info)
- Comments are bilingual (Spanish/English)
- Exits on any error (`set -e`)

### claude/

Purpose: Reusable configuration for Claude Code and Cursor IDE

**Structure:**
- `CLAUDE.md` — Main persona prompt (senior architect, Spanish Spain tone, tech expertise)
- `settings.json` — Permission rules (deny secrets, confirm git operations, allow dev tools)
- `output-styles/default.md` — Response style guide (concepts first, direct answers)
- `skills/` — Technology-specific skills:
  - `nestjs/`, `symfony/`, `php-8/` — Backend frameworks
  - `typescript/`, `react/`, `tailwind/` — Frontend stack
  - `testing/` — Testing patterns (Jest, Vitest, PHPUnit)
  - `pr-review/` — Pull request review guidelines
  - `skill-creator/` — Meta-skill for creating new skills

**Key characteristics:**
- Symlinked to `~/.claude/` by `scripts/install_claude.sh`
- Skills use YAML frontmatter for metadata (`name`, `description`)
- Each skill is self-contained in its directory with a `SKILL.md` file

### scripts/install_claude.sh

Purpose: Install Claude Code and Cursor configuration

**Claude Code flow:**
1. Create `~/.claude/` if it doesn't exist
2. For each item (CLAUDE.md, settings.json, skills/, output-styles/):
   - If symlink already correct → skip
   - If file/dir exists → backup with `.bak` timestamp
   - Create symlink to dotfiles repo

**Cursor flow (optional, interactive prompt):**
1. Create `~/.cursor/rules/` if it doesn't exist
2. Generate `global-rules.mdc` from `CLAUDE.md` (alwaysApply: true)
3. Generate `.mdc` for each skill with appropriate globs

**Key characteristics:**
- Color-coded output (GREEN, YELLOW, RED)
- Idempotent — safe to run multiple times
- Backs up existing files before replacing

### shell/functions.sh

Purpose: Provide utility functions for system administration

**install-deb function:**
1. Validates argument provided
2. Checks file exists and has `.deb` extension
3. Runs `sudo dpkg -i <file>`
4. On success: removes the .deb file and runs `apt-get install -f` to fix dependencies
5. On failure: preserves the .deb file and returns error

**Design notes:**
- Designed to be extensible - add more functions to this file
- All user-facing messages use emojis for visual clarity
- Error handling at each validation step

### shell/aliases.sh

Purpose: Shell aliases grouped by category (Git, Docker, Node/pnpm, System)

**Key characteristics:**
- eza aliases with automatic fallback to ls/tree if eza is not installed
- Navigation shortcuts (`..`, `...`, `....`)
- Sourced at shell startup, not executed as a script

### shell/exports.sh

Purpose: Environment variables and PATH configuration

**Key characteristics:**
- `_add_to_path` helper prevents duplicate PATH entries and checks directory exists
- Sets EDITOR, VISUAL, LANG, LC_ALL, FZF_DEFAULT_OPTS
- PATH additions: `~/.local/bin`, composer, npm-global, cargo, go

### shell/prompt.sh

Purpose: Initialize Starship prompt if installed

**Key characteristics:**
- Guards with `command -v starship` — safe to source even without Starship
- Single responsibility: only prompt initialization

### config/starship.toml

Purpose: Starship prompt configuration — minimal and functional

**Modules enabled:** directory, git_branch, git_status, nodejs, docker_context, cmd_duration, character
**Modules disabled:** php, python, ruby, java, golang, rust (used inside Docker containers)

### git/.gitconfig

Purpose: Global git configuration — symlinked to `~/.gitconfig`

**Key settings:**
- `pull.rebase = true`, `push.autoSetupRemote = true`, `fetch.prune = true`
- `rerere.enabled = true` for automatic conflict resolution memory
- `merge.conflictstyle = diff3`
- Useful aliases: `lg`, `amend`, `undo`, `wip`, `st`, `last`
- Placeholder user name/email — must be changed after install

### scripts/install_packages.sh

Purpose: Install system packages, Docker, and Starship

**apt packages:** build-essential, curl, wget, git, jq, htop, unzip, zip, ripgrep, bat, eza, fd-find

**Docker flow (optional, interactive):**
1. Check if `docker` command exists
2. Add Docker official GPG key and repository
3. Install docker-ce, docker-ce-cli, containerd.io, docker-compose-plugin
4. Add user to docker group

**Starship flow:** Install via official install script if not present

**Key characteristics:**
- Same patterns as `install_from_source.sh`: `set -e`, colors, emojis, idempotent
- Docker installation is interactive (requires user confirmation)

### Makefile

Purpose: Orchestrate all installation targets

**Targets:**
- `all` — Run everything: packages, source, claude, git, starship, shell
- `packages` — Run `install_packages.sh`
- `source` — Run `install_from_source.sh`
- `claude` — Run `install_claude.sh`
- `git` — Symlink `.gitconfig` with backup
- `starship` — Symlink `starship.toml` with backup
- `shell` — Print shell sourcing instructions
- `help` — List targets with descriptions

**Key characteristics:**
- Symlink targets (git, starship) use inline logic matching `install_claude.sh` patterns
- All targets are `.PHONY`
- `help` auto-generates from `##` comments

## Development Practices

### When Modifying Scripts

- The codebase uses Bash, not POSIX sh - Bash-specific features like `[[` conditionals and `set -e` are expected
- Installation scripts should remain idempotent - running them multiple times should be safe
- User-facing output should use the color variables: `$GREEN`, `$YELLOW`, `$NC`
- Both English and Spanish comments are acceptable in this codebase

### When Adding New Functions

Add new shell functions to `shell/functions.sh`:
- Follow the existing pattern of validation → action → cleanup
- Use emojis in user messages for consistency with existing functions
- Include error handling with descriptive messages
- Return appropriate exit codes (1 for errors, 0 for success)

### Git Workflow

- The main branch is `main`
- Remote: `git@github.com:Aivanaso/dotfiles.git`
- Conventional commits: `feat:`, `fix:`, `refactor:`, `docs:`, `test:`, `chore:`
