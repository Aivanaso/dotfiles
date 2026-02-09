---
name: tailwind
description: "Skill para Tailwind CSS 4. Se activa al trabajar con estilos, clases de utilidad, diseño responsive, temas y componentes UI."
---

# Tailwind CSS 4 — Guía de Desarrollo

## Tailwind CSS 4 — Cambios Clave

- Motor nuevo basado en Rust (Lightning CSS)
- Configuración con CSS en lugar de `tailwind.config.js`
- Detección automática de contenido — no necesita `content` array
- Nuevas utilidades y variantes nativas

### Configuración vía CSS
```css
@import "tailwindcss";

@theme {
  --color-primary: #3b82f6;
  --color-secondary: #8b5cf6;
  --font-sans: "Inter", sans-serif;
  --breakpoint-xs: 30rem;
}
```

## Uso de cn() — Clases Condicionales

Siempre usar `cn()` (wrapper de `clsx` + `tailwind-merge`) para clases condicionales:

```typescript
import { clsx, type ClassValue } from 'clsx';
import { twMerge } from 'tailwind-merge';

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}
```

```tsx
<button
  className={cn(
    'rounded-lg px-4 py-2 font-medium transition-colors',
    variant === 'primary' && 'bg-primary text-white hover:bg-primary/90',
    variant === 'secondary' && 'bg-secondary text-white hover:bg-secondary/90',
    variant === 'outline' && 'border border-gray-300 hover:bg-gray-50',
    disabled && 'cursor-not-allowed opacity-50',
    className,
  )}
>
  {children}
</button>
```

## Clases Semánticas — Componentes Reutilizables

No repetir cadenas largas de clases — extraer a componentes:

```tsx
// MAL — clases repetidas por todo el código
<button className="rounded-lg bg-blue-500 px-4 py-2 text-white hover:bg-blue-600">
<button className="rounded-lg bg-blue-500 px-4 py-2 text-white hover:bg-blue-600">

// BIEN — componente reutilizable
function Button({ variant = 'primary', children, className, ...props }) {
  return (
    <button className={cn(buttonVariants({ variant }), className)} {...props}>
      {children}
    </button>
  );
}
```

## Variables CSS para Temas

```css
@theme {
  /* Colores del tema */
  --color-background: #ffffff;
  --color-foreground: #0a0a0a;
  --color-card: #ffffff;
  --color-card-foreground: #0a0a0a;
  --color-primary: #171717;
  --color-primary-foreground: #fafafa;
  --color-muted: #f5f5f5;
  --color-muted-foreground: #737373;
  --color-border: #e5e5e5;

  /* Radios */
  --radius-sm: 0.25rem;
  --radius-md: 0.375rem;
  --radius-lg: 0.5rem;

  /* Spacing custom */
  --spacing-header: 4rem;
  --spacing-sidebar: 16rem;
}
```

Uso en clases:
```html
<div class="bg-background text-foreground">
  <header class="h-header bg-card border-b border-border">
```

## Responsive Design

### Mobile-first (por defecto)
```html
<!-- Columnas: 1 en móvil, 2 en tablet, 3 en desktop -->
<div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
```

### Breakpoints
- `sm`: 640px — Móvil grande
- `md`: 768px — Tablet
- `lg`: 1024px — Desktop
- `xl`: 1280px — Desktop grande
- `2xl`: 1536px — Pantalla ancha

### Container queries (Tailwind 4)
```html
<div class="@container">
  <div class="@sm:flex @sm:items-center">
```

## Dark Mode

```html
<!-- Usa la clase dark: para estilos en modo oscuro -->
<div class="bg-white dark:bg-gray-900 text-gray-900 dark:text-gray-100">
```

Configurar con variables CSS:
```css
@theme {
  --color-background: #ffffff;
  --color-foreground: #0a0a0a;
}

@media (prefers-color-scheme: dark) {
  :root {
    --color-background: #0a0a0a;
    --color-foreground: #fafafa;
  }
}
```

## Layout Patterns

### Flexbox
```html
<div class="flex items-center justify-between gap-4">
<nav class="flex flex-col gap-2">
```

### Grid
```html
<div class="grid grid-cols-[250px_1fr] gap-6">
<div class="grid grid-rows-[auto_1fr_auto] min-h-screen">
```

### Spacing
- Usar escala consistente: `gap-2`, `gap-4`, `gap-6`, `gap-8`
- `space-y-*` / `space-x-*` para hijos directos sin flex/grid
- `p-*` y `m-*` con escala coherente

## Animaciones y Transiciones

```html
<!-- Transiciones suaves -->
<button class="transition-colors duration-200 hover:bg-primary/90">

<!-- Animaciones -->
<div class="animate-fade-in">
<div class="animate-spin">
```

## Buenas Prácticas

1. **No estilos inline** — Siempre clases de Tailwind o variables CSS
2. **Componentes > clases repetidas** — Si copias las mismas clases 3+ veces, haz un componente
3. **cn() para condicionales** — Nunca template literals para clases condicionales
4. **Mobile-first** — Diseñar para móvil, ampliar con breakpoints
5. **Variables CSS para el tema** — No hardcodear colores hex en las clases
6. **Orden de clases** — Usar Prettier plugin para Tailwind: `prettier-plugin-tailwindcss`
7. **No `@apply` en exceso** — Solo cuando realmente necesitas extraer a CSS (muy raro)
8. **Accesibilidad** — `sr-only` para texto solo screen readers, `focus-visible:` para focus
