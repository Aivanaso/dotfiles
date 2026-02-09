---
name: skill-creator
description: "Meta-skill para crear nuevos skills de Claude Code. Se activa cuando el usuario quiere definir un nuevo skill o modificar la estructura de skills existentes."
---

# Skill Creator — Guía para Crear Nuevos Skills

## Cuándo Crear un Skill Nuevo

Crea un skill cuando:
- Trabajas frecuentemente con una tecnología/framework específico
- Necesitas reglas y convenciones consistentes para un dominio
- Quieres que Claude Code se comporte de forma especializada en cierto contexto
- Las instrucciones genéricas no son suficientes para el tema

**No** crees un skill cuando:
- Es algo que usas una vez y ya
- Las instrucciones caben en un comentario del código
- Ya existe un skill que cubre el tema (amplía el existente)

## Estructura de Directorio

```
claude/skills/
└── nombre-del-skill/
    └── SKILL.md
```

### Convenciones de Nombrado
- Directorio en **kebab-case**: `mi-nuevo-skill/`
- Fichero siempre `SKILL.md` (mayúsculas)
- Nombres descriptivos: `nestjs`, `react`, `pr-review`, `docker-compose`
- Evitar nombres genéricos: `utils`, `misc`, `other`

## Frontmatter Requerido

Todo SKILL.md debe empezar con frontmatter YAML:

```yaml
---
name: nombre-del-skill
description: "Descripción clara de qué hace el skill y cuándo se activa. Esta descripción ayuda a Claude Code a saber cuándo aplicar las reglas."
---
```

### Reglas del frontmatter
- `name`: debe coincidir con el nombre del directorio
- `description`: una frase que explique el **qué** y el **cuándo**

## Estructura del Contenido

```markdown
---
name: mi-skill
description: "..."
---

# Título del Skill — Guía de Desarrollo

## Sección 1: Lo más importante primero
[Reglas fundamentales, configuración base]

## Sección 2: Patterns y ejemplos
[Código de ejemplo, cómo se hace X]

## Sección 3: Buenas prácticas
[Lista de DOs y DON'Ts]
```

### Principios de contenido
1. **Concreto > abstracto** — Ejemplos de código > descripciones vagas
2. **Conciso** — No repetir lo que está en la documentación oficial
3. **Opinado** — Toma partido, no listes todas las opciones sin recomendar
4. **Contextual** — Adaptar al stack y preferencias del proyecto
5. **Actualizado** — Versiones actuales del framework/herramienta

## Registrar en el Instalador

Tras crear el skill, actualizar `scripts/install_claude.sh`:

1. Añadir el mapeo de globs para Cursor (si aplica):

```bash
# En la función generate_cursor_rules del instalador
"mi-skill")
    globs='["**/*.ext"]'
    always_apply="false"
    ;;
```

2. Ejecutar el instalador para que genere los symlinks y .mdc:

```bash
bash scripts/install_claude.sh
```

## Checklist de un Buen Skill

- [ ] Frontmatter con `name` y `description`
- [ ] Título claro con `# Nombre — Guía de Desarrollo`
- [ ] Al menos una sección con ejemplos de código
- [ ] Buenas prácticas como lista concreta
- [ ] Sin repetir contenido de otros skills
- [ ] Probado: Claude Code lo aplica correctamente en contexto
