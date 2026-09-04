---
name: github
description: >
  GitHub CLI (`gh`) és GitHub-oldali git használati szabályok (Nyiri Attila szabálykészlete).
  Használd MINDIG, amikor GitHubbal dolgozol: `gh` parancs futtatása, PR vagy issue lekérdezése és
  létrehozása, GitHub Actions futások (`gh run`) vizsgálata, release, `gh api` REST hívás, repo-lista
  lekérdezése, vagy amikor a `git push` a GitHub remote-ra nem megy. KRITIKUS és gyakran elrontott: a
  push **403**-ja szinte mindig a rossz **aktív `gh` fiók**, nem hiányzó token-scope, a javítás
  `gh auth switch`, nem új PAT; egy org üres `gh api user/orgs` válasza sem bizonyítja a hozzáférés
  hiányát, csak azt, hogy rossz fiók aktív; a `could not read Password ... terminal prompts disabled`
  hiba **nem lejárt token**, hanem a `!` prefixes credential helper, ami shellt indít, és a shell
  hibás (megkerülés: egyszeri `-c credential.https://github.com.helper=manager`); a `--jq` mintát a
  PowerShell szétszedi, szűrésre a natív flaget használd; a mutáló parancsok (`gh pr create/merge`,
  `gh workflow run`, `gh run rerun`, `gh release create`, `gh repo delete`) engedélykötelesek, mert
  valódi deployt vagy visszafordíthatatlan változást indíthatnak. Trigger kulcsszavak: GitHub, gh,
  gh cli, gh auth, gh pr, gh run, gh api, gh release, GitHub Actions, workflow run, pull request,
  push 403, credential helper, „nem tudok pusholni", „nem látom a repót", git remote github.com.
---

# GitHub CLI (`gh`)

A részletes szabály a `references/github-cli.md`-ben van. **Olvasd be a `Read` tool-lal**, mielőtt
`gh` parancsot futtatsz, PR-t vagy release-t hozol létre, vagy push-hibát diagnosztizálsz.

## A lényeg (mielőtt bármit teszel)

- **Nem ez a hely a commit- és push-szabályoknak.** A commit-üzenet formátuma, a branch-elnevezés, a
  push-engedély és a „csakis `--force-with-lease`" szabály a [[git-conventions]] core rule-ban van, a
  fiókválasztás a [[git-identity]]-ben. Azok mindig aktívak, ez a skill nem ismétli meg őket.
- **Három dolog dől el egymástól függetlenül:** ki a commit szerzője (repo-local `user.email`),
  melyik fiók tokenjével megy a push (a `gh` **aktív** fiókja), és egyáltalán le tud-e futni a
  credential helper. Bármelyik lehet a rossz, és mindhárom más hibaüzenetet ad.
- **A push 403-ja az aktív fiók, nem a scope.** `gh auth status` több fiókot is bejelentkezettként
  listáz, de a helper az aktív fiók tokenjét adja. `gh auth switch --hostname github.com --user <x>`,
  ne új tokent generálj.
- **A `could not read Password ... terminal prompts disabled` nem lejárt token.** A `gh auth
  setup-git` egy `!` prefixes helpert ír a configba, amit a git **shellen** futtat; ha a Git Bash
  sérült, a helper el sem indul. A `gh auth token` ilyenkor is működik, tehát nem árulja el a bajt.
  Egyszeri megkerülés a felhasználó configjának módosítása nélkül:
  `git -c "credential.https://github.com.helper=" -c "credential.https://github.com.helper=manager" push`.
- **Egy üres lista nem bizonyítja a hozzáférés hiányát.** Rossz fiók alatt a `gh api user/orgs`
  üresen jön és a `gh search repos` sem találja a private repókat. Mielőtt hozzáférést kérnél vagy
  kimondanád, hogy egy repo nem létezik, válts fiókot és kérdezd le újra.
- **PowerShell alól a `--jq` szétesik.** `function not defined: success/0` és
  `accepts 1 arg(s), received 3`, mert az idézőjelek és szóközök elvesznek, és a hiba `gh`-hibának
  látszik. Szűrésre natív flag (`--status`, `--limit`), formázásra `ConvertFrom-Json`. Részletek:
  [[powershell]].
- **Read szabad, write engedélyköteles.** A `gh workflow run` és a `gh run rerun` **valódi deployt
  indíthat**, a `gh release create` és a `gh repo delete` visszafordíthatatlan. Ezekre külön kérdezz
  rá, akkor is, ha a felhasználó általánosságban engedélyt adott a `gh`-ra.
- **Többsoros szöveget `--body-file`-lal adj át**, ne `--body`-val: kikerüli a parancssori kódolást,
  ami az Azure DevOps-nál mérve visszaállíthatatlanul elvitte az ékezeteket.

## Mikor melyik szekciót olvasd

| Feladat | Szekció a `references/github-cli.md`-ben |
|---|---|
| Push 403, rossz fiók, „nem látom a repót" | Authentikáció: a `gh` és a git két külön döntés |
| `could not read Password`, push nem megy | A credential helper: amikor a push a shellen bukik el |
| `gh` parancs elhasal PowerShellben | PowerShell-csapdák |
| Mit futtathatok kérdés nélkül | Engedélymodell |
| PR vagy issue létrehozása CLI-ből | PR és issue szöveg: fájlon add át |
| Melyik CI-futás bukott és miért | CI: melyik futás bukott és miért |
| Nagy lista, sok repo, sweep | Token economy |
