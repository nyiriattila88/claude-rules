# `tsconfig.json`

## A kiindulási pont

```json
{
  "compilerOptions": {
    "target": "ES2023",
    "lib": ["ES2023"],
    "module": "NodeNext",
    "moduleResolution": "NodeNext",

    "strict": true,
    "noUncheckedIndexedAccess": true,
    "exactOptionalPropertyTypes": true,
    "noImplicitOverride": true,
    "noImplicitReturns": true,
    "noFallthroughCasesInSwitch": true,
    "noUnusedLocals": true,
    "noUnusedParameters": true,

    "verbatimModuleSyntax": true,
    "isolatedModules": true,
    "esModuleInterop": true,
    "forceConsistentCasingInFileNames": true,
    "skipLibCheck": true,

    "outDir": "dist",
    "rootDir": "src",
    "sourceMap": true,
    "declaration": true
  },
  "include": ["src/**/*"]
}
```

## Amit muszáj érteni benne

### `strict: true`

Nem egy flag, hanem nyolc, egyben. Ezek közül a `strictNullChecks` a fontos: enélkül a `null` és az
`undefined` minden típusnak tagja, tehát a típusrendszer **nem tud** megvédeni a leggyakoribb Node-os
hibától.

**Egy `strict: false` projekt nem TypeScript-projekt**, hanem JavaScript, amiben típusannotációk vannak.
Meglévő kódbázisnál a bevezetés fájlonként megy (`// @ts-nocheck` a maradékon), de a cél mindig a
`strict: true`.

### `noUncheckedIndexedAccess`

Ez az a flag, ami a valós runtime hibákat kifogja. Tömb- és index-hozzáférés eredménye `| undefined`
lesz, mert **a fordító nem tudja, hogy létezik-e az elem**.

#### ✅ DO

```ts
const first = items[0];

if (first === undefined) {
  throw new Error('items is empty');
}

first.render();   // itt már biztosan létezik
```

#### ❌ DON'T

```ts
// A flag nélkül ez fordul, éles futásban pedig "Cannot read properties of undefined".
items[0].render();
```

Ha egy `Record<string, T>` lookupnál ez zavaró, az azt jelzi, hogy **a típus hazudott**: ha minden kulcs
biztosan létezik, akkor a típus `Record<Kulcs, T>` egy union kulccsal, nem `Record<string, T>`.

### `exactOptionalPropertyTypes`

Az `age?: number` a flag nélkül azt is jelenti, hogy `age: undefined` **explicit** megadható. Ez két
külön dolgot mos össze: „nincs megadva" és „megadva, hogy nincs". JSON szerializálásnál és adatbázis-
frissítésnél ez a különbség számít.

#### ✅ DO

```ts
type Patch = { title?: string };

const patch: Patch = {};                  // nincs megadva
const patch2: Patch = { title: 'new' };   // megadva
```

#### ❌ DON'T

```ts
// Ez a flaggel hiba, és jogosan: az "explicit undefined" mást jelent, mint a hiányzó kulcs.
const patch: Patch = { title: undefined };
```

Ha tényleg kell a `undefined` érték, írd a típusba: `title?: string | undefined`.

### `verbatimModuleSyntax`

A fordító nem találgatja, melyik import törölhető. Ami `import type`, az eltűnik, ami `import`, az
megmarad. Ettől kiszámítható lesz a kimenet, és nem tűnik el csendben egy mellékhatásos import.

```ts
import type { Config } from './config';       // csak típus, eltűnik
import { loadConfig } from './config';        // érték, megmarad
```

### `module` és `moduleResolution`

| Projekt | Beállítás |
|---|---|
| Node backend, ESM | `"module": "NodeNext"`, `"moduleResolution": "NodeNext"` + `"type": "module"` a `package.json`-ban |
| Bundlerrel épülő (Vite, esbuild) | `"module": "Preserve"` vagy `"ESNext"`, `"moduleResolution": "Bundler"` |
| Régi CommonJS | `"module": "CommonJS"`, új projektben ne |

**`NodeNext` esetén az import kiterjesztéssel megy**, mert az ESM így működik:

```ts
import { loadConfig } from './config.js';   // .js, akkor is, ha a forrás .ts
```

Ez elsőre furcsa, de ez a szabvány: a futásidőben a `.js` létezik.

### `erasableSyntaxOnly`

Hibát ad minden olyan TypeScript-konstrukcióra, aminek **futásidejű viselkedése** van: `enum`,
`namespace`, parameter property (`constructor(private x: string)`), `declare` mezők.

Akkor kapcsold be, ha a projektet a **Node natív típus-törlésével** akarod futtatni (`node file.ts`),
mert az csak törölni tud, átalakítani nem. Mellékhatásként a kód is jobb lesz: az `enum` helyett
`as const` objektum, ami tree-shakelhető és nem hoz létre kétirányú map-et.

#### ✅ DO

```ts
export const RenderStatus = {
  started: 'started',
  done: 'done',
  failed: 'failed',
} as const;

export type RenderStatus = (typeof RenderStatus)[keyof typeof RenderStatus];
```

#### ❌ DON'T

```ts
// Futásidejű objektumot generál, kétirányú mappeléssel, és nem törölhető.
export enum RenderStatus { started, done, failed }
```

### `skipLibCheck: true`

Nem lazaság: a `node_modules` alatti `.d.ts` fájlok hibáit nem tudod javítani, ellenőrzésük viszont
sokat lassít. Ez az egyetlen „kikapcsolt szigor", ami indokolt.

## Path alias

Használható, de **két helyen kell beállítani**, mert a `tsc` csak a típusokat oldja fel, a futásidőt nem:

```json
{ "compilerOptions": { "baseUrl": ".", "paths": { "@/*": ["src/*"] } } }
```

A futásidőhöz `tsx` (ami olvassa a `tsconfig`-ot), bundler, vagy `tsc-alias` kell. Ha a projekt nem
bundler-alapú, **egyszerűbb relatív importot használni**, mint egy fél-működő aliast hibakeresni.

## Project references monorepóban

```json
{
  "references": [{ "path": "../money" }],
  "compilerOptions": { "composite": true }
}
```

Ettől a `tsc --build` csak azt fordítja újra, ami változott. Enélkül egy nagy monorepóban minden
typecheck a teljes fát végignézi.

## Külön `tsconfig` a teszteknek

A teszt-fájlok ne kerüljenek a build kimenetébe, de typecheckelve legyenek:

```json
// tsconfig.json, a build
{ "include": ["src/**/*"], "exclude": ["**/*.test.ts"] }
```

```json
// tsconfig.test.json, a typecheck
{ "extends": "./tsconfig.json", "include": ["src/**/*", "test/**/*"] }
```
