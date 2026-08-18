---
name: local-code-review
description: >
  KIEGYENSÚLYOZOTT (nem-adverzális) lokális code review magyarul (Nyiri Attila szabálykészlete). Az
  alapértelmezett review technika a `devils-advocate-review`; erre CSAK akkor válts, ha a felhasználó
  KIFEJEZETTEN enyhébb, nem-kritikus, sima átnézést kér: "sima review", "csak nézd át gyorsan",
  "kiegyensúlyozott review", "ne legyél túl kritikus", "light review". A jelenleg checked-out lokális
  feature branchet nézi a base-hez képest, és KÉT kötelező kimenetet ad: (1) inline REVIEW-kommentek a
  working-tree fájlokban (látszik a `git diff`-ben), (2) magyar szöveges összefoglaló a chatbe. SOHA nem
  remote PR-komment, soha nem commitol/pushol. Ez egyben a `devils-advocate-review` közös mechanika-forrása
  is (base-detektálás, review-range, kimenetek). Trigger: sima/kiegyensúlyozott/enyhe review, nem-adverzális
  átnézés, light review.
---

# Lokális code review

A részletes szabály a `references/local-code-review.md`-ben van. **Olvasd be a `Read` tool-lal**, amikor kifejezetten kiegyensúlyozott/enyhe review-t kérnek. Az **alapértelmezett** review technika a [[devils-advocate-review]], ez a skill a nem-adverzális opt-in mód, és egyben a devil's advocate közös mechanika-forrása.

## A lényeg (mielőtt belekezdesz)

- **Mit review-elsz:** a **jelenleg checked-out lokális feature branchet** a base-hez képest, `git merge-base <base> HEAD`, majd `git diff <merge-base>...HEAD` (a branch commitjai) + `git diff HEAD` (uncommitted munka). Ne válts branchet.
- **Két kötelező kimenet:**
  1. **Inline kommentek a kódon**, minden észrevétel, amit a PR-re írnál, `// REVIEW(blocker|fontos|nit): …` kommentként az érintett sorra a working-tree fájlban (a fájl nyelvének megfelelő komment-szintaxissal). Látszik a `git diff`-ben, könnyen visszavonható. A **hangnem udvarias, kérés-formájú** ("Update-eld kérlek a mezőt"), de a tartalom konkrét és súlyozott marad. Csupa nagybetűs (kiabáló) prózát ne írj.
  2. **Console-összefoglaló**, magyar, tömör szöveges összegzés a chatbe: egysoros verdikt + darabszámok, majd findingonként kattintható `path:sor`, ugyanazzal a súlyozással.
- **Soha:** `git push`, `git commit`, PR-létrehozás, remote komment API / MCP a remote-ra. Lásd [[git-conventions]], ez szigorúbb: a review-kimenet sosem commitolt/pusholt.
- Szakkifejezések angolul maradnak (`race condition`, `nullable`, `cancellation token`).
