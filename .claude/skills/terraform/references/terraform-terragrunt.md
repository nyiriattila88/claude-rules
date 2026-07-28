---
description: Terraform and Terragrunt methodology – layout, root/account/env, modules, state, no hardcoded account/region.
globs: "**/*.tf,**/*.tf.json,**/terragrunt.hcl,**/root.hcl,**/account.hcl,**/*.hcl"
alwaysApply: false
---

# Terraform and Terragrunt conventions

Use Terraform for infrastructure as code; use Terragrunt to keep backend config, provider config, and per-environment values DRY and consistent.

## Layout

- **infra/** – all Terraform/Terragrunt under one folder.
  - **infra/root.hcl** – shared root config: `remote_state` (S3 backend, DynamoDB lock), `generate "providers"`, and common `inputs` (e.g. `component_name`, `repository`). Use `path_relative_to_include()` in state key so each env/stack has its own state path.
  - **infra/environments/{dev,qa,stg,prod}/** – one folder per environment.
    - **account.hcl** – account/region/environment: `locals { aws_region, aws_account_id, environment }` and `inputs` passing those into the module. No secrets; only identifiers.
    - **terragrunt.hcl** – `include "root"` (via `find_in_parent_folders("root.hcl")`), `include "account"` (path to same folder’s `account.hcl`), and `terraform { source = "<path to module>" }` pointing at the shared module.
  - **infra/modules/<component>/** – the actual Terraform module: `*.tf` (e.g. `versions.tf`, `variables.tf`, `locals.tf`, `data.tf`, resource files, `outputs.tf`). One module per component (e.g. `my-service`).

Other layouts (e.g. multiple stacks per env like `environments/dev/common`, `environments/dev/ecs`) follow the same idea: one `terragrunt.hcl` per stack, each including root and an account/env config, and each using a module under `infra/modules/`.

## Root and backend

- **root.hcl:** Define `remote_state` with backend `"s3"`: bucket name from account (e.g. `ent-tf-${aws_account_id}-${aws_region}`), key including component and relative path (e.g. `${component_name}/${path_relative_to_include()}/tofu.tfstate`), DynamoDB table for locks. Use `generate { path = "backend.tf", if_exists = "overwrite_terragrunt" }` so Terragrunt writes backend config.
- **Provider:** Generate provider config in root (e.g. `generate "providers"` or `generate "provider"`) with region from account and `default_tags` (e.g. `component-name`, `terraform_managed`, `source`). Use `if_exists = "overwrite_terragrunt"` so it stays in sync.

## Account and environment

- **account.hcl** (or equivalent) per environment: only `locals` and `inputs` for `aws_region`, `aws_account_id`, `environment`. No secrets; reference these in root for bucket name and provider region.
- **Modules must not hardcode** account id, region, or environment. Receive them via `variable` and pass from Terragrunt `inputs` (and from account.hcl). Root can merge `inputs` from account with component-level inputs.

## Modules

- **versions.tf:** Pin `required_providers` (e.g. `hashicorp/aws` with version).
- **variables.tf:** Declare all inputs (e.g. `environment`, `aws_region`); add descriptions and types.
- **locals.tf:** Non-sensitive derived values (e.g. `service_name`, `ssm_prefix`) shared across more than one file (see File organization below).
- **data.tf:** Data sources (e.g. `aws_caller_identity`, `aws_region`, VPC, subnets, security groups) used by the module.
- Resource files: group by concern (e.g. `ecs.tf`, `iam.tf`, `lb.tf`, `apigateway.tf`, `dynamodb.tf`).
- **outputs.tf:** Output only what other stacks or pipelines need; add descriptions.

## Resource dependencies — make ordering explicit

Terraform builds its apply order from **references** between blocks: reading `aws_x.foo.arn` from another resource creates an implicit dependency edge, so `foo` is created first. A value nobody references is *not* ordered relative to anything — Terraform is free to read or create it at any point, including too early. Wiring dependencies correctly is therefore not optional polish; it is what keeps a first `apply` from failing.

### Never `data`-source a resource you create in the same run (the classic trap)

A `data` source is read during **refresh/plan**, before most resources are created, and it has **no dependency** on whatever resource would create the thing it looks up. So if a `data` block resolves an object that another part of the same configuration is *also creating*, the read runs before that object exists and the plan dies with:

```text
Error: reading Lambda Function (playback-states-read-event-handler): couldn't find resource
  with data.aws_lambda_function.read_handler,
  on data.tf line 11, in data "aws_lambda_function" "read_handler":
Error: reading SQS Queue (playback-state-writes.fifo) URL: couldn't find resource
  with module.write_event_handler.data.aws_sqs_queue.writes,
```

The fix is almost never `depends_on` on the data source — it is to **stop looking the thing up and reference it directly** instead: the managed resource's own attribute, or the creating module's `output`, or a value passed in from the module that owns the resource. That reference is what gives Terraform the ordering edge (and it also avoids a needless extra API read).

#### ✅ DO

```hcl
# The lambda module creates the function and exports its alias; consumers read the
# OUTPUT, so Terraform orders the function first. No data lookup, no ordering gap.
resource "aws_apigatewayv2_integration" "read" {
  integration_uri = module.read_event_handler.live_alias_invoke_arn
}
```

```hcl
# The root owns (creates) the queue and passes its ARN down; the write handler
# consumes var.write_queue_arn instead of re-reading the queue it doesn't own.
module "write_event_handler" {
  source          = "../playback-states-write-event-handler"
  write_queue_arn = aws_sqs_queue.writes.arn
}
```

#### ❌ DON'T

```hcl
# data.tf — looks up a Lambda / SQS queue that THIS same run creates. On a first
# apply (or any run where it doesn't exist yet) the refresh read fails with
# "couldn't find resource": no dependency ties the read to the create.
data "aws_lambda_function" "read_handler" {
  function_name = "playback-states-read-event-handler"
}

data "aws_sqs_queue" "writes" {
  name = "playback-state-writes.fifo"
}
```

### `depends_on` — only for real ordering with no data flow

Use explicit `depends_on` when a genuine ordering requirement exists but **no value flows** between the blocks to express it (e.g. an IAM role policy must exist before the principal uses the role at runtime, or a resource relies on an API the module can't reference). Keep it minimal — every `depends_on` you can replace with a direct reference, you should, because references are self-documenting and survive refactors.

#### ✅ DO

```hcl
# No attribute of the policy is referenced, but the Lambda must not be invoked
# before its execution-role policy is attached — express that ordering explicitly.
resource "aws_lambda_function" "handler" {
  depends_on = [aws_iam_role_policy.handler]
  # ...
}
```

#### ❌ DON'T

```hcl
# depends_on used where a plain reference already implies the order — noise that
# can even mask the fact that the real dependency is the referenced attribute.
resource "aws_lambda_function" "handler" {
  role       = aws_iam_role.handler.arn   # already orders the role first
  depends_on = [aws_iam_role.handler]     # redundant
}
```

> Source: HashiCorp Terraform docs — *Resource dependencies* (implicit references vs. `depends_on`) and *Data sources* (read timing during plan/refresh).

## File organization

Two independent rules keep a module navigable: **where a `local` is declared**, and **when a file is split**.

### Locals: shared in `locals.tf`, single-use may stay in place

- **Shared locals go in `locals.tf`.** Any `local` referenced from more than one file belongs in the module's central `locals.tf`, so there is one source of truth and no guessing which file owns the value.
- **Single-use locals may stay in their file.** A `local` used by only one file may be declared in that file (in its own `locals { }` block), keeping the value next to the resources that use it. Promote it to `locals.tf` the moment a second file needs it.

#### ✅ DO

```hcl
# locals.tf — service_name is used by ecs.tf AND iam.tf, so it lives centrally.
locals {
  service_name = "${var.component_name}-${var.environment}"
}
```

```hcl
# cloudwatch_alarms.tf — this threshold is used only here, so keeping it in-file is fine.
locals {
  cpu_alarm_threshold = 80
}
```

#### ❌ DON'T

```hcl
# ecs.tf — service_name is also referenced from iam.tf, so it must not be
# buried in one resource file; move it to locals.tf.
locals {
  service_name = "${var.component_name}-${var.environment}"
}
```

### Split long files by concern

When a single resource file grows large — typically `apigateway.tf` with many routes/integrations, or a CloudWatch file holding both dashboards and alarms — split it into concern-named files instead of letting one file own everything. Keep the names descriptive and concern-based (`<concern>.tf`).

#### ✅ DO

```text
cloudwatch_dashboard.tf     # dashboard(s)
cloudwatch_alarms.tf        # metric alarms
apigateway_routes.tf        # routes + integrations
apigateway_authorizers.tf   # authorizers, when numerous
```

#### ❌ DON'T

```text
cloudwatch.tf   # 600 lines: dashboards, dozens of alarms, and SNS wiring in one file.
```

### When a single concern is still too large

Concern-based splitting is not enough when one concern is itself huge (an API Gateway with dozens of routes, a CloudWatch file with a big dashboard). Apply these in order — the goal stays the same: a maintainer can immediately tell where a given resource lives.

1. **Sub-divide by sub-concern.** Split `apigateway.tf` into `apigateway_routes.tf`, `apigateway_integrations.tf`, `apigateway_authorizers.tf`; split CloudWatch into `cloudwatch_dashboard.tf` and `cloudwatch_alarms.tf`.
2. **Collapse repetition with `for_each`/`count`.** Dozens of near-identical resources (alarms, dashboard widgets, routes) belong in one `for_each` block driven by a map/local, not N copy-pasted blocks. This shrinks a file far more than splitting it.
3. **Externalize large inline documents.** A CloudWatch dashboard body or a long policy JSON does not belong inline in HCL — move it to `templates/<name>.json.tftpl` and load it with `templatefile(...)`. This is usually what makes a dashboard file explode.
4. **Size cue: ~150 lines.** When one resource group passes roughly 150 lines, that is a good signal to give it its own file; below that, keep it with its concern.
5. **Last resort — a nested module.** If a component is genuinely complex, extract it to `infra/modules/<component>/`, but keep nesting flat (one or two levels) and never wrap a single resource in a module.

#### ✅ DO

```hcl
# cloudwatch_dashboard.tf — the large JSON lives in a template, not inline.
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = local.dashboard_name
  dashboard_body = templatefile("${path.module}/templates/dashboard.json.tftpl", {
    region = var.aws_region
  })
}
```

```hcl
# cloudwatch_alarms.tf — one for_each instead of dozens of near-identical blocks.
resource "aws_cloudwatch_metric_alarm" "this" {
  for_each = local.alarms

  alarm_name  = each.key
  metric_name = each.value.metric
  threshold   = each.value.threshold
  # ...
}
```

#### ❌ DON'T

```hcl
# cloudwatch.tf — a 2,000-line file: the full dashboard JSON inline plus 30
# copy-pasted alarm blocks that differ only in name and threshold.
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_body = <<EOF
  { ... hundreds of lines of JSON ... }
  EOF
}
```

> Sources: HashiCorp Terraform Style Guide (file names, local values) and AWS Prescriptive Guidance — *Best practices for code base structure* (service-named files, the ~150-line cue, externalizing lengthy documents).

## Missing CLI — check WSL before giving up

If `tofu` (OpenTofu) or `terragrunt` (or `terraform`) is **not installed** on the host, do not stop. On Windows the tool is often installed inside **WSL** instead.

1. **Detect the host tool first:** check with `command -v tofu` / `command -v terragrunt` (or `Get-Command` in PowerShell). If found, use it.
2. **If missing, check for WSL:** verify WSL exists (e.g. `wsl --status` or `wsl -l -q`). If there is no WSL, report that the tool is missing and stop.
3. **Check inside WSL:** run the lookup in the default distro, e.g. `wsl command -v tofu` / `wsl command -v terragrunt`. If found there, run the Terragrunt/Tofu commands through WSL (`wsl <command>`).
4. **Path translation:** when invoking via WSL, the working directory and any path arguments must be WSL paths (`/mnt/c/...`), not Windows paths. Run from the correct env/stack directory inside WSL.
5. **Permission model is unchanged:** running through WSL does **not** relax the `apply` rule below — `apply`/`destroy` via `wsl terragrunt apply` still requires explicit permission. `plan` stays safe.

### ✅ DO

```text
A host gépen nincs tofu. WSL telepítve van, és `wsl command -v tofu` megtalálta —
a plan-t `wsl`-en keresztül futtatom a /mnt/c/... úton lévő stack könyvtárból.
```

### ❌ DON'T

```text
(Rögtön azt jelented, hogy nincs telepítve tofu/terragrunt, anélkül hogy
megnéznéd, hátha WSL alatt elérhető.)
```

## Terragrunt commands

- Run from the **environment (or stack) directory** where the target `terragrunt.hcl` lives (e.g. `infra/environments/dev`). Use `terragrunt plan`, `terragrunt apply`, `terragrunt destroy` (or `terraform` equivalents via Terragrunt). Do not run from the module directory; Terragrunt must generate backend and provider and pass inputs.
- Use `terragrunt run-all` only when you intentionally want to run the same command across multiple included stacks (e.g. all stacks under an env).

## `apply` requires explicit permission (critical)

- **Never run `apply` on your own initiative.** Any state-changing command — `terraform apply`, `terragrunt apply`, `tofu apply` (and `destroy`, `run-all apply/destroy`) — may be executed **only** with the user's explicit permission.
- **Always ask first**, unless the user has authorized it in the current prompt — in that case you may run it.
- **`plan` is always safe.** Read-only commands (`plan`, `validate`, `fmt`, `output`, `state list`) need no permission; run them freely to show what an `apply` would change, then wait for approval.
- The same permission model applies to `git push` (see `git-conventions.md`).

### ✅ DO

```text
The plan adds 1 resource and changes 2. Should I run `terragrunt apply`?
```

### ❌ DON'T

```text
(Running `terragrunt apply` right after a plan without being asked or pre-authorized.)
```

## Summary

- **root.hcl** = backend + generated provider + shared inputs; **account.hcl** = per-env account/region/env; **terragrunt.hcl** = include root + account + `terraform.source` to module.
- **Modules** under `infra/modules/<component>/`; no hardcoded account/region; use variables and inputs.
- State in S3, lock in DynamoDB; state key includes component and path so each env/stack is isolated.
