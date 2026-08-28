# Context handoff: write the state down before the window runs out

A long session loses its context window, and what survives is a summary the agent did not write and cannot
verify. Everything established by measurement, every decision the user made, every half-finished
deployment is then either in that summary or gone.

**Before the context window fills, write the state to a file in the working directory the session can
see.** The next context reads it, continues from it, and then deletes it.

## When

- When the context is visibly filling, not when it is already full. A handoff written under pressure is
  the one that omits the deployment still in flight.
- Before starting anything long that will consume a lot of context (a large fan-out, a multi-repository
  sweep, a long log analysis).
- Whenever the user asks for one.

## Where

A single file at the root of the primary working directory, named so it is obvious:
`CONTEXT-HANDOFF.md`. The working directory, not a temp folder, because the next context has to find it
without being told where to look, and the user can read it too.

If the workspace already has a continuity document the user maintains, write into that instead of adding
a second one. Two handoff files disagree with each other within the day.

## What goes in it

Write what a competent stranger needs to continue, not a diary of what happened:

- **Current task and where it stands.** One paragraph, not a narrative.
- **Decisions the user made**, with their reasoning, especially the ones that overrode a default. These
  are the most expensive thing to lose, because the next context will re-propose what was already refused.
- **What is deployed where**, with exact identifiers: branch names, commit hashes, build and deployment
  ids, environments.
- **What is in flight**, including anything running in the background and how to check on it.
- **What is blocked and why**, with the actual error or measurement, not a paraphrase.
- **Measured facts that cost time to establish.** A number that took a live query to get is worth more
  than a paragraph of reasoning.
- **Open questions the user has not answered yet.**

Leave out what the repository already carries: the code, the git history, anything a `git log` answers.

## Delete it after reading

**The new context reads the file, then deletes it.** A handoff that outlives its handoff is a trap: it
describes a state that has moved on, and it reads exactly as authoritative as a current one. Deleting it
is part of reading it, not a tidy-up for later.

Overwrite rather than append when writing a new one. A handoff is a snapshot, not a log.

## ✅ DO

```text
Fogy a context. Írok egy CONTEXT-HANDOFF.md-t: mi van kint STG-n build-id-kkal, mi fut a háttérben,
mi az a blokkoló, amibe ma futottunk, és mit döntött el a felhasználó, amit nem kell újra felvetni.
```

```text
(Új context indul:) Beolvasom a CONTEXT-HANDOFF.md-t, folytatom onnan, és törlöm a fájlt.
```

## ❌ DON'T

```text
(Megvárom, amíg tényleg elfogy a context, és a compaction ír helyettem egy összefoglalót,
amit nem én állítottam össze és nem tudok ellenőrizni.)
```

```text
(Beolvasom a handoffot, de nem törlöm. Két nap múlva egy másik session tényként olvassa,
hogy valami "épp deployol", ami rég lefutott.)
```

```text
(Naplót írok bele arról, mi történt óránként, ahelyett hogy az állapotot írnám le.)
```
