# Local code review

How to perform a **local** code review of the **currently checked-out feature branch** when the user asks for one (e.g. "review-eld", "csinálj code review-t", "nézd át a változásokat", "/review"). Everything stays on the local machine and produces **two outputs, both required**:

1. **Inline comments on the code**, every point you would leave as a PR review comment is written into the working-tree file at the relevant line, so it shows up in `git diff`.
2. **A console (chat) summary**, a written account of what you found overall, grouped and severity-tagged, with clickable `path:line` links.

Never post to the remote, never create a PR comment, never commit, never push.

## When this applies

- This is the **balanced / non-adversarial** review mode. The **default** review technique is [[devils-advocate-review]]; use this one only when the user explicitly asks for a lighter, non-critical pass. The mechanics below (what to review, base detection, the two outputs, never-push/commit) are **shared**: `devils-advocate-review` builds on them, so keep this section neutral.
- Triggered only when the user explicitly asks for a review. Do not review unprompted.
- The subject is the **feature branch that is currently checked out**: review the work on this branch against the base it branches from. Do not switch branches.

## What to review: the current feature branch

Review the diff of the current branch against its base, plus any uncommitted local work.

1. **Base branch**, resolve in this order:
   - `git symbolic-ref --quiet refs/remotes/origin/HEAD` → e.g. `refs/remotes/origin/main`.
   - If unset: `git remote show origin` (read "HEAD branch"), or the first existing of `origin/main`, `origin/master`, `origin/develop`.
   - No remote at all: the local default branch (`main`/`master`).
2. **Divergence point:** `git merge-base <base> HEAD`, where this feature branch's commits start.
3. **Review range**, everything on the branch that is not yet in the base:
   - Committed on the branch: `git diff <merge-base>...HEAD`
   - Uncommitted local work: `git diff HEAD` (staged + unstaged)

Read only the changed files/ranges relevant to the diff (token economy); don't re-read the whole tree.

## Output 1: inline comments on the code (what you'd write on the PR)

- For **every** point you would leave as a PR review comment, write it into the working-tree file **at the line it refers to** (on or directly above the offending line), using a distinct marker so it is trivial to find and revert:
  - `// REVIEW(blocker): …`, `// REVIEW(fontos): …`, `// REVIEW(nit): …`
  - Use the comment syntax of the file's language (`//`, `#`, `--`, `<!-- … -->`, …).
- **Hungarian prose, terse, one point per comment.** Keep technical/industry terms in their canonical (usually English) form, do not translate `nullable`, `race condition`, `cancellation token`, `dependency injection`, etc. See [[documentation-style]].
- **Courteous, request-style tone.** Phrase each comment politely, as a request ("Update-eld kérlek a mezőt", "érdemes lenne …", "javaslom, hogy …"), not as a bare command or a put-down. This is about *tone only*, the *content* stays concrete and severity-tagged, and politeness never softens or hides the problem. Keep it terse: one "kérlek" is enough, skip the verbose pleasantries.
- **No all-caps shouting.** Don't write the comment prose in all-caps, it reads as shouting and comes across as rude. Use normal sentence case; get emphasis from precise wording, not capitals. Genuine acronyms (`API`, `HTTP`), code identifiers / constants (`MAX_SIZE`), and the `REVIEW` marker token itself naturally stay uppercase, this rule is about the prose.
- **Concrete fix?** When a fix is clearer than prose, either apply it in the file (visible in `git diff`) or add it as a fenced snippet inside the comment, the local equivalent of a PR "suggestion".
- The severity tag (`blocker` / `fontos` / `nit`) goes inside the marker so the user can triage in the diff.

## Output 2: the console summary

After annotating the code, write a short **Hungarian** summary in chat so the user sees the review without opening every file:

- A one-line overall verdict + counts (e.g. `2 blocker, 3 fontos, 1 nit`).
- Each finding as a bullet with a clickable `path/to/file.cs:42`, grouped by file, ordered by line, with the same severity tag as the inline comment.
- Keep it terse; the detail lives in the inline comments, the console is the map to them.

## Hard constraints (never violate)

- **Never push, never commit, never publish to the remote.** No `git push`, no PR creation, no remote comment API, no MCP call that posts to a PR/issue. The review is local-only output.
- **Editing the working tree is authorized by the review request.** Writing `REVIEW` comments and suggestion edits into the affected files is exactly how the user reads the review in `git diff`; no separate confirmation is needed for these edits. Still **never stage, commit, or push** them.
- See [[git-conventions]] for the push/commit permission model, this rule is stricter: code-review output is never committed or pushed under any circumstance.

## ✅ DO

Inline comment in the file, at the offending line (this is what you'd write on the PR):

```csharp
// REVIEW(fontos): a `cancellationToken` nincs átadva a `SaveAsync`-nek,
// így a művelet nem cancelálható, add át kérlek.
await _repository.SaveAsync(order);
```

Then the console summary, mirroring it with a clickable link:

```text
Review: feature/orders (base: origin/main), 0 blocker, 1 fontos, 0 nit.
- src/Order/OrderProcessor.cs:42, fontos: `cancellationToken` nincs átadva a `SaveAsync`-nek.
```

## ❌ DON'T

```text
(PR komment feltöltése a remote-ra, vagy PR létrehozása MCP/gh hívással.)
```

```text
(A working tree-be írt review-komment vagy suggestion commitolása/pusholása,
a fájlmódosítás OK és látszik a diffben, de commit/push SOHA.)
```

```text
(Csak chatben összefoglalni, a kódra nem téve kommentet, vagy fordítva, csak a
kódba írni, console-összefoglaló nélkül. Mindkét kimenet kötelező.)
```

```text
("The cancellation token is not flowed…", ne angolul írd a prózát; magyarul,
de a szakkifejezések (`cancellation token`) maradnak angolul.)
```

```text
(Parancsoló vagy lekezelő hangnem: "Ezt elrontottad, javítsd." Helyette udvarias,
kérés-formájú: "Javítsd kérlek, a `cancellationToken` nincs átadva a `SaveAsync`-nek.")
```

```text
(Csupa nagybetűs, kiabáló komment: "EZT JAVÍTSD MEG AZONNAL." Helyette normál írásmód,
udvariasan: "Javítsd kérlek, a `cancellationToken` nincs átadva a `SaveAsync`-nek.")
```
