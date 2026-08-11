# Deployment path — CI/CD first, IaC CLI only as fallback

When the user asks for a **deployment** ("telepítsd ki", "deployold", "rakd ki DEV-re", "deploy this to QA"), the first thing to establish is **which mechanism actually deploys this repository**. There are two possibilities, and they are not equal:

1. **A real CI/CD pipeline** — a GitHub Actions workflow or an Azure DevOps pipeline that owns the deployment. **This is the deployment path.**
2. **No pipeline exists** — only then does running `terraform` / `terragrunt` / `tofu apply` (or any other CLI-driven apply) from the workstation become the deployment path.

**Never start reasoning about a local `apply` before you have checked for a pipeline.** Reaching for the IaC CLI while a deployment pipeline exists bypasses the auditable path the team actually uses.

## Step 1 — look for the pipeline before anything else

Check, in this order, and state what you found:

- **Azure DevOps:** `.azure-pipelines/`, `azure-pipelines.yml`, or any `*deploy*.yml`. Look for the stage/job that performs the apply, and how it selects the environment (parameters, variables, branch→env mapping). See [[azure-devops-cli]].
- **GitHub Actions:** `.github/workflows/`, especially workflows with `workflow_dispatch`, `environment:`, or a deploy job.
- **Anything else the repo documents:** a `README`/`CONTRIBUTING` deployment section, a `Makefile` target, a release runbook.

If a pipeline exists, the remaining questions are all about **running it correctly**, not about replacing it: which pipeline, which parameter selects the environment, does the deploy consume an artifact from an upstream build (so that build has to run first), and is there an environment gate/approval.

## Step 2 — running the pipeline is a permission-gated action

Triggering a deployment pipeline is state-changing and outward-facing, exactly like `git push` and `apply`: **ask first**, unless the user authorized it in the current prompt. See [[git-conventions]] (push policy) and [[terraform-terragrunt]] (apply policy).

## A missing credential is not a reason to fall back to local apply

If the pipeline exists but you cannot trigger it — no PAT for `az devops`, no `gh auth`, no permission — the correct move is to **say so and ask for the credential**. Switching to a local `apply` "because the CLI is not authenticated" silently downgrades the deployment to an unaudited path the team did not choose. The fallback in point 2 is for repositories that have **no pipeline at all**, not for pipelines you happen to be locked out of.

## Why the pipeline wins

- **Toolchain parity.** The pipeline pins its IaC versions; a workstation rarely matches them. An `apply` (even a `plan`) from an older binary against a state written by a newer one fails outright, and a *newer* local binary silently upgrades the state so later CI runs break.
- **Gates and review.** Approvals, branch controls, and plan review live on the pipeline. A local apply skips all of them.
- **Identity.** The pipeline assumes a dedicated deployment role (e.g. an OIDC service connection); a workstation applies as a human's own credentials, so the audit trail and the effective permissions both differ.
- **Artifact provenance.** A pipeline deploy usually ships a specific built artifact. A local apply deploys whatever happens to be in the working tree.

## ✅ DO

```text
Kitelepítés kérés → először megnézem a .azure-pipelines/-t: van deploy_pipeline.yml,
env-választás a deploy_dev/deploy_qa paraméterrel. Ez a deployment útvonal;
megkérdezem, elindíthatom-e.
```

```text
A pipeline megvan, de nincs beállítva PAT, így nem tudom elindítani.
Jelzem, és kérem a PAT-ot — nem váltok lokális terragrunt apply-ra.
```

```text
Nincs sem workflow, sem pipeline a repóban → ilyenkor jön szóba a lokális
terragrunt apply, és külön engedélyt kérek rá.
```

## ❌ DON'T

```text
(Egyenesen a terragrunt apply-t tervezem, mert az infra Terraformban van —
meg sem néztem, hogy van-e deploy pipeline.)
```

```text
(A pipeline létezik, de az `az devops` 401-et ad, ezért "megoldásként"
lokálisan applyolok. Ez kihagyja az approvalt, a plan review-t és a
deployment role-t.)
```

```text
(Lokálisan applyolok egy újabb tofu/terraform binárissal, mint amit a CI pinnel —
a state felfrissül, és a következő CI-futás elhasal rajta.)
```
