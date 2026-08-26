# Claude Rules: Project Memory

This file is the entry point for Claude Code when this repository (or a symlinked copy of it) is loaded.

It applies the shared rule set in `.claude/rules/` and follows the **mandatory first action** defined in [`claude-rules-source.md`](.claude/rules/claude-rules-source.md).

## How this repo is structured (two tiers)

To keep the baseline context small, the rules are split into two tiers:

1. **Core rules, `.claude/rules/`**, small, (almost) always-relevant rules that are **eagerly imported** below, so they are active in every session regardless of the task. These are cheap and include the safety-critical ones (reply marker, language, git/push permissions, format preservation).
2. **Domain skills, `.claude/skills/`**, large, task-specific rule packs exposed as **Claude Code skills**. Only each skill's one-line `description` is loaded up front; the full content is pulled in **on demand** when the task triggers the skill (progressive disclosure). This is where the bulk of the tokens live (.NET, Terraform, AWS, code review).

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

After linking, `dotnet`, `typescript`, `terraform`, `aws`, `azure-devops`, `local-code-review`, and `devils-advocate-review` are triggerable from any project.

## Core rule index (eager imports)

@.claude/rules/claude-rules-source.md
@.claude/rules/claude-meta-rule.md
@.claude/rules/token-economy.md
@.claude/rules/communication-language.md
@.claude/rules/file-format-preservation.md
@.claude/rules/documentation-style.md
@.claude/rules/git-conventions.md
@.claude/rules/git-identity.md
@.claude/rules/git-line-endings.md
@.claude/rules/deployment-path.md
@.claude/rules/session-naming.md
@.claude/rules/shell-path-conversion.md
@.claude/rules/lessons-learned.md

## What each core rule covers

| File | Covers |
|------|--------|
| `claude-rules-source.md` | Mandatory first-action read + reply marker line. **Always applies.** |
| `claude-meta-rule.md` | How Claude must edit `*.md` rule files in this repo. |
| `token-economy.md` | **Critical:** minimize token consumption; trade speed (not quality) for fewer tokens; **fan-out / multiple parallel agents need explicit permission (even under ultracode), one `+1` parallel agent is allowed sparingly to save time.** |
| `communication-language.md` | Reply in Hungarian by default (incl. visible reasoning/process text); mirror the user's language; keep technical terms untranslated. What goes into the repository is English, see `documentation-style.md`. |
| `file-format-preservation.md` | Preserve file encoding, line endings, indentation during edits. |
| `documentation-style.md` | **Code comments and in-code documentation are English**, whatever language the chat runs in. **No em dash and no semicolon in prose**, both read as AI-written. In code the `;` is syntax and stays, never bulk-replace it. XML doc / inline comment / Terraform comment limits, terse, "why not what". |
| `git-conventions.md` | Jira `[NX-32472]` commit prefix, `feature/NX-32472_purpose` branch naming, commit message format, no AI-tool markers, push only with permission, small commits, PR description format (English, Why/What/Notes, the merge commit carries it). |
| `git-identity.md` | **This repo is personal, commit and push with the `nyiriattila88` GitHub account, not the work one.** Repo-local `user.email` overrides the global on purpose; a push 403 means the wrong `gh` account is active (`gh auth switch`), not a missing scope. |
| `git-line-endings.md` | `.gitattributes` policy and CRLF/LF normalization. |
| `deployment-path.md` | **On any deployment request, check for a real CI/CD path first** (GitHub Actions workflow / Azure DevOps pipeline) and use it; local `terraform`/`terragrunt`/`tofu apply` is the fallback only when no pipeline exists. A missing credential is not a reason to fall back. Triggering the pipeline needs permission. |
| `session-naming.md` | Start each session title with the repo/folder name so sessions stay scannable across projects. |
| `shell-path-conversion.md` | **Git Bash on Windows rewrites `/`-leading CLI arguments into Windows paths, usually silently, returning an empty result set.** Set `MSYS_NO_PATHCONV=1` (or use PowerShell); an unexpectedly empty CLI result is this rule's suspect first, never proof that the resource is gone. |
| `lessons-learned.md` | How cross-session lessons are collected: `general.md` (eager) vs. `workspaces/<COMPUTERNAME>.md` (read once per session), what belongs in each store vs. session memory vs. a rule, entry format, and promotion into a rule. |

## Cross-session lessons (`.claude/lessons/`)

Because this repo is wired into every local session, it is where a lesson learned once can improve later sessions. The general collection is **eagerly imported**; the machine-specific one is loaded by the `SessionStart` hook in `.claude/hooks/` (or read manually after looking up `$env:COMPUTERNAME`, on a machine where the hooks are not wired). A `Stop` hook asks for a sweep once per session, so recording a lesson does not depend on remembering to. Mechanics, entry format, and the promotion path into a rule: [`lessons-learned.md`](.claude/rules/lessons-learned.md).

@.claude/lessons/general.md

| Path | Scope | Loading |
|------|-------|---------|
| `.claude/lessons/general.md` | project- and machine-independent working-method lessons | eager (imported above) |
| `.claude/lessons/workspaces/<COMPUTERNAME>.md` | one physical machine: paths, installed CLIs, accounts, proxy/VPN, junctions | on demand, `$env:COMPUTERNAME`, then read the file if it exists |

## Skills (on-demand, `.claude/skills/`)

Each skill is a thin `SKILL.md` (trigger + index) over the detailed rule files in its `references/`. Claude reads only the reference files a given task needs.

| Skill | Triggers on | References |
|------|-------------|-----------|
| `dotnet` | C#/.NET code, `.csproj`/`.sln`/`Directory.*.props`, NuGet, xUnit, MSBuild, ASP.NET | 14 files: C# style, API, testing, repo structure, solution, dependencies, build system, locked restore, project file format, tools (consuming/publishing), NuGet (publishing/signing), benchmarking |
| `typescript` | TS/JS source on Node, `package.json`/`tsconfig.json`/`eslint.config.*`/`vitest.config.*`, npm/pnpm, TS API (Fastify, Hono, Nest), Zod, vitest, Node Dockerfile | 10 files: repo structure (component-first, three layers), tsconfig (`strict`, `noUncheckedIndexedAccess`, `erasableSyntaxOnly`), language style (`unknown` over `any`), local development (the `launchSettings` equivalent: npm scripts + `--env-file` + `tsx --watch`), config layering (Zod, fail fast at startup), testing (vitest, component tests first), dependencies (pnpm, `--frozen-lockfile`, downgrade needs `node_modules` gone too), error handling (operational vs. programmer error, SIGTERM), API (validate at the boundary, 202 for async, charset), Docker (multi-stage, `node` not `npm start`, no Alpine for native modules) |
| `terraform` | `.tf`/`.hcl`, `infra/`, Terragrunt/OpenTofu, `plan`/`apply`; `apply` needs permission | Terraform/Terragrunt layout, root/account/env, modules, resource dependencies (module outputs → inputs over `data` re-lookups; implicit refs vs. `depends_on`) |
| `aws` | any AWS work: services, API/SDK (boto3, SDK for .NET), `aws` CLI, IAM policy/action, service quota, endpoint, CloudFormation, Well-Architected; **plus orphan/unused-resource audits and cost cleanups** | Agent Toolkit for AWS (`aws-core` plugin: `aws-mcp` MCP server + 15 curated skills) as primary; official AWS docs over public URLs via `WebFetch` as fallback; docs-over-memory; knowledge not action (mutating ops stay permission-gated); traffic generation kept low by default (dashboard ~10–20 calls, endpoint 1–2). Orphan audit: diff live inventory against **all** terraform states, verify every hit with a second signal, and know the untracked-but-live false positives (blue/green target groups, `run-task` taskdef families, bootstrap, active CUR exports) |
| `jira` | Jira issue létrehozás/szerkesztés, EPIC + taskok, Acceptance Criteria, mezőkitöltés, watcher, JQL, Atlassian MCP | NX konvenciók: az **AC dedikált mező** (`customfield_10124`, ADF bullet-lista), nem a leírásba írt „Definition of Done"; `Account` sima szám, `Team` UUID; a **watcher-endpoint nincs kitéve** az MCP-ben (a `watches` read-only), mondd ki, ne pótold @mentionnel; a konvenciókat friss ticketből olvasd ki; EPIC + témánként csoportosított taskok bizonyítékkal és „ne töröld" szakasszal |
| `azure-devops` | bármely Azure DevOps munka: `az devops`/`repos`/`pipelines`/`boards`, PR, pipeline run, build timeline, work item, scheduled (cron) trigger, PAT/setup, „nem érem el az ADO-t" | Azure DevOps CLI: **elérés, explicit `--org` + `--detect false`** (a „you need to run the login command" hiba az org-detect, nem a PAT; a beállított default nem védi meg), PAT-alapú auth (nem `az login`), telepítés-ellenőrzés telepítés előtt, PowerShell/`az.cmd` csapdák (`--query` zárójel, markdown `\|` és backtick, `ConvertFrom-Json` tömb), read-only vs. engedélyköteles mutáló parancsok, `az devops invoke` REST fallback, token-takarékos lekérdezés, koncepció-validálás temporary change-dzsel (jelöl → validál → kötelező revert), trigger-szabályok (cron az adott ág YAML-jéből, pipeline-completion a pipeline default branchéből), félrevezető futás-metaadata (`reason`, indexelési késés), pipeline resource artifact-választás |
| `local-code-review` | explicit "sima / kiegyensúlyozott / enyhe / light review" kérés (nem a default) | Balanced, non-adversarial local review in Hungarian; shared mechanics source for `devils-advocate-review`; never commit/push/publish |
| `devils-advocate-review` | **default review technika**, "review-eld", "/review", "nézd át a változásokat", + "devil's advocate", "ördög ügyvédje", "nézd át kritikusan", "stress-test-eld" | Adversarial default review on `local-code-review`'s mechanics; structured 8-section verdict; local-only, never commit/push/publish |
