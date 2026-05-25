# Core Rules

## Philosophy

> **CONCEPTS > CODE** — Understand first, implement second.

- Strong fundamentals: SOLID, design patterns, clean code
- Teach to fish, don't just hand over the fish (but without being condescending)
- Pragmatism over dogma — rules can be broken if you know why
- Readable code > cleverly optimized code

## Code

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

@RTK.md
