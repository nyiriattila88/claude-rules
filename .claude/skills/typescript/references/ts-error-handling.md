# Hibakezelés és logolás

## Két fajta hiba, és a különbség számít

| | **Operational** | **Programmer** |
|---|---|---|
| Mi | várható üzemi helyzet: 404, timeout, érvénytelen input, tele lemez | bug: `undefined` dereferálás, rossz típus, elfelejtett `await` |
| Mit tegyünk | kezeljük: válaszoljunk, próbáljuk újra, jelezzük | **álljunk le**, és induljunk újra |
| Miért | a rendszer működik, csak ez a kérés nem sikerült | a folyamat állapota ismeretlen, minden további válasz gyanús |

Ez a legfontosabb megkülönböztetés a Node-os hibakezelésben. Egy programmer errort „kezelni" és tovább
futni annyi, mint egy ismeretlen állapotú folyamattal kiszolgálni a következő kérést.

```ts
export class AppError extends Error {
  constructor(
    message: string,
    readonly statusCode: number,
    readonly isOperational = true
  ) {
    super(message);
    this.name = new.target.name;
  }
}

export class NotFoundError extends AppError {
  constructor(what: string) {
    super(`${what} not found`, 404);
  }
}
```

## Egy központi handler, nem szétszórt `try`/`catch`

A hibakezelés **egy helyen** történjen: ott dől el, mi kerül a logba, mi megy vissza a hívónak, és
leálljon-e a folyamat. A route-ok és a service-ek csak **dobnak**.

### ✅ DO

```ts
// A service dob, nem válaszol.
export const getRender = async (id: string): Promise<Render> => {
  const render = await store.get(id);

  if (render === null) {
    throw new NotFoundError('render');
  }

  return render;
};
```

```ts
// Egy helyen, a keretrendszer hiba-hookjában.
app.setErrorHandler((error, request, reply) => {
  const status = error instanceof AppError ? error.statusCode : 500;

  request.log.error({ err: error }, 'request failed');

  if (error instanceof AppError && !error.isOperational) {
    // Ismeretlen állapot: elengedjük, az orchestrator újraindít.
    process.exit(1);
  }

  // A belső részletek nem mennek ki: stack trace és SQL a hívónak információszivárgás.
  return reply.code(status).send({
    error: status === 500 ? 'Internal server error' : error.message,
  });
});
```

### ❌ DON'T

```ts
// Minden réteg maga dönt, mit válaszol, és a formátum rétegenként más lesz.
try {
  const render = await store.get(id);
  if (!render) return res.status(404).json({ msg: 'nincs ilyen' });
} catch (e) {
  return res.status(500).json({ error: String(e) });   // a stack trace kimegy a hívónak
}
```

## Amit soha nem szabad elnyelni

```ts
// A hiba eltűnik, a rendszer pedig úgy viselkedik, mintha sikerült volna.
try {
  await saveRender(job);
} catch {
  // ignore
}
```

Ha egy hiba tényleg elhanyagolható, azt **le kell írni**, hogy miért, és **logolni kell** legalább
`debug` szinten. Egy néma `catch` blokk garantáltan el fog fedni egy éles hibát.

## `process.on` a lefedetlen esetekre

```ts
process.on('unhandledRejection', (reason) => {
  logger.fatal({ err: reason }, 'unhandled rejection');
  throw reason;   // átadjuk az uncaughtException ágnak, egy helyen záruljon a folyamat
});

process.on('uncaughtException', (error) => {
  logger.fatal({ err: error }, 'uncaught exception');
  process.exit(1);
});
```

Ez nem hibakezelés, hanem **hálószakadás elleni védőháló**: a dolga annyi, hogy a hiba bekerüljön a
logba, mielőtt a folyamat meghal.

## `SIGTERM`: graceful shutdown

Konténerben ez nem opcionális. A `SIGTERM` az orchestrator kérése, hogy fejezd be. Ha nem kezeled, a
futó kérések félbeszakadnak, és minden deploy hibás válaszokat termel.

```ts
const shutdown = async (signal: string) => {
  logger.info({ signal }, 'shutting down');

  // Sorrend: előbb ne fogadjunk újat, aztán fejezzük be a folyamatban lévőket, végül a kapcsolatokat.
  await server.close();
  await db.end();

  process.exit(0);
};

process.on('SIGTERM', () => { void shutdown('SIGTERM'); });
process.on('SIGINT', () => { void shutdown('SIGINT'); });
```

## Logolás

**`console.log` nem logolás.** Nincs szintje, nincs struktúrája, nem kereshető, és szinkron írásnál
blokkolja az event loopot. Használj **pino**-t (gyors, JSON kimenet) vagy winstont.

### A négy szabály

1. **Strukturált JSON**, ne szöveg. A log-aggregátor mezőre szűr, nem regexre.
2. **stdout-ra írj**, ne fájlba. A fájl rotálása, gyűjtése az infrastruktúra dolga, nem az alkalmazásé.
3. **Korrelációs azonosító** minden log soron, hogy egy kérés összes sora összefűzhető legyen.
4. **Titok soha.** Jelszó, token, teljes kérés-body, személyes adat nem kerülhet logba.

### ✅ DO

```ts
logger.info({ renderId, compositionId, durationMs }, 'render finished');
```

### ❌ DON'T

```ts
console.log(`Render ${renderId} finished in ${durationMs}ms`);   // nem kereshető mezőre
logger.info({ config }, 'starting');                             // a config titkokat tartalmaz
logger.info({ request }, 'incoming');                            // a teljes body, benne minden
```

### Mit logolj hibánál

A hiba **objektumként** menjen a loggernek (`{ err: error }`), ne stringgé alakítva. A pino és a winston
is tudja a stack trace-t szerializálni, `String(error)` esetén viszont csak az üzenet marad.

## Retry: csak ott, ahol értelme van

- **Csak idempotens műveletet** ismételj. Egy `POST /payments` újraküldése kétszer terhel.
- **Exponential backoff jitterrel**, ne fix késleltetéssel. Fix késleltetésnél minden kliens egyszerre
  próbálkozik újra, és pont akkor terhelik a szolgáltatást, amikor amúgy is baja van.
- **Csak átmeneti hibára**: timeout, 429, 5xx. Egy 400-at hiába ismételsz.
- **Legyen felső korlát**, és a végén dobj, ne térj vissza csendben egy üres eredménnyel.
