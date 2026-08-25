---
name: typescript
description: >
  Node.js / TypeScript fejlesztési szabályok és best practice-ek (Nyiri Attila szabálykészlete).
  Használd MINDIG, amikor TypeScript vagy JavaScript kóddal dolgozol Node-on: TS/JS forrás
  írása vagy módosítása, `package.json`/`tsconfig.json`/`eslint.config.*`/`vitest.config.*`
  szerkesztése, npm/pnpm/yarn függőség kezelése, TS API (Express, Fastify, Hono) építése,
  Zod séma írása, vitest/jest teszt írása, lokális futtatás és config-rétegezés beállítása,
  Node-os Dockerfile írása. Akkor is, ha a felhasználó „TS best practice", „Node projekt
  struktúra", „hogy nézzen ki a tsconfig", „hogyan futtassam lokálisan" jellegű kérdést tesz fel.
---

# Node.js / TypeScript szabályok

Ez a skill a részletes szabályokat a `references/` alatt tárolja. **Ne dolgozz emlékezetből**, mielőtt
TypeScript kódot írsz vagy konfigurációs fájlt szerkesztesz, olvasd be a `Read` tool-lal a vonatkozó
reference fájl(oka)t. Csak azt töltsd be, ami a feladathoz kell ([[token-economy]]).

## Melyik fájlt mikor

| Feladat | Reference fájl |
|---|---|
| Repo- és mappaszerkezet, komponens-alapú tagolás, entry point, barrel-fájlok | `references/ts-repository-structure.md` |
| `tsconfig.json`: strictness, module/target, path alias, project references | `references/ts-tsconfig.md` |
| Nyelvi stílus: típusok, `any` kerülése, narrowing, `unknown`, immutability, async | `references/ts-language-style.md` |
| Lokális futtatás: `tsx`, watch, `--env-file`, npm scriptek, debug (a `launchSettings` megfelelője) | `references/ts-local-development.md` |
| Config-rétegezés: env → fájl → default, séma-validálás, fail fast, titkok | `references/ts-configuration.md` |
| Tesztelés: vitest, AAA, mit teszteljünk, coverage, külső hívások mockolása | `references/ts-testing.md` |
| Függőségek: pnpm, lockfile, `--frozen-lockfile`, verziópolitika, audit | `references/ts-dependencies.md` |
| Hibakezelés és logolás: operational vs. programmer error, központi handler, pino | `references/ts-error-handling.md` |
| Node API-k (Express/Fastify/Hono): validálás, hibaválasz, OpenAPI, biztonsági fejlécek | `references/ts-api.md` |
| Node-os Dockerfile: multi-stage, `pnpm prune`, non-root, SIGTERM, tag-pinning | `references/ts-docker.md` |

Ha a feladat több témát érint (pl. új TS API teszttel), olvasd be a releváns fájlokat együtt. Ha
bizonytalan vagy, a `ts-language-style.md` a nyelvi alap.

## Amit mindig tarts szem előtt

- **A `strict: true` nem opcionális.** Egy `strict: false` projekt TypeScript-nek látszó JavaScript.
- **Fail fast induláskor.** Hiányzó vagy rossz konfiguráció induláskor álljon meg, ne az első kérésnél.
- **A típus a szerződés.** Ha egy érték átmegy a folyamathatáron (HTTP, queue, env), akkor **validálni
  kell** (Zod), nem elég típusolni: a `as` csak hazudik a fordítónak.
- **Egy nyelv, egy formázó.** A formázást ne vitassuk meg: Prettier vagy Biome, konfigban rögzítve.
