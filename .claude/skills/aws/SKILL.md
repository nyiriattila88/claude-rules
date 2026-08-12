---
name: aws
description: >
  AWS-specifikus tudás-szabályok (Nyiri Attila szabálykészlete). Elsődleges eszköz a hivatalos Agent
  Toolkit for AWS (`aws-core` plugin: `aws-mcp` MCP server + curated skillek); kiegészítőként/fallbackként
  a hivatalos AWS dokumentáció elérése publikus URL-eken (WebFetch), hogy az agent ne memóriából
  találgasson, hanem a naprakész hivatalos forrásból dolgozzon. Használd MINDIG, amikor AWS-szel dolgozol:
  bármely AWS service (S3, DynamoDB, Lambda, EC2, ECS, SQS, SNS, CloudWatch, KMS, RDS, API Gateway,
  Step Functions, IAM, stb.),
  AWS API / SDK (boto3, AWS SDK for .NET/JS/Java/Go), AWS CLI (`aws ...`), IAM policy / action / condition
  key, service-limit / quota, endpoint, CloudFormation, vagy AWS best practice / Well-Architected kérdés.
  A skill lényege: mielőtt AWS API-t, IAM actiont, limitet, CLI flaget vagy SDK metódust állítasz vagy
  használsz, a hivatalos docs-ból ellenőrizd (publikus URL + WebFetch). Ez tudás, nem action — az AWS-en
  végrehajtott mutáló művelet (deploy, `apply`, mutáló CLI parancs) továbbra is engedélyköteles.
  Trigger kulcsszavak: AWS, Amazon Web Services, S3, DynamoDB, Lambda, EC2, ECS, IAM, SQS, SNS, CloudWatch,
  KMS, RDS, boto3, AWS SDK, aws cli, CloudFormation, IAM policy, service quota, ARN, endpoint.
---

# AWS — hivatalos dokumentáció mint tudásforrás

A részletes szabály és a teljes URL-katalógus a `references/aws-documentation.md`-ben van. **Olvasd be a `Read` tool-lal**, amikor AWS-specifikus munkát végzel.

Melyik reference kell:

| Ha a task… | Olvasd be |
|---|---|
| bármely AWS API / IAM action / limit / CLI flag / SDK metódus | `references/aws-documentation.md` |
| árva, nem használt vagy „még kell ez?" resource keresése, költség-takarítás | `references/aws-orphan-resource-audit.md` |

## A lényeg (mielőtt AWS-hez nyúlsz)

- **Elsődleges eszköz — Agent Toolkit for AWS (`aws-core` plugin).** A hivatalos AWS eszköz Claude Code-hoz ([termékoldal](https://aws.amazon.com/products/developer-tools/agent-toolkit-for-aws/)): egy `aws-mcp` MCP server (AWS CLI-futtatás, dokumentáció-keresés, curated skillek — CloudWatch monitoring + IAM control) és **15 curated skill** (`aws-cdk`, `aws-cloudformation`, `aws-iam`, `aws-serverless`, `aws-containers`, `amazon-bedrock`, `aws-observability`, `aws-messaging-and-streaming`, `aws-sdk-python-usage` / `-js-v3-usage` / `-swift-usage`, `aws-secrets-manager`, `aws-billing-and-cost-management`, `aws-blocks`, `signing-in-to-aws`). Ha egy AWS taskra van rá illő curated skill vagy elérhető az `aws-mcp`, **azt preferáld** a naprakész, managed forrásért. Telepítés (már megvan), bundle-profilok és open source: `references/aws-documentation.md`.
- **Kiegészítő / fallback — publikus URL + `WebFetch`.** Amikor nincs rá illő plugin-skill vagy az `aws-mcp` nem elérhető (pl. plugin nélküli környezet), a **hivatalos AWS dokumentációt** publikus URL-eken, `WebFetch`-csel éred el (markdownná alakítja az oldalt). Teljes URL-katalógus a `references/aws-documentation.md`-ben. Ha a pontos doc-URL nem ismert, `WebSearch` a `docs.aws.amazon.com`-ra, majd fetch.
- **Közös elv — docs over memory.** Bármelyik utat használod: ne memóriából találgass AWS API-t, IAM actiont, limitet, CLI flaget vagy SDK-viselkedést; a naprakész forrásból dolgozz, és verifikáld. Ne hallucinálj — ha a forrás nem erősíti meg, mondd ki, hogy bizonytalan (lásd [[devils-advocate-review]] hallucination-detection).
- **Safety (fontos) — tudás ≠ action.** A dokumentáció-olvasás (doc-search / WebFetch) read-only és biztonságos. De az `aws-mcp` **AWS CLI parancsokat is tud futtatni**, és a mutáló művelet (deploy, `terraform/terragrunt/tofu apply`, mutáló `aws` CLI parancs) **továbbra is engedélyköteles** — kérdezz előbb; lásd [[terraform-terragrunt]] és [[git-conventions]]. Privacy: csak publikus doc-URL, sose tegyél account ID-t / secretet / personal adatot a fetch URL query-jébe.
- **Token-economy:** az `aws-core` ~2,1k always-on tokent ad minden session-höz (a curated skillek on-invoke töltődnek); a WebFetch fallback csak akkor fut, ha tényleg kell — célzottan a releváns oldalt, ne az egész doc-fát. Lásd [[token-economy]].
- **Forgalom-generálás — tartsd alacsonyan (default).** Ha forgalmat/traffic-et kérek (pl. CloudWatch dashboard feltöltése adattal, metrika láthatóvá tétele) → **~10, max 20 hívás**; végpont teszt/validáció → **1-2 hívás** elég. Ennél többet csak explicit kérésre (load/stress test); magadtól sose skálázz felfelé — valós AWS-forgalom (költség, throttle, zajos metrika) és token is. Részletek a `references/aws-documentation.md`-ben.

- **Árva-resource audit — a diff csak jelöltlista.** Ha nem használt / törölhető resource-okat keresek, a módszer az élő leltár diffelése **az összes** terraform state-tel, és **minden találat egyenkénti visszaellenőrzése** egy második jelzéssel (`RoleLastUsed`, `AttachmentCount`, utolsó ECR push, legfrissebb S3 objektum, log group `lastEventTimestamp`, a feature-t kivevő git commit). A „nincs state-ben" önmagában nem bizonyíték, és van egy jól ismert untracked-de-élő halmaz (blue/green target group párok, `run-task` taskdef family-k, bootstrap state bucket, aktív CUR export). Részletek: `references/aws-orphan-resource-audit.md`.
- **Windows-csapda a lekérdezésekben.** Az SSM path, log group prefix és S3 key prefix `/`-el kezdődik, amit a Git Bash csendben Windows úttá ír át — az üres válasz így könnyen „a resource már nincs meg"-nek tűnik. Lásd [[shell-path-conversion]].

Kapcsolódás: AWS + IaC → [[terraform-terragrunt]] (a Terraform AWS provider docs a Registry-ben); AWS SDK C#-ban → a `dotnet` skill; a takarítási találatokból készülő ticketekhez → [[jira-issue-conventions]]. Részletek és a teljes URL-katalógus: `references/aws-documentation.md`.
