---
description: ASP.NET Core API development – REST, versioning, validation, security, docs, performance.
globs: "**/*Controller*.cs,**/Program.cs,**/MinimalApi*.cs,**/*Endpoints*.cs,**/*.Api.csproj,**/*.Web*.csproj"
alwaysApply: false
---

# ASP.NET Core API Development

Rules for building HTTP APIs with ASP.NET Core (Minimal APIs, controllers, EF Core). For general C# style see `dotnet-csharp-style.md`; for tests see `dotnet-testing.md`.

## Project and folder structure

- **API entrypoint:** One project named `*.Api` or `*.Web` (e.g. `Company.Product.Api`). Use `Program.cs` and optionally `MinimalApi` or controller-based structure.
- **Layering:** Keep Controllers/Endpoints thin; put business logic in application services. Use DTOs/records for request/response; domain in separate projects (see `dotnet-repository-structure.md`).
- **Contracts project:** Prefer organising API contract types (request/response DTOs, API surface models) in a dedicated `*.Contracts` project (e.g. `Company.Product.Contracts`). That project should contain only model/contract classes, no business logic, and is typically published as a NuGet package so consumers can reference the same types. See `dotnet-repository-structure.md` for project naming.
- **Organise by feature or layer:** e.g. `Controllers/`, `Endpoints/`, `Models/` (or DTOs), `Services/`, and optionally `Filters/`, `Middleware/`.

## API design

- **REST:** Follow RESTful conventions (resource nouns, HTTP verbs, meaningful status codes). Prefer standard status codes (200, 201, 204, 400, 401, 403, 404, 409, 500).
- **Routing:** Use attribute routing (`[Route(...)]`, `[HttpGet]`, etc.) or Minimal API `Map*` with clear, consistent paths (e.g. `"/api/v1/resources"`).
- **Versioning:** Implement API versioning (e.g. URL path `/api/v1/`, header, or query) and keep versions documented. Prefer explicit version in route or header over query when possible.
- **Cross-cutting:** Use action filters (or endpoint filters in Minimal API) for logging, validation, or auth concerns instead of duplicating logic in each action.
- **GET pagination:** For `GET` endpoints returning collections, always implement pagination (e.g. `page`/`pageSize` or `skip`/`take`). Do not expose unbounded list endpoints.

## Explicit binding sources

- **Always specify the binding source** for action parameters. Do not rely on implicit model binding.
- **Controllers:** Use `[FromQuery]`, `[FromBody]`, `[FromRoute]`, `[FromHeader]`, or `[FromForm]` on every action parameter so it is clear where the value comes from.
- **Minimal APIs:** Use `[FromQuery]`, `[FromBody]`, `[FromRoute]`, `[FromHeader]`, or `[FromForm]` on the parameter type or parameter, or pass parameters explicitly (e.g. `AsParameters` with a type that has binding attributes).
- **Why:** Explicit binding avoids ambiguity (e.g. query vs body), prevents accidental binding from unexpected sources, and makes the API contract obvious in code and in OpenAPI.

Example (controller):

```csharp
[HttpGet("{id:guid}")]
public async Task<ActionResult<ResourceDto>> Get(
    [FromRoute] Guid id,
    [FromQuery] bool includeDetails = false,
    CancellationToken cancellationToken = default)

[HttpPost]
public async Task<ActionResult<ResourceDto>> Create(
    [FromBody] CreateResourceRequest request,
    CancellationToken cancellationToken = default)
```

Example (Minimal API with explicit parameters):

```csharp
app.MapGet("/api/v1/resources/{id:guid}", async (
    [FromRoute] Guid id,
    [FromQuery] int page,
    [FromQuery] int pageSize,
    IResourceService service,
    CancellationToken ct) => await service.GetAsync(id, page, pageSize, ct));

app.MapPost("/api/v1/resources", async (
    [FromBody] CreateResourceRequest request,
    IResourceService service,
    CancellationToken ct) => await service.CreateAsync(request, ct));
```

## Error handling and validation

- **Exception handling middleware:** Use **global exception handling middleware** (or `IExceptionHandler` in .NET 8+) from the start of API development. It should catch unhandled exceptions, map them to a consistent error response shape and HTTP status code, and optionally log them. This avoids duplicate try/catch in every action and ensures clients always receive a predictable error format (e.g. Problem Details). Use exceptions for exceptional cases only; do not use them for normal control flow.
- **Responses:** Return a **consistent error payload** (e.g. `{ "type", "title", "status", "detail", "traceId" }`) and appropriate HTTP status codes. Avoid leaking stack traces or internal details in production.
- **Validation:** Use **Data Annotations** on DTOs or **Fluent Validation** for request validation. Return **400 Bad Request** with a structured list of validation errors (e.g. Problem Details). Validate at the API boundary before calling application services.

## Security

- **Authentication & authorization:** Use ASP.NET Core authentication (e.g. JWT Bearer for stateless APIs) and authorization (policies, `[Authorize]`). Prefer policy-based checks over role strings where possible.
- **HTTPS:** Enforce HTTPS in production (redirect HTTP to HTTPS, HSTS). Do not send sensitive data over plain HTTP.
- **CORS:** Configure CORS explicitly with allowed origins, methods, and headers. Do not use `AllowAnyOrigin` with credentials in production.
- **Secrets:** Never commit secrets or connection strings. Use User Secrets in development and environment variables or a secret store (e.g. Azure Key Vault) in production.

## API documentation

- **Visibility for OpenAPI:** Controllers (and request/response DTOs or types exposed in the API surface) must be **public**, not `internal`. The OpenAPI document generator (Swashbuckle, NSwag, etc.) discovers endpoints and schemas via reflection and cannot see internal types, so internal controllers or DTOs would be missing from the generated documentation.
- **OpenAPI/Swagger:** Expose API documentation via Swashbuckle (Swagger) or NSwag. Enable in development; optionally restrict or disable in production or protect by auth.
- **XML doc for APIs and contracts:** Strive to add XML documentation comments (`///`) on API operations (controller actions, Minimal API endpoints) and on contracts (request/response DTOs, types that appear in the API surface). Document summary and, where useful, `<remarks>`, `<param>`, `<returns>`, and `<response code="...">` so that the OpenAPI document is descriptive and usable by clients and tools.
- **Include XML docs in OpenAPI:** Enable XML documentation file generation in the API project (e.g. `<GenerateDocumentationFile>true</GenerateDocumentationFile>`) and configure the OpenAPI generator to include those comments: with Swashbuckle use `IncludeXmlComments` pointing at the generated XML; with NSwag use the appropriate option to load XML comments. Ensure the generated OpenAPI/Swagger UI shows operation summaries and schema descriptions from the XML docs.
- **Examples:** Provide request/response examples in Swagger where it clarifies usage (e.g. `[SwaggerRequestExample]` / `[SwaggerResponseExample]` or OpenAPI examples).

## Performance and scalability

- **Async I/O:** Use `async`/`await` for all I/O-bound operations (database, HTTP, file). Do not block with `.Result` or `.Wait()`.
- **Caching:** Use `IMemoryCache` for in-process caching or distributed cache (e.g. Redis) when scaling out. Define clear cache keys and expiration. Invalidate or version cache when data changes.
- **Database:** Use efficient queries; avoid N+1 (e.g. include/load related data, or use projections). Prefer async EF Core APIs (`ToListAsync`, `FirstOrDefaultAsync`, etc.).
- **Pagination:** For `GET` list endpoints, pagination is mandatory (e.g. `skip`/`take` or `page`/`pageSize`) and responses should include metadata (e.g. total count, page, page size, has-next). Use consistent query parameter names.

## Conventions and patterns

- **Request/response logging middleware:** Use request/response logging middleware during API development (and optionally in non-production environments) to log HTTP method, path, status code, duration, and optionally request/response body or headers. This aids debugging, auditing, and support. In production, restrict or redact sensitive data (e.g. avoid logging full bodies if they may contain secrets); consider enabling only in development or behind a feature flag.
- **Dependency injection:** Register services in `Program.cs` (or `Startup.cs`). Prefer constructor injection. Keep controllers/endpoints small and delegate to application services.
- **Repository / data access:** Use a repository abstraction over EF Core when it simplifies testing or swapping implementations; otherwise use `DbContext` directly from a scoped service. Avoid exposing IQueryable across layer boundaries; return DTOs or domain types.
- **Mapping:** Use **extension methods** to map between domain/DbContext entities and DTOs (e.g. `entity.ToDto()`, `request.ToEntity()`). Do not use AutoMapper. Do not expose entity types directly in API responses.
- **Background work:** Use `IHostedService` or `BackgroundService` for long-running or periodic tasks. Prefer a proper job queue or worker process for heavy or unreliable work.

## Testing

- **Unit tests:** Test application services and validators in isolation (see `dotnet-testing.md`). Mock repositories and external dependencies.
- **Integration tests:** Test API endpoints with `WebApplicationFactory` and a test server. Use in-memory or test databases where appropriate. See `dotnet-testing.md` for TestContainers and integration patterns.

Follow Microsoft’s ASP.NET Core documentation for routing, middleware, and security best practices.
