# Local code review

How to perform a **local** code review when the user asks for one (e.g. "review-eld", "csinálj code review-t", "nézd át a változásokat", "/review"). The review stays on the local machine: findings are written into the working-tree files as inline comments and optional suggestions (so they show up in `git diff`), and summarized in chat — never as remote PR comments.

## When this applies

- Triggered only when the user explicitly asks for a code review. Do not review unprompted.
- First decide whether this repo is one that **normally uses PRs**, then derive the base the PR would branch from (see below). If the repo has no remote, treat the diff against the local default branch instead — still review locally.

## Detect PR context and the review base

Inspect the git repository to find where the PR's commits start, then review the diff from that base to the current work.

1. **Remote present?** `git remote -v`. A remote (especially `origin`) indicates a PR-style workflow.
2. **Default/base branch:** resolve in this order:
   - `git symbolic-ref --quiet refs/remotes/origin/HEAD` → e.g. `refs/remotes/origin/main`.
   - If unset: `git remote show origin` (read "HEAD branch"), or fall back to the first existing of `origin/main`, `origin/master`, `origin/develop`.
   - No remote at all: use the local default branch (`main`/`master`).
3. **Divergence point:** `git merge-base <base> HEAD` — this is where the branch's PR commits start.
4. **Review range:** the committed branch diff plus any uncommitted local work:
   - Committed: `git diff <merge-base>...HEAD`
   - Working tree: `git diff HEAD` (staged + unstaged), so the review covers everything not yet pushed.

Read only the changed files/ranges relevant to the diff (token economy); don't re-read the whole tree.

## Deliver the review locally — never to the remote

- **Hungarian prose, professional tone, terse.** One short point per finding. Keep technical/industry terms in their canonical (usually English) form — do not translate `nullable`, `race condition`, `cold start`, `dependency injection`, etc. See [[documentation-style]] (technical terms — don't translate).
- **Inline review notes (default):** write each finding as a comment at the relevant line in the working-tree file, using a distinct marker (e.g. `// REVIEW(fontos): …`) so it appears in `git diff` and is trivial to find and revert. Mirror it in a short chat summary with a clickable `path/to/file.cs:42`, grouped by file, ordered by line.
- **Suggestions:** when a concrete fix is clearer than prose, apply it in the file (visible in `git diff`) or show it as a fenced `diff`/replacement snippet. This mirrors a PR "suggestion" but stays local.
- **Severity, optionally:** prefix with a short tag (`blocker` / `fontos` / `nit`) so the user can triage quickly. Keep it optional and lightweight.

## Hard constraints (never violate)

- **Never push, never commit, never publish to the remote.** No `git push`, no PR creation, no remote comment API, no MCP call that posts to a PR/issue. The review is local-only output.
- **Editing the working tree is authorized by a review request.** Asking for a review grants standing permission to write review comments and suggestion edits directly into the affected files at the relevant lines — that is how the user reads the review in `git diff`. No separate confirmation is needed for these edits. Still **never stage, commit, or push** them.
- See [[git-conventions]] for the push/commit permission model — this rule is stricter: code-review output is never committed or pushed under any circumstance.

## ✅ DO

```text
A merge-base origin/main…HEAD diffet review-elem, magyarul, lokálisan.
A találatokat a fájlokba írom REVIEW-kommentként az érintett soroknál,
ahol kell suggestionnel — látszik a git diffben. Nem commitolok, nem pusholok.
```

````text
src/Order/OrderProcessor.cs:42 — fontos: a `cancellationToken` nincs
átadva a `SaveAsync` hívásnak, így a művelet nem cancelálható.

```diff
- await _repository.SaveAsync(order);
+ await _repository.SaveAsync(order, cancellationToken);
```
````

## ❌ DON'T

```text
(PR komment feltöltése a remote-ra, vagy PR létrehozása MCP/gh hívással.)
```

```text
(A working tree-be írt review-komment vagy suggestion commitolása/pusholása —
a fájlmódosítás OK és látszik a diffben, de commit/push SOHA.)
```

```text
("The cancellation token is not flowed…" — ne angolul írd a prózát; magyarul,
de a szakkifejezések (`cancellation token`) maradnak angolul.)
```
