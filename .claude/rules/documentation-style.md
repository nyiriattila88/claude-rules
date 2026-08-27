---
description: Documentation style, terse summaries, "why not what", no comment essays.
globs: "**/*"
alwaysApply: false
---

# Documentation Style

Documentation explains the **why**, not the **what**. The "what" comes from well-named types, methods, fields, attributes, and resource names. Comments are allowed, but keep them **terse**: aim for one line, three lines maximum. If a comment merely restates the identifier or the next line of code, drop it.

Keep summary **content** terse, **a single sentence by default**. The XML doc **block** is always written **multi-line**: opening `<summary>` tag on its own line, content on its own line, closing `</summary>` tag on its own line. The same rule applies to `<remarks>`. This is the physical layout; the brevity limits (one sentence by default) still hold for the content. `<remarks>` are reserved for **non-obvious** information: an invariant, a gotcha, a wire-format decision, a workaround for a specific bug, behavior that would surprise a reader.

Documentation is not a place to record history (migrations, decisions considered, alternatives rejected). That belongs in commit messages, PRs, ADRs, or runbooks.

## Language: what goes into a repository is English

**Every comment and in-code documentation is written in English**, whatever language the conversation
about the work runs in: `//` and `#` comments, C# XML docs, HCL `description` attributes,
`[SuppressMessage]` justifications, and the doc comments of any other language.

This does not contradict [[communication-language]]. That rule governs what the **user** reads: the
chat, the reasoning, the plans, the summaries. This one governs what the **repository** carries. The
two audiences are different: a repository is read by people who never saw the conversation, by tooling,
and by whoever opens the file in two years.

Markdown documents in the repository (`README.md`, ADRs, runbooks) follow the repository's own
established practice, they are not covered by this rule. Commit messages and PR descriptions are
English, see [[git-conventions]].

### The failure mode: a Hungarian chat pulls the comments with it

This rule is easy to state and easy to break, because the pull comes from the conversation. While
reasoning in Hungarian about a Terraform module, the comment that explains a threshold gets written in
Hungarian too, and it reads perfectly natural in the moment. It is still wrong: the file goes to people
who never saw the conversation.

**The trigger is not the file type, it is the moment.** Every time you write a comment during a
Hungarian-language session, that is the moment to switch languages. Applies to `.tf`, `.hcl`, `.yml`
pipeline files, `.conf`, `.cs`, and anything else the repository carries.

**Check before committing, not after.** A comment written in Hungarian survives review easily, because
the reviewer also speaks Hungarian. Grep your own diff:

```bash
git diff | grep -E '^\+\s*(#|//)' | grep -iE 'tehat|ezert|nincs|mert|kell|hogy|ami|csak'
```

Accent-free Hungarian (`tehat`, `ezert`, `keres`) does not make it English, and it is harder to spot than
accented text. Write proper English instead of accent-free Hungarian.

### ✅ DO

```csharp
// The CDN forwards the Range header in both directions, so the player can seek.
```

```hcl
# KMS decrypt for SecureString SSM parameters, scoped via kms:ViaService to the SSM service.
```

### ❌ DON'T

```csharp
// A CDN a Range fejlécet mindkét irányba továbbadja, így a lejátszóban lehet tekerni.
```

```hcl
# Ez az egyetlen jel, ami a mert terhelesi profilnal mukodik, mert a kerescount nem higul.
# (Accent-free Hungarian is still Hungarian. This one shipped in a Terraform module.)
```

```hcl
# A ssm_prefix-ből épül a paraméter elérési útja.
```

## Two characters that read as AI-written: `—` and `;`

**Never use an em dash (`—`) in prose, and avoid the semicolon (`;`) in prose.** These two are the
clearest giveaways that a text was generated rather than written, and a document carrying them is read
differently by the people who receive it, regardless of how good its content is.

This applies to **everything a human reads**: chat replies, documentation, README files, code comments,
XML docs, HCL `description` attributes, commit messages, PR descriptions, and review comments alike.

### What to write instead

| Instead of | Write |
|---|---|
| `A megoldás — bár működik — lassú.` | `A megoldás, bár működik, lassú.` |
| `Két lehetőség van — az egyik olcsóbb.` | `Két lehetőség van: az egyik olcsóbb.` |
| `A render lefut; a videó S3-ba kerül.` | `A render lefut, a videó S3-ba kerül.` |
| `Nem a méret számít; a tartalom.` | `Nem a méret számít. A tartalom.` |

A comma, a colon, a pair of brackets, or simply two sentences: one of these always fits. If none of them
does, the sentence is trying to carry two thoughts at once, and splitting it is the real fix.

### Code is exempt, and this matters

The semicolon is **syntax** in C#, TypeScript, JavaScript, Java, and their relatives. Removing it breaks
the build.

**Never run a bulk replacement of `;` over source files.** The rule is about prose, which inside a code
file means comments, XML docs, and string literals that a human will read. Statement terminators,
`for (int i = 0; i < n; i++)`, and CSS declarations stay exactly as they are.

The em dash has no such exemption: it is never syntax, so it can be replaced anywhere it appears.

### ✅ DO

```csharp
/// <summary>
/// Serves rendered output through this API instead of redirecting to the CDN.
/// </summary>
public sealed class RenderContentProxy(IHttpClientFactory httpClientFactory)
{
    public void Copy(int count)
    {
        for (int index = 0; index < count; index++)   // syntax, leave it alone
        {
            // The CDN forwards the Range header in both directions, so the player can seek.
        }
    }
}
```

### ❌ DON'T

```csharp
/// <summary>
/// Serves rendered output through this API — instead of redirecting to the CDN.
/// </summary>
// The CDN forwards the Range header; so the player can seek.
```

```text
(Tömeges csere a forráson, ami a statement-lezáró pontosvesszőket is elviszi: a build elhasal.)
sed -i 's/;//g' src/**/*.cs
```

### Verifying it

An em dash is invisible in a diff and easy to miss by eye, so check it with a tool, and know that some
shells lie about it: in Git Bash `grep $','` silently expands to nothing and reports a clean file.
Use ripgrep with the literal character, or match the UTF-8 bytes:

```bash
rg -l '—' docs/ src/
grep -rlP "\xe2\x80\x94" docs/ src/
```

## Technical terms: don't translate

Keep established technical/industry terms in their canonical form (usually English); **do not** translate them into the prose language. This applies everywhere you write, chat responses, inline comments, XML docs, and Terraform comments alike. A forced translation is harder to recognise, breaks searchability, and reads worse than the term everyone already uses.

### ✅ DO

```text
Az első hívásnál cold start lassítja a Lambdát; a provisioned concurrency ezt elkerüli.
```

### ❌ DON'T

```text
Az első hívásnál a hidegindítás lassítja a Lambdát; a kiépített konkurencia ezt elkerüli.
```

### Code identifiers and names: never translate

The same rule applies, even more strictly, to **code identifiers and names**: variable, field, property, parameter, method, type, `local`, Terraform `resource`/`variable`/`output`, attribute, SSM/parameter, and tag names. When you mention one in prose, a comment, an XML doc, or a `description`, **write it verbatim in its canonical (code) form**, do not Hungarianise it. A translated name no longer matches the code, breaks grep/search, and reads as noise. This includes "describing" a name in Hungarian: refer to `service_name`, not "Szolgáltatásnév".

#### ✅ DO

```csharp
// service_name drives the default_tags "component-name" tag.
```

```hcl
# The parameter path is built from ssm_prefix, see locals.tf.
resource "aws_ssm_parameter" "component_name" {
```

#### ❌ DON'T

```csharp
// The "Service name" drives the default_tags "component name" tag.
```

```hcl
# The path is built from the "SSM prefix" into the "parameter path".
resource "aws_ssm_parameter" "component_name" {
```

### Language constructs: name them as the code spells them

The rule reaches **language constructs** as well: `throw`, `catch`, `finally`, `await`, `using`, `yield`.
This case slips through more easily than a noun does, because the Hungarian noun built from it inflects
naturally and reads as plain prose rather than as a translated term.

Draw the line at the part of speech. The **verb** describing the behaviour may stay Hungarian where it is
the established phrasing, "a metódus kivételt dob" is how developers say it. The moment you refer to the
**construct itself**, write it as the code spells it, and never nominalise it into Hungarian: there is a
`throw` in that file, and a reader searching for it will not find "dobás".

#### ✅ DO

```text
A SubtitleKey mostantól SubtitleSourceRejectedException-t dob, de ez a `throw` nem szerepel
az interfész `<remarks>`-ében.
```

```text
A `catch` ág csak egy `throw`-t tartalmaz, tehát elhagyható.
```

#### ❌ DON'T

```text
A dobás nem része a contractnak.
```

```text
Az elkapó ág csak egy újradobást tartalmaz, tehát elhagyható.
```

## Targets

- C# XML doc on types, methods, properties, fields, parameters.
- Inline `//` comments in any language.
- HCL `#` comments in Terraform / Terragrunt.
- HCL `description = "..."` attributes on `variable`, `resource`, `output`, and `data` blocks.
- Justifications inside `[SuppressMessage]`, `[JustifyForReview]`, and similar attributes.

## Limits

| Surface | Default | Hard limit |
|---|---|---|
| `<summary>` on any member | 1 sentence (multi-line block: tags on own lines) | 3 sentences |
| `<remarks>` block | absent | only when flagging a non-obvious invariant / gotcha / wire-format decision; 2–4 sentences (multi-line block) |
| Inline `//` or `#` comment | 1 line | 3 lines |
| Terraform file-header comment | 1 line | 3 lines |
| HCL `description = "..."` attribute | 1 sentence | 1 sentence |
| `[SuppressMessage]` justification | 1 line | 1 line |
| Per-resource HCL comment | 1 line | 3 lines (only when non-obvious) |

If a block exceeds the hard limit, the content belongs in a commit message, a sibling ADR, or a runbook, not in the source file.

## Comments on `using` directives

**Do not write comments above `using` directives.** An aliased `using` (`using X = Some.Long.Namespace.X;`) is self-explanatory. If the reason for the alias is genuinely non-obvious, place a single-line comment at the **first call site**, not above the `using`.

### ✅ DO

```csharp
using AuthorizeAttribute = Microsoft.AspNetCore.Authorization.AuthorizeAttribute;
using DomainOrderDirection = Some.Namespace.Domain.OrderDirection;
```

### ❌ DON'T

```csharp
// The Refit global using imports Refit.AuthorizeAttribute too; alias the
// ASP.NET Core one so the [Authorize(Roles = ...)] syntax stays unambiguous
// on this controller.
using AuthorizeAttribute = Microsoft.AspNetCore.Authorization.AuthorizeAttribute;
```

## C# XML doc

### Block layout: opening and closing tags on their own lines

The XML doc **block** is always multi-line: `<summary>`, `<remarks>`, `<param>`, `<returns>` and friends each get their opening tag, content, and closing tag on separate `///` lines. This is purely about physical layout and is independent of how short the content is, even a one-word summary uses three `///` lines. Block elements never inline their content into the same line as the tags.

### ✅ DO

```csharp
/// <summary>
/// Source-media location filter; null means no filter.
/// </summary>
public AmazonS3Uri? SourceUrl { get; init; }

/// <summary>
/// Sort direction; defaults to descending (newest first).
/// </summary>
public OrderDirection OrderDirection { get; init; } = OrderDirection.Descending;
```

### ❌ DON'T

```csharp
// Tags and content collapsed onto one line, harder to scan, breaks the consistent block shape.
/// <summary>Source-media location filter; null means no filter.</summary>
public AmazonS3Uri? SourceUrl { get; init; }
```

### Property summaries: single sentence (in a multi-line block)

Brevity is about **content** (one sentence by default), not physical lines. Even with the multi-line block form, the summary text stays terse.

### ✅ DO

```csharp
/// <summary>
/// Source-media location filter; null means no filter.
/// </summary>
public AmazonS3Uri? SourceUrl { get; init; }
```

### ❌ DON'T

```csharp
/// <summary>
/// Source-media location filter; null means no filter, otherwise the job's
/// stored (Bucket, Key) pair must equal this one. The Api layer parses
/// both s3://… and presigned https://…amazonaws.com/… query-strings into
/// this typed shape.
/// </summary>
public AmazonS3Uri? SourceUrl { get; init; }
```

The implementation detail (the API layer's parsing) belongs in the parser's own doc or its tests, not on the filter property.

### `<remarks>`: only when warranted

### ✅ DO

```csharp
/// <summary>
/// Aggregate-status filter; empty means no filter.
/// </summary>
/// <remarks>
/// Computed on every read, the value is never persisted.
/// </remarks>
public IReadOnlyList<JobStatus> Statuses { get; init; } = [];
```

### ❌ DON'T

```csharp
/// <summary>
/// Aggregate-status filter; empty means no filter, otherwise...
/// </summary>
/// <remarks>
/// The full lifecycle pipeline is: pending → submitting → dubbing → dubbed.
/// Failed and skipped are terminal. The job is in `inProgress` while any
/// task is non-terminal; `completed` once every task reaches a terminal
/// non-failed state; `failed` if any task ended failed.
/// </remarks>
```

The pipeline description belongs in the type's own doc, not on every filter that touches it.

### `[SuppressMessage]` justifications: one line

### ✅ DO

```csharp
[SuppressMessage("Performance", "CA1848:Use the LoggerMessage delegates",
    Justification = "Low-rate controller logging; templates are sufficient.")]
```

### ❌ DON'T

```csharp
[SuppressMessage(
    "Performance",
    "CA1848:Use the LoggerMessage delegates",
    Justification = "This is an application-orchestration layer; one log line per API operation makes templated logging trivially cheap, and the alternative LoggerMessage source-generated delegates would force a large amount of boilerplate for very little win in a non-hot path.")]
```

## Terraform / Terragrunt

### File-header comments: at most 3 lines (1 line preferred)

The filename (`iam.tf`, `dynamodb.tf`) already says what the file is about. The header records the **one non-obvious thing** about the file, not its full design rationale.

### ✅ DO

```hcl
# DubbingJobs aggregate table. PITR + SSE-KMS in every env (recovery requirement).
# deletion_protection_enabled = true is the AWS-side guard; no lifecycle.prevent_destroy needed.

resource "aws_dynamodb_table" "dubbing_jobs" {
  # ...
}
```

### ❌ DON'T

```hcl
# Application-owned DynamoDB table that backs the managed dubbing flow.
# Each row is a full DubbingJob aggregate: the unified ConvertingTask map + a list of
# per-language DubbingTask maps. One POST creates exactly one row regardless of how many target
# languages were requested.
#
# - The partition key `JobId` is our own identifier (UUID v7 string, time-ordered)…
#   (… 25 more lines of architecture / migration / decision history …)
#
# Migration note: the prior schema stored one row per (source, target-language) pair with…
```

That history belongs in a commit message or a `docs/dubbing-jobs.md`, not at the top of `dynamodb.tf`.

### Banner dividers (`# ===============…`): avoid

Multi-line banner blocks tempt people to fill them with prose. Use a single short line.

### ✅ DO

```hcl
# Infrastructure alarms, ALB unhealthy-host (page), ECS memory + DynamoDB (diagnostic).
resource "aws_cloudwatch_metric_alarm" "alb" {
```

### ❌ DON'T

```hcl
# =============================================================================
# Infrastructure alarms
# ALB (unhealthy-host), ECS (memory, diagnostic), DynamoDB (system errors and
# throttling, diagnostic). Per Google SRE: page on symptoms, not causes.
# (… further multi-paragraph rationale …)
# =============================================================================
resource "aws_cloudwatch_metric_alarm" "alb" {
```

### Per-resource comments: only when the AWS / provider behaviour is non-obvious

### ✅ DO

```hcl
# KMS decrypt for SecureString SSM parameters, scoped via kms:ViaService to the SSM service.
statement {
  sid       = "KmsDecryptForSsmSecrets"
  effect    = "Allow"
  # ...
}
```

### ❌ DON'T

```hcl
# This statement allows the role to decrypt SecureString SSM parameters
# referenced as task-def `secrets` (resolved by the execution role BEFORE
# the container starts). Scoped to KMS calls that go via the SSM service
# so the role cannot use this to decrypt arbitrary ciphertexts. Works for
# both the AWS-managed `alias/aws/ssm` key and any customer-managed KMS
# key the environment may use for its SSM parameters.
statement {
  sid       = "KmsDecryptForSsmSecrets"
  # ...
}
```

The `sid` already names it; the inline comment keeps only the non-obvious **why**: the `kms:ViaService` scope.

### Don't repeat attribute names

### ❌ DON'T

```hcl
resource "aws_dynamodb_table" "dubbing_jobs" {
  # Table name.
  name         = "DubbingJobs"
  # Billing mode is pay-per-request.
  billing_mode = "PAY_PER_REQUEST"
  # Hash key for the partition.
  hash_key     = "JobId"
}
```

The attribute names already say all of that.

### `description = "..."` attributes: one sentence, no architecture flow

The `description` field on `variable`, `resource`, `output`, and `data` blocks is **not** a comment, it renders in `terraform-docs`, IDE tooltips, and exported AWS resource descriptions (e.g. an `aws_ssm_parameter` description shows up in the SSM console). Multi-sentence, prose-heavy descriptions look out of place there. Default: **one short sentence**.

### ✅ DO

```hcl
variable "environment" {
  description = "Environment (dev, qa, stg, prod). Set per stack from account.hcl."
  type        = string
}

resource "aws_ssm_parameter" "mediaconvert_job_tag_component_name" {
  name        = "${local.ssm_prefix}/MediaConvert/Tags/component-name"
  description = "Cost-allocation 'component-name' tag for SDK-created MediaConvert jobs (matches default_tags)."
  type        = "String"
  value       = local.component_name
}
```

### ❌ DON'T

```hcl
variable "component_name" {
  description = "Component identifier (e.g. \"mediaforge\"). Single source of truth is local.component_name in root.hcl, propagated here via the root inputs block. Drives the AWS provider default_tags 'component-name' tag, the MediaConvert job-template prefix, and any other component-level identifiers."
  type        = string
}
```

The architecture flow (root → inputs → variable) belongs in the file-header comment or repo docs, not in every consumer's `description`.

## What NOT to write in source-level docs

- **What a method does, when its name already says it.** A `<summary>` block whose content is just `Returns the user.` on a `Task<User> GetUserAsync()` adds nothing the signature did not already say.
- **References to current callers** ("used by X", "called from Y"). Callers move; the comment goes stale silently.
- **Migration / refactor history.** "We used to do X but now we do Y because…", that's a commit message.
- **Alternatives considered.** "We could have used Kafka here but…", that's an ADR.
- **TODOs without an owner or ticket.** A bare `// TODO: clean this up` rots forever. Either fix it now, or open a ticket and reference it.
- **JSON property order / wire shape recitals** when the `[JsonPropertyOrder]` attributes already encode them.
- **Decoration banner blocks** with multi-paragraph descriptions inside.

## When in doubt: pull, don't add

When a comment block grows past the hard limit, the right move is to **delete** it, not to find a clever way to keep it. If the lost information matters, it goes into:

- a **commit message** (for the change that introduced the situation),
- an **ADR** (for cross-cutting architectural decisions),
- a **runbook** (for operational behavior),
- a **docs/** page (for cross-file flows),

never back into the source file as another comment block.
