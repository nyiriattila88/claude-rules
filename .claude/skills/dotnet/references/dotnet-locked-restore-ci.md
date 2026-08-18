---
description: Enforce locked restore and split restore/build/test steps in .NET CI/CD with package lock file practices.
globs: "**/.github/workflows/*.yml,**/.github/workflows/*.yaml,**/build-system/*.yaml,**/.azure/*.yaml,**/Directory.Build.props,**/Directory.Build.targets,**/*.csproj,**/*.fsproj"
alwaysApply: false
---

# .NET Locked Restore in CI/CD

Use locked-mode restore in CI/CD and keep restore/build/test as separate steps for deterministic and reproducible builds.

## Required CI/CD flow

In CI/CD pipelines, run commands in this exact sequence:

1. `dotnet restore --locked-mode -c Release`
2. `dotnet build -c Release --no-restore`
3. `dotnet test -c Release --no-build`

Why:
- `--locked-mode` guarantees dependency graph is resolved from lock files only.
- **`-c Release` on restore** aligns with Release **and** ensures **`TreatWarningsAsErrors` (Release-only)** applies during restore: NuGet/MSBuild warnings from the restore step surface as errors the same way as during build. Without `-c Release`, restore often runs under Debug and **new NU\* warnings can slip through** while Release build stays clean.
- `--no-restore` prevents implicit restore during build.
- `--no-build` prevents redundant build during test.

## No new warnings on restore or Release build

- **Goal:** CI (and release checks) must **not allow new warnings** during **restore** or **Release** compile,treat them as failures, not noise.
- **Restore:** Use **`dotnet restore --locked-mode -c Release`** when **`TreatWarningsAsErrors`** is enabled for Release in `Directory.Build.props` (see `dotnet-project-file-format.md`). Alternatively, force once: `dotnet restore --locked-mode /p:TreatWarningsAsErrors=true` if you cannot pass `-c Release`.
- **Build/test:** Keep **`dotnet build -c Release`** and **`dotnet test -c Release`** so compiler/analyzer warnings fail the pipeline.
- **Local parity:** Before push, run the same three steps locally so restore + Release build match CI.

## Package lock file requirements

- Enable lock file generation centrally in `Directory.Build.props`:

```xml
<Project>
  <PropertyGroup>
    <RestorePackagesWithLockFile>true</RestorePackagesWithLockFile>
  </PropertyGroup>
</Project>
```

- Keep `packages.lock.json` committed to source control.
- Do not copy `packages.lock.json` to output or publish artifacts. Configure `Directory.Build.targets`:

```xml
<Project>
  <ItemGroup Condition="Exists('packages.lock.json')">
    <Content Remove="packages.lock.json" />
    <None Remove="packages.lock.json" />
    <None Include="packages.lock.json">
      <CopyToPublishDirectory>Never</CopyToPublishDirectory>
      <CopyToOutputDirectory>Never</CopyToOutputDirectory>
    </None>
  </ItemGroup>
</Project>
```

## ✅ DO

### CI/CD pipeline example

```yaml
steps:
  - script: dotnet restore --locked-mode -c Release
    displayName: Restore (locked mode, Release, no new warnings)

  - script: dotnet build -c Release --no-restore
    displayName: Build (no restore)

  - script: dotnet test -c Release --no-build --logger:trx
    displayName: Test (no build)
```

### Local dependency update flow

```bash
dotnet restore --use-lock-file -c Release
dotnet build -c Release --no-restore
dotnet test -c Release --no-build
```

Commit the resulting lock file changes together with dependency updates.

## ❌ DON'T

### Don't mix restore into build/test

```yaml
steps:
  - script: dotnet build -c Release
  - script: dotnet test -c Release
```

### Don't skip lock files in source control

```gitignore
# Bad when using locked mode in CI
**/packages.lock.json
```

## Validation expectations

- CI must fail if `dotnet restore --locked-mode -c Release` detects drift between project dependencies and lock files.
- CI must fail on **any warning** promoted by **`TreatWarningsAsErrors`** during that restore step and during **Release** build/test (no new warnings tolerated in those phases).
- Dependency upgrades must include updated `packages.lock.json`.
- Any pipeline using `dotnet test` should run `dotnet build` first, then `dotnet test --no-build`.
- **`TreatWarningsAsErrors`** for Release requires **`-c Release` on restore, build, and test** so restore-time NU\* warnings and compile-time warnings both fail the pipeline; **Debug-only or restore without `-c Release`** can hide warnings that would break Release.
