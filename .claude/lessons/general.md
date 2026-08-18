# Lessons: general (project- and machine-independent)

Cross-session lessons that hold in **every** project on **every** machine. Mechanics, where an entry belongs, when to write one, the format, and when to promote it into a rule, are in [[lessons-learned]].

Machine-specific facts do not go here; they belong in `.claude/lessons/workspaces/<COMPUTERNAME>.md`.

## Agent working method

- **2026-08-14, hook-konfig írását auto módban blokkolja a classifier:** a `~/.claude/settings.json` és minden `hooks` blokkot tartalmazó fájl írása megtagadásra fut (a `.ps1` scriptek írása viszont átmegy). Ne próbáld újra ugyanazt, mondd ki, mit akarsz beírni, és kérj rá engedélyt.
- **2026-08-14, a repo `.claude/skills` szerkesztése azonnal globális:** a `~/.claude/skills` junctionként erre a repóra mutat, így egy skill módosítása minden projekt minden új sessionjében azonnal él, nincs „csak lokálisan kipróbálom" állapot, a repo szerkesztése éles hatás.
- **2026-08-17, fájl végére illesztő regex tömeges cserénél:** a `<[^>]*$` mintám markdownban a `<25`-be kapott bele, és a fájl felét levágta (a találatszám ettől még „sikeres" volt). Csere után a fájlméretet és a farkat ellenőrizd, ne a match-számot.

## Windows & PowerShell

- **2026-08-14, ékezetes `.ps1` csak UTF-8 BOM-mal:** a Windows PowerShell 5.1 a BOM nélküli scriptet ANSI-ként olvassa, így az ékezetes stringek mojibake-ké válnak, és a parse is elhasalhat („Missing ')' in method call"). Átirányított stdout-nál a `[Console]::OutputEncoding` sem érvényesül, írj bájtokat a `[System.Console]::OpenStandardOutput()`-ra.
- **2026-08-14, `$input` foglalt automatikus változó:** a PowerShell pipeline-enumerátora, ne használd saját változónévként (pl. stdin JSON tárolására), csendes vagy nehezen olvasható hibát ad.
- **2026-08-17, magyar idézőjel és backtick a PS-stringben:** a `„ ”` smart quote-okat a parser valódi idézőjelnek veszi (a string lezárul → „Unexpected token"), a backtick pedig escape karakter, így a markdownnak szánt `` `kód` `` csendben újsorrá alakul. Magyar vagy markdown szöveget generáló scriptben sima `"` kell, vagy single-quoted string.
- **2026-08-17, `powershell -File` nem vesz át tömb-paramétert:** a `-Ids 1,2,3` egyetlen stringként érkezik (cast-hiba), a space-elválasztott forma pedig csak az első elemet adja át. Tömbhöz `-Command "& './script.ps1' -Ids 1,2,3"` kell.
