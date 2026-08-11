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
| `Before you can run Azure DevOps commands, you need to run the login command` | **nem** lejárt PAT: az org-detect rossz keyring-kulcsot képez | tedd ki az `--org`-ot és a `--detect false`-t — lásd a következő szekciót |
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

## Org-feloldás — a hamis „nincs bejelentkezve" hiba (kritikus)

Ha egy `az devops`/`az repos`/`az pipelines` parancs **egyáltalán nem éri el** az Azure DevOps-ot, a leggyakoribb ok nem az auth, hanem az **org-detektálás**. `--org` nélkül az extension a git remote-ból találja ki az orgot, és a remote `user@` prefixéből **rossz keyring-kulcsot** képez:

| Amit a detect keres | Ahol a credential valójában van |
|---|---|
| `azdevops-cli:https://nexius-aether@dev.azure.com/nexius-aether` | `azdevops-cli:https://dev.azure.com/nexius-aether` |

Az eredmény egy félrevezető hibaüzenet — pedig a PAT él:

```
ERROR: Before you can run Azure DevOps commands, you need to run the login command
(az login if using AAD/MSA identity else az devops login if using PAT token) to setup credentials.
```

**A beállított default ettől nem védi meg.** Mérve egy Aether/Backend checkoutban: az `az devops configure --list` kiírja az `organization` + `project` defaultot, az `az devops project list` ugyanabban a cwd-ben mégis a fenti hibát adja, `--org … --detect false`-szal viszont azonnal válaszol. A detect a repo-kontextusból indul, így a default nem jut szóhoz.

### A működő forma

```bash
az devops project list --org https://dev.azure.com/<org> --detect false -o table
az repos pr show --id <n> --org https://dev.azure.com/<org> --detect false
az pipelines runs list --pipeline-ids <id> --top 5 --org https://dev.azure.com/<org> -p <project> --detect false
```

- A `--detect false` a legbiztosabb: így a detect akkor sem fut le, ha a parancsnak van repo-kontextusa.
- A `-p <project>` a projekt-scope-ú parancsokhoz kell (`az pipelines`, `az boards`, `az repos list`) — detect nélkül a default project sem oldódik fel magától.
- Az orgot és a projectet a remote adja meg, a `user@` rész **nélkül**:

```bash
git remote -v
# origin  https://Nexius-Aether@dev.azure.com/Nexius-Aether/Backend/_git/static-content
#                                             ^^^^^^^^^^^^^ org       ^^^^^^^ project
```

Aether/Backend checkoutokban ez konkrétan `--org https://dev.azure.com/Nexius-Aether -p Backend`.

### Ha mégis auth-hibára gyanakszol

- `--debug` mellett a kimenetben ott van, hogy `PAT is present which can be used against this instance` — ha ez látszik, **a token él**, és a hiba a detektált org-stringből jön.
- A sandboxolt shell ugyanezt a hibát adja; a sandbox kikapcsolása **nem** segít, a gyökér az org-mismatch.
- A működő `git push`/`git fetch` sem bizonyíték az `az devops` authjáról, és a fordítottja sem: az külön credential (lásd *Git remote auth*).

### ✅ DO

```text
Minden `az devops`/`az repos`/`az pipelines` hívásba kiírom az `--org`-ot és a `--detect false`-t,
és egy `az devops project list`-tel smoke-tesztelek, mielőtt a valódi lekérdezést indítom.
```

### ❌ DON'T

```text
„Before you can run Azure DevOps commands..." → új PAT-ot kérek és `az devops login`-t futtatok.
(A tárolt token él; csak a detektált org-string rossz — a login semmit nem javít.)
```

```text
`az login`-t futtatok, vagy újratelepítem az `azure-devops` extensiont, esetleg a sandboxot
kapcsolom ki. (Egyik sem a hiba oka; a hiányzó `--org` az.)
```

## Defaultok

```bash
az devops configure --defaults organization=https://dev.azure.com/<org> project=<project>
```

A default hasznos **dokumentációként** (a `configure --list` megmondja, melyik org/project a szokásos), de **ne hagyatkozz rá**: repo-kontextusban az org-detect előbb fut, és a fenti hamis login-hibát adja. Írd ki az `--org`-ot és a `--detect false`-t akkor is, ha a default be van állítva — scriptbe kerülő recepthez pedig különösen, mert a default gépfüggő, és a másik gépen csendben más org ellen futna.

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

### További wrapper- és PowerShell-csapdák

Ugyanaz a gyökér (batch wrapper + PowerShell parser), más tünetekkel:

| Tünet | Ok | Megoldás |
|---|---|---|
| `'---' is not recognized as an internal or external command` | markdown **táblázat** a `--description`/`--title` értékben: a `\|` karaktert a `cmd.exe` pipe-ként értelmezi | a PR-leírásban ne használj táblázatot (listát igen), vagy REST-tel küldd |
| `You must provide a value expression following the '-' operator` | a **backtick** a PowerShell escape-karaktere, a markdown inline-kód meg épp azt használja | a leírást **single-quoted** stringbe tedd (`'...'`), ne double-quotedba |
| `Cannot convert the "System.Object[]" value ... to "System.DateTime"` | PS 5.1-ben a `ConvertFrom-Json` a **tömböt egyetlen objektumként** adja a pipeline-ba, így a `ForEach-Object` egyszer fut le a teljes tömbre | `$arr = ... \| ConvertFrom-Json`, majd `foreach ($x in $arr) { ... }` |
| `ConvertFrom-Json : Invalid JSON primitive: WARNING` | az `az` a stdout elejére **WARNING**-ot írhat (pl. `az pipelines create`) | szűrd a parse előtt: `az ... -o json \| Where-Object { $_ -notmatch '^WARNING' } \| ConvertFrom-Json` |
| `You cannot call a method on a null-valued expression` egy saját helper hívása után — és **fájlok tűnnek el** | **az alias nyer a function felett**: a rövid nevek ütköznek (`rd` = `Remove-Item`, `ni` = `New-Item`, `sc` = `Set-Content`), így egy `function Rd` után az `Rd $path` valójában törli a fájlt | ne adj 2–3 karakteres nevet függvénynek; írd inline (`[System.IO.File]::ReadAllText($p)`) vagy `Verb-Noun` nevet használj |

Több soros leírás (PR description) átadása: PowerShell **tömbként**, soronként egy elem — a CLI így külön argumentumokként veszi át, és nem kell escape-elni.

```powershell
$desc = @(
  '## What this contains',
  '',
  '* `path/to/file` — mit tesz most.'
)
az repos pr create --repository <repo> --source-branch <br> --target-branch <base> `
  --title '[NX-12345] Subject' --description $desc
```

A leírás **legfeljebb 4000 karakter** lehet, különben `Invalid argument value. Parameter name: A description for a pull request must not be longer than 4000 characters.` Küldés előtt mérd meg — a hiba csak a teljes összeállítás után derül ki, és a `--description` felülírja a régit, tehát a hosszra bukó hívás után nincs mit visszaállítani:

```powershell
$len = ($desc -join "`n").Length
if ($len -lt 4000) { az repos pr update --id <id> --description $desc } else { 'too long' }
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

### Pipeline-indítás — a „nem indult el" csapda (kritikus)

Deploy indításánál két, egymást erősítő félrevezetés okoz **duplikált futást ugyanarra a Terraform state-re**. Mérve `azure-devops` extension 1.0.5-tel:

1. **A `--output table` elhasal a run-válaszon, de a run ekkor is létrejön.**

   ```
   ERROR: Table output unavailable. Use the --query option to specify an appropriate query.
   ```

   Ez **formázási** hiba, nem indítási hiba: a POST már lefutott, a pipeline elindult. Aki a hibaüzenetre reagálva újra kiadja a parancsot, két párhuzamos deployt kap. Indításnál ezért **mindig `-o json`** — az a run objektumot adja vissza (`id`, `resources.repositories.self.version`).

2. **A frissen indított run nem látszik azonnal a `runs list`-ben.** A `az pipelines runs list` a Build API-n keresztül indexelt adatot ad, ott másodpercekig üres marad az új run — a Runs GET viszont azonnal válaszol. Tehát a „`runs list` nem mutatja → nem indult el" következtetés **hibás**:

   ```powershell
   az devops invoke --area pipelines --resource runs `
     --route-parameters project=<project> pipelineId=<id> runId=<runId> `
     --api-version 7.1 --org https://dev.azure.com/<org> --detect false -o json
   ```

**A `--parameters` template paraméterként megy át.** Egy `parameters:` blokkban deklarált runtime paramétert (pl. `deploy_dev`) a `az pipelines run --parameters deploy_dev=true` **helyesen** template paraméterként ad át ebben a verzióban — nem változóként. Ellenőrizni utólag a fenti GET `templateParameters` mezőjével kell:

```
tp = {"deploy_dev":"true","deploy_qa":false,"deploy_stg":false,"deploy_prod":false}
```

A bejelölt paraméter `"true"` **stringként**, a nem bejelölt a default `false`-ként jelenik meg. Ugyanez a mező mondja meg utólag egy **korábbi** runról, hogy melyik környezetre ment — ez a leggyorsabb, read-only válasz a „ki telepített ide és mit" kérdésre, gyorsabb, mint a timeline stage-einek végigolvasása.

**Környezetenkénti deploynál előbb a Build kell.** Ha a deploy pipeline `pipelines:` resource-ként hivatkozik a build pipeline-ra a *saját* branchével (`branch: ${{ replace(variables['Build.SourceBranch'], 'refs/heads/', '') }}`), akkor egy feature branchen **először a Buildet kell manuálisan lefuttatni**, különben nincs `infra` artifact, amit a deploy letölthetne. A build CI-triggerében jellemzően nincs `feature/*`, tehát magától soha nem futott le rajta.

Két további mutáló művelet, aminél a részletek számítanak:

- **`az pipelines variable-group create`** — `--authorize true` nélkül a group létrejön, de a pipeline-ok nem érik el. Ezzel a flaggel nem kell utólag pipeline-onként engedélyezni a Library UI-ban.
- **Agent pool jogosultság** (egy pool *Pipeline permissions* listája) — ez **biztonsági beállítás**, nem sima pipeline-konfiguráció: a `pipelinePermissions` REST PATCH-et a harness blokkolja, és jogosan. Ha egy frissen létrehozott (probe) pipeline-nak self-hosted poolra lenne szüksége, ne kerülőutat keress: vagy a felhasználó adja meg a jogot, vagy a validációt olyan **meglévő** pipeline-nal végezd, aminek már megvan.

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

## Resource authorization — új pipeline semmit nem örököl

Egy **frissen létrehozott** pipeline (és az is, amit egy `az pipelines update` átír) egyetlen protected resource-hoz sem kap jogot automatikusan: sem agent poolhoz, sem ADO Environmenthez. Ez akkor is így van, ha a repo társ-pipeline-jai (ugyanaz a pool, ugyanaz a YAML-template) rendben futnak — a jog **pipeline-onként** áll.

A tünet félrevezető: „a másik service ugyanezzel a setuppal megy, ez meg nem". Ne a YAML-t vagy a Terraformot kezdd keresni, hanem hasonlítsd össze a jogokat egy **működő** társ-pipeline-nal.

```powershell
function Check($type, $id, $label) {
  $o = az devops invoke --area pipelinePermissions --resource pipelinePermissions `
         --route-parameters project=<project> resourceType=$type resourceId=$id `
         --api-version 7.1-preview -o json 2>$null
  $p = ($o | Where-Object { $_ -notmatch '^Please wait' }) -join "`n" | ConvertFrom-Json
  "{0,-26} all={1,-6} uj={2,-6} mukodo={3}" -f $label, $p.allPipelines.authorized,
    [bool]($p.pipelines | Where-Object { $_.id -eq <newPipelineId> }),
    [bool]($p.pipelines | Where-Object { $_.id -eq <workingPipelineId> })
}
Check 'queue'       <queueId>    'pool'
Check 'environment' <envId>      'environment'
Check 'endpoint'    <endpointId> 'service connection'
```

A `resourceType` értékei: `queue` (agent pool), `environment`, `endpoint` (service connection), `repository`, `variablegroup`, `securefile`. A `queue`**Id** a queue id-je, **nem** a pool id — `az devops invoke --area distributedtask --resource queues` adja meg. Ha `allPipelines.authorized = true`, az adott resource-hoz nem kell külön engedély (az MS-hosted `Azure Pipelines` pool tipikusan ilyen).

### A kétféle hibaviselkedés — csak az egyikhez tartozik jóváhagyás

Ez a lényegi rész, és ezen szokott elmenni egy kör:

| Hiányzó jog | Mit tesz a run | Van jóváhagyható prompt? |
|---|---|---|
| **agent pool** | a stage azonnal `failed`: `Pipeline does not have permissions to use the referenced pool(s) <név>` | **Nincs.** Hard error, nem várakozó állapot — az „Authorize resources" sáv nem jelenik meg |
| **environment** | a deployment job `pending`, a timeline-on `Checkpoint.Authorization` = `inProgress` | **Van**, a run oldalán: *„This pipeline needs permission to access a resource"* → **View** → **Permit** |

Ezért hiába kéred a felhasználót, hogy „nyomja meg az Authorize resources gombot", ha a pool joga hiányzik: **nincs ott gomb.** Azt csak a resource *Security → Pipeline permissions* listáján lehet megadni, vagy REST PATCH-csel — amit a harness blokkol (lásd az Engedélymodell agent-pool pontját).

### Ha a Permit promptot akarod előhozni

Ha a pool-hiba előbb üt, mint az environment-check, a run el sem jut a jóváhagyásig. Indítsd a futást olyan poolon, amihez **`allPipelines.authorized = true`** (jellemzően a MS-hosted `Azure Pipelines`) — a korábbi stage-ek átmennek, a run eljut a deployment jobig, és ott feljön a Permit. Ez egyben azt is bizonyítja, hogy a YAML és az infra rendben van, csak jogok hiányoznak.

Ehhez a pipeline-nak pool-választó paramétere kell (`agent_pool: MicrosoftHosted`); a pool nevét futásidőben feloldó `$(agent_pool_name)` minta pont ezt teszi lehetővé.

### ✅ DO

```text
Az új Deploy pipeline bukik, a társ-pipeline megy → előbb a pipelinePermissions-t
hasonlítom össze a kettőn (pool + environment + endpoint), és csak utána nézek YAML-t.
```

```text
A pool joga hiányzik, tehát nincs Authorize gomb. MS-hosted poolon indítom a runt,
hogy eljusson az environment-checkig — így a felhasználó tud Permitet nyomni,
és közben kiderül, hogy a plan/apply tartalmilag jó.
```

### ❌ DON'T

```text
(A bukott runra ráküldöm a felhasználót, hogy nyomja meg az „Authorize resources"
gombot — pool-jog hiányánál ilyen gomb nem létezik, csak keresni fogja.)
```

```text
(„A static-content ugyanígy van beállítva és megy, tehát a YAML-em hibás" →
elkezdem átírni a pipeline-t, pedig egyetlen engedély hiányzik.)
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
8. **A probe szerkezete legyen valósághű.** Ha stage-eket gatelsz, írd ki a `dependsOn: []`-t minden független stage-en: az ADO különben **implicit láncba** fűzi őket, és egy skipelt stage után a következő `succeeded()` feltétele hamis lesz. Ez **hamis negatívot** ad — a jó condition tűnik hibásnak.

### Gyors helyettesítő pipeline — a trigger valódi, a job nem

Ha egy Build → Deploy lánc egy ciklusa 20 perc, néhány mérés órákba fut. Ilyenkor írd át **ideiglenesen magukat a pipeline-okat**: a `trigger`, `schedules`, `resources.pipelines` és a stage-conditionök **maradnak valódiak**, a jobok helyére egy `echo` kerül. Egy ciklus így másodperc, és pontosan azt méri, amit kell — a gatinget, nem a job tartalmát.

A probe job írja ki azt, amit a lista nem mond meg: `Build.Reason`, `Build.SourceBranch`, és a feloldott artifact (`resources.pipeline.<alias>.runName`).

```yaml
steps:
  - checkout: none
  - script: |
      echo "reason:   $(Build.Reason)"
      echo "branch:   $(Build.SourceBranch)"
      echo "artifact: $(resources.pipeline.build.runName)"
```

### Melyik ág YAML-je dönt — a két trigger ellentétesen működik

Ez a leggyakoribb tévedés, és a kétféle triggernek **más** a szabálya:

| Trigger | Melyik ág YAML-jét olvassa |
|---|---|
| **Scheduled (cron)** | **Azt az ágat**, amelyben a `schedules:` blokk van. Egy feature branchen felvett cron **elsül**, ha a `branches: include:` abban az ágban tartalmazza magát az ágat. |
| **Pipeline-completion (resource trigger)** | A **pipeline** „Default branch for manual and scheduled builds" beállítását — a definition `repository.defaultBranch` mezőjét. A feature branchen bővített `trigger.branches` önmagában **nem** lép életbe. |

A hivatalos megfogalmazás a scheduled triggerre: *„Scheduled runs for a branch are added only if the branch matches the branch filters for the scheduled triggers in the YAML file **in that particular branch**."* Vagyis a cron **validálható** feature branchről.

A resource trigger beállítása **nem** a repo default branchje. A repo default branchének átállítása nem is segít: a definícióban egy befagyasztott érték áll, azt a pipeline-szintű beállítás írja át (engedélyköteles, temporary):

```bash
az pipelines update --id <pipelineId> --branch <branch>
```

### Cron trigger — mire nézz, ha „nem fut"

| Ok | Mit jelent |
|---|---|
| `always` alapból `false` | Nincs új commit az előző ütemezett futás óta → a scheduler kihagyja. Validációhoz szinte mindig kell az `always: true`. |
| A cron **UTC**-ben jár | Lokális idő szerint számolva „nem indult el", pedig csak máskor fog. |
| A UI-s override (**Triggers → Scheduled**) be van kapcsolva | A YAML `schedules:` blokkját a pipeline-beállítás felülírja. Ellenőrzés a definition `triggers` tömbjében: `settingsSourceType: 2` = YAML-ből jön, `1` = UI-ból. |
| Túl korán néztél | Az API késleltetve indexel — lásd *A futás metaadata félrevezető*. |

A definition `triggers` tömbje a YAML `schedules:` blokkot **nem** tükrözi (csak a `continuousIntegration` bejegyzés látszik benne), tehát CLI-ből nem tudod ellenőrizni, hogy a schedule regisztrálódott-e. Erre a UI **Triggers → Scheduled runs** nézete jó.

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

## A futás metaadata félrevezető — `reason` és indexelés

Két csapda, amelyik egy valódi session-ben sorban két hibás következtetést okozott:

**A REST API `reason` mezője nem mondja meg, mi indította a futást.** Pipeline-completion triggerből indult futásnál a `reason` értéke **`manual`**, a `requestedFor` pedig a rendszer-identitás (`Microsoft.VisualStudio.Services.TFS`) vagy a triggerelő build szerzője. A **valódi** érték a futáson belüli `Build.Reason` (`ResourceTrigger`), ami csak a job logjából olvasható ki — ezért írja ki a probe.

**Az API késleltetve indexeli a futásokat.** Egy épp elindult run nem jelenik meg azonnal a `runs list`-ben. Egy cron-ablak után **2–4 perccel** nézz rá; ha azonnal kérdezel, azt látod, hogy „nem indult el", pedig fut.

### ✅ DO

```text
A cron ablaka 09:20 volt; 09:24-kor kérdezem le a futásokat, és a stage-log
`Build.Reason` sorából állapítom meg, mi indította.
```

### ❌ DON'T

```text
A `runs list` egy perccel a cron ideje után nem hozta a futást → jelentem, hogy
a cron nem működik. (Csak az indexelés késett; a futás megvolt.)
```

```text
A `reason=manual`-ból arra következtetek, hogy valaki kézzel indította —
pedig pipeline-completion trigger volt.
```

## Pipeline resource — melyik build artifactját kapod

A `resources.pipelines.pipeline.branch` hiánya **csendes** hiba. A schema szerint *„defaults to all branches, used only for manual or scheduled triggers"*: egy **scheduled** deploy a legutóbbi sikeres buildet veszi **bármely** ágról — akár egy feature branchét —, és azt telepíti a trunk környezetébe.

Fix érték (`branch: develop`) megoldja a nightlyt, de elrontja a release/hotfix ág manuális deployját: ott is a trunk artifactját vennéáá. A futás **saját** ágára kötve mindkettő helyes:

```yaml
    - pipeline: build
      source: '<build pipeline name>'
      branch: ${{ replace(variables['Build.SourceBranch'], 'refs/heads/', '') }}
```

A `${{ }}` compile-time oldódik fel, és **cron-futásban is** működik (mérve). A resource-triggerből indult futást nem érinti: ott a triggerelő build artifactja megy.

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

**Preview resource-nál a verzió formátuma külön csapda.** A CLI a `--api-version` értékét float-ként is parse-olja, a szerver viszont megköveteli a `-preview` jelölést — a doksiban szereplő `7.1-preview.1` így **mindkét** oldalon elhasal. A működő forma a `-preview` **build-szám nélkül**:

| Amit beírsz | Mit kapsz |
|---|---|
| `--api-version 7.1-preview.1` | `ERROR: could not convert string to float: '7.1.1'` (a CLI törik el) |
| `--api-version 7.1` | `ERROR: The requested version "7.1" ... is under preview. The -preview flag must be supplied` |
| `--api-version 7.1-preview` | ✅ működik |

Hogy egy resource preview-e, a katalógusból derül ki: `az devops invoke` (paraméter nélkül) kilistázza az összes area/resource párt a `routeTemplate`-tel együtt, és a `releasedVersion: 0.0` jelzi a preview-t. A kimenet elé az `az` egy `Please wait...` sort ír, ezért parse előtt szűrni kell.

```powershell
$raw = az devops invoke 2>$null | Where-Object { $_ -notmatch '^Please wait' }
$a = ($raw -join "`n") | ConvertFrom-Json
$a | Where-Object { $_.resourceName -match 'permission' } |
  ForEach-Object { "$($_.area)/$($_.resourceName) released=$($_.releasedVersion) route=$($_.routeTemplate)" }
```

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
