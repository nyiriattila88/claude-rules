# Lessons — general (project- and machine-independent)

Cross-session lessons that hold in **every** project on **every** machine. Mechanics — where an entry belongs, when to write one, the format, and when to promote it into a rule — are in [[lessons-learned]].

Machine-specific facts do not go here; they belong in `.claude/lessons/workspaces/<COMPUTERNAME>.md`.

## Agent working method

- **2026-08-14 — hook-konfig írását auto módban blokkolja a classifier:** a `~/.claude/settings.json` és minden `hooks` blokkot tartalmazó fájl írása megtagadásra fut (a `.ps1` scriptek írása viszont átmegy). Ne próbáld újra ugyanazt — mondd ki, mit akarsz beírni, és kérj rá engedélyt.
- **2026-08-14 — a repo `.claude/skills` szerkesztése azonnal globális:** a `~/.claude/skills` junctionként erre a repóra mutat, így egy skill módosítása minden projekt minden új sessionjében azonnal él — nincs „csak lokálisan kipróbálom" állapot, a repo szerkesztése éles hatás.
- **2026-08-17 — fájl végére illesztő regex tömeges cserénél:** a `<[^>]*$` mintám markdownban a `<25`-be kapott bele, és a fájl felét levágta (a találatszám ettől még „sikeres" volt). Csere után a fájlméretet és a farkat ellenőrizd, ne a match-számot.
- **2026-08-17 — .NET-ből írt DynamoDB enum számként áll a táblában:** a `WorkflowType = :t` `{"S":"TEMPLATE"}`-tel `ValidationException: Condition parameter type does not match schema type`; a `{"N":"0"}` a helyes. Enumot tartalmazó DTO-nál a C# enum-definíciót olvasd ki, ne a JSON-exportban látszó nevet.
- **2026-08-17 — SPA-nál a 200-as API-válasz nem bizonyíték:** elrontott (relatívvá váló) base URL esetén a SPA-fallback `index.html`-t ad **200**-zal, így a hiba nem 404-ként, hanem séma-validációs hibaként („Invalid input at &lt;mező&gt;") jelenik meg. Frontend hibánál a network log teljes URL-jét nézd, ne a státuszkódot.
- **2026-08-18 — a Bash tool cwd-je persistál, a heredoc-özön viszont törékeny:** egy `cd poc/...` után a következő hívásban ugyanaz a relatív `cd` „No such file or directory"-t ad (már ott vagy), és több fájlt egy hívásban heredoc-kal írva egy „unexpected EOF" csendben kihagyja a fájlt — a `set -e` sem véd, mert a korábbi heredocok már lefutottak. Használj absolute path-t, és 2-nál több fájlhoz a Write toolt.

## Windows & PowerShell

- **2026-08-14 — ékezetes `.ps1` csak UTF-8 BOM-mal:** a Windows PowerShell 5.1 a BOM nélküli scriptet ANSI-ként olvassa, így az ékezetes stringek mojibake-ké válnak, és a parse is elhasalhat („Missing ')' in method call"). Átirányított stdout-nál a `[Console]::OutputEncoding` sem érvényesül — írj bájtokat a `[System.Console]::OpenStandardOutput()`-ra.
- **2026-08-14 — `$input` foglalt automatikus változó:** a PowerShell pipeline-enumerátora, ne használd saját változónévként (pl. stdin JSON tárolására) — csendes vagy nehezen olvasható hibát ad.
- **2026-08-17 — magyar idézőjel és backtick a PS-stringben:** a `„ ”` smart quote-okat a parser valódi idézőjelnek veszi (a string lezárul → „Unexpected token"), a backtick pedig escape karakter, így a markdownnak szánt `` `kód` `` csendben újsorrá alakul. Magyar vagy markdown szöveget generáló scriptben sima `"` kell, vagy single-quoted string.
- **2026-08-17 — `powershell -File` nem vesz át tömb-paramétert:** a `-Ids 1,2,3` egyetlen stringként érkezik (cast-hiba), a space-elválasztott forma pedig csak az első elemet adja át. Tömbhöz `-Command "& './script.ps1' -Ids 1,2,3"` kell.

## Azure Pipelines

- **2026-08-18 — template-hívás nem vesz `env` blokkot:** a `- template: x.yml@repo` alatt csak `parameters` állhat, így egy megosztott `dotnet_cli.yml`-lel nem tudsz env változót átadni a tesztfolyamatnak — az ilyen lépést sima `- bash:` step-ként kell megírni `env:`-vel. A `@repo`-s hivatkozás path-ja mindig a repo gyökerétől abszolút, nem a hívó template-hez relatív.
