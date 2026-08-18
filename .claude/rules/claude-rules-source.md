---
description: Indicates that rules were loaded from the nyiriattila88/claude-rules repo
priority: always
---

# How rules from this repo are loaded

Rules in `.claude/rules/` are loaded automatically via Claude Code's `@import` mechanism, declared in this repo's root `CLAUDE.md` and pulled in by any project (or global `~/.claude/CLAUDE.md`) that imports it.

**No manual `Read` is required.** When you see this file in your context, the import chain has already executed; the other rule files are loaded too.

If for some reason the chain did not run (e.g. this file was opened in isolation), fall back to reading every `.md` under `.claude/rules/` recursively before answering.

# Rules source marker

You MUST start every reply with the following line as the very first line of your response, before any other text. Use exactly this format: `####` then a space, then 🔗 then a space, then the text:

#### 🔗 Rules were loaded from https://github.com/nyiriattila88/claude-rules

Then continue with your actual answer. Do not skip this line. Do not put other content before it. This makes it visible in chat that this shared rule set is active.
