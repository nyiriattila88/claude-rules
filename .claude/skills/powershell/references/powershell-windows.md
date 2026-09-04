# PowerShell (Windows) használati szabályok

Ez a skill a **Windows PowerShell 5.1** (`powershell.exe`) viselkedéséről szól, mert a gépeken ez a
default, és a legtöbb csapda pont abból jön, hogy a PowerShell 7 (`pwsh`) másképp működik. Ahol egy
szabály csak az egyik kiadásra igaz, az ki van írva.

A közös nevező szinte minden bejegyzésben ugyanaz: **a PowerShell nem szövegként adja tovább az
argumentumot egy natív exe-nek, és nem szövegként veszi át a kimenetét.** Objektumokkal dolgozik, a
határon pedig konvertál, és a konverzió veszteséges. Ami elveszik, az csendben veszik el.

## A natív exe határ: argumentumok

### JSON-t soha ne adj át argumentumként

A PowerShell a parancssorból kiszedi a belső dupla idézőjeleket, mielőtt a natív exe megkapná. Az
`aws` erre `Expecting property name enclosed in double quotes`-ot ad, ami elgépelésnek látszik, pedig
a hívó a hibás. **Fájlon add át**, és a fájlt ASCII-ként, záró újsor nélkül írd.

#### ✅ DO

```powershell
$json | Out-File -Encoding ascii -NoNewline "$env:TEMP\lb.json"
aws elbv2 modify-target-group --cli-input-json "file://$env:TEMP\lb.json"
```

#### ❌ DON'T

```powershell
# A belso idezojelek eltunnek, a hiba viszont a JSON-ra mutat.
aws elbv2 modify-target-group --load-balancers "$json"
```

Ugyanitt: a `ConvertTo-Json -AsArray` **nincs** PS 5.1-ben, és egy elemű tömbnél a `ConvertTo-Json`
objektumot ad vissza, nem tömböt.

### Idézőjelet tartalmazó azonosító: escape-eld, ne csak idézd

Egy `for_each` cím vagy bármely `[...]`-t és dupla idézőjelet tartalmazó argumentum single-quoted
formában is elhasal, mert a PowerShell a **belső** dupla idézőjeleket viszi el.

#### ✅ DO

```powershell
tofu state list 'module.db.aws_dynamodb_table.this[\"Jobs\"]'   # read-only teszt eloszor
tofu state rm   'module.db.aws_dynamodb_table.this[\"Jobs\"]'
```

#### ❌ DON'T

```powershell
tofu state rm 'module.db.aws_dynamodb_table.this["Jobs"]'   # exit 1, ertelmezhetetlen hibaval
```

### JMESPath és jq minták: ne a wrapperen át

Az `az` Windowson egy `az.cmd` batch wrapper, a `--query` JMESPath zárójelei elhasalnak rajta
(`-o was unexpected at this time`). A `gh --jq` mintát a PowerShell szedi szét: a
`select(.conclusion=="success")` `function not defined: success/0`-ra fut, a `+`-szal fűzött
kifejezés pedig `accepts 1 arg(s), received 3`-ra, mert az idézőjelek és a szóközök elvesznek.

**Szűrésre a natív flaget használd, formázásra `ConvertFrom-Json`-t.** A `--jq` maradjon a triviális
`.[] | [...] | @tsv` alaknál. Ez token-takarékosabb is, mert a szűrés a szerveren történik.

#### ✅ DO

```powershell
gh run list --status success --limit 5 --json databaseId,headSha | ConvertFrom-Json
az pipelines runs list -o json | ConvertFrom-Json | Where-Object { $_.result -eq 'succeeded' }
```

#### ❌ DON'T

```powershell
gh run list --jq 'select(.conclusion=="success") | .databaseId + " " + .headSha'
az pipelines runs list --query "[?result=='succeeded'].[id,sourceBranch]"
```

### A `-File` nem vesz át tömb-paramétert

A `powershell -File script.ps1 -Ids 1,2,3` egyetlen stringként adja át az egészet (cast-hiba), a
space-elválasztott alak pedig csak az első elemet. Tömbhöz `-Command` kell.

#### ✅ DO

```powershell
powershell -Command "& './script.ps1' -Ids 1,2,3"
```

## A natív exe határ: kimenet

### Az `az` cp1250-et ír, a pipe UTF-8-ként dekódolja

A PR-kommentbe felküldött magyar szöveg épen tárolódik, visszaolvasva mégis minden ékezet U+FFFD-nek
látszik. A `>` átirányítás sem ment meg, mert az már a dekódolt stringet írja ki. A hívás **köré**
kell a codepage:

```powershell
[Console]::OutputEncoding = [Text.Encoding]::GetEncoding(1250)
```

Bashből fájlba írva ugyanez a cp1250 megy a fájlba, ezért a `json.load(..., encoding='utf-8')`
`UnicodeDecodeError`-ral hasal el: ott `cp1250`-nel olvasd.

### `ConvertTo-Json` nem escape-el, az ASCII-írás kérdőjelre cserél

A PS 5.1 `ConvertTo-Json` a nem-ASCII karaktereket **változatlanul** hagyja. Ha ezután
`[Text.Encoding]::ASCII`-vel írod fájlba, minden ékezet kérdőjel lesz, és a "nulla non-ASCII bájt a
fájlban" ellenőrzés emiatt **hamis biztonságot ad**: a kérdőjel is ASCII.

Ha a célnak ASCII-tiszta JSON kell (például egy CLI `--in-file` paramétere, ami a bodyt a konzol
codepage-én kódolná), a JSON stringet **magad escape-eld** a hatjegyű unicode alakra:

#### ✅ DO

```powershell
$json = $body | ConvertTo-Json -Depth 8 -Compress
$sb = New-Object System.Text.StringBuilder
foreach ($ch in $json.ToCharArray()) {
  if ([int]$ch -gt 127) { [void]$sb.AppendFormat('\u{0:x4}', [int]$ch) } else { [void]$sb.Append($ch) }
}
[System.IO.File]::WriteAllText($path, $sb.ToString(), [System.Text.Encoding]::ASCII)
```

#### ❌ DON'T

```powershell
# Minden ekezet kerdojel lesz, es a "0 non-ASCII bajt" ellenorzes ezt nem mutatja meg.
[System.IO.File]::WriteAllText($path, ($body | ConvertTo-Json), [System.Text.Encoding]::ASCII)
```

**A visszaolvasás nem bizonyíték.** Ugyanez a CLI a választ is a saját codepage-én adja vissza, tehát
egy ékezet nélküli visszaolvasás nem jelenti, hogy a tárolt érték romlott. Külső forrásból ellenőrizd
(böngésző, másik kliens), ne a felküldő eszközzel.

## Fájlok írása: a formátum megőrzése

A [[file-format-preservation]] core rule azt mondja meg, **mit** kell megőrizni. Ez itt a PowerShell
recept hozzá.

### Ne `Set-Content`, ne `>` egy meglévő fájlra

A `Set-Content` és az `Add-Content` a rendszer ANSI codepage-ét használja alapból, a `>` és az
`Out-File` UTF-8 BOM-ot ír. Mindkettő megváltoztatja a fájl bájtjait olyan helyen is, ahol nem
szerkesztettél.

### A megbízható minta: `ReadAllLines`, index, `WriteAllBytes`

Sor-alapú szerkesztéshez (markdown, rule fájl, config) ez a forma őrzi meg a BOM hiányát és a
sorvégeket, és utána a `git diff --numstat` ellenőrizhető:

#### ✅ DO

```powershell
$lines = [System.Collections.ArrayList]@([System.IO.File]::ReadAllLines($f))
$i = $lines.IndexOf($old)
if ($i -lt 0) { "NOT FOUND"; exit 1 }      # mindig ellenorizd, ne vakon cserelj
$lines[$i] = $new
$nl = [char]13 + [string][char]10          # CRLF, ha a fajl CRLF
[System.IO.File]::WriteAllBytes($f, [System.Text.Encoding]::UTF8.GetBytes((($lines -join $nl) + $nl)))
git diff --numstat -- $f                   # a szandekolt sorszamnal tobb: formatumot rontottal
```

A `[System.Text.Encoding]::UTF8` a `GetBytes` hívásnál BOM nélküli bájtokat ad, tehát ez a forma nem
visz BOM-ot a fájlba. Ha a fájlnak BOM-ja **volt**, azt külön kell visszaírni.

### Ékezetes `.ps1` csak UTF-8 BOM-mal

Fordított irány: a Windows PowerShell 5.1 a **BOM nélküli** scriptet ANSI-ként olvassa, így az
ékezetes stringek mojibake-ké válnak, és a parse is elhasalhat (`Missing ')' in method call`).
Átirányított stdoutnál a `[Console]::OutputEncoding` sem érvényesül, ott bájtokat kell írni a
`[System.Console]::OpenStandardOutput()`-ra.

Ez nem mond ellent az előző pontnak: a **script** fájl kap BOM-ot, az **adatfájl** nem.

### Sorvégek: felismerni és nem elrontani

- **Felismerés:** a `sed -n '91,92p' f | cat -A` egy CRLF fájlon csak `$`-t ír ki, `^M` nélkül, tehát
  LF-nek látszik, és a sortörésre épített csere csendben nem talál semmit. A fájlon ellenőrizd
  (`file f`, vagy Pythonban `newline=''`), ne pipe-on át.
- **Elrontás:** Pythonban az `io.open(p, 'w', newline='\r\n')` **és** a tartalomban `\n` -> `\r\n`
  csere együtt `\r\r\n`-t ír, minden sorvéget elront, és a `git diff` a teljes fájlt módosítottnak
  mutatja. A kettő közül csak az egyiket alkalmazd, vagy írj bájtot.

## Nyelvi csapdák

### Magyar idézőjel és backtick a stringben

A magyar nyitó és záró idézőjelet a parser valódi idézőjelnek veszi, a string lezárul, és
`Unexpected token` jön. A backtick escape karakter, így a markdownnak szánt inline kód csendben
újsorrá alakul. Magyar vagy markdown szöveget generáló scriptben a **single-quoted here-string**
(`@'...'@`) a biztonságos, a záró jelöléssel a 0. oszlopban.

### `$input` foglalt automatikus változó

A pipeline-enumerátor. Ne használd saját változónévként (például stdin JSON tárolására), csendes vagy
nehezen olvasható hibát ad.

## Hibakezelés: mit jelent a hiba, és mit nem

### Egy hibára futó hívás mellett a művelet lefuthatott

Egy `-Method Delete` `Invoke-WebRequest` "NonInteractive mode" hibával szállt el, a DELETE viszont
**megtörtént**, a szerver állapota megváltozott. **Mutáló hívás hibája után előbb kérdezd le az
állapotot, ne futtasd újra vakon.** Ugyanez igaz minden natív CLI-re: az `az pipelines run --output
table` `Table output unavailable`-lel elhasal a run-válaszon, de a run ekkor is létrejött, és a
megismételt parancs két párhuzamos deployt indít.

### `-ErrorAction SilentlyContinue` nem teszi sikeressé a parancsot

Elnyomja a hiba **kimenetét**, de a cmdlet bukása továbbra is exit 1-et ad. Ha tényleg nem-fatálissá
akarod tenni, tedd terminálóvá és nyeld el:

```powershell
try { Cmdlet ... -ErrorAction Stop } catch {}
```

### `2>&1` natív exe-n hamis hibát gyárt

Az 5.1 minden stderr sort ErrorRecordbe csomagol (NativeCommandError), és `$?`-t `$false`-ra állítja
**akkor is, ha az exe 0-val tért vissza**. A stderr amúgy is rögzítve van, ne irányítsd át.

### A `-o json` elé WARNING sor kerülhet

A `WARNING: Unable to encode the output with cp1250` a stdout elejére ül, és a `json.load`
`Expecting value: line 1 column 1`-gyel hasal el, ami parancs-hibának látszik. A kimenetet az első
`{` vagy `[` karaktertől vágd, ne a hívást kezdd újra.

```powershell
$r = az ... -o json 2>&1 | Out-String
$j = $r.Substring($r.IndexOf('{')) | ConvertFrom-Json
```

## Környezet: amikor nem a parancs a hibás

### A "CLI not found" lehet egy futó telepítés átmeneti állapota

Egy `Get-Command aws` azért nem talált semmit, mert a winget épp cserélte az `aws.exe`-t, és az a
nagyjából 3 perces uninstall-install ablakban fizikailag nem létezett, miközben a PATH-bejegyzés
végig megvolt. PATH-javítás vagy újratelepítés előtt nézd meg a hiba időpontját a mai `MsiInstaller`
eventek (1040 kezdet, 1042 vég) ablakához képest.

### Windowson a figyelt fájl zárolva marad

Egy `tail -f`-fel figyelt logfájlba az író `Add-Content` `IOException`-re fut, a sorok csendben
elvesznek, a script viszont hibátlanul dolgozik tovább. **A "nem frissül a log" nem azt jelenti, hogy
megállt.** Hosszú futású script állapotát külön state-fájlból olvasd, a logolás retryzzen, a monitor
`tail` processzét pedig kézzel kell kilőni (a `TaskStop` nem viszi).

### Destruktív mappa-művelet: ellenőrzött cwd, natív cmdlet

A `cd X && rm -rf Y && mkdir Y && cd Y` lánc Windowson veszélyes: ha a törlés "Device or resource
busy"-val bukik, a lánc a **szülő** könyvtárban fut tovább. Egy ilyen lánc egyszer egy 46 repót
tartalmazó munkakönyvtárat inicializált gitre. Bash-ben `set -e` és explicit cwd-ellenőrzés kell
(`case "$(pwd)" in *célmappa) ;; *) exit 1 ;; esac`), a törlésre pedig a PowerShell natív, rekurzív
törlő cmdletje a megbízható.
