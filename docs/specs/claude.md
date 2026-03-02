---
module: claude
project: dotfiles
repo: git@github.com:Aivanaso/dotfiles.git
last_updated: 2026-03-02
status: stable
depends_on: []
tags:
  - claude-code
  - cursor
  - ai
  - skills
  - sdd
---

## Purpose

Gestiona la configuración del asistente de IA (Claude Code y Cursor): persona del agente,
permisos de herramientas, estilos de respuesta y skills especializados por tecnología.
Implementa Spec-Driven Development (SDD) como metodología de documentación técnica.

## Decisions

- **Symlinks a `~/.claude/`**: la configuración vive en el repo y se enlaza, no se copia.
  Permite versionar cambios y actualizarlos con `git pull` sin reinstalar.
- **Skills como directorio con `SKILL.md`**: cada skill es autodescriptivo y activable
  independientemente. La alternativa (un único fichero de skills) dificultaría la extensión
  y el mantenimiento por tecnología.
- **YAML frontmatter en specs SDD**: los specs usan frontmatter estructurado (module, project,
  repo, status, depends_on, tags) para ser parseables por scripts/agentes en Phase 2 (SQLite).
  El cuerpo en Markdown sigue siendo legible sin herramientas.
- **Specs en `docs/specs/` siempre centralizados**: descartada la co-localización junto al módulo
  porque en stacks DDD (Symfony) el BC está fragmentado en múltiples capas — no hay un lugar
  obvio donde co-localizar.
- **Cursor generado desde los mismos fuentes**: `install_claude.sh` genera `.mdc` para Cursor
  a partir de `CLAUDE.md` y los skills, manteniendo ambas herramientas sincronizadas.

## Structure

| Fichero / Directorio | Responsabilidad |
|---|---|
| `claude/CLAUDE.md` | Persona del agente: tono, expertise técnico, reglas de comportamiento |
| `claude/settings.json` | Permisos de herramientas: qué puede ejecutar Claude sin confirmación |
| `claude/output-styles/default.md` | Guía de estilo de respuesta: formato, longitud, tono |
| `claude/skills/spec/SKILL.md` | Skill SDD: templates de specs y MEMORY.md, flujo de ejecución |
| `claude/skills/<tech>/SKILL.md` | Skills por tecnología: nestjs, symfony, php-8, react, etc. |

## Open Questions

- [ ] Phase 2: evaluar Engram u otra herramienta Go/SQLite+FTS5 como MCP server para specs
- [ ] Phase 3: definir roles de sub-agentes para orchestration (Explorer, Proposer, Implementer, Verifier)
