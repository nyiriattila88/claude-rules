# Lokális futtatás: a `launchSettings.json` megfelelője Node-on

A .NET-ben a `launchSettings.json` egy dolgot ad: **elnevezett futtatási profilokat**, mindegyikhez saját
környezeti változókkal és indítási beállításokkal. Node-on ennek nincs egyetlen beépített megfelelője,
hanem **három eszköz együtt** adja ki ugyanezt:

| Amit a `launchSettings` ad | Node-os megfelelő |
|---|---|
| elnevezett profil | **npm script** (`dev`, `dev:local-db`, `dev:debug`) |
| profilonkénti env változók | **`.env` fájl** + `node --env-file` |
| indítás debuggerrel | **VS Code `launch.json`**, vagy `--inspect` |
| watch/hot reload | **`tsx --watch`** vagy `node --watch` |

## A profil maga: npm scriptek

A `package.json` `scripts` blokkja a profil-lista. Mindig legyen benne ez a négy, ugyanezekkel a
nevekkel, projekttől függetlenül, hogy egy idegen repóban se kelljen keresgélni:

```json
{
  "scripts": {
    "dev": "tsx --watch --env-file=.env.local src/main.ts",
    "build": "tsc --build",
    "typecheck": "tsc --noEmit",
    "test": "vitest",
    "test:ci": "vitest run --coverage",
    "lint": "eslint ."
  }
}
```

- **`dev`** az egyetlen parancs, amivel a projekt lokálisan elindul. Ha ehhez több lépés kell, azok is
  kerüljenek bele, ne egy README-be.
- **`test:ci`** külön van a `test`-től: a CI-nek egyszer kell lefutnia és kilépnie, a fejlesztőnek watch
  módban kell.
- **`typecheck`** akkor is kell, ha a build fordít: a CI ezzel tudja külön mérni a típushibát.

### ❌ DON'T

```json
{
  "scripts": {
    "start": "node dist/main.js"
  }
}
```

Ez csak a **buildelt** kódot indítja. Egy fejlesztőnek így minden mentés után kézzel kell buildelnie,
és ez az a pont, ahol az emberek elkezdik a `dist/`-et szerkeszteni.

## `tsx`: futtatás fordítás nélkül

A `tsx` a `node` drop-in helyettesítője, ami a TypeScriptet menet közben kezeli. **Fejlesztéshez ez az
alapértelmezés**, nem a `ts-node`.

```bash
pnpm add -D tsx
```

- `tsx src/main.ts` egyszeri futtatás,
- `tsx --watch src/main.ts` újraindítás minden mentésnél.

**Node natív TS-támogatása** (24-től stabil `--experimental-strip-types` nélkül) ugyanezt tudja
`node src/main.ts`-szel, de csak **típus-törléssel**: `enum`, `namespace`, parameter property nem megy.
Ha a projekt `erasableSyntaxOnly: true`-val fordít, akkor a natív út is járható, és eggyel kevesebb
függőség kell.

**Éles futtatásra egyik sem való.** Éles kód mindig előre fordított JavaScript (`tsc` vagy bundler),
mert a menet közbeni fordítás indulási időt és memóriát visz el.

## Env változók: `--env-file`, ne `dotenv`

A Node 20.6 óta natívan tud `.env` fájlt olvasni, tehát a `dotenv` csomag és a `import 'dotenv/config'`
sor felesleges.

```bash
node --env-file=.env.local dist/main.js
tsx --env-file=.env.local src/main.ts
```

Több fájl is megadható, és **a később megadott nyer**, ezzel áll elő a rétegezés:

```bash
tsx --env-file=.env --env-file=.env.local src/main.ts
```

### Melyik fájl mihez

| Fájl | Mi van benne | Verziókezelés |
|---|---|---|
| `.env.example` | **minden** kulcs, üres vagy példa értékkel | **commitolva** |
| `.env` | a csapatnak közös, nem titkos alapértékek | commitolva, ha tényleg nem titkos |
| `.env.local` | a fejlesztő saját értékei, titkok | **`.gitignore`-ban** |

Az `.env.example` nem opcionális: ez az egyetlen hely, ahol egy új fejlesztő megtudja, milyen kulcsokat
kell beállítania. A [[ts-configuration]] séma-validálása pedig kikényszeríti, hogy naprakész legyen.

### ❌ DON'T

```ts
// Titok a forrásban, "csak lokálisan".
const apiKey = process.env.API_KEY ?? 'sk-live-a83f...';
```

## Debug

VS Code-ban a `.vscode/launch.json` a `launchSettings.json` legközelebbi rokona. **Commitold**, ez a
csapat közös futtatási profilja:

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "dev (tsx)",
      "type": "node",
      "request": "launch",
      "runtimeExecutable": "tsx",
      "runtimeArgs": ["--env-file=.env.local"],
      "program": "${workspaceFolder}/src/main.ts",
      "console": "integratedTerminal",
      "skipFiles": ["<node_internals>/**"]
    },
    {
      "name": "vitest (current file)",
      "type": "node",
      "request": "launch",
      "runtimeExecutable": "pnpm",
      "runtimeArgs": ["vitest", "run", "${relativeFile}"],
      "console": "integratedTerminal"
    }
  ]
}
```

IDE nélkül `tsx --inspect src/main.ts`, majd `chrome://inspect`.

## Külső függőségek lokálisan

Adatbázis, queue, S3: ne a fejlesztő gépére telepítve, hanem **`docker-compose.yml`-ben**, a repóban.
Egy `docker compose up -d` és a `pnpm dev` együtt teljes környezetet ad, és ugyanaz a compose fájl
használható az integrációs tesztekhez ([[ts-testing]], testcontainers).

### ✅ DO

```yaml
# docker-compose.yml, a lokális futtatás része, nem külön dokumentum
services:
  postgres:
    image: postgres:17-alpine
    ports: ['5432:5432']
    environment:
      POSTGRES_PASSWORD: local
```

### ❌ DON'T

```text
(README: "Telepíts Postgres 17-et, hozz létre egy adatbázist, majd futtasd a migrációkat.")
```

## Node-verzió rögzítése

A `package.json` `engines` mezője **jelzi**, de nem kényszeríti ki. A kikényszerítéshez `.nvmrc`
(vagy `.tool-versions`, `volta` blokk) kell, és a CI ugyanazt olvassa.

```json
{
  "engines": { "node": ">=22" },
  "packageManager": "pnpm@10.15.0"
}
```

A `packageManager` mező a **corepack**-nek szól: ettől mindenki ugyanazzal a pnpm-mel telepít, és a
lockfile nem változik gépenként.
