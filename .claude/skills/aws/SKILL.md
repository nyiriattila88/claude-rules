---
name: aws
description: >
  AWS-specifikus tudás-szabályok (Nyiri Attila szabálykészlete): a hivatalos AWS dokumentáció elérése
  publikus URL-eken keresztül (WebFetch), hogy az agent ne memóriából találgasson, hanem a naprakész
  hivatalos forrásból dolgozzon. Használd MINDIG, amikor AWS-szel dolgozol: bármely AWS service (S3,
  DynamoDB, Lambda, EC2, ECS, SQS, SNS, CloudWatch, KMS, RDS, API Gateway, Step Functions, IAM, stb.),
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

## A lényeg (mielőtt AWS-hez nyúlsz)

- **Mi ez:** ne memóriából találgass AWS API-t, IAM actiont, service-limitet, CLI flaget vagy SDK-viselkedést — a **hivatalos AWS dokumentációt** publikus URL-eken, `WebFetch`-csel éred el, és onnan dolgozol. A WebFetch a HTML doc oldalt markdownná alakítja, így közvetlenül fogyasztható.
- **Mikor fetch-elj:** mielőtt AWS API-paramétert, IAM action/policy-t, resource-t / condition key-t, service-limitet / quotát, endpointot, CLI flaget, SDK metódust vagy service-specifikus viselkedést **állítasz vagy használsz** — kivéve, ha triviálisan biztos. Ha a konkrét doc-URL nem ismert, `WebSearch`-csel keresd meg a hivatalos `docs.aws.amazon.com` oldalt, majd azt fetch-eld.
- **Fő belépő URL-ek** (teljes katalógus a reference-ben): a `https://docs.aws.amazon.com/` portál, a **Service Authorization Reference** (IAM action/resource/condition key), a **AWS CLI v2 reference**, az **SDK docs** (boto3 / SDK for .NET), és a **General Reference** (endpoints, quotas, ARN-formátumok).
- **Token-economy:** célzottan a releváns oldalt fetch-eld, ne az egész doc-fát; egy-két pontos oldal elég. Lásd [[token-economy]].
- **Verifikáció:** hivatkozd az URL-t (és a doc verzióját, ha van), amiből az információ jön, hogy visszakövethető legyen. Ne hallucinálj API-t/limitet — ha a doc nem erősíti meg, mondd ki, hogy bizonytalan (lásd [[devils-advocate-review]] hallucination-detection).
- **Ez tudás, nem action:** a dokumentáció-fetch read-only, publikus forrásból — biztonságos. Az AWS-en végrehajtott **mutáló művelet** (deploy, `terraform/terragrunt/tofu apply`, mutáló `aws` CLI parancs) **továbbra is engedélyköteles**; lásd [[terraform-terragrunt]] és [[git-conventions]] engedély-modelljét.
- **Privacy:** csak publikus doc-URL-eket fetch-elj; sose tegyél account ID-t, secretet vagy personal adatot a fetch URL query-jébe.

Kapcsolódás: AWS + IaC → [[terraform-terragrunt]] (a Terraform AWS provider docs a Registry-ben); AWS SDK C#-ban → a `dotnet` skill.
