---
description: Git commit and workflow conventions – Jira ID prefix, branch naming, message format, small commits, no push.
globs: "**/*"
alwaysApply: false
---

# Git conventions

When working with Git in this repository, follow these rules.

## Commit message format

- Commit messages must be **single-line only** (no body, no second line).
- Maximum commit message length is **70 characters**.
- If a Jira issue ID is available (e.g. the user gives `NX-32472`), start the message with a `[NX-32472] ` prefix so the commit is tied to its ticket, e.g. `[NX-32472] Initialize repository`.
- The prefix format is `[<PROJECT-KEY>-<NUMBER>] <summary>` for any Jira project key (`NX`, `PROJ`, …); keep the ID in its Jira casing (uppercase), and keep the whole line within the 70-character limit.
- If no Jira issue ID is available, do **not** force a Jira prefix.
- Never include AI tool markers in commit metadata or messages, including but not limited to: `Made-with: Cursor`, `Made-with: Claude`, `Co-Authored-By: Claude`, `Co-Authored-By: Claude Code`, `🤖 Generated with Claude Code`, or any similar attribution to an AI assistant.

### ✅ DO

```
[NX-32472] Initialize repository
```

```
[PROJ-123] Add locked restore CI rule
```

```
Refine .NET rule wording for lock files
```

### ❌ DON'T

```
[PROJ-123] Add locked restore CI rule

With extra body text
```

```
[PROJ-123] This message is intentionally made too long to exceed seventy characters total
```

```
Made-with: Cursor
```

```
Co-Authored-By: Claude <noreply@anthropic.com>
```

```
🤖 Generated with [Claude Code](https://claude.com/claude-code)
```

## Branch naming

- When working on a specific Jira task, name the feature branch after its ticket: `feature/<JIRA-ID>_<purpose>`.
- Start with `feature/`, then the Jira ID in its Jira casing, then an **underscore**, then a short snake_case description of the ticket's goal (lowercase words joined by underscores).
- Keep the purpose part short but descriptive, it says *why* the branch exists, matching the ticket's intent.
- Same `[<PROJECT-KEY>-<NUMBER>]` prefix belongs on every commit made on that branch (see **Commit message format**).

### ✅ DO

```
feature/NX-32472_initialize_repository
```

```
feature/NX-32472_add_jira_commit_prefix_rule
```

### ❌ DON'T

```
(No ticket reference, no purpose, nothing ties the branch to its Jira task:)
feature/new-stuff
```

```
(Purpose joined with dashes instead of underscores, use `_` after the ID and between words:)
feature/NX-32472-initialize-repository
```

### Worktree branches

- Working inside a **worktree** does **not** force the harness default `claude/` branch prefix. If the user asks for a feature branch, create exactly what they asked for, the same `feature/<JIRA-ID>_<purpose>` convention above applies in a worktree too.
- The `claude/…` prefix is only a fallback for when the user gave **no** branch instruction. An explicit request (a ticket, a name, or "csinálj feature branchet") always wins over it, worktree or not.

#### ✅ DO

```
(User asked for a feature branch on NX-32472 while working in a worktree:)
feature/NX-32472_add_worktree_branch_rule
```

#### ❌ DON'T

```
(Forcing the `claude/` prefix in a worktree even though the user asked for a feature branch:)
claude/add-worktree-branch-rule
```

### Repositories worked directly on `main`

Not every repository uses a feature-branch flow. **`claude-rules` is worked directly on `main`**, it is a single-author personal rule source, so commits are expected to land on `main` and no `feature/...` branch is created there unless explicitly asked. The branch-naming convention above governs repositories that go through PRs.

Working on `main` moves all the risk to the push: there is no PR to catch a mistake, and the remote branch is the only copy of the shared history. See the push policy below.

## Commit size and scope

- **Commit small, logically related changes.** One commit = one logical change (e.g. one fix, one feature step, one refactor). Avoid mixing unrelated edits or huge multi-file dumps in a single commit.

## Commit creation policy

- **Never create commits by default.** Create a commit only if the user explicitly asks for it in the current conversation.

## Staging policy

- When a **new file** is created, running `git add <new-file>` is allowed as a normal action.
- This staging rule does **not** allow creating a commit automatically; commit still requires explicit user request.

## Push policy

- **Push only with explicit permission.** Never run `git push` (or any equivalent: sync, upload, publish, push to remote) on your own initiative. **Always ask first**, unless the user has authorized it in the current prompt, in that case you may push.
- **Force-push is especially destructive.** `git push --force`, `git push -f`, or any forced update to a remote branch still requires **explicit** permission, and you must prefer a safer alternative (e.g. `--force-with-lease`) when a force update is genuinely needed.
- **Never overwrite what is already on the remote.** If the remote branch carries commits the local one does not (a push from another machine, another session, or someone else), the answer is to **integrate**, never to overwrite: `git fetch`, then rebase onto `origin/<branch>`, then a plain `git push`. A force update deletes those commits from the remote, and on a repo worked directly on `main` there is no PR or second branch to recover them from.
- **A rejected push is information, not an obstacle.** `! [rejected] ... (fetch first)` means the remote moved ahead. Rebase and push again; do not reach for `--force` or `--force-with-lease` to make the message disappear. Even `--force-with-lease`, the safer form, is only for a branch whose history you deliberately rewrote, and still needs explicit permission.
- Default to keeping work local; treat pushing to remote as a state-changing, outward-facing action that the user must approve. The same permission model applies to `terraform`/`terragrunt`/`tofu apply` (see `terraform-terragrunt.md`).

### ✅ DO

```text
I've committed the change locally. Do you want me to push it to the remote?
```

```bash
# A remote előrébb van: integrálom, nem írom felül.
git fetch origin
git rebase origin/main
git push
```

### ❌ DON'T

```text
(Running `git push origin main` without being asked or pre-authorized.)
```

```bash
# Az elutasított pusht force-szal "megoldom": a remote-on lévő commitok eltűnnek.
git push --force origin main
```

## Pull request description

The merge commit **carries the PR description**, so the same rule applies to it as to commit messages: write it in **English**, even when the conversation itself runs in another language.

Structure, a Jira link, then three fixed sections. The section titles are **markdown headings** (`## Why`), not bare labels: the description renders as markdown, so a plain `Why` line becomes body text and the three sections blur into one wall. Keep a blank line after every heading and between paragraphs.

```markdown
[[NX-12345] Ticket title](https://<org>.atlassian.net/browse/NX-12345)

## Why

What made the change necessary: the missing capability, the wrong behaviour, or the
misleading contract. State the cause, not the solution.

## What

* `path/to/file`, what it does now, in one sentence.
* `other/file`, the non-obvious decision a reviewer would not spot in the diff.

## Notes

Whatever the review needs beyond the above: validation evidence, measurements, a scope
boundary ("documentation only; no behaviour change"), or a required merge order.
```

- The `What` bullets are **file- or component-level**, in backticks, followed by `,` and one terse sentence. They are not a commit list, the commits are already in the PR.
- **Validation evidence belongs in `Notes`**: pipeline run ids, test counts, what was actually measured versus what was only reasoned about.
- If the change spans repositories, the **merge order** goes into `Notes` as well.

### ✅ DO

```markdown
## Why

`Attachment.DownloadUrl` promised a file stream, but content answered from the
integration now carries an endpoint that returns a short-lived URL instead.
```

### ❌ DON'T

```markdown
(Bare labels where headings belong, they render as body text, so the sections vanish:)
Why
`Attachment.DownloadUrl` promised a file stream, but content answered from the
integration now carries an endpoint that returns a short-lived URL instead.
```

```text
(A description in the conversation's language, or a bare list of commit subjects with
no Why, the merge commit inherits both.)
```

## PR comments and review threads: Hungarian, and no AI marker

A PR **comment** is not the PR **description**. The description is English because the merge commit carries it forward; a review comment carries nothing forward, it is a conversation with the team, so [[communication-language]] applies and it goes in **Hungarian, with proper accents**. Technical terms stay in their canonical English form.

- **Do not silently switch to English** because a tool makes non-ASCII hard to transport. Fix the transport (see [[azure-devops-cli]], `az devops invoke` drops non-ASCII when called from PowerShell), or say that you can't and ask. Language is the user's call, not a workaround for an encoding bug.
- **No AI marker on the comment.** The commit rule applies here too: no `🤖 AI-generated review` banner, no `Made-with`, no assistant attribution. If a project's own instructions demand such a disclaimer, that conflict is the user's to resolve, surface it, don't add the marker on your own initiative.
- **One or two sentences per thread**, anchored to the line it is about. The long analysis belongs in the chat verdict; a PR thread that needs three paragraphs is usually two threads.

### ✅ DO

```text
Az overview-ban a blue/green bontás nem ad hozzá semmit: aki ide néz, a szolgáltatás
összes kérését keresi. Kérlek cseréld egy `SUM([m1,m2])` kifejezésre.
```

### ❌ DON'T

```text
(Két hiba egyszerre: AI-marker, és angolra váltás az ékezetek helyett.)

> 🤖 _AI-generated review_

In the overview the blue/green split adds nothing...
```
