---
name: powershell
description: >
  Windows PowerShell 5.1 használati szabályok (Nyiri Attila szabálykészlete). Használd MINDIG, amikor
  PowerShellből natív CLI-t hívsz (`az`, `aws`, `gh`, `git`, `tofu`, `terragrunt`, `dotnet`, `npm`),
  `.ps1` scriptet írsz vagy futtatsz, PowerShellből fájlt írsz vagy szerkesztesz, JSON-t adsz át vagy
  olvasol vissza egy CLI-től, illetve amikor ékezetes vagy magyar szöveget kell egy eszközön
  keresztülvinni. KRITIKUS és gyakran elrontott: a PowerShell **kiszedi a belső dupla idézőjeleket**,
  ezért JSON-t és idézőjelet tartalmazó azonosítót csak fájlon vagy escape-elve szabad átadni; a
  `--query` JMESPath elhasal az `az.cmd` wrapperen és a `--jq` mintát a PowerShell szedi szét; a
  `ConvertTo-Json` **nem** escape-eli a nem-ASCII karaktereket, így az ASCII-ként kiírt fájlban minden
  ékezet kérdőjel lesz, és a „nulla non-ASCII bájt" ellenőrzés emiatt hamis biztonságot ad; a
  `Set-Content` ANSI-t, az `Out-File` BOM-ot ír, tehát meglévő fájlt csak `WriteAllBytes`-szal
  szerkessz; egy hibára futó mutáló hívás mellett a művelet **lefuthatott**, ezért újrafuttatás előtt
  az állapotot kérdezd le. Trigger kulcsszavak: PowerShell, powershell.exe, pwsh, .ps1, cmdlet,
  ConvertTo-Json, ConvertFrom-Json, Out-File, Set-Content, WriteAllBytes, here-string, ErrorAction,
  NativeCommandError, cp1250, BOM, encoding, ékezet, mojibake, sorvég, CRLF, --query, --jq,
  „nem működik a parancs PowerShellből", „elszáll az idézőjelektől".
---

# PowerShell (Windows)

A részletes szabály a `references/powershell-windows.md`-ben van. **Olvasd be a `Read` tool-lal**,
mielőtt PowerShellből natív CLI-t hívsz, fájlt írsz, vagy encoding-hibát diagnosztizálsz.

## A lényeg (mielőtt bármit teszel)

- **A PowerShell nem szövegként adja tovább az argumentumot, és nem szövegként veszi át a kimenetet.**
  Objektumokkal dolgozik, a natív exe határán konvertál, és a konverzió **veszteséges**. Ami elveszik,
  az csendben veszik el, és a hibaüzenet szinte mindig másra mutat: egy elveszett idézőjel a JSON-ra,
  egy elveszett ékezet a szerverre, egy stderr sor a parancs sikerére.
- **JSON-t soha ne adj át argumentumként.** A belső dupla idézőjelek eltűnnek, és az `aws`
  `Expecting property name enclosed in double quotes`-ot ad, ami elgépelésnek látszik. Fájlon add át
  (`file://...`), ASCII-ként, záró újsor nélkül. Ugyanez az `[...]`-t és idézőjelet tartalmazó
  `for_each` címre: ott `\"` escape kell a single-quoted formán **belül** is.
- **A `--query` és a `--jq` a wrapperen elhasal.** Az `az` Windowson `az.cmd` batch wrapper, a
  JMESPath zárójelei `-o was unexpected at this time`-ot adnak; a `gh --jq` mintáját a PowerShell
  szedi szét (`function not defined: success/0`). Szűrésre a **natív flaget** használd
  (`--status`, `--limit`), formázásra `ConvertFrom-Json`-t. Token-takarékosabb is.
- **Ékezet: két külön kérdés, feltöltés és visszaolvasás.** A `ConvertTo-Json` PS 5.1-ben **nem**
  escape-el, tehát `[Text.Encoding]::ASCII`-vel kiírva minden ékezet **kérdőjel** lesz, és a „nulla
  non-ASCII bájt a fájlban" ellenőrzés ezt nem mutatja meg, mert a kérdőjel is ASCII. Escape-eld magad
  a hatjegyű unicode alakra. A **visszaolvasás soha nem bizonyíték**: ugyanaz a CLI a választ is a
  saját codepage-én adja vissza, ellenőrizni külső forrásból (böngésző) kell.
- **Meglévő fájlt csak `WriteAllBytes`-szal szerkessz.** A `Set-Content` ANSI codepage-et, az
  `Out-File` és a `>` UTF-8 BOM-ot ír, tehát olyan bájtokat is átír, ahol nem szerkesztettél
  ([[file-format-preservation]]). A recept: `ReadAllLines`, index-alapú csere, `WriteAllBytes`, majd
  `git diff --numstat` ellenőrzés. Fordítva viszont az **ékezetes `.ps1` script** BOM-ot **igényel**,
  különben a 5.1 ANSI-ként olvassa.
- **Egy hibára futó mutáló hívás mellett a művelet lefuthatott.** Egy `Invoke-WebRequest -Method
  Delete` „NonInteractive mode" hibával szállt el, a DELETE mégis megtörtént; az `az pipelines run
  --output table` formázási hibát ad, de a run létrejön. **Előbb kérdezd le az állapotot, ne futtasd
  újra vakon**, különben két párhuzamos deploy fut ugyanarra a state-re.
- **A hiba nem mindig a parancsé.** A `2>&1` natív exe-n `$?`-t hamisra állítja exit 0 mellett is; a
  `-ErrorAction SilentlyContinue` nem teszi sikeressé a cmdletet; a `-o json` elé `WARNING` sor
  kerülhet, amitől a JSON-parse „első karakter" hibával hasal el; és a „CLI not found" lehet egy futó
  winget-csere 3 perces ablaka.

## Mikor melyik szekciót olvasd

| Feladat | Szekció a `references/powershell-windows.md`-ben |
|---|---|
| JSON vagy idézőjeles azonosító átadása CLI-nek | A natív exe határ: argumentumok |
| `--query` / `--jq` nem működik | JMESPath és jq minták |
| Script paraméterezése (`-File`, tömb) | A `-File` nem vesz át tömb-paramétert |
| Ékezet elveszik vagy kérdőjel lesz | A natív exe határ: kimenet |
| Magyar szöveg felküldése egy API-nak | `ConvertTo-Json` nem escape-el |
| Fájl szerkesztése formátum-megőrzéssel | Fájlok írása: a formátum megőrzése |
| `.ps1` script ékezettel | Ékezetes `.ps1` csak UTF-8 BOM-mal |
| CRLF/LF felismerés és elrontás | Sorvégek: felismerni és nem elrontani |
| Parse-hiba magyar szövegtől | Nyelvi csapdák |
| „Hibát adott, de megtörtént?" | Hibakezelés: mit jelent a hiba, és mit nem |
| Hiányzó CLI, zárolt fájl, destruktív mappa-művelet | Környezet: amikor nem a parancs a hibás |

## Kapcsolódó szabályok

- [[shell-path-conversion]] (core), a Git Bash `/`-kezdetű argumentumokat Windows úttá írja át, és
  ezért **PowerShell a biztonságos választás** olyan CLI-hívásra, ahol az argumentum `/`-rel kezdődik.
- [[file-format-preservation]] (core), mit kell megőrizni; ez a skill a hozzá tartozó PowerShell
  receptet adja.
- [[github-cli]] és [[azure-devops-cli]] skillek, az ott leírt `gh` és `az` csapdák nagy része
  valójában ennek a határnak a tünete.
