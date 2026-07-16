# Claude Rules (Remote)

This repository is an external **rule source** for Claude Code: all rules live in **`.claude/rules/`**, with a master [`CLAUDE.md`](CLAUDE.md) at the root that imports them.

It is the Claude Code counterpart of [`cursor-rules`](https://github.com/nyiriattila88/cursor-rules) — same content, adapted to Claude's memory and instruction model.

## Architecture — two tiers (token economy)

Rules split into two tiers so the per-session baseline context stays small:

- **Core rules — `.claude/rules/`** — small, (almost) always-relevant, safety-critical rules. **Eagerly imported** by `CLAUDE.md`, so active in every session.
- **Domain skills — `.claude/skills/`** — large, task-specific rule packs exposed as Claude Code **skills**. Only each skill's one-line `description` loads up front; the full content is pulled in on demand when the task triggers it (progressive disclosure).

Why: `@import` is deterministic but eager (loads everything, always); skills are lazy but model-triggered. So safety-critical, always-true rules stay in the eager **core**, and heavy, occasional domain rule sets became **skills**. Typical baseline dropped from ~53k to ~8k tokens with no loss of quality — when a domain rule is actually needed it loads in full.

## Repo structure

- **`CLAUDE.md`** – Root memory file. Auto-loaded by Claude Code; imports the **core** rules and documents the skills.
- **`.claude/rules/`** – core `.md` rules, one rule per file (eager import).
- **`.claude/skills/`** – domain skills: each is a thin `SKILL.md` (trigger + index) over detailed rule files in its `references/` (on-demand).

```
claude-rules/
  CLAUDE.md
  .claude/
    rules/                         # core, eager import
      claude-rules-source.md
      claude-meta-rule.md
      token-economy.md
      communication-language.md
      file-format-preservation.md
      documentation-style.md
      git-conventions.md
      git-line-endings.md
      session-naming.md
    skills/                        # domain, on-demand
      dotnet/
        SKILL.md
        references/                # 14 .NET rule files
          dotnet-csharp-style.md
          dotnet-api.md
          dotnet-testing.md
          dotnet-repository-structure.md
          dotnet-solution.md
          dotnet-dependencies.md
          dotnet-build-system.md
          dotnet-locked-restore-ci.md
          dotnet-project-file-format.md
          dotnet-tools-consuming.md
          dotnet-tools-publishing.md
          dotnet-nuget-publishing.md
          dotnet-nuget-signing.md
          dotnet-benchmarking.md
      terraform/
        SKILL.md
        references/terraform-terragrunt.md
      local-code-review/
        SKILL.md
        references/local-code-review.md
      devils-advocate-review/
        SKILL.md
        references/devils-advocate-review.md
  README.md
  .gitignore
  .gitattributes
```

## Making the skills globally available (one-time per machine)

Claude Code discovers personal skills under `~/.claude/skills/`. To expose this repo's skills in **every** project while keeping the repo as source of truth, link them via a **junction** (Windows, no admin needed):

```powershell
New-Item -ItemType Junction -Path "$env:USERPROFILE\.claude\skills" -Target "C:\Users\nyiria\source\repos\claude-rules\.claude\skills"
```

macOS/Linux:

```bash
ln -s ~/source/repos/claude-rules/.claude/skills ~/.claude/skills
```

After linking, `dotnet`, `terraform`, `local-code-review`, and `devils-advocate-review` trigger from any project.

## Using with a symlink (recommended)

1. Clone the repo (e.g. `git clone https://github.com/nyiriattila88/claude-rules.git`).
2. In the project where you want to use the rules: make the **project's** `.claude/rules` point to this repo's **`.claude/rules`** folder, and import its `CLAUDE.md` (or copy/symlink it).

   **Windows (Junction, no admin):**
   ```powershell
   # From the project root, if .claude\rules does not exist yet
   New-Item -ItemType Junction -Path ".claude\rules" -Target "C:\path\to\claude-rules\.claude\rules"
   ```

   **Windows (SymbolicLink, admin required):**
   ```powershell
   New-Item -ItemType SymbolicLink -Path ".claude\rules" -Target "C:\path\to\claude-rules\.claude\rules"
   ```

   **macOS/Linux:**
   ```bash
   ln -s /path/to/claude-rules/.claude/rules .claude/rules
   ```

3. In the project's root `CLAUDE.md`, add an import to the shared rules entry point:

   ```markdown
   @.claude/rules/claude-rules-source.md
   @.claude/rules/claude-meta-rule.md
   # ... import the others as needed, see this repo's CLAUDE.md
   ```

   Claude Code follows `@<path>` imports recursively and treats the imported content as project memory.

### Symlink inside `.claude/rules` (shared + local)

If you want to keep **local rules** in the project and have the **shared rules** appear in a subfolder (e.g. `symlinked`):

1. Create a real `.claude/rules` folder (if it doesn't exist).
2. Inside it, create a junction/symlink named `symlinked` that points to this repo's `.claude/rules`.

   **Windows (Junction):**
   ```powershell
   New-Item -ItemType Directory -Path ".claude\rules" -Force
   New-Item -ItemType Junction -Path ".claude\rules\symlinked" -Target "C:\path\to\claude-rules\.claude\rules"
   ```

   **macOS/Linux:**
   ```bash
   mkdir -p .claude/rules
   ln -s /path/to/claude-rules/.claude/rules .claude/rules/symlinked
   ```

3. **Ignore the symlinked folder in Git** so the other repo's content is not committed. In your **project's** root `.gitignore` add:
   ```
   .claude/rules/symlinked
   ```

   Result: `.claude/rules/` contains your local `.md` files and `symlinked/` (ignored by Git) showing the shared rules. Update your project's `CLAUDE.md` imports accordingly (e.g. `@.claude/rules/symlinked/claude-rules-source.md`).

## Adding a new rule — core or skill?

Decide the tier first:

- **Core rule** — if it is small, (almost) always relevant, or safety-critical (must always be active, cannot rely on trigger heuristics). Add a new **`.md`** under **`.claude/rules/`** and an `@.claude/rules/<file>.md` import to the root `CLAUDE.md`.
- **Skill** — if it is large and task-specific. Add `.claude/skills/<name>/SKILL.md` with a strong `description` (this is what the model matches to trigger the skill) and put the detailed rule files under `.claude/skills/<name>/references/`. No `CLAUDE.md` import is needed; Claude Code discovers skills under `~/.claude/skills/` (via the junction above) and `<project>/.claude/skills/`.

A skill's `SKILL.md` should stay a thin dispatcher (trigger + an index of which reference file to read for which subtask), so even after triggering, only the relevant reference is loaded.

## Contributing

- Keep rules short (< 500 lines) and focused on one topic.
- `.claude/rules/claude-meta-rule.md` is the meta-rule for how to handle `.md` rule files in this repo.
- `.claude/rules/token-economy.md` was added as a standalone cross-cutting rule because token-cost vs. speed trade-offs are an agent-behavior concern that did not fit any existing rule file.
- Treat the rule files as the single source of truth; do not duplicate the content in other places.
