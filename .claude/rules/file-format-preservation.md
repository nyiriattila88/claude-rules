---
description: Preserve file encoding, line endings, and indentation during edits.
globs: "**/*"
alwaysApply: false
---

# File Format Preservation

When modifying existing files, preserve their text format characteristics unless explicitly requested otherwise.

## Requirements

- Keep the original file encoding unchanged (for example UTF-8, UTF-8 BOM, UTF-16, ANSI/code page encodings).
- Keep original line endings unchanged (CRLF or LF).
- Keep existing leading whitespace/indentation unchanged for untouched lines and surrounding blocks.
- When replacing a code block, preserve the block's indentation depth (do not dedent method/class members).
- Do not run tools that rewrite encoding or line endings across the repository unless explicitly requested.
- If unsure about encoding, prefer non-destructive edits that keep existing bytes/format intact.

## ✅ DO

```text
Edit only the required lines and keep existing encoding + line endings.
```

```text
When changing method signatures or attributes, keep the original indentation level.
```

## ❌ DON'T

```text
Convert entire files from CRLF to LF or LF to CRLF during unrelated edits.
```

```text
Re-save files with a different UTF encoding without explicit request.
```

```text
Accidentally remove leading spaces/tabs from a method declaration while editing parameters.
```
