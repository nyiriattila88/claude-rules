# AWS orphan-resource audit — find leftovers without deleting something live

Applies when the task is "find unused / orphaned / leftover AWS resources", a cost-cleanup sweep, or a "is this still used?" question. The output of such an audit is a **deletion proposal**, so the bar for evidence is higher than for an ordinary lookup: a false positive here means deleting a live resource.

## The method — diff live inventory against terraform state

Tag-based detection (`terraform_managed = "true"` in `default_tags`) is a **weak** signal: older resources predate the tag scheme, and other tools create resources with their own tags. The reliable reference is the state itself.

1. **Collect every state file** from the state bucket(s) of every account — not just the monolith. A typical layout has an infra monolith (`v2/<region>/terraform.tfstate`, `v2/global/...`) plus one state per service repo (`<repo>/environments/<env>/.../tofu.tfstate`).
2. **Build the tracked-id set** from resources with `mode: managed` only (skip `data`), taking every identifying attribute: `id`, `arn`, `name`, `function_name`, `bucket`, `table_name`, `repository_name`, `queue_url`, `log_group_name`.
3. **Enumerate live resources** per service and diff.
4. **Verify every hit individually** with a live API call plus the repo and its git history.

Cover the region(s) the accounts actually use, **plus `us-east-1`** for global services (CloudFront, ACM certs for CloudFront, some CFN stacks).

## "Not in state" is not proof — verify per hit

Treat the diff as a **candidate list**, never a delete list. For each candidate, find a second, independent signal:

| Signal | What it settles |
|---|---|
| `iam get-role --query Role.RoleLastUsed.LastUsedDate` | whether a role is dead (`None` = never used) |
| `iam list-policies --scope Local` → `AttachmentCount == 0` | orphaned policy |
| newest object in a bucket | when the writer stopped |
| `ecr describe-images` newest `imagePushedAt` | whether a repo is still fed |
| `logs describe-log-streams --order-by LastEventTime` | whether anything still logs |
| `git log --all -S'<name>'` in the infra repo | the commit that removed the feature — the strongest evidence there is |
| the consuming code / SSM parameter value | which of two similarly named resources is the live one |

Two independent signals agreeing on the same date (e.g. a firehose role's `RoleLastUsed` matching the bucket's newest object) is the gold standard.

## Known false positives — untracked but LIVE

These come up in almost every sweep. Deleting them causes an incident:

- **Bootstrap resources** — the terraform state bucket itself and the lock table. They cannot be in state; that is by design.
- **Blue/green target group pairs** — a target group with **0 load balancers** is the idle half of a CodeDeploy blue/green pair, not an orphan. Look for the `…BL`/`…GR` sibling.
- **`run-task` task-definition families** — a family with no ECS service is normal when a lambda launches it with `run-task`. Check the ECR push recency before calling it dead.
- **External tooling** — Datadog (CFN stacks, forwarder buckets, integration roles), Control Tower StackSets and baseline roles, security scanners, OIDC connections for CI. Intentionally outside terraform.
- **Service-linked and SSO roles** — `AWSServiceRole*`, `AWSReservedSSO_*`, `OrganizationAccountAccessRole`.
- **Active cost/usage exports** — a large, untracked bucket may be the sink of a live CUR / BCM data export. Check `cur describe-report-definitions` and `bcm-data-exports list-exports` (in `us-east-1`) before touching it.
- **Log groups of live APIs** — an `API-Gateway-Execution-Logs_<apiId>/<stage>` group means execution logging was enabled outside terraform. The group is not orphaned; it is merely unmanaged and often has no retention.

Also distinguish **tracked but empty** from **untracked**: an empty bucket that *is* in state must be removed from the `.tf` code, not from the console — terraform would just recreate it.

## What is genuinely worth flagging

- Unattached EBS volumes, unassociated Elastic IPs, available ENIs — pure waste, hourly billed.
- **Disabled customer-managed KMS keys still bill** (~1 USD/month each) until actually deleted, and deletion is `schedule-key-deletion` with a 7–30 day wait.
- Dead ECR repositories — usually the single largest line item, because image layers add up fast.
- IAM roles/policies of deleted lambdas, especially the auto-generated `AWSLambdaBasicExecutionRole-<uuid>` policies with 0 attachments.
- EventBridge rules and Container Insights log groups pointing at ECS clusters that no longer exist.
- CloudFormation stacks whose resources were deleted underneath them — the stack lingers in `CREATE_COMPLETE`.
- Stale state objects in the state bucket, including empty pre-migration states and files that landed in the wrong account's bucket.

## The dangerous case — a stale state that still claims a live resource

A leftover state file is not only clutter. If it still holds a resource that an **active** state also manages, running the legacy root will fight the active state over it. When you find one, check which other state claims the same id, and say so explicitly — the state object is safe to delete, the resource is not.

The mirror image is just as important: a **live, actively used resource tracked only by a legacy state** (or by nothing at all) is an *import* task, not a delete task. Import it under the active state first, and only then drop the legacy state.

## Ordering and safety

Propose the cleanup in risk order: zero-risk metadata first (IAM, empty log groups, stale state objects, empty buckets), then data-bearing buckets and tables, then the imports. For anything holding data, get an explicit decision before deletion, and note when no snapshot exists.

**The sweep itself is read-only and safe. Every deletion is a mutating AWS operation and stays permission-gated** — see [[terraform-terragrunt]] and [[git-conventions]]. Report findings; do not delete on your own initiative, even when the evidence is conclusive.

Windows caveat: several of these queries take `/`-leading arguments (SSM paths, log group prefixes, S3 key prefixes). Read [[shell-path-conversion]] first — a silently empty result here reads exactly like "the resource is gone".
