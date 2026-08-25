# Workspace: LMSONE-NB03

Machine-specific lessons for this box. Read once per session; mechanics in [[lessons-learned]].

Windows 11 Enterprise · user `nyiria` · shells: PowerShell (primary) and Git Bash.

## Paths & links

- **2026-08-14, a szabálykészlet helye:** `C:\Users\nyiria\source\repos\claude-rules`; a globális `~/.claude/CLAUDE.md` innen importálja a repo `CLAUDE.md`-jét, ezért a core rule-ok minden sessionben aktívak, bármelyik projektben dolgozunk.
- **2026-08-14, `~/.claude/skills` junction:** a `C:\Users\nyiria\.claude\skills` junction a repo `.claude\skills` mappájára mutat, tehát a skillek minden projektből triggerelhetők.
- **2026-08-25, Claude Desktop MSIX/Store-telepítés:** a szokásos útvonalak (`AppData\Local\AnthropicClaude`, `Programs\claude`) NEM léteznek itt; a Desktop app a `C:\Program Files\WindowsApps\Claude_<verzió>_x64__pzs8sxrjxfjjc\app\Claude.exe` alatt van, app-adat: `C:\Users\nyiria\AppData\Local\Claude`. A `claude.exe` process kétértelmű: a Claude Code CLI is ezen a néven fut (`AppData\Roaming\npm\...\claude-code\bin`), a `Path`-ból lehet megkülönböztetni. Az élő log `%LOCALAPPDATA%\Claude\Logs\main.log`, az `%APPDATA%\Claude\logs\` az 1.32885-ig tartó régi verzióé (nagyobb és teljesebbnek látszik, de 2026-08-23 óta halott).

## Shells & tooling

- **2026-08-20, a Bash tool nem használható ezen a gépen:** a `PATH`-ba a Windows-lista kerül `;`-elválasztással, `/usr/bin` nélkül, így minden coreutils hívás (`ls`, `head`, `type`) exit 127-cel hasal el, miközben `/usr/bin/bash` maga fut. Fájlolvasásra és shellre PowerShell kell, a [[shell-path-conversion]] `MSYS_NO_PATHCONV` trükkje itt nem segít.

## Accounts

- **2026-08-14, két GitHub fiók él egyszerre:** `nyiri-attila-nxkey` (munkahelyi, jellemzően ez az aktív) és `nyiriattila88` (személyes). Személyes repóban push előtt váltani kell, lásd [[git-identity]].
- **2026-08-14, a globális git identity a munkahelyi:** `Nyiri.Attila@nexius.hu`; a `claude-rules` repóban szándékos repo-local override van (`nyiriattila88@gmail.com`).
