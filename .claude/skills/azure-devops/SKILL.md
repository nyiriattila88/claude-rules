---
name: azure-devops
description: >
  Azure DevOps CLI használati szabályok (Nyiri Attila szabálykészlete): `az devops`, `az repos`,
  `az pipelines`, `az boards`, `az artifacts`, illetve a `az devops invoke` REST fallback. Használd
  MINDIG, amikor Azure DevOps-szal dolgozol: repo/PR lekérdezés vagy létrehozás, pipeline és build
  definition listázás, pipeline-futások (runs) és eredményük vizsgálata, build log / timeline
  elemzés, work item (boards) kezelés, service endpoint, wiki, artifact feed, scheduled (cron)
  trigger vizsgálata, vagy az Azure DevOps CLI telepítése/authentikációja (PAT). KRITIKUS és gyakran
  elrontott: az `az devops` **PAT**-tal authentikál, nem `az login`-nal — a 401 szinte mindig lejárt
  PAT, nem hiányzó telepítés; a `--query` JMESPath PowerShell alól elhasal az `az.cmd` wrapperen; a
  mutáló parancsok (pipeline indítás, PR create/complete, work item write) engedélykötelesek. Lassú
  feedback loopú koncepció (pl. cron trigger) validálásához szabad temporary change — jelöl →
  validál → **kötelező revert**. Trigger kulcsszavak: Azure DevOps, AzDO, ADO, dev.azure.com,
  visualstudio.com, az devops, az repos, az pipelines, az boards, PAT, pull request, pipeline run,
  build definition, work item, WIQL, scheduled trigger, cron, TFS, VSTS.
---

# Azure DevOps CLI

A részletes szabály a `references/azure-devops-cli.md`-ben van. **Olvasd be a `Read` tool-lal**, mielőtt Azure DevOps CLI parancsot futtatsz vagy a setupot diagnosztizálod.

## Az öt legfontosabb dolog (mielőtt bármit teszel)

- **Auth = PAT, nem `az login`.** Az `az devops` extension a Credential Managerben tárolt **Personal Access Token**-nel dolgozik (`azdevops-cli:<org>` target), nem az `az login` ARM-tokenjével. Ezért egy `401`/`TF400813` szinte mindig **lejárt PAT**, nem hiányzó telepítés — ne telepíts újra és ne javasolj `az login`-t. Diagnózis- és javítás-sorrend a reference fájlban.
- **Ne telepíts vaktában.** A "nincs Azure DevOps client" gyakori téves diagnózis: az `az` CLI + `azure-devops` extension gyakran már fent van, defaultokkal együtt. Előbb **ellenőrizz** (`az devops configure --list`, majd egy read-only smoke test), csak utána telepíts.
- **PowerShell quoting trap.** Windowson az `az` egy `az.cmd` batch wrapper: a `--query` JMESPath zárójelei elhasalnak rajta (`-o was unexpected at this time`). Kerüld meg `-o json | ConvertFrom-Json`-nal és client-side szűréssel — ez token-takarékosabb is.
- **Read szabad, write engedélyköteles.** A `list`/`show`/`query` biztonságos. A mutáló parancs — `az pipelines run` / `build queue` (valódi deployt indíthat!), `az repos pr create/update/set-vote`, `az boards work-item create/update/delete`, repo vagy service endpoint létrehozás/törlés — **csak explicit engedéllyel**, ugyanaz a modell, mint a [[git-conventions]] push-policy és a [[terraform-terragrunt]] `apply`.
- **Temporary change szabad a validációhoz, a revert kötelező.** Amit lokálisan nem lehet bizonyítani (elsül-e a cron trigger, fut-e a path-filter), ahhoz szabad ideiglenesen gyorsítani a feedback loopot — sűrűbb cron, eldobható probe pipeline. Feltétel: **jelölöd** (`temp_…`, `# TEMP:`), **listát vezetsz** róla, és a validáció után — eredménytől függetlenül — **visszaállítod**. Prod-ot érintő pipeline-on nem. Részletek a reference `Koncepció-validálás temporary change-dzsel` szekciójában.

## Mikor melyik szekciót olvasd

| Feladat | Szekció a `references/azure-devops-cli.md`-ben |
|---|---|
| "Van telepítve?" / setup / 401 | Előfeltétel-ellenőrzés, Authentikáció |
| Parancs elhasal PowerShellben | PowerShell quoting trap |
| Mit futtathatok kérdés nélkül | Engedélymodell |
| Repo / PR / pipeline / run lekérdezés | Read-only receptek |
| Cron/trigger koncepció kipróbálása, lassú feedback loop | Koncepció-validálás temporary change-dzsel |
| Build log, melyik stage bukott | REST fallback (`az devops invoke`) |
| Nagy lista, sok találat | Token economy |
| `git push` az ADO remote-ra nem megy | Git remote auth (külön credential) |
