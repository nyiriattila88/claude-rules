# Config-rétegezés

Egy jó konfigurációs réteg hat dolgot ad. Ha bármelyik hiányzik, az működés közben derül ki:

1. **Rétegezés**: az érték több forrásból jöhet, és tudjuk, melyik nyer.
2. **Titkok a kódon kívül**, verziókezelésen kívül.
3. **Hierarchia**: `render.task.cpu`, nem `RENDER_TASK_CPU_MAYBE_2`.
4. **Típusosság**: a `port` `number`, nem `string`.
5. **Validálás, fail fast**: hibás konfigurációval **el sem indul** a folyamat.
6. **Alapérték minden kulcshoz**, vagy explicit „kötelező" jelölés.

## A rétegek és a sorrendjük

Alulról felfelé, a **később olvasott nyer**:

```
1. kódban lévő default            (a séma alapértéke)
2. környezeti config fájl         (.env, config/production.json)
3. környezeti változó             (process.env, a konténer adja)
4. futásidőben olvasott titok     (SSM, Secrets Manager, Vault)
```

A 3. réteg a legfontosabb: **konténerben a környezeti változó az elsődleges csatorna**, mert az
orchestrator ezt tudja adni redeploy nélkül. A 4. réteg külön van, mert a titkoknak más az életciklusa
(rotálódnak), és nem szabad a build-artifactba kerülniük.

## Validálás Zod-dal, induláskor

```ts
import { z } from 'zod';

const configSchema = z.object({
  nodeEnv: z.enum(['development', 'test', 'production']).default('development'),
  port: z.coerce.number().int().positive().default(3000),
  logLevel: z.enum(['debug', 'info', 'warn', 'error']).default('info'),
  databaseUrl: z.string().url(),
  renderTimeoutSeconds: z.coerce.number().int().min(1).max(3600).default(900),
});

export type Config = z.infer<typeof configSchema>;

/**
 * A folyamat indulásakor egyszer fut le. Ha bármi hiányzik vagy rossz típusú, itt áll meg, nem az
 * első kérésnél.
 */
export const loadConfig = (): Config => {
  const parsed = configSchema.safeParse({
    nodeEnv: process.env.NODE_ENV,
    port: process.env.PORT,
    logLevel: process.env.LOG_LEVEL,
    databaseUrl: process.env.DATABASE_URL,
    renderTimeoutSeconds: process.env.RENDER_TIMEOUT_SECONDS,
  });

  if (!parsed.success) {
    // A hibaüzenet nevezze meg a kulcsot: "invalid config" önmagában semmit nem mond az üzemeltetőnek.
    console.error('Invalid configuration:', z.treeifyError(parsed.error));
    process.exit(1);
  }

  return parsed.data;
};
```

Három dolog, ami ezt jóvá teszi:

- **`z.coerce.number()`**: minden env változó string, a séma alakítja számmá. Enélkül a `port` string
  marad, és a `server.listen('3000')` másképp viselkedik, mint a `listen(3000)`.
- **`.default(...)`**: az alapérték a sémában van, egy helyen, nem szétszórva `?? 3000` alakban.
- **`process.exit(1)`**: nem dob kivételt, amit egy globális handler elnyelhet. A hibás konfiguráció nem
  futásidejű hiba, hanem indítási hiba.

## A config objektum átadása, ne globális import

A betöltött config **paraméterként** menjen, ne modul-szintű singletonként importálva. Így tesztelhető
(más configgal is példányosítható), és nem lesz betöltési sorrend-függőség.

### ✅ DO

```ts
export const buildApp = (config: Config) => {
  const app = fastify({ logger: { level: config.logLevel } });
  app.register(ordersRoutes, { timeoutSeconds: config.renderTimeoutSeconds });
  return app;
};
```

### ❌ DON'T

```ts
// Minden modul importálja, tehát minden teszt is betölti, és az env-nek már be kell lennie állítva.
import { config } from './config';

const app = fastify({ logger: { level: config.logLevel } });
```

## `process.env` egy helyen

A `process.env` **kizárólag a config modulban** szerepelhet. Ha bárhol máshol felbukkan, akkor az a
kulcs kikerült a sémából, tehát nincs validálva, nincs alapértéke, és nem szerepel az `.env.example`-ben.

Ezt érdemes lintelni: az `eslint` `no-restricted-properties` szabálya vagy egy `no-process-env` szabály
kivétellel a config fájlra.

### ❌ DON'T

```ts
// orders.service.ts, 300 sorral a config modul után
const retries = Number(process.env.ORDER_RETRIES ?? 3);
```

## Futásidőben olvasott titkok

Ha a titok külső tárból jön (SSM Parameter Store, Secrets Manager), akkor **külön réteg**, mert
aszinkron és mert változhat a folyamat élete során.

- **Cache-elj TTL-lel**, ne örökre. Egy hetekig futó service különben a rotálás előtti értéket használja.
- **Ne cache-eld a hibát.** Egy elutasított promise elmentve egy rossz olvasásból véglegesen rossz
  állapotot csinál.
- **Nevezd meg a hiányzó kulcsot** a hibaüzenetben.

```ts
const TTL_MS = 5 * 60 * 1000;
let cached: Promise<Secrets> | undefined;
let loadedAt = 0;

export const getSecrets = (): Promise<Secrets> => {
  if (cached === undefined || Date.now() - loadedAt > TTL_MS) {
    loadedAt = Date.now();
    cached = loadSecrets().catch((error: unknown) => {
      cached = undefined;   // a hibát nem tartjuk meg
      throw error;
    });
  }

  return cached;
};
```

## Amit soha

- **Ne logold a teljes config objektumot.** Egy titkot tartalmazó mező így kerül a log-aggregátorba.
  Ha kell a diagnosztika, a titkos mezőket cseréld `'[redacted]'`-re.
- **Ne ágazz `NODE_ENV`-re üzleti logikában.** A `NODE_ENV` a futtatókörnyezet optimalizálását vezérli,
  nem azt, hogy mit csinál a rendszer. Ha egy viselkedés környezetenként más, annak **saját kulcsa**
  legyen (`features.dryRun`), különben a teszt-környezet nem azt futtatja, amit az éles.

### ❌ DON'T

```ts
if (process.env.NODE_ENV !== 'production') {
  skipPaymentValidation();   // a staging így mást csinál, mint az éles, pont ott, ahol nem szabadna
}
```

### ✅ DO

```ts
if (config.features.skipPaymentValidation) {
  ...
}
```
