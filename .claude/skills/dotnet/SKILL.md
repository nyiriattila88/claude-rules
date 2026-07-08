---
name: dotnet
description: >
  .NET / C# fejlesztési szabályok és best practice-ek (Nyiri Attila szabálykészlete).
  Használd MINDIG, amikor C#/.NET kóddal dolgozol: C# forrás írása vagy módosítása,
  ASP.NET Core API, xUnit teszt vagy BenchmarkDotNet benchmark írása, `.csproj`/`.sln`/
  `.slnx`/`Directory.Build.props`/`Directory.Packages.props`/`global.json` szerkesztése,
  NuGet-csomag készítése/publikálása/aláírása, dotnet tool készítése vagy fogyasztása,
  central package management, locked restore, vagy .NET repo-struktúra kialakítása.
  Trigger kulcsszavak: C#, .NET, dotnet, csproj, NuGet, xUnit, MSBuild, ASP.NET, EF Core.
---

# .NET / C# szabályok

Ez a skill a részletes .NET szabályokat a `references/` alatt tárolja. **Ne dolgozz emlékezetből** — mielőtt a témába vágó kódot írsz vagy fájlt szerkesztesz, olvasd be a `Read` tool-lal a vonatkozó reference fájl(oka)t. Csak azt töltsd be, ami a feladathoz kell (token economy).

## Melyik fájlt mikor

| Feladat | Reference fájl |
|---|---|
| C# nyelvi stílus, típusok, LINQ, async, nullability, pattern matching, immutability | `references/dotnet-csharp-style.md` |
| ASP.NET Core API: routing, binding, validation, security, OpenAPI, hibakezelés | `references/dotnet-api.md` |
| xUnit teszt, AAA, FluentAssertions, NSubstitute, TestContainers | `references/dotnet-testing.md` |
| Repo-szerkezet: `src/`/`tests/`/`docs/`, MSBuild props/targets, projekt-elnevezés, Clean Architecture | `references/dotnet-repository-structure.md` |
| Solution: `global.json`, central package management, `NuGet.Config`, build/compile flagek | `references/dotnet-solution.md` |
| Függőségek: lock file, sebezhetőség-vizsgálat, licenc, verziókezelés | `references/dotnet-dependencies.md` |
| Build-rendszer: natív `dotnet` CLI, `RELEASE_NOTES.md`, verziókezelés, CI/CD | `references/dotnet-build-system.md` |
| Locked restore CI folyamat (`--locked-mode -c Release`) | `references/dotnet-locked-restore-ci.md` |
| `.csproj`/`.props`/`.targets` formátum, ItemGroup sorrend, `TreatWarningsAsErrors` | `references/dotnet-project-file-format.md` |
| dotnet tool fogyasztása (`dotnet-tools.json` manifest) | `references/dotnet-tools-consuming.md` |
| dotnet tool csomagolása és publikálása | `references/dotnet-tools-publishing.md` |
| NuGet publikálás: metaadat, SourceLink, symbols, SemVer, licenc | `references/dotnet-nuget-publishing.md` |
| NuGet aláírás SignClienttel | `references/dotnet-nuget-signing.md` |
| BenchmarkDotNet minták és anti-minták | `references/dotnet-benchmarking.md` |

Ha a feladat több témát érint (pl. új API projekt teszttel), olvasd be a releváns fájlokat együtt. Ha bizonytalan vagy, a `dotnet-csharp-style.md` a nyelvi alap.
