---
name: spec
description: "Skill para Spec-Driven Development. Se activa al completar features, añadir módulos, cambiar contratos de API o tomar decisiones arquitectónicas."
---

# Spec — Guía de Documentación Técnica

## Cuándo Actúa Este Skill

Este skill se invoca con `/spec` o automáticamente según los criterios del CLAUDE.md principal.
También sirve como referencia manual cuando quieres revisar o crear specs sin haber completado una tarea.

---

## Estructura de Directorios

Si no existe, **auto-inicializar** sin preguntar al usuario:

```
proyecto/
├── MEMORY.md              ← Contexto del proyecto (raíz)
└── docs/
    └── specs/
        ├── auth.md        ← Un fichero por módulo/dominio
        ├── users.md
        └── payments.md
```

**Regla de nombrado:** `kebab-case`, plural si el módulo es una colección (`users.md`), singular si es
un proceso o sistema (`auth.md`, `checkout.md`).

---

## Flujo de Ejecución

### 1. Detectar si ya existe spec para el módulo

```
docs/specs/<nombre-modulo>.md
```

- **Existe** → actualizar las secciones afectadas por la tarea recién completada
- **No existe** → crear desde template

### 2. Actualizar MEMORY.md

- Si es un módulo nuevo: añadirlo al índice de specs
- Si hay decisiones project-wide: registrarlas en `Active Decisions`
- Actualizar fecha

### 3. Confirmar al usuario

Decir brevemente qué se ha creado/actualizado. Sin preguntar si debe hacerlo — ya está decidido.

---

## Template: Spec de Módulo

```markdown
---
module: auth
project: my-api-service
repo: git@github.com:org/my-api
last_updated: YYYY-MM-DD
status: stable
depends_on:
  - users
  - config
tags:
  - security
  - jwt
  - api
---

## Purpose

[1-2 frases: responsabilidad del módulo, no implementación]

## Decisions

- **[Decisión]**: [Rationale — qué alternativas se descartaron y por qué]

## Structure

| Fichero / Clase | Responsabilidad |
|---|---|
| `src/auth/auth.service.ts` | Lógica de tokens y validación |
| `src/auth/auth.guard.ts` | Guard de rutas protegidas |

## Contracts

### [Método] [/ruta o nombre del evento]

- **Input**: `{ campo: tipo, ... }`
- **Output**: `{ campo: tipo, ... }`
- **Rules**: [Validaciones, precondiciones, rate limits, errores]

## Open Questions

- [ ] [Algo pendiente de resolver]
```

**Campos del frontmatter:**

| Campo | Propósito Phase 1 | Propósito Phase 2 (SQLite) |
|---|---|---|
| `module` | Identificador único | PRIMARY KEY o índice |
| `project` | Identificar repo de origen | Filtro cross-project |
| `repo` | Enlace al source | Relación a tabla `projects` |
| `last_updated` | Referencia humana | ORDER BY y cache invalidation |
| `status` | Saber si el spec es fiable (`draft` / `stable` / `deprecated`) | Filtro en queries |
| `depends_on` | Documentar dependencias entre BCs | Grafo de relaciones |
| `tags` | Categorización manual | Full-text search + filtros |

---

## Template: MEMORY.md

```markdown
---
project: my-api-service
repo: git@github.com:org/my-api
stack:
  backend: nestjs
  frontend: react
  db: postgresql
  infra: docker
last_updated: YYYY-MM-DD
---

## Architecture

[1-2 párrafos: enfoque arquitectónico, capas, comunicación entre módulos]

## Specs Index

- [auth](docs/specs/auth.md) — Autenticación y autorización
- [users](docs/specs/users.md) — Gestión de usuarios

## Active Decisions

- **[Decisión project-wide]**: [Rationale — por qué aplica a todo el proyecto]

## Conventions

- [Convención de nombrado, estructura de ficheros o patrón específico del proyecto]
```

---

## Reglas de Actualización

### Qué actualizar en un spec existente

| Cambio en el código | Sección a actualizar |
|---|---|
| Nuevo endpoint / evento | `Contracts` |
| Nueva clase o fichero relevante | `Structure` |
| Decisión de patrón o librería | `Decisions` |
| Cambio de responsabilidad | `Purpose` + `Structure` |
| Pregunta resuelta | Borrar de `Open Questions` |
| Cambio de estado del módulo | `status` en frontmatter |

### Qué NO tocar sin motivo

- No reformatear specs que no has modificado
- No añadir secciones vacías — si no hay nada que decir, omitir la sección
- No reescribir decisiones existentes salvo que la decisión haya cambiado

---

## Buenas Prácticas

- **Propósito ≠ implementación** — El propósito describe responsabilidad, no código
- **Decisiones con contexto** — "Usamos JWT" no vale. "Usamos JWT porque el cliente es stateless y necesitamos escalar horizontalmente sin sesiones compartidas" sí vale
- **Contratos precisos** — Los tipos importan. `{ id: string (UUID) }` es mejor que `{ id: string }`
- **Specs pequeños** — Si un spec supera ~100 líneas, probablemente el módulo hace demasiado
- **Sync con el código** — Un spec desactualizado es peor que no tener spec. Si cambias código, actualiza el spec en el mismo paso
