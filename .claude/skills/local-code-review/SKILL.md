---
name: local-code-review
description: >
  Lokális code review magyarul (Nyiri Attila szabálykészlete). Használd, amikor a felhasználó
  code review-t kér: "review-eld", "csinálj code review-t", "nézd át a változásokat", "/review"
  a saját lokális diffre. A review a gépen marad: a találatok a working-tree fájljaiba kerülnek
  inline kommentként/suggestionként (látszik a `git diff`-ben), és chat-összefoglalóként —
  SOHA nem remote PR-komment. KRITIKUS: soha ne commitolj, ne pushol, ne posztolj a remote-ra.
  Trigger kulcsszavak: code review, review, változások átnézése, diff review, kódellenőrzés.
---

# Lokális code review

A részletes szabály a `references/local-code-review.md`-ben van. **Olvasd be a `Read` tool-lal**, amikor review-t kérnek.

## A lényeg (mielőtt belekezdesz)

- **Base meghatározása:** derítsd ki a PR-bázist (`origin/HEAD` → merge-base), majd review-old a `merge-base...HEAD` diffet + a working tree változásait (`git diff HEAD`).
- **Kimenet lokálisan:** magyar próza, tömör, `blocker`/`fontos`/`nit` súlyozással; a találatok inline `// REVIEW(...)` kommentként a working-tree fájlokba, kattintható `path:sor` hivatkozással a chat-összefoglalóban. A working tree írása engedélyezett a review-kéréssel.
- **Soha:** `git push`, `git commit`, PR-létrehozás, remote komment API vagy MCP-hívás a remote-ra. A review-kimenet lokális marad.
- Szakkifejezések angolul maradnak (`race condition`, `nullable`, `cancellation token`).
