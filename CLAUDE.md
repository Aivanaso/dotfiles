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
make recovery    # OOM protection: zram, earlyoom, sysrq, swappiness
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
- Installs the interactive Claude Code profile to `~/.claude/`: CLAUDE.md via an `@import` file (so apps that write to `~/.claude/CLAUDE.md` don't dirty the repo), `settings.json` via a `jq` merge where the repo wins declared keys and local-only runtime keys are preserved, and the hook/statusline scripts plus `output-styles/` copied (not symlinked)
- Installs the isolated headless profile to `~/.claude-headless/` (see `claude/headless/` below): `settings.json` via a full copy (repo is the sole source of truth, no merge — local edits reset on every reinstall, deliberate), `.credentials.json` symlinked from `~/.claude/.credentials.json` (a pre-existing real file is backed up first; a pre-existing directory aborts the link instead of nesting inside it), both `~/.claude-headless/` and its `logs/` set to `chmod 700`
- Optionally generates `.mdc` rule files for Cursor in `~/.cursor/rules/`
- Backs up existing files with `.bak` timestamp before overwriting
- Is idempotent (safe to run multiple times)

### Claude Headless (cron / automation)

```bash
# Run Claude Code non-interactively against the isolated headless profile
scripts/claude-headless.sh [-C <workdir>] "<prompt>" [extra claude flags...]
```

See `claude/headless/` under Architecture for what the profile isolates and why.

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
- `settings.json` — Permission rules (deny secrets, confirm git operations, allow dev tools) for the interactive profile
- `headless/settings.json` — Permission rules for the isolated headless profile (see below)
- `output-styles/default.md` — Response style guide (concepts first, direct answers)
- `skills/` — Technology-specific skills:
  - `nestjs/`, `symfony/`, `php-8/` — Backend frameworks
  - `typescript/`, `react/`, `tailwind/` — Frontend stack
  - `testing/` — Testing patterns (Jest, Vitest, PHPUnit)
  - `pr-review/` — Pull request review guidelines
  - `skill-creator/` — Meta-skill for creating new skills

**Key characteristics:**
- Installed to `~/.claude/` (interactive) and `~/.claude-headless/` (headless) by `scripts/install_claude.sh` — see that section for the exact mechanism per file (import/merge/copy)
- Skills use YAML frontmatter for metadata (`name`, `description`)
- Each skill is self-contained in its directory with a `SKILL.md` file

### claude/headless/ and scripts/claude-headless.sh

Purpose: Isolated Claude Code profile for autonomous/unattended execution (cron, CI, scheduled agents) — separate from the interactive profile so an unattended run never *loads* personal config, hooks, or memory, and its own permission set reduces drastically (not eliminates) what it can read or execute.

**Why `CLAUDE_CONFIG_DIR`:** Claude Code resolves its entire user scope — `settings.json`, `CLAUDE.md`, hooks, and credentials — from `CLAUDE_CONFIG_DIR` when it's exported, and loads nothing from `~/.claude` in that case. Pointing it at `~/.claude-headless` gives the headless profile a boundary at the config-loading layer: no interactive hooks (`notify-hook.sh`, `bash-guard-hook.sh`), no personal `CLAUDE.md`/memory (deliberate — `install_claude.sh` does not create one for this profile), and its own minimal permission set (`claude/headless/settings.json`) where risky operations (`sudo`, `git push`, `rm -rf`, `docker`, reading `~/.claude/**`, `~/.claude-headless/**` or secrets, writing to `~/.claude/**`, `~/.claude-headless/**` or `~/.local/bin/**`) are denied outright, since in `-p` mode an "ask" rule is silently denied rather than prompted.

`Write`/`Edit` are allow-scoped to `~/Proyectos/**` (previously unrestricted) — the cron workdirs an unattended run targets all live there. That narrows the explicit `allow` entry, but the profile's `defaultMode` is `acceptEdits` (`claude/headless/settings.json:4`), which auto-accepts file edits that match neither an `allow` nor a `deny` rule — so the narrowed `allow` alone does not block paths outside `~/Proyectos/**`; the actual hard block for anything outside it is the explicit `deny` list, which always wins regardless of mode. That is why `~/Proyectos/dotfiles/**` is denied even though it sits inside the allowed `~/Proyectos/**` — this repo's own `shell/*.sh` files are sourced into the human's interactive shell (see Shell Configuration above), so an unattended run must never be able to write there — and why `~/.ssh/**` gets an explicit `Write`/`Edit` deny mirroring the existing `Read` deny, rather than relying on it already sitting outside `~/Proyectos/**`. Opening a tool for one task (Docker or otherwise) via `--allowedTools` on that single invocation only ever extends the *allow* side for that run — it can never remove a `deny` entry, so `~/Proyectos/dotfiles/**`, `~/.ssh/**`, `~/.claude/**`, etc. stay blocked regardless. A full default-deny inversion (allow-list only the specific paths a task needs, deny everything else) would close this more durably but is not implemented — the profile still starts from a broad `Write`/`Edit` allow narrowed by explicit denies, so a deny gap is still possible for any path this list hasn't anticipated.

This is a **best-effort reduction, not a sandbox**: the Bash allow list still permits general-purpose readers (`grep`, `find`, `head`, `tail`, `rg`) that can reach the same file content the literal `cat`-shaped deny rules target — mitigated with additional mid-pattern `Bash(*...*)` denies (`*.credentials.json*`, `*~/.claude*`, `*.ssh/*`, `*id_rsa*`, `*.pem*`, `*.key`, `*.key *`, etc.), never fully closed, since the permission matcher works on command-shape, not on what the command actually reads. `*secret*` is deliberately left cat-only (`Bash(cat *secret*)` only) rather than mid-pattern like `.pem`/`.key` — a mid-pattern `*secret*` deny would also block legitimate work in the audited repo, e.g. `grep SECRET_KEY src/`; accepted residual, the `.pem`/`.key`/`.credentials.json`/`~/.claude`/`.ssh`/`id_rsa` cases don't have that false-positive risk. Hard isolation against a compromised run (one that can never read outside the profile at all) needs a container or a dedicated OS user, which this profile does not provide. Docker is deliberately absent from the allow list — an unrestricted `docker run -v $HOME:/host ...` bypasses every other deny rule in a single call; a task that genuinely needs Docker opens it per-invocation, e.g. `scripts/claude-headless.sh "..." --allowedTools "Bash(docker compose *)"`.

**`scripts/claude-headless.sh`:** the wrapper that exports `CLAUDE_CONFIG_DIR` and invokes `claude -p` non-interactively. Resolves the `claude` binary robustly — `CLAUDE_BIN` env override, else `command -v claude`, else `~/.local/bin/claude`, erroring clearly if none is executable, since cron's minimal default `PATH` does not reliably include `~/.local/bin`. Validates the headless profile is installed and credentials are linked before running. Creates the log file explicitly before invoking `claude` (`mkdir -p logs/` + `touch`, both inside a subshell with a restrictive umask scoped to just that step — not a global umask, so files `claude` itself creates in the workdir get the invoking user's normal umask, not owner-only) — an unwritable log is reported as the wrapper's own error (exit 1) instead of being misattributed to `claude`'s exit code. Logs stdout+stderr (`--output-format json` by default) to `~/.claude-headless/logs/<timestamp>-<pid>.log`, preserves `claude`'s exit code, and prunes logs older than 30 days. Caps each run at `--max-turns "${CLAUDE_MAX_TURNS:-25}"` (override via `CLAUDE_MAX_TURNS`); the profile directory is overridable via `CLAUDE_HEADLESS_DIR` (default `~/.claude-headless`). Extra arguments after the prompt pass straight through to `claude` — e.g. `--model`, or `--allowedTools "Bash(docker compose *)"` to open Docker for a single task without widening the base profile. After the run, if `.credentials.json` was a symlink before invocation but no longer is one afterwards (an OAuth token refresh replaces it via atomic rename), the wrapper repairs it — but **only when the profile lives at the default `$HOME/.claude-headless` path**, since the deny rules above are anchored to that literal path and an overridden `CLAUDE_HEADLESS_DIR` would otherwise propagate credentials outside the perimeter those denies protect (the repair is skipped with a warning instead). The repair validates the refreshed file first (non-empty, `jq empty`) before propagating it onto the destination captured via `readlink -f` *before* the run (never a hardcoded `~/.claude`, so a symlink pointing elsewhere gets restored to its own target), backs up the destination first (`chmod 600`, pruned after 7 days the same way logs are) and skips the overwrite entirely if that backup fails, `chmod 600`s the copied file, and re-links with `ln -sfn`. The whole repair runs inside a function invoked with `|| true`, so no step in it — including the final `ln`— can abort the script or override `claude`'s own exit code.

```bash
# Usage
scripts/claude-headless.sh [-C <workdir>] "<prompt>" [extra claude flags...]

# Example crontab line — nightly dependency audit at 03:00
0 3 * * * /home/ivan/Proyectos/dotfiles/scripts/claude-headless.sh -C /home/ivan/Proyectos/some-repo "Audit dependencies for known CVEs and report findings"
```

### scripts/install_claude.sh

Purpose: Install Claude Code (interactive + headless) and Cursor configuration

**Claude Code flow (interactive, `~/.claude/`):**
1. Create `~/.claude/` if it doesn't exist
2. `CLAUDE.md` → real file containing `@<path-to-repo-CLAUDE.md>` (an import, not a symlink), so apps that write to `~/.claude/CLAUDE.md` don't dirty the repo
3. `settings.json` → `jq`-merged: the repo wins the keys it declares (permissions/statusLine/hooks); local-only runtime keys apps write (e.g. `enabledPlugins`) are preserved by exclusion
4. `statusline-command.sh`, `notify-hook.sh`, `bash-guard-hook.sh` → copied (not symlinked), so local edits by external apps don't dirty the repo; hook scripts get `chmod +x`
5. `output-styles/` → copied recursively (not symlinked), same rationale
6. `skills/` is NOT managed here — global skills live directly under `~/.claude/skills/`; per-project skills use `npx autoskills`

**Claude Headless flow (`~/.claude-headless/`, see `claude/headless/` above):**
1. Create `~/.claude-headless/logs/`, then `chmod 700` both `~/.claude-headless/` and `logs/`
2. `settings.json` → full copy (not a merge) from `claude/headless/settings.json`, with a timestamped backup of any prior local file — the repo is the sole source of truth for this profile; a local edit (or a key planted by a compromised run) is reset on the next `make claude` instead of surviving by exclusion
3. `.credentials.json` → symlinked from `~/.claude/.credentials.json` if present: idempotent `ln -sfn` when the target is already a symlink; a pre-existing *real* file is backed up with a timestamp before linking; a pre-existing directory aborts the link with an error instead of nesting inside it; warns if the interactive profile hasn't logged in yet
4. No `CLAUDE.md` is created for this profile — deliberately no global memory for autonomous runs

**Cursor flow (optional, interactive prompt):**
1. Create `~/.cursor/rules/` if it doesn't exist
2. Generate `global-rules.mdc` from `CLAUDE.md` (alwaysApply: true)
3. Generate `.mdc` for each skill with appropriate globs

**Key characteristics:**
- Color-coded output (GREEN, YELLOW, RED)
- Idempotent — safe to run multiple times
- Backs up existing files before replacing (import/merge/copy helpers each take their own backup before overwriting)

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

### scripts/install_system_recovery.sh

Purpose: Configure system resilience against memory-pressure hangs (OOM thrashing) and enable recovery from a frozen system

**What it configures:**
1. **sysctl** — writes `/etc/sysctl.d/99-sysrq.conf` (`kernel.sysrq=1`, full Magic SysRq for REISUB recovery) and `/etc/sysctl.d/99-zram.conf` (`vm.swappiness=180`)
2. **zram** — installs `zram-tools`, configures `/etc/default/zramswap` (zstd, 50% RAM, priority 100) for compressed swap in RAM
3. **earlyoom** — installs `earlyoom`, configures `/etc/default/earlyoom` (`-m 5 -s 5 -r 60`) to kill runaway processes before the system locks up

**Key characteristics:**
- Same patterns as `install_packages.sh`: `set -e`, colors, emojis, idempotent
- Requires sudo (writes under `/etc`, installs packages, manages systemd services)
- NOT part of `make all` — invasive (changes kernel memory policy); run explicitly with `make recovery`
- zram (priority 100) is used before the existing disk swapfile (priority -2)

### Makefile

Purpose: Orchestrate all installation targets

**Targets:**
- `all` — Run everything: packages, source, claude, git, starship, shell
- `packages` — Run `install_packages.sh`
- `source` — Run `install_from_source.sh`
- `claude` — Run `install_claude.sh`
- `recovery` — Run `install_system_recovery.sh` (OOM protection; not in `all`)
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
