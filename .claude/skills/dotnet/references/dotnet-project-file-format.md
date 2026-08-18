---
description: Preferred layout and formatting for .csproj, .props, and .targets files – Project tag, blank lines, separate ItemGroups for PackageReference vs ProjectReference, order.
globs: "**/*.csproj,**/*.props,**/*.targets"
alwaysApply: false
---

# .NET project file format (.csproj, .props, .targets)

When editing or creating `.csproj`, `.props`, or `.targets` files, follow this structure and formatting.

## Document structure

- **First line:** Must be the opening `<Project ...>` tag (e.g. `<Project Sdk="Microsoft.NET.Sdk">` or `<Project>`).
- **Last line:** Must be the closing `</Project>` tag.
- **Blocks:** Put exactly one blank line before and after every top-level block (e.g. each `PropertyGroup`, `ItemGroup`, `Import`, etc.). No blank line between the opening `<Project>` and the first block; one blank line between blocks; one blank line before `</Project>` when there is content.

## ItemGroup separation and order

- **Do not mix** `PackageReference` and `ProjectReference` in the same `ItemGroup`. Use separate `ItemGroup` elements.
- **Order:** The `ItemGroup` that contains only `PackageReference` entries must appear **before** the `ItemGroup` that contains only `ProjectReference` entries.

Other item types (e.g. `None`, `Content`, `InternalsVisibleTo`) may be in their own `ItemGroup`(s); keep them logically grouped and use the same blank-line rule between blocks.

## TreatWarningsAsErrors

### New greenfield projects: starting with `true` is often worth it

For **brand-new solutions** with little or no code yet:

- **Do consider** `<TreatWarningsAsErrors>true</TreatWarningsAsErrors>` **unconditionally** (all configurations) in root **`Directory.Build.props`**: zero legacy warning debt, every new warning breaks the build immediately, **Debug matches CI**,no surprise failures only on Release.
- **Trade-off:** local Debug is as strict as Release; some teams later relax to **Release-only** (below) if third-party noise or rapid prototyping friction grows.
- Keep exceptions rare and explicit via **`WarningsNotAsErrors`** (and comment or doc why).

Root `Directory.Build.props` (greenfield, strict):

```xml
<Project>

  <PropertyGroup>
    <TreatWarningsAsErrors>true</TreatWarningsAsErrors>
  </PropertyGroup>

</Project>
```

### Default for most repos: Release only

Set **`TreatWarningsAsErrors`** only when **`Configuration` is `Release`**, so CI and publish builds fail on warnings while local **Debug** stays more permissive. Prefer this once a codebase or team is larger, or when migrating brownfield code.

- Prefer defining this once in repo-root **`Directory.Build.props`** (see `dotnet-repository-structure.md`, `dotnet-build-system.md`).
- **CI must run `dotnet restore` with `-c Release`** (e.g. `dotnet restore --locked-mode -c Release`) when **`TreatWarningsAsErrors` is Release-only**: otherwise restore runs under Debug by default and **NuGet (NU\*) warnings are not promoted to errors**, so new restore warnings slip past CI while Release build still fails on compile warnings.
- **CI must run `dotnet build` / `dotnet test` with `-c Release`** (or equivalent); otherwise warnings that would break Release are never exercised.

#### ✅ DO: conditional PropertyGroup (central or per-project)

Root `Directory.Build.props` (recommended for Release-only):

```xml
<Project>

  <PropertyGroup Condition="'$(Configuration)' == 'Release'">
    <TreatWarningsAsErrors>true</TreatWarningsAsErrors>
    <!-- Optional: keep specific codes as warnings in Release -->
    <WarningsNotAsErrors>CS1591;NU5104</WarningsNotAsErrors>
  </PropertyGroup>

</Project>
```

Single project (only if not inherited from `Directory.Build.props`):

```xml
<Project Sdk="Microsoft.NET.Sdk">

  <PropertyGroup Condition="'$(Configuration)' == 'Release'">
    <TreatWarningsAsErrors>true</TreatWarningsAsErrors>
  </PropertyGroup>

</Project>
```

### ❌ DON'T

- Rely on **Debug-only** local builds to prove the solution is clean when CI uses **Release-only** TWAE: Release will turn warnings into **errors** and can fail CI/pack.
- Duplicate the same `TreatWarningsAsErrors` block in **many** `.csproj` files,keep it in **`Directory.Build.props`** once (whether unconditional greenfield or Release-only).

## ✅ DO

```xml
<Project Sdk="Microsoft.NET.Sdk">

  <ItemGroup>
    <PackageReference Include="AWSSDK.DynamoDBv2" />
    <PackageReference Include="Microsoft.Extensions.Configuration.Abstractions" />
    <PackageReference Include="Microsoft.Extensions.DependencyInjection.Abstractions" />
    <PackageReference Include="Microsoft.Extensions.Options" />
    <PackageReference Include="Microsoft.Extensions.Options.ConfigurationExtensions" />
  </ItemGroup>

  <ItemGroup>
    <ProjectReference Include="..\Editor.Domain\Editor.Domain.csproj" />
  </ItemGroup>

</Project>
```

## ❌ DON'T

- First line not being `<Project ...>` or last line not being `</Project>`.
- No blank line between top-level blocks.
- Mixing `PackageReference` and `ProjectReference` in one `ItemGroup`:

```xml
<!-- DON'T: mixed ItemGroup -->
<ItemGroup>
  <PackageReference Include="Some.Package" />
  <ProjectReference Include="..\Other\Other.csproj" />
</ItemGroup>
```

- Putting `ProjectReference` ItemGroup before `PackageReference` ItemGroup:

```xml
<!-- DON'T: wrong order -->
<ItemGroup>
  <ProjectReference Include="..\Other\Other.csproj" />
</ItemGroup>

<ItemGroup>
  <PackageReference Include="Some.Package" />
</ItemGroup>
```
