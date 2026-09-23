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

# Skill marker

When a skill was loaded in the current turn, the reply header names it too, with where it comes from, so the chat shows which domain rules are in play and whose they are. It is one line directly below the marker (and below any further header line the global `CLAUDE.md` adds), before the blank line that opens the answer:

```text
[Skill betöltve: <name> (saját|telepített), <name> (saját|telepített)]
```

- **`saját`** only when the skill loads from `~/.claude/skills/<name>` (this repo, through the junction) or from the current project's `.claude/skills/<name>`. Read it from the base directory the skill reports when it loads, or check whether that folder exists.
- **`telepített`** for everything else: plugin skills (`aws-core:`, `canva:`), `anthropic-skills:`, and the skills that ship with Claude Code (`simplify`, `update-config`, `loop`).
- **The prefix does not decide it.** The skills that ship with Claude Code are unprefixed, exactly like the ones in this repo.
- **This turn only.** Loaded means a `Skill` tool call in this turn, or the user invoking it as `/<name>`. A skill loaded in an earlier turn is not listed again.
- **Loaded after the header was written** (text came before the tool calls): the line opens the next text block of the same reply instead.
- **One line for all of them**, in load order, each name exactly as invoked.
- **Fixed text.** The line does not follow the reply language, so it stays greppable across transcripts.
- **No skill, no line.** Never write a placeholder such as `[Skill betöltve: nincs]`.

The line is a self-report, like the marker above. Where the hooks are wired, `post-tool-use-skill-marker.ps1` also shows every `Skill` load as a harness message, and that one does not depend on the model.

## ✅ DO

```text
#### 🔗 Rules were loaded from https://github.com/nyiriattila88/claude-rules
[CLAUDE.md aktív: ~/.claude/CLAUDE.md]
[Skill betöltve: terraform (saját), aws-core:aws-iam (telepített)]

A plan 2 resource-ot hoz létre, destroy nincs benne.
```

## ❌ DON'T

```text
(A `simplify` prefix nélküli, de a Claude Code hozza, nem ez a repo:)
[Skill betöltve: simplify (saját)]
```

```text
(A skill-sor az üres sor után, a válasz szövegébe csúszik:)
#### 🔗 Rules were loaded from https://github.com/nyiriattila88/claude-rules
[CLAUDE.md aktív: ~/.claude/CLAUDE.md]

[Skill betöltve: dotnet (saját)] Átnéztem a csproj-t.
```

# Official skills

A custom skill in this repo carries the house rules, an official skill carries the vendor's current guidance, and a task in a domain that has both needs both. Load the matching official skill in the same turn as the custom one, before the first action or answer that relies on it. For AWS that is `aws` plus the `aws-core:` skill that fits the task.

For AWS this is enforced, not only asked: `pre-tool-use-official-skills.ps1` denies every `aws` CLI call and `aws-mcp` tool call until the session transcript shows both loads. A denial is not an obstacle to route around, load the named skills and run the same call again.

## ✅ DO

```text
(Az első AWS-hívás előtt mindkettő betöltődik, a fejléc ezt mutatja:)
[Skill betöltve: aws (saját), aws-core:aws-containers (telepített)]
```

## ❌ DON'T

```text
(A kapu elutasította az `aws` hívást, ezért ugyanezt egy boto3-as py scripttel futtatom,
amit a kapu nem lát. A szabály a skillek betöltéséről szól, nem az `aws` binárisról.)
```
