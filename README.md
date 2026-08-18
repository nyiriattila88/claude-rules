# Claude Rules (Remote)

This repository is an external **rule source** for Claude Code: all rules live in **`.claude/rules/`**, with a master [`CLAUDE.md`](CLAUDE.md) at the root that imports them.

It is the Claude Code counterpart of [`cursor-rules`](https://github.com/nyiriattila88/cursor-rules), same content, adapted to Claude's memory and instruction model.

## Architecture: two tiers (token economy)

Rules split into two tiers so the per-session baseline context stays small:

- **Core rules, `.claude/rules/`**, small, (almost) always-relevant, safety-critical rules. **Eagerly imported** by `CLAUDE.md`, so active in every session.
- **Domain skills, `.claude/skills/`**, large, task-specific rule packs exposed as Claude Code **skills**. Only each skill's one-line `description` loads up front; the full content is pulled in on demand when the task triggers it (progressive disclosure).
- **Cross-session lessons, `.claude/lessons/`**, what sessions *learn*, as opposed to what they are *told*. `general.md` (project- and machine-independent) is eagerly imported; `workspaces/<COMPUTERNAME>.md` is read on demand once per session. A lesson that hardens into a normative statement is promoted into a rule and deleted from the collection, see [`lessons-learned.md`](.claude/rules/lessons-learned.md).

Why: `@import` is deterministic but eager (loads everything, always); skills are lazy but model-triggered. So safety-critical, always-true rules stay in the eager **core**, and heavy, occasional domain rule sets became **skills**. Typical baseline dropped from ~53k to ~8k tokens with no loss of quality, when a domain rule is actually needed it loads in full.

## Repo structure

- **`CLAUDE.md`** – Root memory file. Auto-loaded by Claude Code; imports the **core** rules and documents the skills.
- **`.claude/rules/`** – core `.md` rules, one rule per file (eager import).
- **`.claude/skills/`** – domain skills: each is a thin `SKILL.md` (trigger + index) over detailed rule files in its `references/` (on-demand).
- **`.claude/lessons/`** – cross-session lessons: `general.md` (eager) and one file per machine under `workspaces/` (on-demand).
- **`.claude/hooks/`** – the automation behind the lessons collection: a `SessionStart` hook that injects this machine's lessons, and a `Stop` hook that asks for a sweep once per session.

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
      git-identity.md
      git-line-endings.md
      deployment-path.md
      session-naming.md
      shell-path-conversion.md
      lessons-learned.md
    lessons/                       # cross-session lessons
      general.md                   # eager import
      workspaces/                  # on-demand, one file per machine
        LMSONE-NB03.md
    hooks/                         # lessons automation (wired per machine)
      session-start-lessons.ps1
      stop-lessons-sweep.ps1
      settings.hooks.example.json
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
      aws/
        SKILL.md
        references/
          aws-documentation.md
          aws-orphan-resource-audit.md
      jira/
        SKILL.md
        references/jira-issue-conventions.md
      azure-devops/
        SKILL.md
        references/azure-devops-cli.md
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

After linking, `dotnet`, `terraform`, `aws`, `jira`, `azure-devops`, `local-code-review`, and `devils-advocate-review` trigger from any project.

## Making the lessons collection automatic (one-time per machine)

A rule can say "record what you learned"; only a hook makes it happen without being remembered. Two hooks in `.claude/hooks/` do that, and they are wired into the machine's **own** `~/.claude/settings.json` (user scope, so they apply in every project, the file is per-machine and deliberately not versioned here):

- **`session-start-lessons.ps1`** on `SessionStart`, resolves `$env:COMPUTERNAME` and injects `.claude/lessons/workspaces/<machine>.md` into the session context, so the machine-specific half loads with no lookup and no `Read`. `general.md` needs no hook; `CLAUDE.md` imports it eagerly.
- **`stop-lessons-sweep.ps1`** on `Stop`, once per session, as the turn would end, blocks with a reminder to record anything worth keeping. A per-session marker file in `%TEMP%\claude-lessons-sweep\` makes it fire exactly once, so it cannot loop, and sessions with a transcript under ~30 KB are skipped.

Setup: merge the `hooks` block from [`.claude/hooks/settings.hooks.example.json`](.claude/hooks/settings.hooks.example.json) into `~/.claude/settings.json`, keeping the rest of that file intact, and adjust the absolute script paths to where this repo is cloned. A user-scope `settings.json` normally exists already, so the watcher picks the hooks up immediately, verified: the `Stop` hook fired in the very session that wired it. If they stay silent, start a new session.

Both scripts are **UTF-8 with BOM on purpose**: Windows PowerShell 5.1 reads a BOM-less script as ANSI and mangles every accented string. Keep the BOM when editing them.

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

## Adding a new rule: core or skill?

Decide the tier first:

- **Core rule**, if it is small, (almost) always relevant, or safety-critical (must always be active, cannot rely on trigger heuristics). Add a new **`.md`** under **`.claude/rules/`** and an `@.claude/rules/<file>.md` import to the root `CLAUDE.md`.
- **Skill**, if it is large and task-specific. Add `.claude/skills/<name>/SKILL.md` with a strong `description` (this is what the model matches to trigger the skill) and put the detailed rule files under `.claude/skills/<name>/references/`. No `CLAUDE.md` import is needed; Claude Code discovers skills under `~/.claude/skills/` (via the junction above) and `<project>/.claude/skills/`.
- **Lesson**, if it is an **observation**, not yet a norm: something a session learned that a later session would otherwise re-learn. Add a dated bullet to `.claude/lessons/general.md`, or to `.claude/lessons/workspaces/<COMPUTERNAME>.md` when the fact is true only on that machine. Once the observation hardens into "always/never do X", promote it into a core rule or a skill reference and delete the lesson entry.

A skill's `SKILL.md` should stay a thin dispatcher (trigger + an index of which reference file to read for which subtask), so even after triggering, only the relevant reference is loaded.

## Contributing

- Keep rules short (< 500 lines) and focused on one topic.
- `.claude/rules/claude-meta-rule.md` is the meta-rule for how to handle `.md` rule files in this repo.
- `.claude/rules/token-economy.md` was added as a standalone cross-cutting rule because token-cost vs. speed trade-offs are an agent-behavior concern that did not fit any existing rule file.
- `.claude/rules/deployment-path.md` was added as a standalone core rule because choosing the deployment mechanism has to happen **before** the `terraform` skill would be triggered, a "deploy this to DEV" request must not go straight to a local `apply` when a pipeline owns the deployment. It is eagerly imported for that reason; the `terraform` skill only cross-references it.
- `.claude/rules/shell-path-conversion.md` was added as a standalone core rule because the corruption it describes is **silent** and not tied to one tool: Git Bash rewrites any `/`-leading argument, so the empty result can come from `aws`, `az`, `kubectl` or `gh` alike, and no skill trigger reliably covers all of them. It is eagerly imported because the failure looks like valid evidence, an empty result set, and acting on it can mean deleting a live resource.
- `.claude/rules/git-identity.md` was added as a standalone core rule because *which account* commits is not a Git convention but an identity fact, and getting it wrong is expensive in two different ways: a push from the wrong `gh` account fails with a misleading **403** (read as a scope problem, it invites minting a pointless new token), while a **commit** authored by the wrong account is only fixable by rewriting history. It is eagerly imported so the check happens before the first commit, not after the push fails.
- `.claude/rules/lessons-learned.md` and `.claude/lessons/` were added because this repo is wired into *every* local session, which makes it the only store where knowledge can cross session and project boundaries. It is deliberately separate from the rules: a rule is normative ("always do X"), a lesson is an observation that has not earned that status yet, and the machine-specific half (`workspaces/<COMPUTERNAME>.md`) must not be eagerly imported, because those facts are false on any other box.
- `.claude/hooks/` exists because the lessons collection had to be **automatic**, and instructions alone cannot do that: a rule is only followed if the model happens to act on it, while a hook is executed by the harness every time. The `SessionStart` half also removes the per-session machine-name lookup and `Read`, so the automation is cheaper in tokens than the manual protocol it replaces.
- `.claude/skills/jira/` was added as a new skill because Jira issue conventions (which custom field carries the Acceptance Criteria, what shape `Account` and `Team` expect, what the MCP cannot do) did not fit `azure-devops`, Jira and Azure DevOps Boards are separate systems, and are too project-specific and detailed for a core rule.
- Treat the rule files as the single source of truth; do not duplicate the content in other places.
