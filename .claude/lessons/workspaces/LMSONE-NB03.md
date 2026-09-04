# Workspace: LMSONE-NB03

Machine-specific lessons for this box. Read once per session; mechanics in [[lessons-learned]].

Windows 11 Enterprise · user `nyiria` · shells: PowerShell (primary) and Git Bash.

## Paths & links

- **2026-08-14, a szabálykészlet helye:** `C:\Users\nyiria\source\repos\claude-rules`; a globális `~/.claude/CLAUDE.md` innen importálja a repo `CLAUDE.md`-jét, ezért a core rule-ok minden sessionben aktívak, bármelyik projektben dolgozunk.
- **2026-08-14, `~/.claude/skills` junction:** a `C:\Users\nyiria\.claude\skills` junction a repo `.claude\skills` mappájára mutat, tehát a skillek minden projektből triggerelhetők.
- **2026-08-25, Claude Desktop MSIX/Store-telepítés:** a szokásos útvonalak (`AppData\Local\AnthropicClaude`, `Programs\claude`) NEM léteznek itt; a Desktop app a `C:\Program Files\WindowsApps\Claude_<verzió>_x64__pzs8sxrjxfjjc\app\Claude.exe` alatt van, app-adat: `C:\Users\nyiria\AppData\Local\Claude`. A `claude.exe` process kétértelmű: a Claude Code CLI is ezen a néven fut (`AppData\Roaming\npm\...\claude-code\bin`), a `Path`-ból lehet megkülönböztetni. Az élő log `%LOCALAPPDATA%\Claude\Logs\main.log`, az `%APPDATA%\Claude\logs\` az 1.32885-ig tartó régi verzióé (nagyobb és teljesebbnek látszik, de 2026-08-23 óta halott).

## Shells & tooling

- **2026-08-26, a Bash tool működik ezen a gépen** (a 2026-08-20-i ellenkező bejegyzés elavult): a `git`, `pnpm`, `node`, `sed`, `grep`, `az` és a coreutils is fut belőle, egy teljes repo-felállítás ment végig rajta. A [[shell-path-conversion]] `/`-kezdetű argumentumokra vonatkozó szabálya viszont továbbra is él.
- **2026-08-26, a home-dir `.editorconfig` beszivárog a repo buildjébe:** a `C:\Users\nyiria\.editorconfig` `_` prefixet ír elő a private fieldekre, és minden `C:\Users\nyiria\...` alatti repo buildjét eltöri IDE1006-tal, amelynek a saját `.editorconfig`-jában nincs `root = true` (a PR által nem is érintett fájlokon is). Nem a change hibája, a review-hoz `dotnet build -p:EnforceCodeStyleInBuild=false` a kerülőút.

- **2026-09-04, a Bash tool `fatal error - add_item`-mel is indulhat:** a `bash.exe: *** fatal error - add_item ("\??\C:\Program Files\Git", "/", ...) failed, errno 1` exit 5-tel minden hívást megbuktat már az első `cd`-nél, tehát a 2026-08-26-i „a Bash tool működik ezen a gépen" bejegyzés nem mindig áll. Ne próbálgasd újra, vidd az egész sessiont PowerShellre.

- **2026-09-04, Windows-natív tofu/terragrunt:** a `%LOCALAPPDATA%\Programs\iac` alatt `tofu.exe` 1.11.4 és `terragrunt.exe` 0.99.1 (a CI-vel egyező), user PATH-on. A WSL-ben 1.12.1 / 0.99.5 van, ami újabb a CI-nál, ezért state-írásra a Windows-os bináris a biztonságos.

## Accounts

- **2026-08-14, két GitHub fiók él egyszerre:** `nyiri-attila-nxkey` (munkahelyi) és `nyiriattila88` (személyes). Személyes repóban push előtt váltani kell, lásd [[git-identity]].
- **2026-08-14, a globális git identity a munkahelyi:** `Nyiri.Attila@nexius.hu`; a `claude-rules` repóban szándékos repo-local override van (`nyiriattila88@gmail.com`).
- **2026-08-30, két Chrome csatlakozik az extensionhöz:** a `Personal Chrome` (`5e7a300d`) és egy másik (`5c600449`). A Picsart-fiók a `Personal Chrome`-ban van bejelentkezve, a másikban nincs. Két csatlakozott böngészőnél a választást fel kell dobni a felhasználónak.
- **2026-09-04, a `nexius-learning` org csak a munkahelyi fiókkal látszik:** a `nyiriattila88` alatt (alapból ez az aktív) a `gh api user/orgs` üresen jön és a `gh search repos` sem találja a private repókat, ami hiányzó hozzáférésnek látszik. Előbb `gh auth switch --hostname github.com --user nyiri-attila-nxkey`.
- **2026-09-04, az `aether-sso` session közös:** egy `aws sso login` után a `dev-admin`, `qa-admin`, `stg-admin` és `prod-admin` profil mind használható újralogin nélkül.

A session végén futó ellenőrzés emlékeztet a rögzítésre; a szabályok a `lessons-learned` rule-ban vannak.
