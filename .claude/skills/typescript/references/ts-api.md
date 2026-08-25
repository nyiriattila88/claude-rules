# Node API-k

## Keretrendszer

| Keretrendszer | Mikor |
|---|---|
| **Fastify** | alapértelmezés backend service-hez: gyors, séma-alapú validálás beépítve, jó TypeScript-támogatás |
| **Hono** | ha edge/serverless célpont is van (Lambda, Workers), vagy nagyon kicsi a felület |
| **NestJS** | nagy, sok fejlesztős, OOP-t és DI-t elváró kódbázisnál, ahol a struktúra kikényszerítése többet ér, mint a boilerplate ára |
| **Express** | meglévő kódbázisban. Új projektben nincs oka, a Fastify mindent tud, amit ő |

## A validálás nem opcionális

Minden, ami a folyamathatáron kívülről jön (body, query, path param, header, queue üzenet), **ismeretlen
típusú, amíg nem validáltad**. A TypeScript típus nem validálás: fordítás után nem létezik.

Zod séma **egyszer** definiálva, és abból származik a típus is:

```ts
export const startRenderSchema = z.object({
  compositionId: z.string().min(1),
  inputProps: z.record(z.string(), z.unknown()).optional(),
  codec: z.enum(['h264', 'gif']).default('h264'),
});

export type StartRenderRequest = z.infer<typeof startRenderSchema>;
```

### ✅ DO

```ts
app.post('/renders', async (request, reply) => {
  const body = startRenderSchema.parse(request.body);   // itt dob, ha rossz
  const render = await startRender(body);
  return reply.code(202).send(render);
});
```

### ❌ DON'T

```ts
// A típus hazugság: a fordító elhiszi, a futásidő nem ellenőrzi.
app.post('/renders', async (request, reply) => {
  const body = request.body as StartRenderRequest;
  ...
});
```

## Séma egyszer, OpenAPI belőle

A séma ne létezzen kétszer (egyszer Zod-ként, egyszer OpenAPI YAML-ként): a kettő **el fog térni**.
`zod-to-openapi` vagy `fastify-type-provider-zod` generálja a dokumentumot ugyanabból a sémából, amivel
validálsz.

A dokumentum kiszolgálása **Scalar**-ral vagy Swagger UI-jal, verziózott útvonalon (`/scalar/v1.0`).

## Válaszok

| Helyzet | Státusz |
|---|---|
| létrehozás, ami azonnal kész | `201` + `Location` |
| létrehozás, ami elindult (aszinkron) | `202` + az azonosító, amivel lekérdezhető |
| sikeres olvasás | `200` |
| sikeres törlés | `204` |
| érvénytelen input | `400` (vagy `422`, ha a szintaxis jó, a tartalom rossz) |
| nincs ilyen | `404` |
| állapot-ütközés (már fut, már törölve) | `409` |

**Az aszinkron művelet ne adjon `200`-at.** A `202` azt mondja: elfogadtam, még nincs kész, itt van a
lekérdezéshez az azonosító. Ez a szerződés, nem stílus kérdése.

### Hibaválasz formátuma

Egyetlen alak, mindenhol ugyanaz. A [RFC 9457 (`application/problem+json`)](https://www.rfc-editor.org/rfc/rfc9457)
kész szabvány erre, de bármilyen következetes forma jobb, mint a rétegenként más.

**Belső részlet nem mehet ki**: stack trace, SQL, fájlútvonal, belső hoszt-név. Ezek a támadónak
információt adnak, a hívónak semmit.

## Karakterkódolás

JSON válasznál a `content-type` **tartalmazza a charsetet**:

```ts
reply.header('content-type', 'application/json; charset=utf-8');
```

Enélkül az ékezetes karakterek egyes kliensekben elromlanak, és ez a hiba csak akkor derül ki, amikor a
tesztadat is ékezetes.

## Biztonság

- **`helmet`** vagy `@fastify/helmet`: biztonsági fejlécek (HSTS, CSP, `X-Content-Type-Options`).
- **Rate limit** minden publikus végponton, szigorúbb az autentikációs útvonalon.
- **Payload limit** explicit (`bodyLimit`), különben egy nagy body memóriát esz.
- **CORS** explicit origin-listával, ne `*`-gal, ha hitelesített kérés is jön.
- **Ne írj ki verziószámot** a `Server` fejlécbe vagy hibaválaszba.

## Timeout és megszakítás

Minden kimenő hívásnak legyen **timeoutja**. Timeout nélkül egy lassú upstream a saját szolgáltatásod
összes szálát lefoglalja, és a hiba nálad jelentkezik, nem náluk.

```ts
const response = await fetch(url, { signal: AbortSignal.timeout(5000) });
```

Ha a kliens bontja a kapcsolatot, a `request.raw.signal`-t add tovább a kimenő hívásoknak, hogy a
munka is leálljon.

## Health és version végpont

Két külön dolog, ne mosd össze:

| Végpont | Mit mond | Ki hívja |
|---|---|---|
| `/health` (liveness) | a folyamat él-e, **függőségek nélkül** | az orchestrator |
| `/ready` (readiness) | kiszolgálásra kész-e, **függőségekkel együtt** | a load balancer |
| `/version` | melyik build fut | a deploy ellenőrzése, ember |

A liveness ne kérdezze le az adatbázist: ha az adatbázis pillanatnyilag lassú, az orchestrator
újraindítja az összes egészséges példányodat, és ezzel a részleges hibából teljeset csinál.

## Naplózás kérésenként

Minden kérés kapjon **korrelációs azonosítót** (a beérkező `x-request-id`, vagy generált), és az kerüljön
minden log sorra, illetve a kimenő hívások fejlécébe.

```ts
app.addHook('onRequest', async (request) => {
  request.id = request.headers['x-request-id'] ?? crypto.randomUUID();
});
```
