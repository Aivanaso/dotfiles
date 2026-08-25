# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a personal dotfiles repository for managing shell configurations, development environment setup, and AI coding assistant configuration. The codebase is organized into these directories:

- **scripts/** - Installation and setup automation
- **shell/** - Runtime shell functions, aliases, exports, and prompt
- **claude/** - Claude Code configuration (global instructions, permissions, output styles)
- **git/** - Git global configuration
- **config/** - Application configs (Starship prompt, Kitty terminal)
- **Makefile** - Orchestrator for all installation targets

## Key Commands

### Setup and Installation

```bash
# Install everything (packages, tools, configs, symlinks)
make all

# Or run individual targets
make packages    # System packages + Docker + Starship
make fonts       # JetBrains Mono Nerd Font
make source      # FZF + FNM + Kitty from source (FNM/Kitty opt-in)
make claude      # Claude Code config
make recovery    # OOM protection: zram, earlyoom, sysrq, swappiness
make git         # Symlink .gitconfig + gitignore.global
make starship    # Symlink starship.toml
make shell       # Install the single shell/index.sh source line in ~/.bashrc
make kitty       # Symlink Kitty config (opt-in — install the binary first via `make source`)
make local       # Create ~/.dotfiles.local from the template (never overwrites an existing one)
make help        # List all targets
```

**install_from_source.sh:**
- Installs/updates FZF (fuzzy finder) from source to `~/.fzf`, with `--no-update-rc` on both the initial install and the update path so it never writes to the user's `.bashrc`/`.zshrc` — sourcing `~/.fzf.bash` is left to `shell/` (a separate phase)
- Prompts for optional FNM (Fast Node Manager) installation
- Prompts for optional Kitty (terminal emulator) installation — official installer plus the desktop integration (`.desktop` files, `~/.local/bin` symlinks) that installer does not do on its own; Konsole stays installed either way
- Is idempotent (safe to run multiple times)
- Uses `set -e` so exits on any error

**install_fonts.sh:**
- Downloads JetBrains Mono Nerd Font's zip from `ryanoasis/nerd-fonts` and verifies it before extracting anything (fails closed — a mismatch aborts with a `RED` error and a non-zero exit, never installs unverified). For the version pinned by default, verification is against a SHA-256 constant fixed in the script itself (`EXPECTED_SHA256_PINNED`, next to `NERD_FONT_PINNED_VERSION`) rather than the release's own `SHA-256.txt` — the checksums file is downloaded from the same origin and over the same channel as the zip, so it only catches corruption/truncation, not a TLS-intercepting proxy serving a tampered zip and a matching tampered checksums file together; a hash pinned in the repo can't be altered by that proxy. `NERD_FONT_PINNED_VERSION`/`EXPECTED_SHA256_PINNED` must be updated together whenever the pinned version is bumped (comment above the constant documents how to recompute it). Overriding `NERD_FONT_VERSION` to a different tag falls back to downloading and checking against that release's `SHA-256.txt`, with a `YELLOW` warning that this path does not cover the MITM case. Extraction happens in a temporary directory and is validated there (expected `.ttf` present, `unzip` exit code checked) before it replaces `~/.local/share/fonts/JetBrainsMonoNerdFont/` — a failed download, checksum or extraction never touches the previous, working installation. The font cache is refreshed with `fc-cache -f` only after the swap
- Idempotent — the marker encodes the installed version, so a version bump reinstalls automatically; `NERD_FONT_FORCE=1` forces reinstalling the same version too. The skip check also requires the expected font file to still be present, so a partially-deleted install self-repairs instead of reporting a false "already installed". The version marker is written only after `fc-cache` succeeds, so a `fc-cache` failure is never recorded as a completed install (and gets retried on the next run) — and the destination directory is only ever wiped after the new extraction is already validated in the temp directory, never before, so files removed/renamed between releases don't linger as orphans without risking the previous install on failure
- Release version pinned in the script by default; override with `NERD_FONT_VERSION` (tag from `ryanoasis/nerd-fonts` releases) — see the SHA-256 note above for what that changes about integrity verification
- Validates `curl`, `unzip`, `sha256sum` and `fc-cache` are present before acting, with a clear error otherwise (`curl`/`unzip`/`fontconfig` are all in `install_packages.sh`'s `PACKAGES` array)

**install_claude.sh:**
- Installs the Claude Code profile to `~/.claude/`: `CLAUDE.md` as a delimited block holding an `@import` to the repo's file (so the rest of that shared file survives), `settings.json` via a `jq` merge where the repo wins declared keys and local-only runtime keys are preserved, and `notify-hook.sh`/`statusline-command.sh` plus `output-styles/` copied (not symlinked)
- Backs up existing files with `.bak` timestamp before overwriting
- Is idempotent (safe to run multiple times)
- **Copies, never prunes:** a file removed from the repo survives in `~/.claude/` until it's deleted by hand. `output-styles/` is the exception — `copy_directory` moves the whole destination to a backup before copying, so it does track removals

### Shell Configuration

Bash-only — this repo has one code path, no per-shell branches. `make shell` (`scripts/install_shell.sh`) installs a single delimited block in `~/.bashrc` that sources the one entry point:

```bash
# >>> dotfiles >>>
[ -f "/path/to/dotfiles/shell/index.sh" ] && source "/path/to/dotfiles/shell/index.sh"
# <<< dotfiles <<<
```

`shell/index.sh` loads everything else, in a fixed order, each step guarded by file existence or `command -v`: `exports.sh` → `~/.fzf.bash` (if present) → `aliases.sh` → `functions.sh` → `options.sh` → `prompt.sh` → `local.sh`. `local.sh` is always last, so machine-specific config in `~/.dotfiles.local` (see `shell/local.sh` below) can override anything the repo sets.

Available functions (see `shell/functions.sh`):
- `install-deb <file.deb>` — installs a .deb package, fixes dependencies, and removes the file on success
- `find-in-files <text>` (alias `fif`) — `rg` content search piped into `fzf` with a `bat`/`cat` preview, opens the pick at the exact line in `$EDITOR`
- `git-log-interactive [git-log-args]` (alias `glf`) — `git log --oneline` piped into `fzf` with a commit preview; Enter opens the full commit, Ctrl-Y copies the hash (Wayland `wl-copy` or X11 `xclip`, whichever is present)
- `git-switch-pull <rama>` (alias `gsp`) — `git switch <rama> && git pull`; keeps git's own branch-name completion for both names when bash-completion's git support is available on the machine, degrades silently (no completion, function/alias still work) otherwise
- `mkalias <nombre> <comando>` — appends an `alias <nombre>=<comando>` line to `~/.dotfiles.local` (override: `DOTFILES_LOCAL`, mirrors `install_shell.sh`'s `DOTFILES_RC`) — the command shell-quoted via `printf %q`, not the literal single-quoted form the name might suggest — and defines it in the current shell immediately, no new terminal needed. Only ever appends — there is no overwrite path: fails if the name is already in use — as an active alias (which may come from `shell/aliases.sh`, not just the local file), as a line already in the local file (indented or not — a definition living inside a hand-written `if`/`fi` counts too), or as a function currently defined in this shell (`declare -F` doesn't distinguish this repo's own functions, e.g. `install-deb`, from ones loaded elsewhere, e.g. zoxide's `z`) — printing what already exists and exiting non-zero; changing an existing definition is a manual `~/.dotfiles.local` edit, not this function's job. The name `alias` is rejected outright: `alias alias=…` expands in command position, so every line appended below it would die on source. Both reads that gate the append — the collision `grep` and the trailing-newline `tail` — fail CLOSED: an unreadable file aborts with an error instead of being assumed to hold no definition and to end in a newline, the two assumptions that would otherwise duplicate a definition or fuse two lines. Creates `~/.dotfiles.local` from `shell/dotfiles.local.example` first, at the same `600` mode `make local` gives it, if the file doesn't exist yet; refuses outright (rather than writing through it) if the path is a dangling symlink

Key aliases (see `shell/aliases.sh` for full list):
- **Git:** `gs`, `ga`, `gc`, `gcm`, `gp`, `gpl`, `gd`, `gl`, `gco`, `gcb`, `gsp`
- **Docker:** `d`, `dc`, `dcu`, `dcd`, `dcl`, `dcr`
- **Node/pnpm:** `p`, `pi`, `pd`, `pb`, `pt`, `px`
- **System:** `ll`, `la`, `lt` (eza with ls fallback), `cat` (bat/batcat fallback), `help` (tldr), `fif`, `glf`, `..`, `...`, `cls`

**Machine-local config (`~/.dotfiles.local`):** anything that must NOT be versioned — SDKMAN init, `JAVA_HOME`, `OLLAMA_MODELS`, a corporate proxy, a company npm registry — goes in `~/.dotfiles.local` on that machine, sourced by `shell/local.sh` if the file exists (no error if it doesn't). This is the repo's only sanctioned per-machine drift point; everything that applies to every machine belongs in the repo itself. `make local` scaffolds it the first time from the versioned template `shell/dotfiles.local.example` (mostly commented-out example blocks — alias, exports, PATH — pointing back at this same section and at `shell/local.sh`'s own header instead of repeating the what-goes-here list a second time) and never overwrites a file that's already there; `mkalias` (see `shell/functions.sh` below) scaffolds it the same way if it's still missing when the first alias is added. Both honor a `DOTFILES_LOCAL` override of the destination path, the same testability pattern `install_shell.sh` uses for `DOTFILES_RC`. A dangling symlink there (target missing — an unmounted disk, an uncloned private repo) is handled asymmetrically on purpose: `make local` treats it as "already there" and just skips with a warning, since it has nothing it must do either way; `mkalias` cannot do the same, because it always has an alias to write, so it refuses outright rather than creating a real file through the broken link at the umask's default mode. Before sourcing it — and `~/.fzf.bash` in `shell/index.sh` — a shared `_dotfiles_safe_source` helper (defined in `shell/index.sh`, `unset -f` at the end) checks the file is owned by the current user (`[ -O ]`), reads mode and GID in one call (`stat -c '%a %g'`), unconditionally rejects other-writable (masked against `002`), and rejects group-writable (masked against `020`) UNLESS the file's group is verifiably the user's own single-member private group: the file's GID must equal `id -g`'s real GID (a syscall, never bash's `$UID`/`$GID` — those keep whatever value an ancestor process already had exported into the environment, since bash only computes them itself when it initializes them fresh) AND `getent group` must report that group has no other members (closing the case of a private group later widened with `usermod -aG`, or a shared group whose GID coincides by chance with the user's). Either check failing to run (unreadable `stat`, unresponsive `id`/`getent`) fails CLOSED, treated as shared. Under Debian/Ubuntu's default per-user-group scheme (`USERGROUPS=yes`) this makes a `664 ivan:ivan` file no more a shared-write vector than `600`; a `664` file owned by any other or widened group is still rejected. Any rejection prints a warning to stderr and skips sourcing instead of running code of uncertain ownership on every interactive shell. Residual, accepted: this checks only the file's own permissions, never its containing directory's — a group-writable `$HOME` would let another member of that group replace the file wholesale before this check ever runs.

## Architecture

### scripts/install_from_source.sh

Purpose: Automate installation of development tools from source

**FZF Installation Flow:**
1. Check if `~/.fzf` directory exists
2. If not: shallow clone from GitHub, run `~/.fzf/install --all --no-fish --no-update-rc`
3. If exists: pull updates and reinstall with the same flags

`--no-update-rc` on both branches means the installer never writes to `~/.bashrc`/`~/.zshrc` — sourcing `~/.fzf.bash` (key bindings, completion) is left to the shell-config phase (`shell/`), not this script.

**FNM Installation Flow:**
1. Interactive prompt asking user if they want FNM
2. Check if `fnm` command exists
3. If not: curl install script from fnm.vercel.app and execute

**Kitty Installation Flow (opt-in, same pattern as FNM):**
1. Interactive prompt asking user if they want Kitty
2. Check if `kitty` command exists — skip the binary install (idempotent) if already installed
3. If not: run the official installer hardened with `--fail --location --retry 3 --retry-delay 2 --connect-timeout 10 --max-time 60` (same convention as `install_fonts.sh`) and `launch=n` — the installer's own default is `launch=y`, which auto-execs the freshly downloaded binary as soon as the download finishes; `launch=n` is kitty's own documented flag for scripted/unattended installs. It drops the app under `~/.local/kitty.app/` but does NOT put the binary on `PATH` or register desktop integration. A precondition check aborts with a `RED` error (mirroring `install_fonts.sh:200-203`) if `~/.local/kitty.app/bin/kitty` is not present afterwards, instead of planting dangling symlinks
4. Symlink `kitty`/`kitten` into `~/.local/bin/` and copy `kitty.desktop`/`kitty-open.desktop` into `~/.local/share/applications/` — each pre-existing target is backed up with a `.bak.<timestamp>` first — rewriting their `TryExec=`/`Icon=`/`Exec=` lines to the absolute install path (the steps kitty's own docs document as manual after a binary install) — `update-desktop-database` is refreshed afterwards if present
5. Desktop integration is idempotent independently of the `command -v kitty` gate that guards the binary install: it checks for the `.desktop` files' own presence, so a prior run that installed the binary but was interrupted before finishing desktop integration self-repairs on the next invocation instead of being skipped forever
6. Config itself is a separate step: `make kitty` (see `config/kitty/` below) — this script only installs the binary
7. Konsole is never touched — it stays installed as Kubuntu's default; switching the system default terminal is a manual step in Systemsettings
8. Success banner tells the user to open a new shell session so `kitty` resolves on `PATH` (same convention as the `bat`→`batcat` symlink, see below)

**Key characteristics:**
- Color-coded output (GREEN for success, YELLOW for info, RED for the Kitty precondition-check failure)
- Comments are bilingual (Spanish/English)
- Exits on any error (`set -e`)

### scripts/install_fonts.sh

Purpose: Install JetBrains Mono Nerd Font for terminal/editor glyph support (icons, ligature-adjacent symbols used by Starship and terminal prompts)

**Flow:**
1. Validate `curl`, `unzip`, `sha256sum`, and `fc-cache` are present — clear `RED` error and `exit 1` if any is missing (`curl`/`unzip` are already in `install_packages.sh`'s `PACKAGES` array; `fc-cache` comes from the `fontconfig` package, also in that array)
2. Idempotency check: skip if a version marker (`.nerd-font-version`) already exists under `~/.local/share/fonts/JetBrainsMonoNerdFont/` **and matches** `NERD_FONT_VERSION` **and** the expected regular-weight `.ttf` is still present — so bumping the pinned version over an existing install triggers a reinstall instead of a silent no-op, and a partially-deleted install (marker present, font file gone) self-repairs instead of reporting a false "already installed"; `NERD_FONT_FORCE=1` also forces reinstall of the same version
3. Download the release zip from `ryanoasis/nerd-fonts` (tag from `NERD_FONT_VERSION`, defaulted in-script) to a `mktemp -d` directory, cleaned up via `trap ... EXIT` — `--retry`/`--connect-timeout`/`--speed-limit`/`--speed-time` so a hung connection cannot block `make all` indefinitely; deliberately no `--max-time` on the ~130 MiB zip, since an absolute time cap would also kill a slow-but-alive connection that `--speed-limit`/`--speed-time` already tolerate, and `--retry` restarts the download from scratch (no resume)
4. Verify the zip's SHA-256 **before** extracting anything — a mismatch is a `RED` error and a non-zero exit, nothing is decompressed, there is no "install without verifying" fallback. When `NERD_FONT_VERSION` equals the pinned default, verification is against `EXPECTED_SHA256_PINNED`, a hash constant fixed in the script — closing the MITM gap a same-origin/same-channel `SHA-256.txt` download can't close. When it's been overridden to a different tag, the script falls back to downloading and checking against that release's own `SHA-256.txt` (`YELLOW` warning that this path doesn't cover MITM)
5. Extract only the "Mono" variant (Regular/Bold/Italic/BoldItalic — the variant recommended for terminal use, since its icon glyphs share the character cell width) plus `OFL.txt` (the release's actual license file — it does not publish a `LICENSE.txt`) into a **temporary** directory, never straight into the destination. `unzip` runs without `-q`/`-qq` (that flag silently downgrades its path-traversal-sanitization exit code from 1 to 0 on the `unzip` build this targets) and only exit code `0` is accepted — any other code, including 1 (entries sanitized for path traversal / zip-slip) or 11 (a requested pattern had no match), aborts the script; nothing is ever swallowed with a blanket fallback
6. Assert the expected regular-weight file exists in the temp extraction (fails loudly instead of printing a false success banner) — only then wipe and replace the destination directory with the validated temp extraction, so a failed download/checksum/extraction/assert never costs the user a previously-working install
7. Refresh the font cache with `fc-cache -f`, and only once that succeeds, write the version marker — so a `fc-cache` failure is never recorded as a completed install and gets retried on the next run

**Key characteristics:**
- Same patterns as the other install scripts: `set -e`, colors, emojis, idempotent
- Two overridable environment variables: `NERD_FONT_VERSION` (release tag) and `NERD_FONT_FORCE` (force reinstall of the same version)
- `NERD_FONT_PINNED_VERSION` and `EXPECTED_SHA256_PINNED` must be bumped together when the pinned release changes — the in-script comment above the constant documents how to recompute the hash
- Never invoked automatically outside `make fonts` / `make all` — no network calls happen unless the target is explicitly run


### claude/

Purpose: the Claude Code configuration this repo owns — what any session on this machine should know, whatever project it is working in.

**Structure:**
- `CLAUDE.md` — global instructions: register (how to word an explanation), code and git conventions, and the tools this repo installs
- `settings.json` — permission rules, output style, status line and hooks
- `output-styles/` — `arquitecto.md`, `jarvis.md` (the default) and `laconico.md`
- `notify-hook.sh` — desktop notification on Stop/Notification, only when the terminal isn't focused
- `statusline-command.sh` — the status line renderer

**Scope boundary:** this directory holds the standard AI configuration for the machine. The working protocol — ai-team, its `organic-*` skills and its agents — lives in its own repo and injects its own delimited block into `~/.claude/CLAUDE.md`. `install_import_block` is written so the two never overwrite each other.

**What is deliberately NOT here:**
- **Skills.** Stack skills (nestjs, react, symfony…) go per project with `npx autoskills`, so they only load where they apply. Global skills live directly under `~/.claude/skills/` and are managed by whoever installs them
- **A headless profile.** There was one (`~/.claude-headless/` plus a `claude -p` wrapper). It went unused — one log file and no crontab entry — because the same need is met by exporting `CLAUDE_CONFIG_DIR` at the point of use
- **Cursor rules.** `install_claude.sh` used to generate `.mdc` files under `~/.cursor/rules/` from the repo's skills. Both went when Cursor stopped being used
- **A PreToolUse Bash guard.** `bash-guard-hook.sh` denied `cd` combined with a redirection, and `for`/`while` loops over variables, so that permission prompts wouldn't stall a delegated task. Under auto mode the classifier never prompts — it approves or denies — so the failure it prevented cannot happen, while its false positives were real: it rejected any `git commit -m "$(...)"` whose message contained the word "for" or "while"
- **`autoMode.environment`.** The classifier's trusted-infrastructure list describes one machine — its repos, its sensitive directories — so it belongs in each machine's own `~/.claude/settings.json`. The `jq` merge preserves it by exclusion for as long as this repo doesn't declare the key

### scripts/install_claude.sh

Purpose: install the Claude Code configuration into `~/.claude/`

**Flow:**
1. Create `~/.claude/` if it doesn't exist
2. `CLAUDE.md` → `install_import_block` writes a delimited block holding an import of the repo's file:

   ```
   <!-- dotfiles:import -->
   @/path/to/dotfiles/claude/CLAUDE.md
   <!-- /dotfiles:import -->
   ```

   The destination is a shared file — ai-team writes `<!-- ai-team:orchestrator -->` into it — so only what sits between these two markers is ever touched. The function also removes the bare `@…` line older versions of this script wrote: without that, the old line would end up below the new block and the repo's CLAUDE.md would load twice. Unbalanced markers (an opening without its closing) abort with exit 1 instead of guessing where the block ends, and a file that already matches the desired content is skipped with no backup and no write
3. `settings.json` → `jq` merge, repo wins the keys it declares (`permissions`, `outputStyle`, `statusLine`, `hooks`). Local-only keys that apps write — `enabledPlugins`, `effortLevel`, `autoMode`… — survive by exclusion. Arrays are replaced whole, never concatenated
4. `statusline-command.sh` and `notify-hook.sh` → copied, not symlinked, so an external app editing them doesn't dirty the repo; `notify-hook.sh` gets `chmod +x`
5. `output-styles/` → copied recursively, same rationale
6. `skills/` is not managed here (see the scope boundary above)

**Key characteristics:**
- Color-coded output (GREEN, YELLOW, RED)
- Idempotent — safe to run multiple times
- Backs up before replacing: each import/merge/copy helper takes its own timestamped backup
- No path hardcoded to one user — `settings.json` writes `$HOME` into the status line and hook commands, and both fields run through a shell that expands it
- **Copies, it does not prune.** A file dropped from the repo survives in `~/.claude/` until deleted by hand. `output-styles/` is the exception: `copy_directory` moves the whole destination to a backup before copying, so removals there do propagate

### shell/index.sh

Purpose: Single entry point for the whole shell configuration — the file `~/.bashrc` actually sources (via the delimited block `scripts/install_shell.sh` installs)

**Load order (fixed, each step guarded by file existence or `command -v`):**
1. `exports.sh` — environment variables, PATH
2. `~/.fzf.bash` (if present) — fzf key bindings/completion; `scripts/install_from_source.sh` installs fzf with `--no-update-rc`, so this repo is the only thing that sources it
3. `aliases.sh`
4. `functions.sh`
5. `options.sh` — bash interactive `shopt`s and history settings
6. `prompt.sh` — Starship
7. `local.sh` — always LAST, so `~/.dotfiles.local` can override anything above

**Key characteristics:**
- Resolves its own directory via `${BASH_SOURCE[0]}` — if that `cd` fails (repo dir removed/unreadable while a shell starts, or the file was executed instead of sourced), it fails loudly (`echo ... >&2` + `return 1`/`exit 1`) instead of silently degrading to a shell with no aliases, no functions and no PATH additions
- Bash-only by design — no per-shell branching; the repo has one code path
- Defines `_dotfiles_safe_source` (ownership + group/other-write check before sourcing an auto-loaded, non-repo file) once, used for both `~/.fzf.bash` here and `~/.dotfiles.local` in `shell/local.sh`; `unset -f` at the end alongside `_DOTFILES_SHELL_DIR`. The group-write check rejects whenever the file is group-writable AND it is not verifiably the user's own single-member private group: the file's GID must equal `id -g` (a syscall — never `$UID`, which is falsifiable via an inherited environment variable) AND `getent group` must show that group has no other members. So the real `~/.fzf.bash` on a default Debian/Ubuntu install (`664 ivan:ivan`, GID == the user's own GID, no other members) is accepted, while a file owned by any shared group (e.g. `ivan:developers`) or a private group later widened with `usermod -aG` is still rejected. Checked property only: the file's own mode/GID — the containing directory's permissions are never inspected (accepted residual, see `shell/index.sh` above)

### shell/options.sh

Purpose: Bash interactive options (`shopt`) and history configuration

**Key characteristics:**
- Guards itself with `[[ $- == *i* ]] || return 0` — these settings only make sense in an interactive shell, and a freshly-created rc (`scripts/install_shell.sh` on a machine with none yet) carries no Debian-style early-return to rely on instead
- `shopt -s autocd globstar cdspell dirspell histappend checkwinsize` — the first four are off by default on Debian/Ubuntu and replace zsh conveniences (`autocd`, `**` recursive globbing, `cd`/directory-name typo correction)
- `HISTSIZE=10000`, `HISTFILESIZE=20000`, `HISTCONTROL=ignoreboth:erasedups` — `erasedups` deduplicates only the in-memory history list of the *current* session; combined with `histappend` (which appends to `HISTFILE` rather than rewriting it), duplicates already on disk from previous sessions are NOT removed — the comment in the file describes this accurately rather than claiming persisted deduplication

### shell/local.sh

Purpose: Hook for machine-local configuration that must never be versioned

**Key characteristics:**
- Sources `~/.dotfiles.local` via `_dotfiles_safe_source` (defined in `shell/index.sh`) if it exists; does not fail if it doesn't; skips sourcing (warning on stderr) if the file isn't owned by the current user, is other-writable, or is writable by a group that isn't the user's own private group (see `shell/index.sh` above)
- Documents in-file what belongs there (SDKMAN, `JAVA_HOME`, `OLLAMA_MODELS`, corporate proxy, private npm registry) vs. what belongs in the repo instead
- Loaded LAST by `shell/index.sh` so it can override any repo default
- Always reads the fixed path `$HOME/.dotfiles.local` — it does not honor `DOTFILES_LOCAL` (that override is `make local`'s and `mkalias`'s own scaffolding-time convenience, see "Machine-local config" above; deliberately out of scope for this file and for `_dotfiles_safe_source`)

### shell/dotfiles.local.example

Purpose: versioned template for `~/.dotfiles.local` — see "Machine-local config" above and `make local` below

**Key characteristics:**
- Almost entirely comments: a short pointer to `shell/local.sh`'s header and to CLAUDE.md's "Machine-local config" section for the full what-goes-here/what-doesn't list, plus commented-out example blocks (alias, exports/`*_HOME`, `PATH`, proxy) ready to uncomment
- Deliberately valid bash on its own (`bash -n` passes) even fully commented — it is copied byte-for-byte to `~/.dotfiles.local`, which `shell/local.sh` sources on every interactive shell

### shell/functions.sh

Purpose: Provide utility functions for system administration, interactive search/navigation, and git workflow shortcuts

**install-deb function:**
1. Validates argument provided
2. Checks file exists and has `.deb` extension
3. Runs `sudo dpkg -i <file>`
4. On success: removes the .deb file and runs `apt-get install -f` to fix dependencies
5. On failure: preserves the .deb file and returns error

**find-in-files function (alias `fif`):**
- `rg --line-number --no-heading --color=always --smart-case` piped into `fzf`, previewed with `bat`/`batcat` (falls back to `cat` if neither is present) highlighted at the matched line
- Enter becomes `$EDITOR +<line> <file>` (defaults to `vim`)
- Errors clearly if `rg` or `fzf` is missing, or if called with no search text

**git-log-interactive function (alias `glf`):**
- `git log --oneline --color=always "$@"` (forwards any extra args, e.g. a path or `--author`) piped into `fzf` with a `git show` preview
- Enter opens the full commit in `less -R`; Ctrl-Y copies the hash — via `wl-copy` (Wayland) or `xclip` (X11), whichever is present; the binding is omitted if neither is
- Errors clearly if not run inside a git repository

**git-switch-pull function (alias `gsp`):**
- `git switch <rama> && git pull` — switches branch and immediately brings it up to date with the remote
- Registers git's own branch-name completion (`_git_switch`, via bash-completion's `__git_complete`) for both `git-switch-pull` and `gsp`, forcing bash-completion's lazy git-completion load if it hasn't fired yet in that shell process (measured cost: ~2.9 ms of startup, paid once per interactive shell process — every new terminal or tab, not once per login session) — registered only in an interactive shell, and only when bash-completion's git support is present on the machine; sourcing this file in a non-interactive shell, or on a machine without it, is a silent no-op — the function and alias still work, just without branch completion
- Errors clearly (usage message, exit 1) if called with no branch name, same pattern as `find-in-files`

**mkalias function:**
- `mkalias <nombre> <comando>` — appends `alias <nombre>=<comando>` to `~/.dotfiles.local` (override: `DOTFILES_LOCAL`, same testability pattern as `install_shell.sh`'s `DOTFILES_RC`) and `eval`s the same line in the current shell, so it is usable immediately — not just written to disk for the next terminal. The command is shell-quoted with `printf %q` (`printf -v linea 'alias %s=%q' "$nombre" "$comando"`), not the literal single-quoted form the name might suggest — what lands in the file for `mkalias q 'echo hola'` is `alias q=echo\ hola`, which round-trips exactly through quoting, backslashes and embedded newlines
- Only ever appends — no in-place rewrite, no backup, no overwrite path exists. Refuses to clobber silently: if `<nombre>` is already an active alias in the current shell (which may come from `shell/aliases.sh`, not the local file), already has a matching line in the local file — the match tolerates leading whitespace, so an alias indented inside a hand-written `if`/`fi` is detected too, not only one starting at column 0 — or already names a function currently defined in this shell — `declare -F` finds any function, not just this repo's own (e.g. `install-deb`); zoxide's `z` triggers the same message even though it isn't defined in `shell/functions.sh` — it prints what's already there and fails (exit 1). Changing an existing definition is a manual `~/.dotfiles.local` edit, by design: this function never touches a line it didn't just write itself
- Creates `~/.dotfiles.local` first, from `shell/dotfiles.local.example`, at mode `600` (the same starting point `make local` produces) if the file doesn't exist yet — no need to run `make local` before the first `mkalias`. If the template itself is missing (the repo moved, a partial checkout), it falls back silently to creating an empty file at the same mode rather than failing — the alias still lands, just without the commented example blocks. If the path is instead a dangling symlink (target missing), it refuses outright rather than writing a real file through the link at the umask's default mode — see "Machine-local config" above for why this differs from `make local`'s own handling of the same case
- Before appending, guarantees the file ends in a newline: a file whose last line lacks a trailing `\n` (e.g. hand-edited) would otherwise fuse with the new alias line into one corrupted line — breaking both whatever was there and the alias just added — so a bare `printf '\n' >>` runs first whenever the file is non-empty and its last byte isn't already one

**Design notes:**
- Designed to be extensible - add more functions to this file
- All user-facing messages use emojis for visual clarity
- Error handling at each validation step

### shell/aliases.sh

Purpose: Shell aliases grouped by category (Git, Docker, Node/pnpm, System)

**Key characteristics:**
- eza aliases with automatic fallback to ls/tree if eza is not installed
- `cat` aliased to `bat`, falling back to `batcat` (Ubuntu's package name for the binary), guarded by `command -v` on both names — no alias at all if neither is installed
- `help` aliased to `tldr` if installed
- `fif`/`glf` — aliases for the `find-in-files`/`git-log-interactive` functions in `shell/functions.sh`
- `gsp` — alias for the `git-switch-pull` function in `shell/functions.sh`; lives in the Git block, not the search/navigation block at the bottom — unlike `fif`/`glf`, `gsp` is a git alias
- Navigation shortcuts (`..`, `...`, `....`)
- Sourced at shell startup, not executed as a script

### shell/exports.sh

Purpose: Environment variables and PATH configuration

**Key characteristics:**
- `_add_to_path` helper prevents duplicate PATH entries and checks directory exists — it PREPENDS, so the LAST call wins highest precedence; `~/.local/bin` is deliberately the last call so it outranks every third-party package manager's bin directory (composer, npm-global, cargo, go, fnm)
- Sets EDITOR, VISUAL, FZF_DEFAULT_OPTS
- **Locale guard:** `LANG`/`LC_ALL` are only exported as `es_ES.UTF-8` when `locale -a` confirms that locale is actually generated on the machine — forcing an ungenerated locale produces perl/locale warnings on every command, which is likely on a machine that hasn't generated Spanish locales (e.g. a work machine). If `es_ES.UTF-8` isn't available, it falls back to `C.UTF-8` (present on every modern glibc, no `locale-gen` needed) or `en_US.UTF-8` if that one exists instead — only `LANG` is set in the fallback, `LC_ALL` stays unset so per-category overrides still work. Without this fallback a machine with neither locale would inherit `C`/`POSIX`, which breaks this repo's own emoji/box-drawing output (`scripts/install_*.sh`, `shell/functions.sh`)
- PATH additions: composer, npm-global, cargo, go, `~/.local/share/fnm`, `~/.local/bin` (in that order — see above)
- **fnm:** `eval "$(fnm env)"` if the `fnm` binary resolves (absorbed from what used to be hand-written directly in the user's `~/.bashrc`, and therefore missing on any new machine)
- **zoxide:** `eval "$(zoxide init bash)"` if installed
- **cargo:** sources `~/.cargo/env` if the file exists

### shell/prompt.sh

Purpose: Initialize Starship prompt if installed

**Key characteristics:**
- Guards with `command -v starship` — safe to source even without Starship
- Single responsibility: only prompt initialization

### config/starship.toml

Purpose: Starship prompt configuration — minimal and functional

**Modules enabled:** directory, git_branch, git_status, nodejs, docker_context, cmd_duration, character
**Modules disabled:** php, python, ruby, java, golang, rust (used inside Docker containers)

### config/kitty/

Purpose: Kitty terminal configuration — symlinked to `~/.config/kitty/kitty.conf` by `make kitty`. The config side is fully isolated from `make all`: it is only linked by an explicit `make kitty` run, never a dependency of `all`. The binary side is not as isolated — `make all` runs `make source` (`scripts/install_from_source.sh`), and that script does reach the interactive Kitty prompt; it is consent-gated (nothing installs on an empty answer or `n`), but `make all` genuinely reaches it. Konsole remains Kubuntu's installed default; Dolphin's embedded terminal panel (F4) is a KonsolePart and is not replaceable by Kitty, and switching the system-wide default terminal is a manual step in Systemsettings, never done by this repo's scripts.

**`config/kitty/kitty.conf`:**
- **Font:** `JetBrainsMono Nerd Font Mono` at `font_size 10.0` (down from the 12.0 this repo set initially, settled by testing live; kitty's own default is 11.0), the fontconfig family produced by `make fonts` (`scripts/install_fonts.sh`) — depends on that target having run first, or Kitty falls back to a different font and Nerd Font glyphs may render as tofu/squares
- **`symbol_map`:** explicitly maps Nerd Font Private Use Area glyph ranges (through `U+e0d7`, matching Nerd Fonts v3.x's Powerline extra-symbols block) to that same font family instead of relying on fontconfig's fallback resolution — the fallback path is what caused square glyphs in Konsole; forcing the mapping makes glyph resolution deterministic
- **Security:** `clipboard_control` explicitly drops kitty's default unconfirmed clipboard-write permission (verified against kitty's own docs) — only confirmed reads remain, and only for OSC 52 escapes from a program running inside the terminal, never for the user's own copy/paste shortcuts; `update_check_interval 0` disables kitty's own phone-home update check (this repo's installer owns the binary version); `allow_hyperlinks` is declared explicit at its default (`yes`) instead of left implicit
- **Theme:** Japanesque, taken from kitty's own theme catalogue with `kitten themes --dump-theme Japanesque` — reproducible, so the hexes are verifiable rather than transcribed by hand. This block is the repo's single source of truth for the palette: `FZF_DEFAULT_OPTS` (`shell/exports.sh`, FZF section) derives from it and not the other way round, so the terminal and fzf share one scheme — changing theme means editing both places. The five values the theme does not define but this file needs (`url_color`, the three border colors, `cursor_text_color`) are derived from Japanesque itself rather than borrowed from another scheme, and the tab-bar colors come from the theme's own `START_AUTOGENERATED_TAB_STYLE` block (kept in the theme section, not the tabs section, so every hex in the file lives in one place). Worth knowing when reading the block: several of Japanesque's "bright" slots (`color10`-`color13`, `color15`) are *darker* than their base — that is the upstream theme, not a transcription slip. fzf departs from the role-for-role mapping in three documented spots, all for contrast against its teal `bg+`: `hl+` takes the light cyan, `pointer` takes the theme's amber cursor color, and `fg+` stays light where kitty's own selection is deliberately dark
- **Window:** `window_padding_width 6` — the unit is **pts, not pixels** (kitty scales it with the display's DPI, so the same value looks the same on a HiDPI laptop panel and an external monitor); the value was picked by testing live with throwaway instances (`kitty -o window_padding_width=N`) rather than by editing the repo, since kitty's own default of `0` leaves text flush against the border. `background_opacity 0.94` for a deliberately subtle translucency, carrying three costs the in-file comment spells out so the choice stays conscious: any value below `1.0` is a "possibly significant" performance hit by kitty's own documentation; it applies only to cells whose background IS the terminal's default background, so a themed editor or a powerline segment still renders opaque (intentional — it keeps status bars legible); and **changing it and reloading the config does nothing unless `dynamic_background_opacity` was already enabled when that kitty instance started**. That option is deliberately left undeclared (its default is `no`, precisely because it costs performance), so an opacity edit is only visible in instances started afterwards — `ctrl+shift+f5` will not show it. `hide_window_decorations` is undeclared on purpose too: running without KDE's titlebar was tested live and rejected, because without it the window can only be moved with `Meta`+drag
- Generous scrollback, audio bell disabled; tab/split keybindings declared explicitly (window navigation on `ctrl+shift+up`/`down` rather than `ctrl+shift+[`/`]`, which need AltGr on a Spanish keyboard; explicit `ctrl+shift+d`/`ctrl+shift+s` bindings for vertical/horizontal splits, since `enabled_layouts splits` alone gives no way to pick the axis); `confirm_os_window_close` set to avoid accidentally closing a window that has multiple tabs/panels open. Known benign startup warning: kitty prints `ignoreboth or ignorespace present in bash HISTCONTROL setting, showing running command will not be robust` because of `HISTCONTROL=ignoreboth:erasedups` in `shell/options.sh` — it degrades only kitty's ability to put the running command in the tab title, nothing else

### git/.gitconfig

Purpose: Global git configuration — symlinked to `~/.gitconfig`

**Key settings:**
- `pull.rebase = true`, `push.autoSetupRemote = true`, `fetch.prune = true`
- `rerere.enabled = true` for automatic conflict resolution memory
- `merge.conflictstyle = diff3`
- `core.excludesfile = ~/.gitignore` — the target for `git/gitignore.global` below
- Useful aliases: `lg`, `amend`, `undo`, `wip`, `st`, `last`
- Placeholder user name/email — must be changed after install

### git/gitignore.global

Purpose: Global gitignore, symlinked to `~/.gitignore` — the `core.excludesfile` target `git/.gitconfig` declares but that isn't itself versioned. Without it, a fresh machine silently ignores nothing via that setting, and directories like `.claude/` or `.ai-team/` show up as untracked in every repo.

**Contents (6 patterns):** `.claude/`, `.vscode/`, `memorias-ivan/`, `.agents/`, `skills-lock.json`, `.ai-team/`

### scripts/install_packages.sh

Purpose: Install system packages, Docker, and Starship

**apt packages:** build-essential, curl, wget, git, jq, jc, gron, htop, unzip, zip, ripgrep, bat, eza, fd-find, zoxide, tldr, fontconfig

`fontconfig` is required so `fc-cache` exists before `make all` reaches the `fonts` target (`Makefile`'s second prerequisite, right after `packages`) — `install_fonts.sh` aborts if `fc-cache` is missing, which would otherwise break the whole bootstrap on a minimal base before `source`, `claude`, `git`, `starship` and `shell` ever run.

**bat → batcat symlink:** Ubuntu's `bat` apt package installs its binary as `batcat` (name collision with `bacula-console`). After installing packages, the script symlinks `~/.local/bin/bat` → `/usr/bin/batcat` — idempotent (`ln -sf`) and skipped if `bat` already resolves in the `PATH` (never overwrites a real `bat` binary). The success message does not claim `bat` already works: on a fresh install `~/.local/bin` may not be on the `PATH` yet, so it also tells the user to open a new shell session (see `shell/exports.sh`).

**fd → fdfind symlink:** same name-collision pattern as `bat`/`batcat` — Ubuntu's `fd-find` apt package installs its binary as `fdfind`. Immediately after the `bat` block, the script symlinks `~/.local/bin/fd` → `/usr/bin/fdfind` with the identical shape: idempotent (`ln -sf`), skipped if `fd` already resolves in the `PATH` (never overwrites a real `fd` binary), same `PATH`-not-yet-updated warning.

**`jc`/`gron` (no symlink block):** both come from apt, both in Ubuntu's `universe` repository. Unlike `bat` and `fd-find` above, neither Ubuntu package renames its binary — `jc`'s package installs `/usr/bin/jc` and `gron`'s installs `/usr/bin/gron`, so both resolve under their own name with no shim required. apt is the install path deliberately, not `pip install jc` as some `jc` write-ups suggest: Ubuntu 24.04 ships Python as an externally-managed environment (PEP 668), so an unqualified `pip install` at the system level is refused there. One cross-file consequence worth knowing: `shell/exports.sh` exports `LC_ALL=es_ES.UTF-8` when that locale exists, and `jc`'s parsers key off the command's English column headers — so `jc` invocations on this machine need an `LC_ALL=C` prefix. The failure is silent for localized coreutils output (`df -h | jc --df` returns Spanish keys like `tamaño`/`uso%` rather than erroring), which is why `claude/CLAUDE.md` documents the prefix as mandatory rather than optional.

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

### scripts/install_shell.sh

Purpose: Install the single `source shell/index.sh` line into the user's `~/.bashrc`, replacing whatever ad hoc sourcing was there before

**Flow:**
1. Read the target rc file (`$DOTFILES_RC`, default `~/.bashrc`) — created empty if it doesn't exist yet (new machine); remembers this so it never backs up a file it just created itself
2. **Pre-scan marker balance BEFORE touching anything:** walks the file counting `# >>> dotfiles >>>` / `# <<< dotfiles <<<` as a depth (0 or 1, never nested); if a start marker is missing its end (truncated rc, half-finished manual edit, interrupted previous run) the file is NOT touched at all — the script aborts with a non-zero exit and a `$RED` error naming the offending line number. An unterminated marker is never treated as "the block legitimately extends to EOF": that ambiguity used to delete everything after it silently while still reporting success
3. Scrub legacy sourcing found anywhere in the file, outside the delimited block — anchored to THIS repo's own resolved path (`$DOTFILES_DIR`), plus its `$HOME/...` and `~/...` literal-text forms, never to any project whose path merely happens to end in `shell/{exports,aliases,functions,prompt}.sh`: standalone `source`/`.` lines (with an optional trailing `# comment`), the same paths wrapped in a 3-line `if [ -f ... ]; then source ...; fi` guard, and the one-line `[ -f X ] && source X` form — plus any previously-installed delimited block itself, so it can be rewritten fresh. A `#` comment immediately preceding a removed construct is also dropped when it would otherwise become an orphan (the line right after the construct is blank or EOF) — a single line in that case, never the whole contiguous comment block, so a section header sitting above it is not dragged along. It is ALSO dropped, and then as the whole contiguous block, when code survives right below instead AND the comment block carries positive textual evidence that it introduced what was removed: it must both name (in Spanish or English) the `shell/{exports,aliases,functions,prompt}.sh` file the construct sourced — case-insensitive stem `alias`/`export`/`func`/`prompt` — and contain a loading verb (`cargar`/`carga`/`load`/`source`). Both conditions are required because the stem alone produced a reproduced false positive: "# Exports y variables de entorno de esta maquina" above a removed `exports.sh` line describes the surviving `export EDITOR=...` below it, not the removed block, and it names no loading verb. Every comment the scrub retires is printed by name in the installer's output — the removal is never silent. Left alone otherwise, since a comment with no such textual link could just as well be describing the surviving code (e.g. "# Configura el PATH del usuario" directly above a surviving `export PATH=...` stays even after an unrelated block above it is removed)
4. Collapse consecutive blank lines, but ONLY in the gaps a removal in this run just opened — a run of blank lines with zero legacy content anywhere near it is never touched, so re-running never rewrites the user's own spacing choices elsewhere in the file
5. Compute the desired final content (a separator blank line is added before the fresh block only if the kept content doesn't already end in one) and compare it to the current file; if they already match, skip entirely (no backup, no write) — mirrors the skip-if-already-linked pattern the `Makefile`'s `git`/`starship` targets use
6. Otherwise: resolve the real write target via `readlink -f` (so a symlinked rc is preserved as a symlink — only its target's content changes) and capture its current permission mode; timestamped backup of the current rc file (skipped entirely if the rc was created fresh by this same run — step 1); prune `<rc>.bak.*` backups older than 30 days (a deliberately generous window — this backup is the only recovery path from a destructive scrub); write the desired content to a temp file in the same directory, `chmod` it to the captured mode, then `mv -f` onto the resolved target — never a direct `>` redirect, so an interrupted write can't leave a partially-truncated rc:
   ```
   # >>> dotfiles >>>
   [ -f "<abs-path-to-repo>/shell/index.sh" ] && source "<abs-path-to-repo>/shell/index.sh"
   # <<< dotfiles <<<
   ```
7. If the rc contains a line matching "MUST BE AT THE END" (e.g. SDKMAN's own init comment), print a `$YELLOW` warning that the new block landed below it and may need reordering — the script never reorders the file itself, only warns

**Key characteristics:**
- `DOTFILES_RC` env override makes the script testable without touching the real `~/.bashrc` (default `~/.bashrc`)
- Idempotent: running it twice leaves the rc file byte-for-byte identical, with exactly one delimited block
- Reports the number of legacy lines removed on success, instead of rewriting silently
- Same patterns as the other install scripts: `set -e`, colors, emojis, timestamped backup before any destructive write

### Makefile

Purpose: Orchestrate all installation targets

**Targets:**
- `all` — Run everything: packages, fonts, source, claude, git, starship, shell, local
- `packages` — Run `install_packages.sh`
- `fonts` — Run `install_fonts.sh` (JetBrains Mono Nerd Font)
- `source` — Run `install_from_source.sh`
- `claude` — Run `install_claude.sh`
- `recovery` — Run `install_system_recovery.sh` (OOM protection; not in `all`)
- `git` — Symlink `.gitconfig` and `gitignore.global` (→ `~/.gitignore`) with backup
- `starship` — Symlink `starship.toml` with backup
- `shell` — Run `install_shell.sh` (single `shell/index.sh` source line in `~/.bashrc`)
- `kitty` — Symlink `config/kitty/kitty.conf` with backup (opt-in; not a dependency of `all` — install the binary first via `make source`)
- `local` — Copy `shell/dotfiles.local.example` to `~/.dotfiles.local` (override: `DOTFILES_LOCAL`) at mode `600`, only if nothing is there yet — never overwrites; aborts with a `❌` error and a non-zero exit if the copy or the `chmod` fails, instead of reporting success regardless; see "Machine-local config" above
- `help` — List targets with descriptions

**Key characteristics:**
- Symlink targets (git, starship, kitty) and `local` use inline logic matching `install_claude.sh` patterns — `local` is a plain copy-if-absent, not a symlink, since `~/.dotfiles.local` is meant to be edited on that machine, not kept in lockstep with the repo; unlike a plain copy, it also checks that its own `cp`/`chmod` succeeded before printing success, since a failure here (e.g. `DOTFILES_LOCAL` pointing at an unwritable path) must not report `✅` and exit `0`
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
