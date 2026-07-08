---
description: .NET repository layout (src/tests/docs), solution format, Directory.Build.*, .gitignore, DDD naming, InternalsVisibleTo.
globs: "**/*.sln,**/*.slnx,**/Directory.Build.props,**/Directory.Build.targets,**/Directory.Packages.props,**/NuGet.Config,**/.gitignore"
alwaysApply: false
---

# .NET Repository Structure

Follow this layout and naming for new .NET repositories so build, tests, and tooling stay consistent.

## Architecture and design principles

- **Clean Architecture:** Organise code by layers (e.g. Domain, Application, Infrastructure, API/Web) with dependencies pointing inward. Domain has no outward dependencies; application depends on domain; infrastructure and API depend on application/domain. Keep use cases and domain logic independent of frameworks and I/O.
- **SOLID:** Apply Single Responsibility, Open/Closed, Liskov Substitution, Interface Segregation, and Dependency Inversion so that types and layers stay testable and maintainable. Prefer depending on abstractions (interfaces) and injecting dependencies rather than concrete implementations.

## Folder structure

Use a flat, standard layout at the repository root:

```
RepositoryRoot/
  src/                    # Production code (libraries, apps)
  tests/                  # Test projects only
  docs/                   # Documentation (markdown, diagrams)
  NuGet.Config            # NuGet sources (root)
  MyProduct.sln           # or MyProduct.slnx (see below)
  Directory.Packages.props
  Directory.Build.props
  Directory.Build.targets
  .gitignore
```

- **src/** – All production projects (class libraries, web apps, workers). No test projects here.
- **tests/** – Only test projects (unit and integration). Each test project references the corresponding `src` project(s).
- **docs/** – User/docs and design docs (e.g. README fragments, ADRs, API notes).

## Solution file (root)

- **Name:** Same as the main product/solution name, e.g. `MyProduct.sln` or `MyProduct.slnx`.
- **Format:** From **.NET 10 onwards**, the preferred solution format is **`.slnx`** (SDK-style solution; better for large repos and tooling). Use **`.sln`** for older SDKs or when tooling does not yet support `.slnx`.
- **DisplayName in .slnx:** When using `.slnx`, prefer setting **DisplayName** for project entries where it improves readability (e.g. short labels in the solution explorer instead of long paths). Keep DisplayName consistent with project purpose or folder structure.
- **Location:** Repository root only (no solution files under `src/` or `tests/`).

## Root MSBuild files

All three files live at the **repository root**:

| File | Purpose |
|------|--------|
| **Directory.Packages.props** | Central package versions (`ManagePackageVersionsCentrally`), shared `<PackageVersion>` entries. |
| **Directory.Build.props** | Shared metadata (version, authors, copyright, LangVersion, Nullable, etc.). **New greenfield repos** may use unconditional **`<TreatWarningsAsErrors>true</TreatWarningsAsErrors>`** (see `dotnet-project-file-format.md`); otherwise set **TreatWarningsAsErrors** only for Release. When Release-only, run **`dotnet restore -c Release`** in CI (with `--locked-mode` when using lock files). Put NuGet-related properties (Authors, PackageLicenseExpression, RepositoryUrl, etc.) in a `<PropertyGroup Condition="'$(IsPackable)' == 'true'">` so they apply only to packable projects, not to test or app projects. |
| **Directory.Build.targets** | Shared targets and root-level build behavior. |

## Centralize duplicates from project files

- If the same **property** or **item group** appears in multiple `*.csproj`/`*.fsproj` files, move it into a dedicated `Directory.Build.props` or `Directory.Build.targets`.
- Prefer centralization order:
  1. **root** `Directory.Build.props` / `Directory.Build.targets` for repo-wide settings.
  2. `src/Directory.Build.*` or `tests/Directory.Build.*` only for area-specific differences.
- Keep project files focused on project-specific settings only (e.g. package id, output type, unique references).

### ✅ DO: move repeated settings to central files

Use a conditional `PropertyGroup` for NuGet-related metadata so it only applies to packable projects:

```xml
<!-- Directory.Build.props at root -->
<Project>
  <PropertyGroup>
    <Nullable>enable</Nullable>
  </PropertyGroup>

  <PropertyGroup Condition="'$(Configuration)' == 'Release'">
    <TreatWarningsAsErrors>true</TreatWarningsAsErrors>
  </PropertyGroup>

  <PropertyGroup Condition="'$(IsPackable)' == 'true'">
    <Authors>Your Company</Authors>
    <Company>Your Company</Company>
    <Copyright>© $([System.DateTime]::Now.Year) Your Company</Copyright>
    <PackageLicenseExpression>MIT</PackageLicenseExpression>
    <PackageProjectUrl>https://github.com/your/repo</PackageProjectUrl>
    <RepositoryUrl>https://github.com/your/repo.git</RepositoryUrl>
    <RepositoryType>git</RepositoryType>
  </PropertyGroup>
</Project>
```

### ❌ DON'T: duplicate same settings in many project files

```xml
<!-- Repeated in multiple .csproj files -->
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <Nullable>enable</Nullable>
  </PropertyGroup>
  <PropertyGroup Condition="'$(Configuration)' == 'Release'">
    <TreatWarningsAsErrors>true</TreatWarningsAsErrors>
  </PropertyGroup>
</Project>
```

## src/ MSBuild files

Under **src/** add:

- **Directory.Build.props** – Overrides or extra properties for all projects under `src/` (e.g. output paths, defaults).
- **Directory.Build.targets** – **InternalsVisibleTo** for test assemblies (see below). Optional other src-specific targets.

When `src/Directory.Build.props` or `src/Directory.Build.targets` exists, make the **first line inside `<Project>`** import the parent file if it exists, to preserve inheritance and avoid re-declaring shared values.

Example `src/Directory.Build.props`:

```xml
<Project>
  <Import Project="$(MSBuildThisFileDirectory)..\Directory.Build.props"
          Condition="Exists('$(MSBuildThisFileDirectory)..\Directory.Build.props')" />
  <PropertyGroup>
    <!-- src-specific settings only -->
  </PropertyGroup>
</Project>
```

Example `src/Directory.Build.targets`:

```xml
<Project>
  <Import Project="$(MSBuildThisFileDirectory)..\Directory.Build.targets"
          Condition="Exists('$(MSBuildThisFileDirectory)..\Directory.Build.targets')" />
  <ItemGroup>
    <!-- src-specific targets/items only -->
  </ItemGroup>
</Project>
```

Do **not** put solution or repo-wide package versions here; keep those at the root.

## tests/ MSBuild files

Under **tests/** add:

- **Directory.Packages.props** – Optional: test-only package versions or extra packages used only by tests (e.g. test frameworks, fakes). Can import or extend the root `Directory.Packages.props` if needed.

You can also add **Directory.Build.props** and **Directory.Build.targets** under `tests/` if you need test-specific defaults (e.g. `IsTestProject`, coverage, nullable).

When `tests/Directory.Build.props` or `tests/Directory.Build.targets` exists, make the **first line inside `<Project>`** import the parent file if it exists.

Example `tests/Directory.Build.props`:

```xml
<Project>
  <Import Project="$(MSBuildThisFileDirectory)..\Directory.Build.props"
          Condition="Exists('$(MSBuildThisFileDirectory)..\Directory.Build.props')" />
  <PropertyGroup>
    <!-- tests-specific settings only -->
  </PropertyGroup>
</Project>
```

Example `tests/Directory.Build.targets`:

```xml
<Project>
  <Import Project="$(MSBuildThisFileDirectory)..\Directory.Build.targets"
          Condition="Exists('$(MSBuildThisFileDirectory)..\Directory.Build.targets')" />
  <ItemGroup>
    <!-- tests-specific targets/items only -->
  </ItemGroup>
</Project>
```

## NuGet.Config

- **Location:** Repository **root**.
- **Content:** Package sources, source mapping, and (if needed) auth. No need to duplicate under `src/` or `tests/` unless you intentionally want different sources there.

## .gitignore

Use a **.NET-aware** `.gitignore` that covers:

- **.NET:** `bin/`, `obj/`, `[Dd]ebug/`, `[Rr]elease/`, `*.user`, `*.suo`, `*.nupkg`, `*.snupkg`, `packages/` (with usual exceptions), `project.lock.json`, `project.fragment.lock.json`, `*.log`, coverage outputs.
- **Visual Studio:** `.vs/`, `*.user`, `*.suo`, `*.userosscache`, `*.sln.docstates`, `*.rsuser`.
- **VS Code:** `.vscode/` (optionally keep `.vscode/settings.json` or launch/tasks if the team commits them).
- **Rider:** `.idea/`, `*.iml` (or equivalent).

Prefer the official **dotnet** and **VisualStudio** templates (e.g. `dotnet new gitignore` or GitHub’s VisualStudio.gitignore) and extend them for Rider/VS Code if needed.

## Project naming (DDD-style)

- **Production projects (under src/):** Use **Domain Driven Design**-style names, e.g.:
  - `Company.Product.Domain` – domain model, entities, value objects.
  - `Company.Product.Application` – use cases, application services.
  - `Company.Product.Infrastructure` – persistence, external services.
  - `Company.Product.Api` or `Company.Product.Web` – entrypoint (API or web app).
  - `Company.Product.Contracts` – **optional, recommended for APIs:** API contract types only (request/response DTOs, API surface models). No business logic or dependencies on other layers. Typically published as a NuGet package so API consumers can reference the same contract types.
- **Test projects (under tests/):** Same base name as the project under test, with a **fixed suffix**:
  - **Unit:** `*.Tests.Unit` (e.g. `Company.Product.Domain.Tests.Unit`).
  - **Integration:** `*.Tests.Integration` (e.g. `Company.Product.Infrastructure.Tests.Integration`).

So: one production project → one or two test projects (Unit and/or Integration), with names that match by prefix.

## InternalsVisibleTo (src/Directory.Build.targets)

So that unit and integration tests can use `internal` types and members of production assemblies:

- **Where:** In **src/Directory.Build.targets** (not in the root `Directory.Build.targets`).
- **What:** Add `InternalsVisibleTo` for the **test assemblies** that correspond to each project under `src/`. Use the naming convention above: for a project named `MyProduct.Domain`, the test assemblies are `MyProduct.Domain.Tests.Unit` and `MyProduct.Domain.Tests.Integration`.

Example **src/Directory.Build.targets**:

```xml
<Project>
  <ItemGroup>
    <InternalsVisibleTo Include="$(AssemblyName).Tests.Unit" />
    <InternalsVisibleTo Include="$(AssemblyName).Tests.Integration" />
  </ItemGroup>
</Project>
```

`$(AssemblyName)` is the output assembly name (defaults to project file name without extension) (e.g. `MyProduct.Domain`), so every project under `src/` exposes internals to its `*.Tests.Unit` and `*.Tests.Integration` assemblies. If a project has only unit or only integration tests, omit the unused line or add a condition.

## Summary checklist

- [ ] Root: `src/`, `tests/`, `docs/`
- [ ] Root: `NuGet.Config`, `ProjectName.sln` or `ProjectName.slnx` (from .NET 10 onwards prefer .slnx)
- [ ] Root: `Directory.Packages.props`, `Directory.Build.props`, `Directory.Build.targets`
- [ ] **src/:** `Directory.Build.props`, `Directory.Build.targets` (with `InternalsVisibleTo` for `*.Tests.Unit` and `*.Tests.Integration`)
- [ ] **tests/:** `Directory.Packages.props` (and optionally `Directory.Build.props` / `Directory.Build.targets`)
- [ ] `.gitignore` covers .NET, Visual Studio, VS Code, Rider
- [ ] Project names follow DDD; test projects end with `.Tests.Unit` or `.Tests.Integration`
