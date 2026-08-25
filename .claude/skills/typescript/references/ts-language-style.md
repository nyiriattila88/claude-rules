# TypeScript nyelvi stílus

## `any` és `unknown`

Az `any` **kikapcsolja a típusellenőrzést** arra az értékre és mindenre, ami belőle származik. Egy `any`
a kódbázis közepén csendben elrontja a körülötte lévő tíz típust is.

Ha egy érték típusa ismeretlen (JSON parse, `catch` blokk, külső könyvtár), az **`unknown`**, nem `any`.
Az `unknown`-t nem lehet használni, amíg le nem szűkíted, és pont ez a lényege.

### ✅ DO

```ts
const parsed: unknown = JSON.parse(raw);
const job = renderJobSchema.parse(parsed);   // innentől típusos, és validált is
```

```ts
try {
  await render();
} catch (error: unknown) {
  const message = error instanceof Error ? error.message : String(error);
  logger.error({ err: error }, message);
}
```

### ❌ DON'T

```ts
const job = JSON.parse(raw) as RenderJob;   // hazugság: semmi nem ellenőrizte
```

```ts
} catch (error: any) {
  logger.error(error.response.data.message);   // három ponton dobhat, egyiken sem szól a fordító
}
```

## `as`: az utolsó lehetőség

A type assertion nem konverzió, hanem **utasítás a fordítónak, hogy hallgasson**. Három elfogadható
esete van, minden más helyett `unknown` + validálás vagy type guard kell:

1. `as const` (literál típus rögzítése),
2. amikor bizonyíthatóan többet tudsz, mint a fordító, **kommenttel indokolva**,
3. teszt-fixture, ahol az objektum szándékosan hiányos.

### ❌ DON'T

```ts
// Kétszeres assertion, hogy elhallgattassuk a hibát. Ez mindig hiba jele.
const config = raw as unknown as Config;
```

## Type guard, ha a szűkítés újrahasznosul

```ts
export const isRenderFailure = (value: unknown): value is RenderFailure =>
  typeof value === 'object' && value !== null && 'reason' in value;
```

A `value is X` visszatérési típus a fordítónak szól. **Cserébe felelősséget vállalsz**: ha a függvény
törzse hazudik, a fordító elhiszi. Ezért a törzs legyen triviálisan ellenőrizhető, vagy használj Zod-ot.

## `interface` vagy `type`

Egy szabály elég: **`type` az alapértelmezés**, `interface` akkor, ha kell a declaration merging (külső
könyvtár típusának bővítése) vagy osztályt implementálsz vele.

A `type` mindent tud, amit az `interface`, plusz uniont, mapped és conditional típust. Az `I` prefix
(`IRenderJob`) magyar viszonteladói szokás, ne használd: a típus és az implementáció megkülönböztetése
nem a névből, hanem a helyéből derül ki.

## Immutability

```ts
type RenderJob = {
  readonly renderId: string;
  readonly tags: readonly string[];
};
```

- **`const` mindenhol**, `let` csak ott, ahol tényleg újraértékelsz. `var` soha.
- **`readonly`** a mezőkön, ahol az érték a létrehozás után nem változik.
- **`readonly T[]`** a tömbökön, amiket csak olvasol. Ettől a `.push()` fordítási hiba lesz, nem egy
  meglepetés két hívási szinttel arrébb.

### ❌ DON'T

```ts
// A hívó tömbjét mutáljuk: a hiba ott jelenik meg, ahol senki nem keresi.
const addTag = (job: RenderJob, tag: string) => { job.tags.push(tag); return job; };
```

### ✅ DO

```ts
const addTag = (job: RenderJob, tag: string): RenderJob => ({ ...job, tags: [...job.tags, tag] });
```

## Async

- **`async`/`await` mindig**, `.then()` láncok helyett.
- **`return await`** `try` blokkon belül: enélkül a `catch` nem fogja el a hibát, és a stack trace is
  csonka lesz.
- **`Promise.all`** párhuzamos, független műveletekre. Egymás után `await`-elt független hívások
  feleslegesen sorosítanak.
- **`Promise.allSettled`**, ha az egyik elhasalása nem szabad hogy elvigye a többit.
- **Ne indíts floating promise-t.** Egy `await` nélkül hagyott async hívás hibája `unhandledRejection`
  lesz, ami Node-on alapból leállítja a folyamatot. Ha tényleg nem érdekel, írd ki: `void doIt();`

### ✅ DO

```ts
const [user, orders] = await Promise.all([fetchUser(id), fetchOrders(id)]);
```

### ❌ DON'T

```ts
// Két független hívás sorosítva: kétszer annyi ideig tart, minden ok nélkül.
const user = await fetchUser(id);
const orders = await fetchOrders(id);
```

## Hibák

Dobj **`Error`-t vagy abból származó típust**, ne stringet vagy objektumot. Csak az `Error`-nak van
stack trace-e, és a legtöbb logger is erre számít.

```ts
export class RenderRequestError extends Error {
  constructor(message: string, readonly renderId?: string) {
    super(message);
    this.name = 'RenderRequestError';
  }
}
```

Részletek: [[ts-error-handling]].

## Nullish operátorok

```ts
const port = config.port ?? 3000;        // csak null/undefined esetén
const port2 = config.port || 3000;       // a 0-t is lecseréli, ami itt hiba
```

A `??` és a `?.` az alapértelmezés. A `||` csak akkor, ha tényleg minden falsy értéket (üres string, 0,
`false`) helyettesíteni akarsz.

## Névtelen függvények kerülése

```ts
// A stack trace-ben "anonymous" jelenik meg, ami hibakereséskor semmit nem mond.
setTimeout(() => { ... }, 1000);

// Ha a callback nem triviális, adj neki nevet:
const flushBuffer = () => { ... };
setTimeout(flushBuffer, 1000);
```

## `node:` prefix a beépített modulokra

```ts
import { readFile } from 'node:fs/promises';   // egyértelmű, hogy beépített
import { readFile } from 'fs/promises';        // egy npm csomag is hívhatná így magát
```

## Amit ne írj

- **Ne írj osztályt, ha nincs állapota.** Egy csak statikus metódusokat tartalmazó osztály egy modul,
  körülményesebben. Exportálj függvényeket.
- **Ne használj `enum`-ot**, lásd [[ts-tsconfig]] (`erasableSyntaxOnly`). `as const` objektum a helyette.
- **Ne írj típus-akrobatikát**, ha egy egyszerűbb típus is elég. Egy hét conditional type-ból álló
  kifejezés, amit senki nem tud olvasni, nem védi jobban a kódot, mint egy `unknown` + validálás.
- **Ne tegyél `!` non-null assertiont** oda, ahol egy `if` is elférne. A `!` ugyanaz, mint az `as`:
  a fordító elhallgattatása.
