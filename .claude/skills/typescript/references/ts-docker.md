# Node-os Dockerfile

## Multi-stage, mindig

Egy egyszakaszos image tartalmazza a fordítót, a devDependencies-t és a forrást is. Ez nagyobb (gyakran
3-5-ször), lassabban indul, és minden benne lévő csomag egy potenciális sebezhetőség.

```dockerfile
FROM node:22-bookworm-slim AS build
WORKDIR /app

RUN corepack enable

# Külön rétegben, a forrás előtt: amíg a függőségek nem változnak, ez a réteg cache-ből jön.
COPY package.json pnpm-lock.yaml ./
RUN pnpm install --frozen-lockfile

COPY tsconfig.json ./
COPY src ./src
RUN pnpm run build

# A devDependencies innentől nem kell.
RUN pnpm prune --prod

FROM node:22-bookworm-slim AS runtime
ENV NODE_ENV=production
WORKDIR /app

COPY --from=build /app/dist ./dist
COPY --from=build /app/node_modules ./node_modules

USER node
EXPOSE 3000

CMD ["node", "dist/main.js"]
```

## Réteg-sorrend: a ritkán változó előre

A `COPY package.json` és a `pnpm install` **a forrás másolása előtt** van. Ha fordítva lenne, minden
kódmódosítás újratelepítené az összes függőséget, ami a build idejének a legnagyobb tétele.

### ❌ DON'T

```dockerfile
COPY . .
RUN pnpm install --frozen-lockfile    # minden apró kódváltozás után újratelepít
```

## `node`, ne `npm start`

```dockerfile
CMD ["node", "dist/main.js"]      # ✅
CMD ["npm", "start"]              # ❌
```

Az `npm start` egy extra folyamatot ékel be, ami **nem adja tovább a signalokat**. Emiatt a `SIGTERM`
nem jut el az alkalmazásig, a graceful shutdown nem fut le, és a konténer leállítása 10 másodperc
után `SIGKILL`-lel végződik, futó kérések közepén.

Az exec forma (`["node", "..."]`) is számít: a shell forma (`CMD node dist/main.js`) shellt indít, ami
ugyanezt a signal-problémát okozza.

## Non-root felhasználó

A `node` image-ben már létezik a `node` user. Egy `USER node` sor elég, és a konténer nem rootként fut.

Ha a `USER` után kell írási jog, azt a `COPY --chown=node:node` adja, ne a `chmod 777`.

## `.dockerignore`

Enélkül a `node_modules`, a `.git`, a `.env` és a `dist` is bekerül a build kontextusba. Ez lassít, és
a `.env` esetében **titkot szivárogtat az image-be**.

```
node_modules
dist
.git
.env*
*.log
coverage
```

## Base image

| Változat | Mikor |
|---|---|
| `node:22-bookworm-slim` | **alapértelmezés**: kicsi, glibc-alapú, minden natív modul működik rajta |
| `node:22` (teljes Debian) | ha build-eszközök kellenek a runtime-ban is, ami ritka |
| `node:22-alpine` | csak akkor, ha a méret kritikus **és** a natív modulokat teszteltétek |
| distroless | maximális szigorúságnál, de nincs benne shell, tehát a hibakeresés nehezebb |

**Az Alpine musl libc-t használ**, nem glibc-t. Emiatt a natív bináris modulok (Chromium, sharp,
canvas, egyes adatbázis-driverek) vagy nem működnek, vagy máshogy. A Remotion dokumentációja
kifejezetten ellenjavallja.

## Tag rögzítés

```dockerfile
FROM node:22-bookworm-slim        # ✅ konkrét major
FROM node:22.11.0-bookworm-slim   # ✅ még szigorúbb, reprodukálható
FROM node:latest                  # ❌ a build ma mást jelent, mint holnap
```

## Chromium és társai

Ha az image headless böngészőt futtat (Puppeteer, Playwright, Remotion), a runtime rétegbe kellenek a
natív függőségek. Ezek hiányában a böngésző elindul és **azonnal meghal**, egy hibaüzenettel, ami egy
hiányzó `.so`-t nevez meg, nem a valódi okot.

```dockerfile
RUN apt-get update && apt-get install -y --no-install-recommends \
    libnss3 libdbus-1-3 libatk1.0-0 libgbm-dev libasound2 libxrandr2 \
    libxkbcommon-dev libxfixes3 libxcomposite1 libxdamage1 libatk-bridge2.0-0 \
    libpango-1.0-0 libcairo2 libcups2 ca-certificates \
    fonts-liberation fonts-noto-color-emoji \
    && rm -rf /var/lib/apt/lists/*
```

Két részlet, ami könnyen kimarad:

- **`fonts-noto-color-emoji`**: enélkül az emoji üres négyzetként renderelődik, és ez csak a kész
  videón/képernyőképen látszik.
- **`rm -rf /var/lib/apt/lists/*`** ugyanabban a `RUN`-ban: külön rétegben már nem csökkenti a méretet.

A böngésző letöltése is **build időben** történjen, ne az első futásnál, különben minden konténer-indítás
megfizeti.

## Memória-korlát

A V8 alapértelmezett heap-limitje nem a konténer memória-korlátjához igazodik. Ha a konténer 512 MB-ot
kap, a V8 ettől még nagyobbra nőne, és az OOM killer **a folyamatot** öli meg, nem a GC-t hívja.

```dockerfile
ENV NODE_OPTIONS="--max-old-space-size=460"   # a konténer-limit alatt, hagyva helyet a nem-heap részeknek
```

## Build-time titkok

```dockerfile
ARG NPM_TOKEN                     # ❌ az ARG a build historyban marad
RUN --mount=type=secret,id=npm    # ✅ BuildKit secret, nem kerül rétegbe
```
