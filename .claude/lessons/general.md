# Lessons — general (project- and machine-independent)

Cross-session lessons that hold in **every** project on **every** machine. Mechanics — where an entry belongs, when to write one, the format, and when to promote it into a rule — are in [[lessons-learned]].

Machine-specific facts do not go here; they belong in `.claude/lessons/workspaces/<COMPUTERNAME>.md`.

## Agent working method

- **2026-08-14 — hook-konfig írását auto módban blokkolja a classifier:** a `~/.claude/settings.json` és minden `hooks` blokkot tartalmazó fájl írása megtagadásra fut (a `.ps1` scriptek írása viszont átmegy). Ne próbáld újra ugyanazt — mondd ki, mit akarsz beírni, és kérj rá engedélyt.
- **2026-08-14 — a repo `.claude/skills` szerkesztése azonnal globális:** a `~/.claude/skills` junctionként erre a repóra mutat, így egy skill módosítása minden projekt minden új sessionjében azonnal él — nincs „csak lokálisan kipróbálom" állapot, a repo szerkesztése éles hatás.

## Windows & PowerShell

- **2026-08-14 — ékezetes `.ps1` csak UTF-8 BOM-mal:** a Windows PowerShell 5.1 a BOM nélküli scriptet ANSI-ként olvassa, így az ékezetes stringek mojibake-ké válnak, és a parse is elhasalhat („Missing ')' in method call"). Átirányított stdout-nál a `[Console]::OutputEncoding` sem érvényesül — írj bájtokat a `[System.Console]::OpenStandardOutput()`-ra.
- **2026-08-14 — `$input` foglalt automatikus változó:** a PowerShell pipeline-enumerátora, ne használd saját változónévként (pl. stdin JSON tárolására) — csendes vagy nehezen olvasható hibát ad.
