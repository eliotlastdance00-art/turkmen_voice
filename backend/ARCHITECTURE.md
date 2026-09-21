# Türkmen Ses Backend Architecture

## Layerler

```text
routers       HTTP transport, validation, response models
schemas       Pydantic API contracts
services      Use-cases/business rules
repositories  Persistence implementation
 domain       Entities and repository interfaces
 db           SQLite connection and migrations/bootstrap
 core         Configuration and cross-cutting concerns
```

## Dependency direction

```text
router -> service -> domain repository interface
                    ^
                    |
             sqlite repository
```

Domain layer FastAPI ýa-da SQLite-den garaşsyz saklanýar. Soňra SQLite ýerine PostgreSQL, audio disk ýerine S3 goýlanda service we router üýtgemeli däl.

## Täze feature goşmak tertibi

1. `domain/entities` içinde entity ýa-da value object.
2. `domain/repositories` içinde Protocol interface.
3. `schemas` içinde request/response contract.
4. `repositories` içinde persistence implementation.
5. `services` içinde use-case.
6. `routers` içinde HTTP endpoint.
7. `api_dependencies.py` içinde dependency wiring.

## Production-a geçiş

- SQLite -> PostgreSQL + SQLAlchemy/SQLModel
- Local audio -> S3-compatible object storage
- `allow_origins=['*']` -> belli domainler
- Admin auth, JWT, roles, rate limiting
- Alembic migrations
- Background job queue: Celery/RQ/Arq
- WAV validation: header, duration, sample rate, mono check
- Structured logging, metrics, health/readiness endpoints
