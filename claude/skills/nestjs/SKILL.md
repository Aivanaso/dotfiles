---
name: nestjs
description: "Skill para desarrollo con NestJS. Se activa al trabajar con módulos, controllers, services, guards, DTOs y otros artefactos de NestJS."
---

# NestJS — Guía de Desarrollo

## Estructura de Proyecto

```
src/
├── modules/
│   └── <feature>/
│       ├── <feature>.module.ts
│       ├── <feature>.controller.ts
│       ├── <feature>.service.ts
│       ├── dto/
│       │   ├── create-<feature>.dto.ts
│       │   └── update-<feature>.dto.ts
│       ├── entities/
│       │   └── <feature>.entity.ts
│       ├── guards/
│       ├── interceptors/
│       └── <feature>.controller.spec.ts
├── common/
│   ├── decorators/
│   ├── filters/
│   ├── guards/
│   ├── interceptors/
│   └── pipes/
├── config/
├── app.module.ts
└── main.ts
```

## Módulos

- Un módulo por dominio/feature — nunca módulos gigantes con todo
- Usar `forRoot()` / `forRootAsync()` para módulos de configuración
- Exportar solo lo necesario — principio de mínima exposición
- Módulos dinámicos para configuración variable

```typescript
@Module({
  imports: [TypeOrmModule.forFeature([UserEntity])],
  controllers: [UserController],
  providers: [UserService],
  exports: [UserService],
})
export class UserModule {}
```

## Controllers

- Solo orquestación — la lógica va en services
- Decoradores de ruta claros y RESTful
- Usar DTOs para request/response — nunca `any`
- Swagger decorators para documentación

```typescript
@Controller('users')
export class UserController {
  constructor(private readonly userService: UserService) {}

  @Post()
  @HttpCode(HttpStatus.CREATED)
  create(@Body() dto: CreateUserDto): Promise<UserResponseDto> {
    return this.userService.create(dto);
  }
}
```

## Services

- Lógica de negocio aquí — los controllers delegan
- Inyección de dependencias vía constructor
- Métodos pequeños y con nombre descriptivo
- Lanzar excepciones HTTP apropiadas (`NotFoundException`, `ConflictException`, etc.)

## DTOs con class-validator y class-transformer

- Siempre validar input con decoradores
- `class-transformer` para transformar datos de entrada
- DTOs separados para create/update — no reusar el mismo
- `PartialType()`, `PickType()`, `OmitType()` para composición

```typescript
export class CreateUserDto {
  @IsString()
  @IsNotEmpty()
  @MinLength(2)
  name: string;

  @IsEmail()
  email: string;

  @IsOptional()
  @IsString()
  avatar?: string;
}
```

## Guards, Interceptors, Pipes

### Guards
- Para autenticación y autorización
- Implementar `CanActivate`
- Usar `@UseGuards()` a nivel de controller o método
- Guards globales para auth general

### Interceptors
- Para transformar respuestas, logging, cache
- Implementar `NestInterceptor`
- `ClassSerializerInterceptor` para excluir campos

### Pipes
- Para validación y transformación de datos
- `ValidationPipe` global con `whitelist: true` y `transform: true`
- Pipes custom para transformaciones específicas

### Exception Filters
- `AllExceptionsFilter` global para formato de errores consistente
- Filtros específicos para errores de dominio

## TypeORM / Prisma

### TypeORM
- Entities con decoradores — relaciones explícitas
- Repository pattern: inyectar `@InjectRepository()`
- Migrations para cambios de schema — nunca `synchronize: true` en producción
- QueryBuilder para consultas complejas

### Prisma
- Schema como fuente de verdad
- Prisma Client inyectado como service
- Migraciones con `prisma migrate`

## Testing

- Usar `@nestjs/testing` y `Test.createTestingModule()`
- Mockear dependencias con providers override
- Tests unitarios para services, e2e para controllers
- `supertest` para tests HTTP

```typescript
const module = await Test.createTestingModule({
  providers: [
    UserService,
    { provide: getRepositoryToken(UserEntity), useClass: MockRepository },
  ],
}).compile();
```
