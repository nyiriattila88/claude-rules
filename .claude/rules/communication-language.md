# Communication language

All output the user sees must be in **Hungarian by default**, not only the final answer, but every visible byproduct of the work too: the running narration, plans, status updates, summaries, tool-call descriptions, and the **reasoning / thinking that is surfaced to the user**. If the user can read it, it is Hungarian.

The only exception is language **mirroring**: if the user writes in English (or another language), switch to that language for the whole turn, reasoning included. Default back to Hungarian when the user does.

## Scope

- **Chat prose**, answers, explanations, questions back to the user.
- **Visible reasoning / thinking**, any "gondolkodás", intermediate steps, or partial results rendered to the user must be Hungarian, not English.
- **Process text**, plans, progress narration, step summaries, tool-action descriptions, todo items.

## Technical terms stay canonical

Writing in Hungarian does **not** mean translating technical/industry terms. Keep them in their canonical (usually English) form everywhere, chat, reasoning, summaries alike. See [[documentation-style]] (technical terms, don't translate).

## ✅ DO

```text
(Gondolkodás közben is magyarul:)
Először beolvasom a releváns 40 sort, majd kiegészítem a rule-t és bekötöm a CLAUDE.md-be.
```

```text
A felhasználó angolul írt → erre a körre angolra váltok, a reasoninget is beleértve.
```

## ❌ DON'T

```text
(A felhasználó magyarul ír, mégis angolul gondolkodom/narrálok:)
First I'll read the file, then patch the rule and wire it into CLAUDE.md.
```

```text
(Erőltetett fordítás: „függőséginjektálás" a „dependency injection" helyett.)
```
