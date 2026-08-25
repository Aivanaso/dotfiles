# Core Rules

## Communication

Target reader: a competent engineer who does not know *this* domain. Neither a beginner
nor a specialist in it.

- Name a technical term once, then define it in plain words in the same sentence
- At most one unexplained term per paragraph
- Lead with the observable effect ("what this changes for you"), then the mechanism — and
  only if asked for it
- At most one analogy per response, only for structure that can't be seen. Never chain them
- Teach to fish rather than hand over the fish — without being condescending
- These rules govern word choice. Length and format are the active output style's business

## Code

> **CONCEPTS > CODE** — understand first, implement second.

Strong fundamentals (SOLID, design patterns, clean code), pragmatism over dogma — a rule can
be broken if you know why — and readable code over cleverly optimized code.

1. **Composition over inheritance** — whenever possible
2. **Strict typing** — `strict: true` in TypeScript, `declare(strict_types=1)` in PHP
3. **Tests as living documentation** — a good test explains what the code does
4. **Semantic commits** — Conventional Commits: `feat:`, `fix:`, `refactor:`, `docs:`, `test:`, `chore:`
5. **No dead code** — no unused functions, no abandoned TODOs, no commented-out blocks
6. **Descriptive names** — variables, functions, and classes with names that explain their purpose
7. **Small functions** — one function, one responsibility
8. **Explicit errors** — never swallow exceptions silently

## Git

- Do not attribute code to AI in commit messages. NEVER add "Co-Authored-By"
- Atomic commits: one commit, one logical change
- Descriptive branches: `feat/user-auth`, `fix/login-redirect`, `refactor/api-client`

## Tools on this machine

Installed by this dotfiles repo. Listed only where they beat the default tool.

**Search ladder** — the same three steps for content (`rg`) and for filenames (`fd`):

1. `rg <pattern>` / `fd <fragment>` — fast, and `fd` matches any fragment of the name
   without needing `find -exec`
2. Zero results inside a repo? Retry with `rg -uu` / `fd -u`. Both skip hidden files **and**
   anything the gitignore covers, and the global gitignore here hides `.claude/`,
   `.ai-team/`, `.agents/`, `docs/` and `memorias-ivan/` — the agent working directories
3. Binary missing? Only then fall back to `grep -r` / `find`. On Ubuntu `fd` may be
   installed under the name `fdfind`

Never fall back to `find`/`grep` because a search came back empty. That hides the ignore
filter instead of lifting it, and an empty result is sometimes the true answer. Fall back
only when the binary isn't there.

`jq` for reading and transforming JSON when you already know the document's shape.

`gron` for when you don't: it flattens JSON into one assignment line per value
(`json.a.b[0] = "x";`), so finding a key in an unfamiliar document becomes an `rg` search
instead of guessing the schema — `gron file.json | rg -i token` returns the exact path to
that value. `gron -u` (or `--ungron`) reverses the flattening back to JSON. This slots into
the search ladder above the same way `rg`/`fd` do.

`jc` converts command output to JSON (`jc --ps`, `jc --df`, `jc --ss`, `jc --systemctl`,
`jc --dig`; `jc -p` pretty-prints). Its value isn't readability — `df -h`/`ps aux`'s own
columns read fine as-is — it's piping that output into `jq` to filter and sort it. Don't
reach for it for a plain read. Two things it will bite you with here:

- **Always prefix `LC_ALL=C`.** `shell/exports.sh` exports `LC_ALL=es_ES.UTF-8` on this
  machine, and jc's parsers key off the command's English column headers. Under the Spanish
  locale `df -h | jc --df` does not fail — it silently returns Spanish keys
  (`{"s.ficheros": ..., "tamaño": ..., "uso%": ...}`, with "montado en" split across two
  keys), so a `select(.use_percent > 80)` matches nothing and looks like an empty result.
  `LC_ALL=C df -h | jc --df` gives `filesystem`/`size`/`use_percent`, numbers as numbers.
- **A wrong flag can break a parser outright.** `ss -tln | jc --ss` dies with
  `KeyError: 'netid'` regardless of locale: filtering to a single protocol makes `ss` drop
  the `Netid` column the parser requires. Add `-u` — `LC_ALL=C ss -tuln | jc --ss | jq '.[]
  | select(.local_port == "5432")'` works. When a parser errors, re-read the raw command
  output before assuming jc is at fault.

Both `jc` and `gron` install from apt and resolve under their own name — no `bat`/`fd`-style
rename to work around.

Don't reach for `bat`, `eza`, `fzf`, `zoxide` or `tldr`: they colorize, paginate or need a
terminal to sit in. They're for the human at the keyboard, not for tool output.
