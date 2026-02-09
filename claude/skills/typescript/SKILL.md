---
name: typescript
description: "Skill para TypeScript estricto. Se activa al trabajar con ficheros .ts/.tsx que usen generics, utility types, type guards, discriminated unions y tipado avanzado."
---

# TypeScript Estricto — Guía de Desarrollo

## Configuración Base

```json
{
  "compilerOptions": {
    "strict": true,
    "noUncheckedIndexedAccess": true,
    "exactOptionalPropertyTypes": true,
    "noImplicitReturns": true,
    "noFallthroughCasesInSwitch": true
  }
}
```

**Regla de oro**: `any` está prohibido. Si necesitas un tipo genérico, usa `unknown` y haz narrowing.

## Utility Types

Dominar estos es obligatorio:

```typescript
// Parcializar
Partial<User>          // Todas las propiedades opcionales
Required<User>         // Todas las propiedades obligatorias

// Seleccionar / Omitir
Pick<User, 'name' | 'email'>    // Solo name y email
Omit<User, 'password'>          // Todo menos password

// Registros y mapeos
Record<string, User>             // Diccionario de usuarios
Record<Status, string>           // Mapeo enum → string

// Otros útiles
Readonly<Config>                 // Inmutable
ReturnType<typeof fn>            // Tipo de retorno de una función
Parameters<typeof fn>            // Tipos de parámetros de una función
Awaited<Promise<User>>           // Desenvuelve Promise → User
NonNullable<string | null>       // Elimina null/undefined
```

## Generics

### Básicos con Constraints
```typescript
function getProperty<T, K extends keyof T>(obj: T, key: K): T[K] {
  return obj[key];
}
```

### Generics en interfaces
```typescript
interface Repository<T extends { id: string }> {
  findById(id: string): Promise<T | null>;
  save(entity: T): Promise<T>;
  delete(id: string): Promise<void>;
}
```

### Inferencia con `infer`
```typescript
type UnwrapPromise<T> = T extends Promise<infer U> ? U : T;
type ArrayItem<T> = T extends Array<infer U> ? U : never;
```

## Conditional Types

```typescript
type IsString<T> = T extends string ? true : false;

type ApiResponse<T> = T extends undefined
  ? { success: boolean }
  : { success: boolean; data: T };
```

## Type Guards y Narrowing

### Type predicates
```typescript
function isUser(value: unknown): value is User {
  return (
    typeof value === 'object' &&
    value !== null &&
    'name' in value &&
    'email' in value
  );
}
```

### Discriminated Unions
```typescript
type Result<T, E = Error> =
  | { success: true; data: T }
  | { success: false; error: E };

function handleResult<T>(result: Result<T>) {
  if (result.success) {
    // TypeScript sabe que result.data existe aquí
    console.log(result.data);
  } else {
    // TypeScript sabe que result.error existe aquí
    console.error(result.error);
  }
}
```

### Exhaustive checking
```typescript
function assertNever(value: never): never {
  throw new Error(`Valor inesperado: ${value}`);
}

function getLabel(status: Status): string {
  switch (status) {
    case 'active': return 'Activo';
    case 'inactive': return 'Inactivo';
    default: return assertNever(status);
  }
}
```

## Const Assertions y Satisfies

### `as const`
```typescript
const ROLES = ['admin', 'user', 'guest'] as const;
type Role = (typeof ROLES)[number]; // 'admin' | 'user' | 'guest'

const CONFIG = {
  apiUrl: 'https://api.example.com',
  timeout: 5000,
} as const;
```

### `satisfies`
```typescript
type ColorMap = Record<string, [number, number, number]>;

const colors = {
  red: [255, 0, 0],
  green: [0, 255, 0],
} satisfies ColorMap;

// colors.red sigue siendo tupla [255, 0, 0], no number[]
```

## Interfaces vs Types

- **Interfaces** para contratos de objetos — extensibles con `extends`
- **Types** para uniones, intersecciones, utility types
- Interfaces planas — evitar herencia profunda (máximo 2 niveles)
- No mezclar sin motivo: elige uno y sé consistente en el proyecto

```typescript
// Interface para objetos
interface User {
  id: string;
  name: string;
  email: string;
}

// Type para uniones y compuestos
type ApiResult = Success | Failure;
type UserId = string & { readonly brand: unique symbol };
```

## Branded Types (Nominal Typing)

```typescript
type UserId = string & { readonly __brand: 'UserId' };
type PostId = string & { readonly __brand: 'PostId' };

function createUserId(id: string): UserId {
  return id as UserId;
}

// Previene mezclar IDs accidentalmente
function getUser(id: UserId): Promise<User> { /* ... */ }
```

## Buenas Prácticas

1. **Nunca `any`** — Usa `unknown` + type guards
2. **Nunca `as` para castear** — Salvo branded types y casos muy justificados
3. **Evitar `!` (non-null assertion)** — Verifica en su lugar
4. **Enums → union types** — `type Status = 'active' | 'inactive'` sobre `enum Status { ... }`
5. **Readonly por defecto** — `readonly` en propiedades, `Readonly<T>` en parámetros
6. **Funciones con return type explícito** — No depender solo de inferencia en funciones exportadas
7. **Evitar herencia profunda** — Composición e interfaces planas
