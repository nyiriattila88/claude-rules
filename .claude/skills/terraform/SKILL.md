---
name: terraform
description: >
  Terraform / Terragrunt / OpenTofu (tofu) infrastruktúra-szabályok (Nyiri Attila szabálykészlete).
  Használd, amikor IaC-vel dolgozol: `.tf`/`.hcl` fájlok írása vagy szerkesztése, `infra/` mappa,
  root/account/environment szerkezet, modulok, backend/state konfiguráció, vagy `terraform`/
  `terragrunt`/`tofu` parancsok (plan/apply/destroy) futtatása. KRITIKUS: az `apply`/`destroy`
  csak explicit engedéllyel futtatható; a `plan` biztonságos. Ha a CLI hiányzik, WSL-t is ellenőrizz.
  Trigger kulcsszavak: terraform, terragrunt, tofu, opentofu, hcl, infra, terragrunt.hcl, iac.
---

# Terraform / Terragrunt szabályok

A részletes szabály a `references/terraform-terragrunt.md`-ben van. **Olvasd be a `Read` tool-lal**, mielőtt IaC-fájlt szerkesztesz vagy Terraform/Terragrunt parancsot futtatsz.

## A két legfontosabb dolog (mielőtt bármit teszel)

- **`apply`/`destroy` = engedélyköteles.** Soha ne futtass `terraform/terragrunt/tofu apply`-t (vagy `destroy`-t, `run-all apply/destroy`-t) magadtól — előbb kérdezz. A `plan`/`validate`/`fmt`/`output` biztonságos, szabadon futtatható. (Lásd még a mag `git-conventions` push-engedély modelljét és a globális CLAUDE.md destruktív-művelet szabályát.)
- **Hiányzó CLI → WSL.** Ha `tofu`/`terragrunt`/`terraform` nincs a hoston, ne add fel: ellenőrizd WSL alatt (`wsl command -v tofu`), és WSL-en át `/mnt/c/...` utakkal futtasd.

A layout (root.hcl / account.hcl / terragrunt.hcl / modules), a backend/state és a parancs-részletek a reference fájlban.
