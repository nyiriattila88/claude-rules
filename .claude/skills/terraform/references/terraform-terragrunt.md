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
