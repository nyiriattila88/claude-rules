---
description: Git commit and workflow conventions – Jira ID, message format, small commits, no push.
globs: "**/*"
alwaysApply: false
---

# Git conventions

When working with Git in this repository, follow these rules.

## Commit message format

- Commit messages must be **single-line only** (no body, no second line).
- Maximum commit message length is **70 characters**.
- If a Jira issue ID is available, start with `[JIRA-123] ` prefix.
- If no Jira issue ID is available, do **not** force a Jira prefix.
- Never include AI tool markers in commit metadata or messages, including but not limited to: `Made-with: Cursor`, `Made-with: Claude`, `Co-Authored-By: Claude`, `Co-Authored-By: Claude Code`, `🤖 Generated with Claude Code`, or any similar attribution to an AI assistant.

### ✅ DO

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
