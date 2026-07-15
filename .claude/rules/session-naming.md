# Session naming

When several repositories are in play, a session's title should say **which repo or folder it belongs to** at a glance. Start every session title with the repository (or working-directory) name so the session list stays scannable across projects.

## When to apply it

- Apply this whenever you **set or propose** a session title: when you (re)name a session with the session-title tool, or when the user asks to name/rename one.
- **Tool reality:** `set_session_title` renames **another** session and asks for confirmation — there is **no** tool to auto-rename the *current* live session. For guaranteed automatic prefixing, a `SessionStart` hook in the harness settings is the deterministic mechanism; a rule alone cannot rename the running session.
- Set it **once**; don't rename every turn. Change it only if the session's focus shifts substantially.

## Which name to use as the prefix

- **Git repository:** the repo root folder name — the basename of `git rev-parse --show-toplevel`.
- **Not a git repo:** the current working-directory folder name.
- Use the name **verbatim**; don't translate or reformat it (see [[communication-language]] — code/identifier names stay canonical).

## Format

```
<repo-or-folder>: <short task description>
```

- Prefix = the repo/folder name, then `: `, then a short, specific description of what the session is about.
- Keep the description terse. Its language follows [[communication-language]] (Hungarian by default, technical terms verbatim); the prefix stays as-is.

## ✅ DO

```
(Working dir C:\Users\nyiria\source\repos\claude-rules — a git repo:)
claude-rules: worktree branch-naming szabály

(Non-git folder ~/scratch/notes:)
notes: markdown export tisztítása
```

## ❌ DON'T

```
(No repo/folder prefix — can't tell which project the session belongs to:)
Branch szabály javítása
```

```
(Prefix is not the repo/folder name — defeats the purpose:)
saját-munka: worktree branch-naming szabály
```
