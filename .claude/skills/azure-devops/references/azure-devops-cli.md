# Azure DevOps CLI

Az Azure DevOps CLI nem önálló program: az **Azure CLI (`az`) `azure-devops` extension**-je. Innen jön a legtöbb meglepetés — az auth, a quoting és a telepítés-ellenőrzés is máshogy működik, mint amire az `az` többi parancsánál számítanál.

## Előfeltétel-ellenőrzés (mielőtt telepítenél)

A **"nincs Azure DevOps client telepítve"** gyakori téves diagnózis. Az `az` CLI és az `azure-devops` extension sokszor már fent van, sőt bekonfigurált defaultokkal. Ellenőrizd ebben a sorrendben, és csak a legvégén telepíts:

1. **Van `az`?** — `Get-Command az`
2. **Van extension?** — `az extension list --query "[].name"` (vagy nézd a `$env:USERPROFILE\.azure\cliextensions` mappát; a `--query` PowerShell-trapre lásd lentebb)
3. **Vannak defaultok?** — `az devops configure --list`
4. **Él az auth?** — egy read-only smoke test: `az devops project list`

Csak ha a 2. lépés tényleg üres:

```bash
az extension add --name azure-devops
```

### ✅ DO

```text
Előbb `az devops configure --list` + egy read-only smoke test, és csak akkor telepítek,
ha az extension tényleg hiányzik.
```

### ❌ DON'T

```text
(A felhasználó azt kérdezi, van-e telepítve → azonnal futtatok egy `az extension add`-et
és végigviszem a teljes setupot, pedig már minden működött.)
```

## Authentikáció — PAT, nem `az login`

Az `az devops` **Personal Access Token**-nel authentikál. Az `az login`-nal szerzett ARM-token ehhez alapesetben nem elég, és `az login` nélkül is tökéletesen működik minden `az devops`/`az repos`/`az pipelines` parancs.

### Hol van a token

Windowson a PAT a **Windows Credential Manager**-ben van, `azdevops-cli:https://dev.azure.com/<org>` target alatt (az org rész **kisbetűsítve** kerül be, akkor is, ha a configban CamelCase-ben áll):

```powershell
cmdkey /list | Select-String -Pattern 'azdevops-cli'
```

### Token beállítása / cseréje

```bash
az devops login --org https://dev.azure.com/<org>
```

Interaktívan bekéri a PAT-ot, és a Credential Managerbe teszi. Non-interaktív (CI, script) útvonal az `AZURE_DEVOPS_EXT_PAT` env var — de **ne** írd tartós user-scope env varba: az plaintext tokent hagy a gépen. Session-szintű vagy CI secret igen, `[Environment]::SetEnvironmentVariable(...,'User')` nem.

### Tipikus PAT scope-ok

| Feladat | Scope |
|---|---|
| repo/PR olvasás | Code (Read) |
| PR nyitás, szavazás | Code (Read & Write) |
| pipeline/build lekérdezés | Build (Read) |
| pipeline indítás | Build (Read & Execute) |
| work item olvasás/írás | Work Items (Read) / (Read & Write) |

Új token: `https://dev.azure.com/<org>/_usersSettings/tokens` → **New Token**.

### Hibadiagnózis

| Tünet | Ok | Teendő |
|---|---|---|
| `TF400813`, `401 Unauthorized` | lejárt vagy visszavont PAT | **új PAT + `az devops login`** — ne telepíts újra, ne `az login` |
| `403 Forbidden` egy konkrét parancsnál | a PAT scope-ja kevés | új token a hiányzó scope-pal |
| `Please run 'az login' to setup account` | **nem** az `az devops` hibája — egy sima `az` (ARM) parancsot futtattál | ez az `az devops`-t nem érinti |
| interaktív token-prompt scriptben beakad | nincs tárolt credential | `AZURE_DEVOPS_EXT_PAT`, vagy előbb `az devops login` |

### ✅ DO

```text
401-et kaptam az `az repos list`-re → a tárolt PAT lejárt.
Kérek új tokent Code (Read) scope-pal, majd `az devops login --org ...`.
```

### ❌ DON'T

```text
401-et kaptam → `az login`-t javaslok és újratelepítem az extensiont.
(Egyik sem segít: az `az devops` nem az ARM-tokent használja.)
```

## Defaultok

```bash
az devops configure --defaults organization=https://dev.azure.com/<org> project=<project>
```

Ha be vannak állítva, **hagyd el** a `--org`/`-p` flageket — rövidebb parancs, kevesebb token. Kivétel: **megosztott vagy scriptbe kerülő** recepthez írd ki explicit, mert a default gépfüggő, és a másik gépen csendben más org ellen futna.

## PowerShell quoting trap (kritikus)

Windowson az `az` valójában egy `az.cmd` **batch wrapper**. A `cmd.exe` a `(`/`)` karaktereket a saját szintaxisaként értelmezi, ezért a `--query` JMESPath kifejezés zárójelei szétesnek, mielőtt Pythonhoz érnének:

```
-o was unexpected at this time.
```

Ez **nem** az `az` hibája és nem a JMESPath-é — a shell wrapper eszi meg. Bash (Git Bash, WSL) alól a `--query` gond nélkül működik; a trap PowerShell/cmd-specifikus.

### ✅ DO

```powershell
# Client-side szűrés: a zárójel sosem megy át a cmd wrapperen
(az repos list -o json | ConvertFrom-Json).Count

$runs = az pipelines runs list --pipeline-ids 42 --top 10 -o json | ConvertFrom-Json
$runs | Where-Object { $_.result -ne 'succeeded' } | Select-Object id, result, sourceBranch
```

```powershell
# Zárójel nélküli, egyszerű --query továbbra is jó
az repos list --query "[].name" -o tsv
```

### ❌ DON'T

```powershell
# Elhasal: a length(@) zárójelei a cmd wrapperen törnek meg
az repos list --query "length(@)" -o tsv
```

```powershell
# Megoldja ugyan, de elveszíted a változó-behelyettesítést az egész sorra
az --% repos list --query "length(@)" -o tsv
```

## Engedélymodell — read szabad, write engedélyköteles

Ugyanaz a modell, mint a [[git-conventions]] push-policy és a [[terraform-terragrunt]] `apply`: a **remote állapotát megváltoztató** parancs sosem indul magadtól.

| Szabadon futtatható (read-only) | Engedélyköteles (mutáló) |
|---|---|
| `az devops project list`, `az devops configure --list` | `az pipelines run`, `az pipelines build queue` |
| `az repos list/show`, `az repos pr list/show` | `az repos pr create/update/set-vote`, `az repos pr policy` |
| `az pipelines list/show`, `az pipelines runs list/show` | `az repos create/delete`, `az repos policy create` |
| `az boards query`, `az boards work-item show` | `az boards work-item create/update/delete` |
| `az devops invoke` **GET**-tel | `az devops invoke` POST/PATCH/PUT/DELETE-tel |
| `az artifacts universal download` | `az devops service-endpoint create/delete`, `az devops user add` |

Külön kiemelve: az **`az pipelines run` valódi deployt indíthat** egy környezetbe. Egy "futtasd le a pipeline-t" kérés is előbb visszakérdezést érdemel, ha nem derül ki egyértelműen, melyik pipeline melyik környezetre megy.

### ✅ DO

```text
Megvan a PR-hoz tartozó pipeline (id=42). Elindítsam a runt a feature branchen,
vagy csak az utolsó futás eredményét nézzem meg?
```

### ❌ DON'T

```text
(A felhasználó a futások eredményére kérdezett rá → én "hasznosságból" újra is
indítom a pipeline-t, hogy friss adat legyen.)
```

## Koncepció-validálás temporary change-dzsel

Egy Azure DevOps pipeline visszajelzési ciklusa lassú: a change csak a remote-on érvényesül, futnia kell hozzá, **scheduled (cron) trigger** esetén pedig meg is kell várni az ütemezést. Egy állítás — „a cron tényleg elindítja a pipeline-t" — lokálisan nem validálható.

Ilyenkor **szabad ideiglenes változtatást tenni**, ami lerövidíti a ciklust: sűrűbb cron, külön eldobható probe pipeline, kihagyott stage, ideiglenesen kikapcsolt condition. Ez nem hack, hanem a validáció eszköze — de csak a **jelöl → validál → revert** hármassal együtt érvényes.

### Előbb: mit validálsz?

| A kérdés | Kell-e temporary change |
|---|---|
| Jó-e a pipeline **tartalma** (task, script, változó) | **Nem.** Egy manuális futtatás (`az pipelines run`, engedélyköteles) ugyanezt megválaszolja. |
| Elsül-e maga a **trigger** (cron, PR-, path-filter) | **Igen.** A manuális run megkerüli a triggert, ezért semmit nem bizonyít róla. |

### Kötelező elemek

1. **Jelöld egyértelműen.** A temporary artifact neve/kommentje árulja el magát: `temp_cron_probe.yml`, `# TEMP: validation only, revert`. Így egy `git status`-ból is látszik, mi maradt bent.
2. **Vezess listát arról, mit nyúltál meg.** A revert csak akkor teljes, ha minden érintett fájl szerepel rajta — új fájl, módosított cron, kikapcsolt condition.
3. **A revert kötelező, és nem függ az eredménytől.** Bukott validáció után is revertálsz; utána ellenőrizd is (`git status` tiszta, a diff a kiindulási állapothoz képest üres).
4. **Temporary change soha nem kerül PR-ba vagy merge-be.** Ha a ciklushoz commit kellett, a revert is saját commit — vagy a validációs commitok kikerülnek a branchből.
5. **A push továbbra is engedélyköteles** ([[git-conventions]]). Mivel a temporary change push nélkül semmit nem validál, **egyszer** kérj engedélyt a **teljes ciklusra** (validációs push + revert push), ne körönként.
6. **Prod-ot ne érintsen.** Sűrített cron vagy probe csak nem-prod pipeline-on; deploy pipeline-t ne tegyél gyakori ütemezésre — ötpercenkénti valódi deploy lesz belőle.
7. **A probe legyen no-op.** Egy `echo`-nyi script gyorsabban fordul, nem éget agent-időt, és nem tol ki valódi artifactot.

### Cron trigger — előbb a nem-futtatós ellenőrzés

Mielőtt sűrítenél és megvárnál egy futást, nézd meg, hogy a schedule **egyáltalán érvényesült-e** — ez azonnali, futás nélkül:

- A pipeline **Triggers → Scheduled runs** nézete listázza a következő ütemezett futásokat. Ha üres, a cron nem él, és a várakozás felesleges.
- CLI-ből a definition `triggers` mezője mutatja ugyanezt: `az pipelines show --id <id> -o json | ConvertFrom-Json`, majd a `.triggers` vizsgálata.

Négy klasszikus ok, amiért „nem fut a cron" — egyiket sem oldja meg a sűrítés:

| Ok | Mit jelent |
|---|---|
| A schedule a **default branch** YAML-jéből olvasódik ki | A feature branchen módosított `schedules:` blokk önmagában nem lép életbe; a `branches: include:` csak azt mondja meg, *melyik* branchre fusson. |
| `always` alapból `false` | Nincs új commit az előző ütemezett futás óta → a scheduler kihagyja. Validációhoz szinte mindig kell az `always: true`. |
| A cron **UTC**-ben jár | Lokális idő szerint számolva „nem indult el", pedig csak máskor fog. |
| A UI-s override (**Triggers → Scheduled**) be van kapcsolva | A YAML `schedules:` blokkját a pipeline-beállítás felülírja, akármit írsz a fájlba. |

### ✅ DO

```text
A cron triggert validálom: külön `temp_cron_probe.yml` no-op scripttel, `always: true`-val,
sűrű ütemezéssel. Egyben kérek engedélyt a validációs push-ra és a revert push-ra;
futás után törlöm a probe-ot, és `git status`-szal ellenőrzöm, hogy nem maradt semmi.
```

```text
Előbb megnézem a Scheduled runs / `.triggers` értéket — ha ott nem jelenik meg a schedule,
felesleges megvárni a futást, a cron nem érvényesült.
```

### ❌ DON'T

```text
A deploy pipeline cronját `*/5`-re állítom, hogy hamarabb lássam az eredményt —
közben ötpercenként valódi deploy megy ki egy környezetre.
```

```text
Manuálisan futtatom a pipeline-t, és ebből azt állítom, hogy „a cron trigger működik".
(A manuális run megkerüli a triggert — a triggerről semmit nem mond.)
```

```text
Sikerült a validáció → továbblépek a következő feladatra, a temp probe és a sűrített cron
bent marad a branchen.
```

## Read-only receptek

Az alábbiak feltételezik a beállított defaultokat; egyébként `--org`/`-p` kell.

**Repók:**

```bash
az repos list -o table
```

**Aktív PR-ok:**

```bash
az repos pr list --status active -o table
```

**Pipeline keresése név szerint** — a `--name` szerver-oldali szűrése korlátozott, ezért client-side szűrj. A `path` mező a pipeline folderét adja (pl. `\Build`, `\Deploy`):

```powershell
$defs = az pipelines list -o json | ConvertFrom-Json
$defs | Where-Object { $_.name -like '*deploy*' } | Select-Object id, path, name, queueStatus
```

**Egy pipeline utolsó futásai:**

```powershell
$runs = az pipelines runs list --pipeline-ids 42 --top 15 --query-order QueueTimeDesc -o json | ConvertFrom-Json
$runs | ForEach-Object {
  '{0} | {1} | {2} | {3}' -f $_.id, ([datetime]$_.queueTime).ToString('MM-dd HH:mm'),
    $_.result, ($_.sourceBranch -replace '^refs/heads/','')
}
```

Hasznos szűrők a `runs list`-en: `--branch`, `--result failed`, `--status completed`, `--requested-for`, `--reason`.

**Work item lekérdezés (WIQL):**

```bash
az boards query --wiql "select [System.Id], [System.Title] from workitems where [System.State] = 'Active'" -o table
```

## REST fallback — `az devops invoke`

A CLI nem fedi le a teljes Azure DevOps REST API-t. Ami hiányzik (build **log**, timeline, teszt-eredmény, policy evaluation), azt az `az devops invoke` éri el:

```bash
az devops invoke --area <area> --resource <resource> --route-parameters project=<project> <id>=<value> --api-version 7.1
```

**Melyik stage/task bukott el egy futásban** — a `build`/`timeline` a leggyakoribb eset:

```powershell
$t = az devops invoke --area build --resource timeline `
       --route-parameters project=<project> buildId=<id> --api-version 7.1 -o json | ConvertFrom-Json
$t.records | Where-Object { $_.result -eq 'failed' } | Select-Object type, name, result
```

A `type` a hierarchia szintjét adja (`Stage` → `Phase` → `Job` → `Task`), így egy lekérésből látszik, melyik task bukott és melyik stage-ben.

Az `--api-version` **kötelező** az `invoke`-nál (a CLI nem talál ki defaultot). Ha nem tudod az area/resource nevet, a REST doksi URL-je adja: `.../_apis/<area>/<resource>`.

## Token economy

Az Azure DevOps válaszok nagyok (egy build definition JSON-ja több kB). A [[token-economy]] itt konkrétan ezt jelenti:

- **Szűrj a CLI-ben, ne a kontextusban.** `--top N`, `--result failed`, `--branch` — a szerver szűrjön, ne te olvass be 139 definitiont.
- **A `ConvertFrom-Json` a PowerShell processzben marad.** Csak a formázott, szűkített kimenet kerül a kontextusba — ez a quoting trap megkerülésének a mellékhaszna is.
- **Ne `-o json`-t adj vissza nyersen.** Építs stringet vagy `Select-Object`-tel vedd ki a 4-5 releváns mezőt.
- **Több project végigpásztázása** (`foreach ($p in ...)`) egy PowerShell hívásban menjen, ne külön tool-hívásonként.

### ✅ DO

```powershell
# 1 tool-hívás, 4 project, csak a találatok kerülnek a kontextusba
foreach ($p in $projects) {
  (az pipelines list -p $p -o json | ConvertFrom-Json) |
    Where-Object { $_.name -like '*static*' } | ForEach-Object { "$p | $($_.id) | $($_.name)" }
}
```

### ❌ DON'T

```powershell
# A teljes definition-lista JSON-ja bezuhan a kontextusba, aztán én szűröm
az pipelines list -o json
```

## Git remote auth — külön credential

A `git clone/fetch/push` az Azure DevOps remote ellen **nem** az `az devops` PAT-jával megy, hanem a **Git Credential Manager**-rel (`credential.helper = manager`), külön bejegyzéssel a Credential Managerben (`git:https://dev.azure.com/<org>`, illetve legacy `git:https://<account>.visualstudio.com`).

Következmény: a kettő **függetlenül** jár le. Ha az `az devops` 401-ezik, a `git push` attól még mehet — és fordítva. Ne diagnosztizáld egyiket a másik alapján, és PAT-cserénél gondolj rá, hogy lehet, mindkettőt frissíteni kell.

## Kapcsolódások

- Mutáló művelet engedélymodellje: [[git-conventions]] (push), [[terraform-terragrunt]] (`apply`).
- Ha a pipeline Terraformot/Terragruntot futtat, a plan/apply olvasásához: [[terraform-terragrunt]].
- Válaszok nyelve és a technikai terminusok kezelése: [[communication-language]], [[documentation-style]].
