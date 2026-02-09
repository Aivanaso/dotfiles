---
name: symfony
description: "Skill para desarrollo con Symfony. Se activa al trabajar con controllers, Doctrine, forms, security, console commands y el ecosistema Symfony."
---

# Symfony — Guía de Desarrollo

## Estructura de Proyecto

```
src/
├── Controller/
├── Entity/
├── Repository/
├── Service/
├── Form/
├── Security/
│   ├── Voter/
│   └── Authenticator/
├── EventSubscriber/
├── Command/
├── DataFixtures/
└── Kernel.php
config/
├── packages/
├── routes/
└── services.yaml
templates/
migrations/
tests/
```

## Controllers

- Extender `AbstractController` — acceso a helpers
- Rutas con atributos PHP 8: `#[Route('/api/users', methods: ['GET'])]`
- Un método por acción — no controllers gordos
- Devolver `JsonResponse` para APIs, `Response` con Twig para web
- Inyectar dependencias por constructor o por parámetro de método

```php
#[Route('/api/users')]
class UserController extends AbstractController
{
    public function __construct(
        private readonly UserService $userService,
    ) {}

    #[Route('', methods: ['GET'])]
    public function index(): JsonResponse
    {
        return $this->json($this->userService->findAll());
    }

    #[Route('/{id}', methods: ['GET'])]
    public function show(int $id): JsonResponse
    {
        $user = $this->userService->findOrFail($id);
        return $this->json($user);
    }
}
```

## Doctrine ORM

### Entities
- Atributos PHP 8 para mapeo: `#[ORM\Entity]`, `#[ORM\Column]`
- Relaciones explícitas: `#[ORM\OneToMany]`, `#[ORM\ManyToOne]`, etc.
- `readonly` para propiedades inmutables
- Constructor para campos obligatorios

```php
#[ORM\Entity(repositoryClass: UserRepository::class)]
class User
{
    #[ORM\Id]
    #[ORM\GeneratedValue]
    #[ORM\Column]
    private ?int $id = null;

    #[ORM\Column(length: 255)]
    private string $name;

    #[ORM\Column(length: 255, unique: true)]
    private string $email;
}
```

### Repositories
- Extender `ServiceEntityRepository`
- Métodos custom con QueryBuilder para consultas complejas
- DQL para consultas de dominio
- Criteria para filtrado dinámico

### Migrations
- Generar con `php bin/console make:migration`
- Revisar SQL generado antes de ejecutar
- Nunca editar migrations ya ejecutadas — crear nuevas
- `doctrine:migrations:migrate` en despliegues

## Forms

- Crear con `make:form` y personalizar
- Validación con Constraints en la entity o en el form type
- FormType para formularios reutilizables
- Data transformers para conversión de datos

## Security

### Authenticators
- Custom authenticator implementando `AuthenticatorInterface`
- JWT con `lexik/jwt-authentication-bundle`
- Login form con `form_login` en `security.yaml`

### Voters
- Para autorización granular basada en atributos
- Un voter por dominio/recurso
- Implementar `VoterInterface` o extender `Voter`

```php
class PostVoter extends Voter
{
    protected function supports(string $attribute, mixed $subject): bool
    {
        return in_array($attribute, ['EDIT', 'DELETE']) && $subject instanceof Post;
    }

    protected function voteOnAttribute(string $attribute, mixed $subject, TokenInterface $token): bool
    {
        $user = $token->getUser();
        return match ($attribute) {
            'EDIT', 'DELETE' => $subject->getAuthor() === $user,
            default => false,
        };
    }
}
```

### Firewalls
- Configurar en `config/packages/security.yaml`
- Firewall separado para API y web
- `access_control` para restricciones por ruta

## Console Commands

- Para tareas de mantenimiento, migraciones de datos, crons
- Extender `Command` con atributo `#[AsCommand]`
- Input/Output tipado, opciones y argumentos claros
- Progress bars para operaciones largas

```php
#[AsCommand(name: 'app:import-users', description: 'Importa usuarios desde CSV')]
class ImportUsersCommand extends Command
{
    protected function execute(InputInterface $input, OutputInterface $output): int
    {
        // ...
        return Command::SUCCESS;
    }
}
```

## Event System

- Event subscribers para lógica transversal
- Eventos de Doctrine: `prePersist`, `postUpdate`, etc.
- Eventos custom con `EventDispatcher`
- Kernel events para middleware-like behavior

## Twig Templates

- Herencia de plantillas con `extends` y `block`
- Componentes reutilizables con `include` o Twig Components
- Filtros y funciones custom cuando sea necesario
- Escape automático — confiar en Twig para XSS

## Testing

- `WebTestCase` para tests funcionales con `createClient()`
- `KernelTestCase` para tests de integración
- Fixtures con `doctrine/doctrine-fixtures-bundle`
- PHPUnit como test runner
- Base de datos de test separada
