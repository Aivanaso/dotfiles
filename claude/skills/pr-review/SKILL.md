---
name: pr-review
description: "Skill para revisión de Pull Requests. Se activa al revisar código, hacer code review o analizar cambios en PRs."
---

# Revisión de Pull Requests — Guía

## Categorías de Comentarios

Usar prefijos claros para que el autor sepa la severidad:

- **CRÍTICO** — Bloquea la aprobación. Bug, vulnerabilidad de seguridad, pérdida de datos, rompe funcionalidad existente
- **REVISAR** — No bloquea pero debería cambiarse. Code smell, rendimiento pobre, falta de tests para caso importante
- **PREGUNTA** — Necesita aclaración. No entiendes la decisión o crees que puede haber una razón que desconoces
- **SUGERENCIA** — Mejora opcional. Alternativa más limpia, refactor menor, naming más claro

## Formato de Comentarios

```
**CRÍTICO**: [Descripción del problema]

[Explicación de por qué es un problema — con evidencia si es posible]

Sugerencia:
```código con la alternativa```
```

## Qué Revisar (por prioridad)

### 1. Correctitud
- ¿Hace lo que dice que hace?
- ¿Maneja edge cases?
- ¿Hay race conditions o problemas de concurrencia?
- ¿Rompe funcionalidad existente?

### 2. Seguridad
- ¿Hay inyección SQL, XSS, CSRF u otras vulnerabilidades OWASP?
- ¿Se valida y sanitiza el input del usuario?
- ¿Se exponen datos sensibles en logs o respuestas?
- ¿Los permisos y autorizaciones son correctos?

### 3. Rendimiento
- ¿Hay queries N+1?
- ¿Se trabaja con conjuntos de datos grandes sin paginación?
- ¿Hay operaciones costosas en loops?
- ¿Falta caché donde haría falta?

### 4. Mantenibilidad
- ¿Es legible sin conocer el contexto?
- ¿Los nombres son descriptivos?
- ¿Hay duplicación que debería abstraerse?
- ¿Los tests cubren el comportamiento nuevo?

### 5. Arquitectura
- ¿Respeta los patterns del proyecto?
- ¿La responsabilidad está en el lugar correcto?
- ¿Se puede extender fácilmente?

## Tono

- **Sé colega, no robot** — "Mira, aquí podrías..." en vez de "This violates principle X"
- **Explica el porqué** — No basta con decir "cambia esto", explica por qué importa
- **Reconoce lo bueno** — Si algo está bien hecho, dilo. Un "buen curro aquí" motiva
- **Pregunta antes de asumir** — "¿Hay alguna razón para hacerlo así?" antes de decir que está mal
- **Contexto > dogma** — A veces la solución "impura" es la correcta por contexto

## NO Bloquear Por...

- **Estilo** si hay linter/formatter configurado — eso es trabajo de la herramienta
- **Preferencia personal** sin impacto técnico — "yo lo habría hecho así" no es motivo de bloqueo
- **Perfección** — Bueno y enviado > perfecto y atascado
- **Cosas fuera del scope del PR** — Si ves tech debt vieja, abre un issue, no bloquees este PR

## Antes de Aprobar

1. ¿El código compila/pasa el build?
2. ¿Los tests nuevos pasan?
3. ¿Los tests existentes siguen pasando?
4. ¿La descripción del PR explica el cambio?
5. ¿Has probado localmente (si el cambio lo requiere)?

## Plantilla de Review

```markdown
## Resumen

[1-2 frases sobre la impresión general]

## Comentarios

### CRÍTICO
- [ ] [Descripción + explicación]

### REVISAR
- [ ] [Descripción + explicación]

### SUGERENCIAS
- [Descripción]

## Veredicto

✅ Aprobado / ⚠️ Aprobado con comentarios / ❌ Cambios necesarios
```
