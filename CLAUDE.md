# Claude Rules — Project Memory

This file is the entry point for Claude Code when this repository (or a symlinked copy of it) is loaded.

It applies the shared rule set in `.claude/rules/` and follows the **mandatory first action** defined in [`claude-rules-source.md`](.claude/rules/claude-rules-source.md).

## How this repo is structured (two tiers)

To keep the baseline context small, the rules are split into two tiers:

1. **Core rules — `.claude/rules/`** — small, (almost) always-relevant rules that are **eagerly imported** below, so they are active in every session regardless of the task. These are cheap and include the safety-critical ones (reply marker, language, git/push permissions, format preservation).
2. **Domain skills — `.claude/skills/`** — large, task-specific rule packs exposed as **Claude Code skills**. Only each skill's one-line `description` is loaded up front; the full content is pulled in **on demand** when the task triggers the skill (progressive disclosure). This is where the bulk of the tokens live (.NET, Terraform, AWS, code review).

Rationale: the `@import` mechanism is deterministic but eager (everything loads always). Skills are lazy but model-triggered. So safety-critical, always-true rules stay in the eager **core**, and heavy, occasional domain rule sets become **skills**.

## How to use this file

- Place this repository (or a symlink of `.claude/rules/`) inside a project, or import this `CLAUDE.md` from your global `~/.claude/CLAUDE.md`, so Claude Code sees the core rules.
- Claude Code automatically loads `CLAUDE.md` from the project root and any subdirectory you operate in. This file imports the **core** rule set below.
- The marker line specified in `claude-rules-source.md` MUST be the first line of every Claude reply when these rules are active.

## Making the skills globally available (one-time setup per machine)

Claude Code discovers skills under `~/.claude/skills/` (personal, all projects) and `<project>/.claude/skills/`. To make the repo's skills available in **every** project while keeping the repo as the single source of truth, link them via a **junction** (Windows, no admin/developer-mode needed):

```powershell
New-Item -ItemType Junction -Path "$env:USERPROFILE\.claude\skills" -Target "C:\Users\nyiria\source\repos\claude-rules\.claude\skills"
```

macOS/Linux equivalent:

```bash
ln -s ~/source/repos/claude-rules/.claude/skills ~/.claude/skills
```

After linking, `dotnet`, `terraform`, `aws`, `local-code-review`, and `devils-advocate-review` are triggerable from any project.

## Core rule index (eager imports)

@.claude/rules/claude-rules-source.md
@.claude/rules/claude-meta-rule.md
@.claude/rules/token-economy.md
@.claude/rules/communication-language.md
@.claude/rules/file-format-preservation.md
@.claude/rules/documentation-style.md
@.claude/rules/git-conventions.md
@.claude/rules/git-line-endings.md
@.claude/rules/session-naming.md

## What each core rule covers

| File | Covers |
|------|--------|
| `claude-rules-source.md` | Mandatory first-action read + reply marker line. **Always applies.** |
| `claude-meta-rule.md` | How Claude must edit `*.md` rule files in this repo. |
| `token-economy.md` | **Critical:** minimize token consumption; trade speed (not quality) for fewer tokens; **fan-out / multiple parallel agents need explicit permission (even under ultracode) — one `+1` parallel agent is allowed sparingly to save time.** |
| `communication-language.md` | Reply in Hungarian by default (incl. visible reasoning/process text); mirror the user's language; keep technical terms untranslated. |
| `file-format-preservation.md` | Preserve file encoding, line endings, indentation during edits. |
| `documentation-style.md` | XML doc / inline comment / Terraform comment limits — terse, "why not what". |
| `git-conventions.md` | Jira `[NX-32472]` commit prefix, `feature/NX-32472_purpose` branch naming, commit message format, no AI-tool markers, push only with permission, small commits. |
| `git-line-endings.md` | `.gitattributes` policy and CRLF/LF normalization. |
| `session-naming.md` | Start each session title with the repo/folder name so sessions stay scannable across projects. |

## Skills (on-demand, `.claude/skills/`)

Each skill is a thin `SKILL.md` (trigger + index) over the detailed rule files in its `references/`. Claude reads only the reference files a given task needs.

| Skill | Triggers on | References |
|------|-------------|-----------|
| `dotnet` | C#/.NET code, `.csproj`/`.sln`/`Directory.*.props`, NuGet, xUnit, MSBuild, ASP.NET | 14 files: C# style, API, testing, repo structure, solution, dependencies, build system, locked restore, project file format, tools (consuming/publishing), NuGet (publishing/signing), benchmarking |
| `terraform` | `.tf`/`.hcl`, `infra/`, Terragrunt/OpenTofu, `plan`/`apply`; `apply` needs permission | Terraform/Terragrunt layout, root/account/env, modules |
| `aws` | any AWS work: services, API/SDK (boto3, SDK for .NET), `aws` CLI, IAM policy/action, service quota, endpoint, CloudFormation, Well-Architected | Agent Toolkit for AWS (`aws-core` plugin: `aws-mcp` MCP server + 15 curated skills) as primary; official AWS docs over public URLs via `WebFetch` as fallback; docs-over-memory; knowledge not action (mutating ops stay permission-gated); traffic generation kept low by default (dashboard ~10–20 calls, endpoint 1–2) |
| `local-code-review` | explicit "sima / kiegyensúlyozott / enyhe / light review" kérés (nem a default) | Balanced, non-adversarial local review in Hungarian; shared mechanics source for `devils-advocate-review`; never commit/push/publish |
| `devils-advocate-review` | **default review technika** — "review-eld", "/review", "nézd át a változásokat", + "devil's advocate", "ördög ügyvédje", "nézd át kritikusan", "stress-test-eld" | Adversarial default review on `local-code-review`'s mechanics; structured 8-section verdict; local-only, never commit/push/publish |
