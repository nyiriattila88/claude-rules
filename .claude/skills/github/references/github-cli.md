# GitHub CLI (`gh`) és a GitHub-oldali git

Ez a skill a `gh` CLI-ről és arról a rétegről szól, ahol a git a GitHubbal beszél: authentikáció,
credential helper, PR és release műveletek, CI-futások vizsgálata.

**Amit nem itt keresel:** a commit-üzenet formátuma, a branch-elnevezés, a push-engedély és a
force-with-lease szabály a [[git-conventions]] core rule-ban van, a fiókválasztás pedig a
[[git-identity]]-ben. Azok mindig betöltődnek, ez a skill nem ismétli meg őket.

## Authentikáció: a `gh` és a git két külön döntés

Egy gépen több GitHub-fiók lehet bejelentkezve egyszerre. Ilyenkor **három** dolog dől el
egymástól függetlenül, és bármelyik lehet a rossz:

| Kérdés | Mi dönti el |
|---|---|
| Ki a commit szerzője | repo-local `user.name` / `user.email` |
| Melyik fiók tokenjével megy a push | a **`gh` aktív fiókja** plusz a remote URL user-prefixe |
| Egyáltalán le tud-e futni a credential helper | a `.gitconfig` `credential.<host>.helper` értéke |

### A 403 az aktív fiók, nem a scope

`gh auth status` több fiókot is `Logged in`-ként listáz, de csak az egyik `Active account: true`. A
git credential helper az **aktív** fiók tokenjét adja a pushnak, ezért egy személyes repo pushja
403-cal bukik, miközben a token scope-ja tökéletes. A javítás fiókváltás, nem új token:

```powershell
gh auth status                                              # melyik az aktiv?
gh auth switch --hostname github.com --user <felhasznalo>
```

### Egy üres lista nem bizonyítja a hozzáférés hiányát

Ha egy org csak az egyik fiókkal látszik, a másik fiók alatt a `gh api user/orgs` **üresen** jön
vissza, és a `gh search repos` sem találja a private repókat. Ez pontosan úgy néz ki, mint egy
hiányzó jogosultság, pedig csak a rossz fiók aktív. Mielőtt hozzáférést kérnél vagy azt állítanád,
hogy egy repo nem létezik, válts fiókot és kérdezd le újra.

## A credential helper: amikor a push a shellen bukik el

A `gh auth setup-git` a következőt írja a `.gitconfig`-ba:

```
[credential "https://github.com"]
    helper =
    helper = !'C:\\Program Files (x86)\\GitHub CLI\\gh.exe' auth git-credential
```

A `!` prefix azt jelenti, hogy a git ezt **shellen keresztül** futtatja, Windowson a Git Bash
`sh.exe`-jével. Ha az `sh.exe` bármi miatt sérült (például `fatal error - add_item`), a helper el sem
indul, és a push ezt adja:

```
fatal: could not read Password for 'https://<user>@github.com': terminal prompts disabled
```

**Ez a hiba lejárt tokennek látszik, pedig a token jó, és a `gh auth switch` is lefutott.** A
`gh auth token` ilyenkor működik, tehát az sem árulja el a bajt.

Egyszeri megkerülés a Git Credential Managerrel, a felhasználó configjának módosítása nélkül:

```powershell
git -c "credential.https://github.com.helper=" -c "credential.https://github.com.helper=manager" push origin main
```

Az első `-c` üríti a listát (a git a helpereket sorban próbálja), a második a natív GCM-et teszi be,
ami nem indít shellt. **Ne írd át a felhasználó `.gitconfig`-ját** egy egyszeri push kedvéért.

### Diagnózis-sorrend, ha a push nem megy

1. `git remote -v`, user-scoped-e az URL (`https://<user>@github.com/...`).
2. `gh auth status`, melyik fiók aktív.
3. `git config --show-origin --get-regexp 'credential\..*'`, van-e `!` prefixes helper.
4. Csak ezután gyanakodj a tokenre.

## PowerShell-csapdák

Az itteni hibák nagy része nem `gh`-hiba, hanem a PowerShell natív exe határa. A teljes kép a
[[powershell]] skillben van, a `gh`-specifikus rész:

- **A `--jq` mintát a PowerShell szétszedi.** A `select(.conclusion=="success")`
  `function not defined: success/0`-ra fut, a `+`-szal fűzött kifejezés pedig
  `accepts 1 arg(s), received 3`-ra, mert az idézőjelek és a szóközök elvesznek, és a hiba
  `gh`-hibának látszik.
- **Szűrésre natív flag, formázásra `ConvertFrom-Json`.**

### ✅ DO

```powershell
gh run list --status success --limit 5 --json databaseId,headSha,displayTitle | ConvertFrom-Json
```

### ❌ DON'T

```powershell
gh run list --jq 'select(.conclusion=="success") | .databaseId + " " + .headSha'
```

## Engedélymodell: mit futtathatsz kérdés nélkül

Ugyanaz a modell, mint a [[git-conventions]] push-policyjében és az [[azure-devops-cli]]-ben:
**a read szabad, a mutáló művelet engedélyköteles.**

| Szabad | Engedélyköteles |
|---|---|
| `gh repo list`, `gh repo view` | `gh repo create`, `gh repo delete`, `gh repo edit` |
| `gh pr list`, `gh pr view`, `gh pr diff`, `gh pr checks` | `gh pr create`, `gh pr merge`, `gh pr close`, `gh pr review` |
| `gh issue list`, `gh issue view` | `gh issue create`, `gh issue close` |
| `gh run list`, `gh run view`, `gh run view --log-failed` | `gh run rerun`, `gh run cancel`, `gh workflow run` |
| `gh release list`, `gh release view` | `gh release create`, `gh release delete` |
| `gh api <GET>` | `gh api -X POST/PATCH/PUT/DELETE` |

A `gh workflow run` és a `gh run rerun` **valódi deployt indíthat**, ezekre külön kérdezz rá, még
akkor is, ha a felhasználó általánosságban engedélyt adott a `gh` használatára. A
[[deployment-path]] szerint egyébként is a pipeline a deployment útvonala, nem a lokális apply.

## PR és issue szöveg: fájlon add át

A PR-leírás nyelve és szerkezete a [[git-conventions]]-ben van (angol, Jira-link, Why/What/Notes;
a PR-komment viszont magyar). Ami idetartozik: **a többsoros szöveget `--body-file`-lal add át**, ne
`--body`-val.

Az Azure DevOps-nál mérve a parancssorban átadott leírás **elveszti az ékezeteket**, és a felküldött
bájt utólag semmilyen codepage-dzsel nem dekódolható vissza. A `gh`-nál ez nincs megmérve, de a
`--body-file` így is a biztonságos alapértelmezés, mert kikerüli a parancssori kódolást, és
egyébként is olvashatóbb.

```powershell
gh pr create --title "..." --body-file "$env:TEMP\pr-body.md" --base develop
```

## CI: melyik futás bukott és miért

```powershell
gh run list --workflow build.yml --limit 10 --json databaseId,status,conclusion,headBranch | ConvertFrom-Json
gh run view <id> --log-failed
```

- A `--log-failed` csak a bukott stepek logját hozza, ez a token-takarékos alak. A teljes
  `gh run view --log` egy nagy build logján több tízezer sor.
- **A build log lossy forrás, ne építs belőle vissza fájlt.** Az ADO-nál mérve a log minden
  titok-egyezésű szót maszkol (egy `true` értékű változó miatt minden `true` szó `***` lett), és a
  nem-ASCII karaktereket eldobja. A GitHub Actions ugyanígy maszkol. Ha logból veszel át tartalmat,
  utána `git diff -w`-vel ellenőrizd, mi változott valójában.

## Token economy

- `--limit` mindig, `--json` a szükséges mezőkkel. A `gh pr list` alapból 30 PR-t hoz, minden mezővel.
- `gh api --paginate` csak akkor, ha tényleg kell a teljes halmaz.
- **Több repót érintő sweepnél a terjedelmet a remote listából vedd** (`gh repo list <org> --limit
  200 --json name`), ne a lokális mappákból: egy sosem klónozott repo csendben kimarad, egy
  időközben törölt pedig fölöslegesen bekerül.
