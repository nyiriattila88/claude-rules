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
- Keep the purpose part short but descriptive — it says *why* the branch exists, matching the ticket's intent.
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
(No ticket reference, no purpose — nothing ties the branch to its Jira task:)
feature/new-stuff
```

```
(Purpose joined with dashes instead of underscores — use `_` after the ID and between words:)
feature/NX-32472-initialize-repository
```

## Commit size and scope

- **Commit small, logically related changes.** One commit = one logical change (e.g. one fix, one feature step, one refactor). Avoid mixing unrelated edits or huge multi-file dumps in a single commit.

## Commit creation policy

- **Never create commits by default.** Create a commit only if the user explicitly asks for it in the current conversation.

## Staging policy

- When a **new file** is created, running `git add <new-file>` is allowed as a normal action.
- This staging rule does **not** allow creating a commit automatically; commit still requires explicit user request.

## Push policy

- **Push only with explicit permission.** Never run `git push` (or any equivalent: sync, upload, publish, push to remote) on your own initiative. **Always ask first**, unless the user has authorized it in the current prompt — in that case you may push.
- **Force-push is especially destructive.** `git push --force`, `git push -f`, or any forced update to a remote branch still requires **explicit** permission, and you must prefer a safer alternative (e.g. `--force-with-lease`) when a force update is genuinely needed.
- Default to keeping work local; treat pushing to remote as a state-changing, outward-facing action that the user must approve. The same permission model applies to `terraform`/`terragrunt`/`tofu apply` (see `terraform-terragrunt.md`).

### ✅ DO

```text
I've committed the change locally. Do you want me to push it to the remote?
```

### ❌ DON'T

```text
(Running `git push origin main` without being asked or pre-authorized.)
```
