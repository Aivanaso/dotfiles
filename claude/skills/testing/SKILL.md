---
name: testing
description: "Skill para testing. Se activa al trabajar con tests unitarios, de integración o E2E usando Jest, Vitest, PHPUnit, Playwright u otros frameworks de testing."
---

# Testing — Guía de Desarrollo

## Filosofía

- **Cada test prueba UNA cosa** — Si el nombre del test tiene "y", probablemente son dos tests
- **AAA (Arrange-Act-Assert)** — Estructura clara en cada test
- **Tests como documentación** — El nombre del test describe el comportamiento esperado
- **Test lo que importa** — Lógica de negocio y edge cases, no getters/setters triviales

## Patrón AAA

```typescript
it('should return discount price for premium users', () => {
  // Arrange
  const user = createUser({ tier: 'premium' });
  const product = createProduct({ price: 100 });

  // Act
  const price = calculatePrice(product, user);

  // Assert
  expect(price).toBe(80);
});
```

## Jest / Vitest

### Configuración recomendada
```typescript
// vitest.config.ts
export default defineConfig({
  test: {
    globals: true,
    environment: 'node', // o 'jsdom' para componentes
    coverage: {
      reporter: ['text', 'lcov'],
      exclude: ['**/*.test.*', '**/*.spec.*', '**/mocks/**'],
    },
  },
});
```

### Mocks y Spies

```typescript
// Mock de módulo
vi.mock('./userService', () => ({
  UserService: {
    findById: vi.fn(),
  },
}));

// Spy en método existente
const spy = vi.spyOn(userService, 'findById');
spy.mockResolvedValue(mockUser);

// Verificar llamada
expect(spy).toHaveBeenCalledWith('user-123');
expect(spy).toHaveBeenCalledTimes(1);

// Restaurar
spy.mockRestore();
```

### Testing async
```typescript
it('should fetch user data', async () => {
  const user = await userService.findById('123');
  expect(user).toEqual(expect.objectContaining({ id: '123' }));
});

it('should throw on invalid id', async () => {
  await expect(userService.findById('')).rejects.toThrow('Invalid ID');
});
```

### Testing Library (React)
```tsx
import { render, screen, fireEvent } from '@testing-library/react';
import userEvent from '@testing-library/user-event';

it('should submit form with valid data', async () => {
  const onSubmit = vi.fn();
  const user = userEvent.setup();

  render(<LoginForm onSubmit={onSubmit} />);

  await user.type(screen.getByLabelText('Email'), 'ivan@example.com');
  await user.type(screen.getByLabelText('Password'), 'secret123');
  await user.click(screen.getByRole('button', { name: /entrar/i }));

  expect(onSubmit).toHaveBeenCalledWith({
    email: 'ivan@example.com',
    password: 'secret123',
  });
});
```

### Matchers útiles
```typescript
expect(value).toBe(exact);              // ===
expect(value).toEqual(deep);            // Deep equality
expect(array).toContain(item);          // Array includes
expect(obj).toMatchObject(partial);     // Partial object match
expect(fn).toThrow(ErrorClass);         // Throws
expect(value).toBeDefined();            // Not undefined
expect(array).toHaveLength(3);          // Array length
```

## PHPUnit

### Estructura de test
```php
class UserServiceTest extends TestCase
{
    private UserService $service;
    private UserRepository&MockObject $repository;

    protected function setUp(): void
    {
        $this->repository = $this->createMock(UserRepository::class);
        $this->service = new UserService($this->repository);
    }

    public function testCreateUserWithValidData(): void
    {
        // Arrange
        $dto = new CreateUserDto('Iván', 'ivan@example.com');
        $this->repository
            ->expects($this->once())
            ->method('save')
            ->willReturnCallback(fn (User $user) => $user);

        // Act
        $user = $this->service->create($dto);

        // Assert
        $this->assertSame('Iván', $user->getName());
        $this->assertSame('ivan@example.com', $user->getEmail());
    }
}
```

### Data Providers
```php
#[DataProvider('invalidEmailProvider')]
public function testRejectsInvalidEmails(string $email): void
{
    $this->expectException(ValidationException::class);
    $this->service->create(new CreateUserDto('Test', $email));
}

public static function invalidEmailProvider(): array
{
    return [
        'empty' => [''],
        'no at sign' => ['invalid'],
        'no domain' => ['user@'],
        'spaces' => ['user @example.com'],
    ];
}
```

### Mocks y Stubs
```php
// Mock con expectativa
$mock = $this->createMock(UserRepository::class);
$mock->expects($this->once())
    ->method('findById')
    ->with(42)
    ->willReturn(new User('Test'));

// Stub sin verificación de llamada
$stub = $this->createStub(Logger::class);
$stub->method('info')->willReturn(null);
```

### Assertions comunes
```php
$this->assertSame($expected, $actual);         // ===
$this->assertEquals($expected, $actual);        // ==
$this->assertTrue($value);
$this->assertCount(3, $array);
$this->assertInstanceOf(User::class, $result);
$this->assertEmpty($collection);
$this->assertStringContainsString('hello', $text);
```

## Test Doubles — Cuándo Usar Qué

| Tipo | Uso | Ejemplo |
|------|-----|---------|
| **Stub** | Devuelve datos predefinidos | Repositorio que devuelve usuario fake |
| **Mock** | Verifica que se llamó correctamente | Verificar que se envió un email |
| **Spy** | Registra llamadas sin cambiar comportamiento | Registrar logs para verificar después |
| **Fake** | Implementación simplificada pero funcional | Repositorio en memoria |
| **Dummy** | Solo rellena un parámetro requerido | Logger que no hace nada |

## Tests Unitarios vs Integración

### Unitarios
- Testean una unidad aislada (función, clase)
- Mockean todas las dependencias externas
- Rápidos: <1ms por test
- La mayoría de tus tests deberían ser unitarios

### Integración
- Testean la interacción entre unidades
- Pueden usar DB real (de test), HTTP, etc.
- Más lentos pero más confianza
- Para flujos críticos y puntos de integración

### E2E (Playwright)
- Testean el flujo completo desde la UI
- Los más lentos pero mayor confianza
- Solo para happy paths y flujos críticos
- Page Object pattern para mantener mantenibilidad

## Buenas Prácticas

1. **Nombres descriptivos**: `should return 404 when user not found` > `test1`
2. **No testear implementación** — Testea comportamiento y resultados, no cómo se llega a ellos
3. **Fixtures reutilizables** — Factory functions para crear datos de test
4. **Un assert por test** (idealmente) — Si falla, sabes exactamente qué
5. **No mockear lo que no es tuyo** — Wrappea librerías externas y mockea el wrapper
6. **Tests independientes** — Cada test debe poder ejecutarse solo, sin depender del orden
7. **Cobertura ≠ calidad** — 100% de cobertura con tests malos no vale de nada
