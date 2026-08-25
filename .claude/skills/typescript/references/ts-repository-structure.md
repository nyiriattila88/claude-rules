# TypeScript repo- és mappaszerkezet

A cél, hogy **egy új fejlesztő a mappaneveket olvasva megértse, mit csinál a rendszer**, ne azt, hogy
milyen technikai rétegekből áll.

## Komponens szerint tagolj, ne típus szerint

A `controllers/`, `services/`, `models/`, `utils/` felosztás azt mondja el, **hogyan** épül fel a kód,
nem azt, hogy **miről** szól. Egy `orders` funkció megváltoztatása így négy mappát érint, és semmi nem
akadályozza meg, hogy bármelyik rész bármelyikbe belenyúljon.

A komponens-alapú tagolás minden üzleti egységet egy mappába zár. A rétegek **azon belül** jelennek meg.

### ✅ DO

```
src/
  orders/
    orders.routes.ts       belépési pont, vékony
    orders.service.ts      üzleti logika
    orders.repository.ts   adathozzáférés
    orders.schema.ts       Zod séma, a szerződés
    orders.test.ts         a teszt a kód mellett
  users/
    ...
  shared/                  amit tényleg több komponens használ
    http/
    logging/
  main.ts                  a folyamat indítása, semmi más
```

### ❌ DON'T

```
src/
  controllers/     orders, users, payments mind itt
  services/        orders, users, payments mind itt
  models/          orders, users, payments mind itt
  utils/           minden, aminek nem találtunk helyet
```

## Három réteg komponensen belül

| Réteg | Mit tartalmaz | Mit NEM |
|---|---|---|
| entry point (`*.routes.ts`, handler, consumer) | HTTP/queue-specifikus dolgok: útvonal, státuszkód, header | üzleti szabályt |
| domain (`*.service.ts`) | az üzleti logika, keretrendszer-független | `req`/`res` objektumot, SQL-t |
| data access (`*.repository.ts`) | lekérdezés, mappelés | üzleti döntést |

A domain rétegnek **nem szabad ismernie a keretrendszert**. Ha egy service-be bekerül a `req`, akkor a
logika csak HTTP-n keresztül tesztelhető, és egy queue consumer nem tudja újrahasználni.

### ✅ DO

```ts
// orders.service.ts, keretrendszer-független
export const cancelOrder = async (orderId: string, reason: string): Promise<Order> => { ... };

// orders.routes.ts, vékony
app.post('/orders/:id/cancel', async (request, reply) => {
  const order = await cancelOrder(request.params.id, request.body.reason);
  return reply.code(200).send(order);
});
```

### ❌ DON'T

```ts
// A service ismeri a HTTP-t, tehát a logika csak HTTP-n át tesztelhető.
export const cancelOrder = async (req: Request, res: Response) => {
  const order = await db.orders.findById(req.params.id);
  if (!order) return res.status(404).send({ error: 'not found' });
  ...
};
```

## `utils/`: a mappa, ami mindent elnyel

Az `utils/` nevű mappa idővel a projekt szemetes fiókja lesz. Két szabály tartja kordában:

- **Ha egy segédfüggvényt egyetlen komponens használ, ott a helye**, nem a `shared/`-ben.
- **Ha többen használják, adj neki nevet**: `shared/money/`, `shared/dates/`, nem `utils/helpers.ts`.

Ha egy `shared/` alatti egység mérete és stabilitása indokolja, csináljon belőle **külön csomagot** saját
`package.json`-nal (monorepóban workspace package). Ettől a határa kikényszerített lesz, nem konvenció.

## Entry point: egy fájl, ami csak indít

A `main.ts` (vagy `index.ts`) dolga a **folyamat** elindítása: konfiguráció betöltése, függőségek
összeállítása, szerver indítása, `SIGTERM` kezelése. Üzleti logika nem lehet benne, és **modul-szinten
nem lehet mellékhatása** (adatbázis-kapcsolat, hálózati hívás), különben minden teszt, ami importálja,
elindítja az egész alkalmazást.

### ✅ DO

```ts
// main.ts
const config = loadConfig();
const app = buildApp(config);

const server = await app.listen({ port: config.port, host: '0.0.0.0' });

process.on('SIGTERM', () => { void server.close(); });
```

### ❌ DON'T

```ts
// Modul-szintű mellékhatás: az import maga nyit egy kapcsolatot.
export const db = await connectToDatabase(process.env.DATABASE_URL!);
```

## Barrel fájlok (`index.ts`, ami újraexportál)

Kis csomagon belül hasznos, **nagy projektben viszont árt**: kör-importot okoz, elrontja a tree
shakinget, és a build idejét is növeli. A szabály: **barrel csak csomaghatáron**, komponensen belül ne.

### ✅ DO

```ts
// shared/money/index.ts, ez a csomag publikus felülete
export { formatAmount, parseAmount } from './amount';
```

### ❌ DON'T

```ts
// orders/index.ts, ami mindent újraexportál, és amit a saját komponens fájljai is importálnak:
// kör-import, és a bundler sem tud rajta segíteni.
export * from './orders.service';
export * from './orders.repository';
export * from './orders.routes';
```

## Tesztek helye

A teszt **a tesztelt fájl mellett** legyen (`orders.service.test.ts`), ne egy párhuzamos `test/`
fában. Így egy fájl átnevezésekor a teszt vele mozog, és látszik, ha egy modulhoz nincs teszt.

Kivétel az **end-to-end** és a **smoke** teszt: ezek nem egy modulhoz tartoznak, hanem a futó
rendszerhez, tehát külön mappában (`test/e2e/`, `test/smoke/`) a helyük.

## Elnevezés

| Mi | Hogyan | Példa |
|---|---|---|
| Fájl | kebab-case | `render-job-store.ts` |
| Mappa | kebab-case, egyes szám a komponensnél | `order/`, `shared/http/` |
| Típus, interface, osztály | PascalCase, **`I` prefix nélkül** | `RenderJob`, nem `IRenderJob` |
| Függvény, változó | camelCase | `startRender` |
| Konstans | camelCase vagy SCREAMING_SNAKE, de **egységesen** | `MAX_RETRIES` |

## Monorepo

Több csomagnál a `pnpm workspace` az alapértelmezés (a `packages/` vagy `apps/` + `packages/` bontással).
Két dolog kell hozzá, különben a monorepo lassabb lesz, mint amennyit ér:

- **TypeScript project references** a csomagok között, hogy ne kelljen mindent újrafordítani,
- **explicit függőségek**: egy csomag csak azt importálhatja, ami a `package.json`-jában szerepel.

### ❌ DON'T

```ts
// Csomagok közti mély import: megkerüli a publikus felületet, és a refaktor eltöri.
import { parseAmount } from '../../../packages/money/src/amount';
```

### ✅ DO

```ts
import { parseAmount } from '@nexius/money';
```
