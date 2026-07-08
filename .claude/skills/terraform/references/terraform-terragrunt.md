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
- **locals.tf:** Non-sensitive derived values (e.g. `service_name`, `ssm_prefix`) used in resources.
- **data.tf:** Data sources (e.g. `aws_caller_identity`, `aws_region`, VPC, subnets, security groups) used by the module.
- Resource files: group by concern (e.g. `ecs.tf`, `iam.tf`, `lb.tf`, `apigateway.tf`, `dynamodb.tf`).
- **outputs.tf:** Output only what other stacks or pipelines need; add descriptions.

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
