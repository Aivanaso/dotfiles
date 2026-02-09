---
name: react
description: "Skill para React 19. Se activa al trabajar con componentes React, hooks, Server Components, y patrones modernos de React."
---

# React 19 — Guía de Desarrollo

## React 19 — Cambios Clave

### React Compiler
- Ya no necesitas `useMemo`, `useCallback` ni `React.memo` de forma manual
- El compilador optimiza re-renders automáticamente
- Si usas React 19 con el compiler, **elimina** memoización manual innecesaria

### `use()` Hook
```tsx
// Leer promesas y contexto directamente
function UserProfile({ userPromise }: { userPromise: Promise<User> }) {
  const user = use(userPromise);
  return <h1>{user.name}</h1>;
}
```

### `useActionState`
```tsx
function LoginForm() {
  const [state, formAction, isPending] = useActionState(loginAction, null);

  return (
    <form action={formAction}>
      <input name="email" type="email" />
      <button disabled={isPending}>
        {isPending ? 'Entrando...' : 'Entrar'}
      </button>
      {state?.error && <p>{state.error}</p>}
    </form>
  );
}
```

### `useFormStatus`
```tsx
function SubmitButton() {
  const { pending } = useFormStatus();
  return <button disabled={pending}>{pending ? 'Enviando...' : 'Enviar'}</button>;
}
```

### Ref como prop directa
- Ya no hace falta `forwardRef` — ref es una prop normal

```tsx
function Input({ ref, ...props }: { ref?: React.Ref<HTMLInputElement> }) {
  return <input ref={ref} {...props} />;
}
```

## Server Components vs Client Components

### Server Components (por defecto)
- Se ejecutan solo en el servidor
- Pueden hacer `await` directamente, acceder a DB, ficheros, etc.
- No pueden usar hooks ni event handlers
- No necesitan directiva — son el default

### Client Components
- Marcar con `"use client"` en la primera línea
- Para interactividad: hooks, eventos, estado
- Mantener lo más pequeño posible — solo lo que necesita ser client

```tsx
// Server Component — por defecto
async function UserList() {
  const users = await db.users.findMany();
  return <UserTable users={users} />;
}

// Client Component — solo lo interactivo
"use client";
function UserTable({ users }: { users: User[] }) {
  const [sortBy, setSortBy] = useState<keyof User>('name');
  // ...
}
```

### Regla: Empuja "use client" lo más abajo posible en el árbol.

## Hooks Esenciales

### Estado y efectos
- `useState` — Estado local del componente
- `useReducer` — Estado complejo con lógica de transición
- `useEffect` — Sincronización con sistemas externos (NO para fetch de datos)

### Refs y DOM
- `useRef` — Referencias a DOM o valores mutables que no causan re-render
- `useImperativeHandle` — Exponer API custom del componente (raro, solo cuando es necesario)

### Rendimiento (menos relevante con React Compiler)
- `useMemo` — Memoizar cálculos caros (solo si no usas React Compiler)
- `useCallback` — Memoizar funciones (solo si no usas React Compiler)
- `useDeferredValue` — Deprioritizar actualizaciones pesadas
- `useTransition` — Marcar actualizaciones como no urgentes

## Patrones

### Custom Hooks
- Extraer lógica reutilizable de componentes
- Nombre con `use` prefix — siempre
- Un hook, una responsabilidad

```tsx
function useDebounce<T>(value: T, delay: number): T {
  const [debouncedValue, setDebouncedValue] = useState(value);

  useEffect(() => {
    const timer = setTimeout(() => setDebouncedValue(value), delay);
    return () => clearTimeout(timer);
  }, [value, delay]);

  return debouncedValue;
}
```

### Compound Components
```tsx
function Tabs({ children }: { children: React.ReactNode }) {
  const [activeTab, setActiveTab] = useState(0);
  return (
    <TabsContext value={{ activeTab, setActiveTab }}>
      {children}
    </TabsContext>
  );
}

Tabs.List = TabList;
Tabs.Panel = TabPanel;
Tabs.Tab = Tab;
```

### Render Props (para lógica compartida sin hook)
```tsx
function Toggle({ children }: { children: (props: ToggleProps) => React.ReactNode }) {
  const [on, setOn] = useState(false);
  return <>{children({ on, toggle: () => setOn(!on) })}</>;
}
```

## Buenas Prácticas

1. **Componentes pequeños** — Si un componente tiene +150 líneas, probablemente hay que dividirlo
2. **Props tipadas** — Siempre interfaces/types para props, nunca `any`
3. **Keys estables** — Nunca usar `index` como key en listas que cambian
4. **useEffect con cuidado** — No es para fetch de datos (usa Server Components o react-query)
5. **Estado lo más local posible** — Levantar estado solo cuando sea necesario
6. **Composición sobre configuración** — `children` y slots sobre props booleanas
7. **Error boundaries** — Para capturar errores de render sin romper toda la app
8. **Suspense** — Para estados de carga con fallback
