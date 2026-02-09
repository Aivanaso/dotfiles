---
name: php-8
description: "Skill para PHP 8.x moderno. Se activa al trabajar con código PHP que usa features de PHP 8.0 a 8.4: enums, fibers, readonly, match, union types, attributes."
---

# PHP 8.x Moderno — Guía de Desarrollo

## Regla Base

```php
declare(strict_types=1);
```

Siempre. En todos los ficheros. Sin excepciones.

## PHP 8.0 — Features Clave

### Union Types
```php
function process(int|string $value): string|false
{
    // ...
}
```

### Named Arguments
```php
$user = new User(
    name: 'Iván',
    email: 'ivan@example.com',
    active: true,
);
```

### Match Expression
- Usar `match` en lugar de `switch` — es una expresión, no una sentencia
- Comparación estricta (`===`) por defecto
- Lanza `UnhandledMatchError` si no hay match

```php
$status = match ($code) {
    200 => 'OK',
    404 => 'Not Found',
    500 => 'Server Error',
    default => 'Unknown',
};
```

### Constructor Promotion
```php
class Product
{
    public function __construct(
        private readonly string $name,
        private readonly float $price,
        private readonly ?string $description = null,
    ) {}
}
```

### Nullsafe Operator
```php
$country = $user?->getAddress()?->getCountry()?->getName();
```

### Attributes
- Reemplazan annotations de docblock
- Tipadas y autocompletables

```php
#[Route('/api/users', methods: ['GET'])]
#[IsGranted('ROLE_ADMIN')]
public function index(): JsonResponse {}
```

## PHP 8.1

### Enums
- Usar enums en lugar de constantes para valores finitos
- Backed enums (`string` o `int`) para persistencia

```php
enum Status: string
{
    case Active = 'active';
    case Inactive = 'inactive';
    case Pending = 'pending';

    public function label(): string
    {
        return match ($this) {
            self::Active => 'Activo',
            self::Inactive => 'Inactivo',
            self::Pending => 'Pendiente',
        };
    }
}
```

### Readonly Properties
```php
class User
{
    public function __construct(
        public readonly string $name,
        public readonly string $email,
    ) {}
}
```

### Fibers
- Para concurrencia cooperativa
- Base de bibliotecas async (ReactPHP, Amp)
- No usar directamente salvo que sepas lo que haces

### Intersection Types
```php
function process(Countable&Iterator $collection): void {}
```

### First-class Callables
```php
$fn = strlen(...);
$mapped = array_map(strtoupper(...), $names);
```

## PHP 8.2

### Readonly Classes
```php
readonly class Point
{
    public function __construct(
        public float $x,
        public float $y,
    ) {}
}
```

### DNF Types (Disjunctive Normal Form)
```php
function handle((Countable&Iterator)|null $items): void {}
```

### Constants in Traits
```php
trait HasVersion
{
    public const VERSION = '1.0';
}
```

### `true`, `false`, `null` como tipos standalone
```php
function alwaysFails(): false
{
    return false;
}
```

## PHP 8.3

### Typed Class Constants
```php
class Config
{
    public const string APP_NAME = 'Mi App';
    public const int MAX_RETRIES = 3;
}
```

### `#[\Override]` Attribute
- Usar siempre al sobreescribir métodos — el compilador verifica que el padre tiene el método

```php
class AdminUser extends User
{
    #[\Override]
    public function getRole(): string
    {
        return 'admin';
    }
}
```

### `json_validate()`
```php
if (json_validate($input)) {
    $data = json_decode($input, true);
}
```

## PHP 8.4

### Property Hooks
```php
class User
{
    public string $fullName {
        get => $this->firstName . ' ' . $this->lastName;
    }
}
```

### Asymmetric Visibility
```php
class User
{
    public function __construct(
        public private(set) string $name,
    ) {}
}
```

## Buenas Prácticas Generales

- **Tipado estricto siempre** — `strict_types=1` + return types + property types
- **Composición sobre herencia** — Interfaces + traits cuando sea necesario
- **Inmutabilidad** — `readonly` por defecto, mutabilidad solo cuando sea necesario
- **Null safety** — Evitar null cuando sea posible, usar `?Type` solo si null tiene significado
- **Enums sobre constantes** — Para cualquier conjunto finito de valores
- **Named arguments** — Para mejorar legibilidad en constructores y funciones con muchos parámetros
- **Match sobre switch** — Siempre, salvo que necesites efectos secundarios por case
- **Attributes sobre docblocks** — Para metadatos que el runtime necesita
