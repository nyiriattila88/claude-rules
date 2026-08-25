# Függőségek

## Csomagkezelő: pnpm

Az alapértelmezés a **pnpm**. Egy globális store-ból linkel, tehát kevesebb lemezt és időt visz el, és
a `node_modules` szerkezete **szigorú**: egy csomag csak azt látja, amit a `package.json`-jában megadott.

Az npm és a yarn classic lapos `node_modules`-t csinál, amiben egy nem deklarált tranzitív függőség
importja is működik. Az ilyen import **csendben eltörik**, amikor a tranzitív függőség verziója változik.

A `package.json`-ban rögzítsd, melyikkel megy a projekt:

```json
{ "packageManager": "pnpm@10.15.0" }
```

Corepack ezt olvassa, tehát mindenki ugyanazzal telepít, és a lockfile nem változik gépenként.

## Lockfile

- **Commitold** (`pnpm-lock.yaml`), kivétel nélkül, könyvtárnál is.
- **CI-ban `--frozen-lockfile`**: ha a lockfile nem egyezik a `package.json`-nal, a build hasaljon el,
  ne oldja fel újra a fákat. Enélkül a CI mást telepít, mint a fejlesztő gépe.

```bash
pnpm install --frozen-lockfile
```

Az npm megfelelője a `npm ci`. **`npm install` soha nem futhat CI-ban.**

## Verziószámok a `package.json`-ban

| Írásmód | Mit enged | Mikor |
|---|---|---|
| `^1.2.3` | minor és patch | alapértelmezés alkalmazásban is, könyvtárban is |
| `~1.2.3` | csak patch | ha a csomag minor kiadásai törtek már |
| `1.2.3` | semmit | ha egy konkrét verzió kell (build eszköz, ahol a reprodukálhatóság a fontos) |

Alkalmazásnál a `^` biztonságos, mert a **lockfile** rögzíti a tényleges verziót. A caret azt mondja meg,
mi lesz elfogadható a következő szándékos frissítéskor, nem azt, mi települ ma.

## `dependencies` és `devDependencies`

Az elválasztás nem esztétika: a **production image-ből a devDependencies kimarad** (`pnpm prune --prod`),
tehát ami rossz helyre került, az éles futásnál `MODULE_NOT_FOUND`-dal jelentkezik.

| Hova | Mi |
|---|---|
| `dependencies` | ami futásidőben kell: keretrendszer, SDK, Zod, logger |
| `devDependencies` | ami csak buildhez vagy teszthez: TypeScript, vitest, eslint, `@types/*`, tsx |

**Kivétel**: ha a csomag `.d.ts`-t publikál és a fogyasztónak is kell a típus, akkor a `@types/*`
`dependencies`-be megy. Ez csak könyvtárnál fordul elő, alkalmazásnál soha.

## Új függőség felvétele: négy kérdés

1. **Kell egyáltalán?** Sok kis csomag kiváltható 5 sor kóddal. A `left-pad` tanulsága nem az volt, hogy
   rossz csomagot választottak, hanem hogy volt rá csomag.
2. **Karbantartott?** Utolsó kiadás, nyitott issue-k, egyetlen karbantartó vagy több.
3. **Mekkora a függőségi fája?** Egy csomag, ami 40 tranzitívat hoz, 40 potenciális sebezhetőség.
4. **Milyen licenc?** Céges kódban a copyleft licenc (GPL, AGPL) jogi kérdés, nem technikai.

## Sebezhetőség-vizsgálat

```bash
pnpm audit --audit-level high
```

Fusson a CI-ban, de **ne blokkoljon automatikusan** minden találatra: a fejlesztői függőségek
sebezhetőségei ritkán érintik az éles futást, és a vak blokkolás oda vezet, hogy kikapcsolják.
Amit blokkolni érdemes: `high` és `critical` a `dependencies` fában.

## Frissítés

```bash
pnpm outdated
pnpm update --interactive --latest
```

**Rendszeresen, kis lépésekben.** Egy fél év után elvégzett nagy frissítés kockázatosabb, mint tizenkét
havi kicsi, mert egyszerre több breaking change érkezik, és nem lehet megmondani, melyik törte el.

Automatizálásra Renovate vagy Dependabot, csoportosított PR-okkal (patch-ek egyben, majoroknál külön).

## Frissen kiadott csomag a CI-ban

Ha a CI **minimum package age** szabályt futtat (pl. AikidoSec Safe-Chain), akkor egy néhány órája
kiadott verzió `403`-mal elhasal, miközben lokálisan simán települ. Ez **nem a szabály megkerülésével**
oldandó meg, hanem néhány napnál régebbi verzió választásával:

```bash
npm view <csomag> time --json
```

## Verzió lefokozása: a lockfile önmagában nem elég

Egy `pnpm add <csomag>@<régebbi>` **nem** fokozza le a tranzitív csomagokat: a peer-ként feloldott
al-csomagok a legfrissebben maradnak. A lockfile törlése sem elég, mert a pnpm a meglévő `node_modules`
alapján old fel.

A működő sorrend:

```bash
rm -rf node_modules pnpm-lock.yaml
pnpm install
```

és a csomagcsalád rögzítése:

```json
{ "pnpm": { "overrides": { "@remotion/renderer": "4.0.500" } } }
```

Ellenőrzés: keresd a lefokozott verziószámot a lockfile-ban, amíg nulla találat nem lesz a régire.

## Amit ne

- **Ne commitold a `node_modules`-t.**
- **Ne szerkeszd a lockfile-t kézzel.** Ha konfliktus van, oldd fel a `package.json`-ban, majd generáld
  újra.
- **Ne telepíts globálisan** olyat, amitől a build függ. Ami a buildhez kell, az `devDependencies`, és
  `pnpm exec`-kel vagy npm scriptből fut.
