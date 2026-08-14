# Lessons learned — cross-session memory

This repository is imported into **every** local session (through the global `~/.claude/CLAUDE.md`), which makes it the only place where something learned in one session can improve the next one — in a different project, on a different day. Two collections carry that knowledge:

| Collection | Scope | Loading |
|---|---|---|
| `.claude/lessons/general.md` | project- **and** machine-independent | **eager** — imported by the root `CLAUDE.md`, active in every session |
| `.claude/lessons/workspaces/<COMPUTERNAME>.md` | one physical machine | **on demand** — read once per session (below) |

## Automation — two hooks carry it

The collection must not depend on remembering it, so two hooks in `.claude/hooks/` drive both halves. They are wired into the machine's own `~/.claude/settings.json` (user scope, so every project gets them) — one-time setup per machine, described in the repo `README.md`.

- **`session-start-lessons.ps1`** (`SessionStart`) — resolves `$env:COMPUTERNAME`, reads that machine's workspace file, and injects it into the session context. Nothing to look up and no `Read` to spend; if the machine has no file yet, it says so and names the path to create.
- **`stop-lessons-sweep.ps1`** (`Stop`) — **once per session**, as the turn would end, blocks with a reminder to record what the session learned. A per-session marker file guarantees it fires exactly once (no loop), and a session whose transcript is under ~30 KB is skipped as too small to have produced a lesson.

Both fail open: on any error they emit nothing rather than breaking a session start or trapping a turn.

**The sweep is not a quota.** A reminder that fires does not mean an entry must be written — "there was no lesson this session" is the correct and common answer. An invented entry costs every later session context for nothing.

### When the hooks are not wired

On a machine without them, both halves are manual: `@import` cannot be parameterised and the machine name is not in the session context, so resolve it once per session (`$env:COMPUTERNAME`), read `.claude/lessons/workspaces/<name>.md` if it exists, and record anything worth keeping before finishing. A missing file means this machine has no recorded lessons yet — create it when the first one is worth writing, not empty up front.

## Where a lesson belongs

Four stores, and the distinction matters: a lesson written into the wrong one is either invisible later or duplicated.

- **`general.md`** — working-method and agent-behaviour lessons that hold everywhere: a trap that recurs across projects, a tool that reports a misleading result, an approach that wasted a turn.
- **`workspaces/<machine>.md`** — facts about *this box*: paths, which CLIs are installed and which are not, accounts and profiles, proxy/VPN behaviour, junctions, WSL — anything that would be wrong on another machine.
- **session memory** (`~/.claude/projects/<project>/memory/`) — bound to the current project, not versioned, invisible from other repos. Project state, goals, per-project feedback.
- **rules / skills** (`.claude/rules/`, `.claude/skills/`) — where a lesson lands once it has hardened into a **normative** statement ("always do X", "never conclude Y from an empty Z").

## Promotion — a lesson is not meant to stay a lesson

A lesson that keeps recurring, or that has become a rule you would want enforced, gets **promoted**: rewrite it as a core rule or a skill reference, then **delete the lesson entry**. The rule is then the single source of truth — never leave both, see [[claude-meta-rule]].

## When to write an entry

Write one when the session produced something a future session would otherwise re-learn from scratch:

- the user corrected an approach, and the correction generalises beyond the current project;
- a tool or CLI returned a **misleading** result (empty, stale, wrong account) and the real cause was non-obvious;
- a step needed several attempts before it worked, and the working form is not discoverable from the docs;
- an environment fact cost real time to establish (which account, which path, which version).

Do **not** write an entry for something the code, `git log`, or an existing rule already records; for a one-off detail of the current task; or for a guess you did not verify.

## Entry format

One entry = one lesson, as a dated bullet, terse — the limits in [[documentation-style]] apply (one line by default, three at most). Newest at the bottom of its section. Create a `##` section only when it has content; empty placeholder sections are noise.

```markdown
- **2026-08-14 — `gh` aktív fiók:** a push 403-cal elhasalt, mert a munkahelyi fiók volt aktív;
  előbb `gh auth switch`, ne új tokent generálj.
```

Language follows [[communication-language]] — Hungarian by default; technical terms and identifiers stay verbatim.

## Size limit

`general.md` is eagerly imported, so every session pays for it as **baseline cost**. Keep it under ~40 entries: when it grows past that, do not simply append — promote the hardened entries into rules and delete the ones that no longer apply ([[token-economy]]). Workspace files load on demand, so they can be longer, but stale entries about a changed machine are worse than no entry.

## ✅ DO

```text
A session elején egyszer lekérdezem a $env:COMPUTERNAME-et, beolvasom a workspace-fájlt,
és a végén egyetlen dátumozott sorral rögzítem, amit tanultunk.
```

```text
Ez a tanulság már harmadszor jön elő és normatív → promótálom core rule-ba,
a lessons bejegyzést pedig törlöm.
```

## ❌ DON'T

```text
(Minden turnben újra beolvasom a lessons fájlokat, vagy minden apró lépést
bejegyzésként rögzítek — a general.md eager import, ez mindenkinek fizetendő költség.)
```

```text
(Gép-specifikus tényt — telepített CLI, elérési út, profil — a general.md-be írok,
így egy másik gépen hamis lesz.)
```
