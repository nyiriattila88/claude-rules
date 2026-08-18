---
description: A meta-rule for Claude when reading or updating *.md rule files in this repository.
applies_to: "**/*.md"
priority: when-editing-rules
---

# Claude Rules: Meta Rule

This document outlines the meta-rules for Claude operations on rule files in this repository.

## Line Ending & Formatting Rules

1. **Line Endings**
   - Don't modify existing line endings.
   - Preserve CRLF/LF as found in the original file.

2. **Whitespace**
   - Preserve trailing whitespace where it exists.
   - Maintain existing indentation style (spaces vs tabs).
   - Keep line length consistent with existing code.

## File Handling

1. **Rule Files (`*.md` under `.claude/rules/`)**
   - Always commit changes to `*.md` rule files directly.
   - Ensure changes to `*.md` rule files are synchronized with their implementation.
   - Maintain consistent formatting within rule files.
   - Prefer modifying existing files over creating new ones unless explicitly requested.
   - When adding new content, first check if it fits within an existing rule file.

2. **File Creation**
   - Only create new rule files when:
     - Explicitly requested by the user.
     - The content doesn't logically fit in any existing rule file.
     - Creating a new file would significantly improve organization and clarity.
   - Document the rationale for creating new files in the repository `README.md`.

## Code Style & Structure

1. **Formatting**
   - Preserve existing code formatting patterns.
   - Maintain consistent naming conventions.
   - Keep indentation consistent with file style.

2. **Organization**
   - Keep file structure consistent.
   - Don't move files without updating all references.
   - Maintain existing import/include order.

## Rule Content

1. **Examples**
    - Always include "do" and "don't" examples when showing specific changes to files or syntax.
    - Include helpful comments that explain why an example is a "do" or a "don't".

## Documentation

1. **README.md**
    - Each `*.md` rule file is grouped under `.claude/rules/` and listed in the repository `README.md` explaining what the rule does and when it's used.
