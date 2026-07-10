---
name: local-code-review
description: >
  Lokális code review magyarul (Nyiri Attila szabálykészlete). Használd, amikor a felhasználó
  code review-t kér: "review-eld", "csinálj code review-t", "nézd át a változásokat", "/review".
  A jelenleg checked-out lokális feature branchet nézi végig a base-hez képest, és KÉT kötelező
  kimenetet ad: (1) inline REVIEW-kommentek a kódra a working-tree fájlokban (látszik a `git diff`-ben,
  az, amit a PR-re írnál), (2) magyar szöveges összefoglaló a console-ra/chatbe. SOHA nem remote
  PR-komment, és soha nem commitol/pushol. Trigger: code review, review, változások átnézése, diff review.
---

# Lokális code review

A részletes szabály a `references/local-code-review.md`-ben van. **Olvasd be a `Read` tool-lal**, amikor review-t kérnek.

## A lényeg (mielőtt belekezdesz)

- **Mit review-elsz:** a **jelenleg checked-out lokális feature branchet** a base-hez képest — `git merge-base <base> HEAD`, majd `git diff <merge-base>...HEAD` (a branch commitjai) + `git diff HEAD` (uncommitted munka). Ne válts branchet.
- **Két kötelező kimenet:**
  1. **Inline kommentek a kódon** — minden észrevétel, amit a PR-re írnál, `// REVIEW(blocker|fontos|nit): …` kommentként az érintett sorra a working-tree fájlban (a fájl nyelvének megfelelő komment-szintaxissal). Látszik a `git diff`-ben, könnyen visszavonható.
  2. **Console-összefoglaló** — magyar, tömör szöveges összegzés a chatbe: egysoros verdikt + darabszámok, majd findingonként kattintható `path:sor`, ugyanazzal a súlyozással.
- **Soha:** `git push`, `git commit`, PR-létrehozás, remote komment API / MCP a remote-ra. Lásd [[git-conventions]] — ez szigorúbb: a review-kimenet sosem commitolt/pusholt.
- Szakkifejezések angolul maradnak (`race condition`, `nullable`, `cancellation token`).
