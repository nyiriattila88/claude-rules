# Tesztelés

Az alapértelmezés a **vitest**. Gyorsabb, mint a jest, natívan érti az ESM-et és a TypeScriptet, és
ugyanaz az API (`describe`/`it`/`expect`), tehát nincs tanulási költsége.

## Mit teszteljünk, milyen arányban

A klasszikus piramis Node-os backenden félrevisz: rengeteg unit teszt születik, amiből egy sem mondja
meg, hogy az API működik-e. A használható arány:

| Szint | Mit fed le | Arány |
|---|---|---|
| **Komponens (API) teszt** | a service-t a saját belépési pontján át, in-process, valódi DB-vel vagy testcontainerrel | **a legtöbb** |
| **Unit teszt** | üzleti szabályt, algoritmust, számítást, ami magában is értelmes | ahol a logika sűrű |
| **E2E** | a deployolt rendszert kívülről, a legfontosabb néhány folyamatra | néhány darab |

A komponens-teszt az, ami a legtöbbet fizeti vissza: a route-tól az adatbázisig mindent lefed, mégis
gyors, és nem törik el egy refaktortól, ami nem változtatta meg a viselkedést.

## A teszt neve három részből áll

**Mit** tesztelünk, **milyen körülmények között**, **mit várunk**. Egy hibás teszt neve önmagában
elmondja, mi romlott el, anélkül hogy a kódot el kellene olvasni.

### ✅ DO

```ts
it('rejects a render request when the composition id is empty', async () => { ... });
it('closes the registry row as failed when the task stopped without reporting', async () => { ... });
```

### ❌ DON'T

```ts
it('works', async () => { ... });
it('test cancel', async () => { ... });
```

## AAA szerkezet

Három blokk, üres sorral elválasztva: **Arrange**, **Act**, **Assert**. Kommentek nélkül is látszik.

### ✅ DO

```ts
it('returns the second bucket after the cache expired', async () => {
  send.mockResolvedValueOnce(parameters()).mockResolvedValueOnce(parameters({ BucketName: 'moved' }));
  const { getContract } = await loadContract();

  const before = await getContract();
  vi.advanceTimersByTime(TTL_MS + 1);
  const after = await getContract();

  expect(before.bucketName).not.toBe(after.bucketName);
});
```

### ❌ DON'T

```ts
// Act és assert összefonva: ha elhasal, nem derül ki, melyik lépésnél.
it('caches', async () => {
  expect((await (await loadContract()).getContract()).bucketName).toBe('poc-renderer-s4-eucentral1');
  expect(send).toHaveBeenCalledTimes(1);
});
```

## Minden teszt a saját adatát hozza

Közös fixture, amit több teszt olvas **és** ír, két bajt okoz: a tesztek sorrendfüggők lesznek, és egy
elhasalás után a többi is elhasal, ami elrejti az igazi hibát.

### ✅ DO

```ts
const aRenderJob = (overrides: Partial<RenderJob> = {}): RenderJob => ({
  renderId: `test-${crypto.randomUUID()}`,
  compositionId: 'Storyboard',
  status: 'started',
  ...overrides,
});
```

### ❌ DON'T

```ts
// Globális, mutálható fixture: az egyik teszt átírja, a másik ezen bukik el.
const job = { renderId: 'abc', status: 'started' };
```

## Mit ellenőrizz egy komponens-tesztben

Egy kérésnek öt fajta megfigyelhető hatása lehet. Ne csak az elsőt nézd:

1. a **válasz** (státuszkód, body),
2. az **állapotváltozás** (mit ír az adatbázisba, olvasd is vissza),
3. a **kimenő hívás** (mit küldött egy külső API-nak),
4. az **üzenet** (mit tett queue-ba),
5. a **megfigyelhetőség** (hibánál keletkezett-e log, metrika).

### ✅ DO

```ts
it('records the started render before answering', async () => {
  const response = await app.inject({ method: 'POST', url: '/renders', payload: aRequest() });

  expect(response.statusCode).toBe(202);

  // 2. az állapotváltozás: a válasz azt is jelenti, hogy a sor létrejött
  const stored = await store.get(response.json().renderId);
  expect(stored?.status).toBe('started');
});
```

## Külső hálózati hívás: `nock` vagy `msw`

Ne az SDK-t mockold, hanem a **HTTP réteget**. Az SDK mockolása azt teszteli, hogy jól hívod-e a saját
mockodat, egy SDK-frissítés pedig csendben eltörheti a valódi hívást úgy, hogy a teszt zöld marad.

### ✅ DO

```ts
nock('https://api.example.com').post('/v1/jobs').reply(202, { id: 'job-1' });
```

### ❌ DON'T

```ts
// Ez a saját mockot teszteli, nem a hívást.
vi.mock('./example-client', () => ({ createJob: vi.fn().mockResolvedValue({ id: 'job-1' }) }));
```

Kivétel: **AWS SDK**, ahol a hálózati mockolás a signature-számítás miatt körülményes. Ott a `send`
metódust mockolni elfogadott, ahogy az `aws-sdk-client-mock` teszi.

## Adatbázis: testcontainers, ne in-memory helyettes

Egy in-memory helyettesítő (sqlite Postgres helyett, `dynalite` DynamoDB helyett) mást tud, mint az
éles. A hiba, amit így nem veszünk észre, éppen az, amit tesztelni akartunk.

```ts
const container = await new PostgreSqlContainer('postgres:17-alpine').start();
```

Ha ez túl lassú a fejlesztői ciklushoz, akkor **taggeld** a lassú teszteket, és a gyors körben hagyd ki
őket, de a CI futtassa mindet.

## `vi.useFakeTimers()` a TTL és a retry teszteléséhez

Egy cache-TTL vagy exponential backoff tesztelése valós idővel értelmetlen (percekig futna). Fake
timerrel az idő ugrik, a teszt milliszekundum alatt lefut.

```ts
beforeEach(() => { vi.useFakeTimers(); });
afterEach(() => { vi.useRealTimers(); });   // enélkül a következő teszt fájl is fake időt kap
```

## Coverage: mérőszám, nem cél

A coverage arra jó, hogy **megtalálja a nem tesztelt ágakat**, nem arra, hogy egy számot elérjünk. Egy
95%-os coverage, ami csak `expect(result).toBeDefined()`-ot tartalmaz, semmit nem véd.

Amit érdemes kikényszeríteni: **ne csökkenjen**. Egy abszolút küszöb (`80%`) vagy megvalósíthatatlan,
vagy értelmetlen, projekttől függően.

## Amit ne tegyél

- **Ne tesztelj implementációt.** Ha egy privát metódus átnevezése eltör egy tesztet, a teszt rossz.
- **Ne használj fix portot.** Két párhuzamos teszt ütközik rajta. `listen(0)` szabad portot kér.
- **Ne hagyj `only`-t a kódban.** Egy bent felejtett `it.only` a CI-t zölden hagyja, miközben egyetlen
  teszt fut. Az `eslint` `no-only-tests` szabálya ezt kifogja.
- **Ne `expect`-elj `try`/`catch`-ben** anélkül, hogy `expect.assertions(n)`-t is írnál: ha nem dob, a
  teszt zöld marad, pedig épp az volt az elvárás, hogy dobjon. Egyszerűbb: `await expect(...).rejects`.
