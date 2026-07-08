---
description: Git line endings – .gitattributes policy, CRLF/LF warning fix, no autocrlf ambiguity.
globs: ".gitattributes,**/.gitattributes"
alwaysApply: false
---

# Git line endings

When you see Git warnings like *"CRLF will be replaced by LF the next time Git touches it"* (or the reverse), fix them by defining a clear line-ending policy in the repository and normalizing files.

## Policy

- **Prefer LF in the repository** for cross-platform consistency (Linux, macOS, CI). Windows editors can still use CRLF in the working copy if `core.autocrlf` is set, but the committed version is LF.
- **Define the policy in `.gitattributes`** at the repository root. Do not rely only on `core.autocrlf`; that is per-machine and causes the "will be replaced" warnings when it disagrees with the file.

## Required: `.gitattributes` at repository root

Ensure the root has a `.gitattributes` that sets text files to normalize to LF:

```gitattributes
# Default: treat as text, normalize line endings to LF in the repo
* text=auto eol=lf
```

- `text=auto`: Git detects text files and normalizes them.
- `eol=lf`: On commit, line endings are stored as LF.

Optional overrides (only if needed):

```gitattributes
# Keep batch/shell scripts with CRLF if they must run on Windows as-is
# *.bat text eol=crlf
# *.ps1 text eol=crlf
```

## Fixing the "CRLF will be replaced by LF" warning

1. **Add or update `.gitattributes`** at the repository root with `* text=auto eol=lf` (as above).
2. **Renormalize** so all tracked files match the new policy:
   ```bash
   git add --renormalize .
   ```
3. **Check** that the affected files (e.g. `README.md`) show as modified; then commit the `.gitattributes` and the renormalized files. After that, the warning should stop.

Do not run renormalize or change line endings across the repo unless the user is explicitly fixing line-ending warnings or setting up policy (see `file-format-preservation.md` for normal edits).

## ✅ DO

- Keep a root `.gitattributes` with `* text=auto eol=lf` (or an explicit eol choice).
- Use `git add --renormalize .` when introducing or changing line-ending policy.
- Commit `.gitattributes` and the renormalized files together.

## ❌ DON'T

- Rely only on `core.autocrlf` to define repo policy.
- Change line endings in arbitrary file edits; use renormalize only when fixing line-ending policy or warnings.
- Remove or override `.gitattributes` without the user asking.
