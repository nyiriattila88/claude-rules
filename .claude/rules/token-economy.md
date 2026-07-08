# Token economy (critical)

**Token cost is a first-class constraint. Optimize for fewer tokens, never at the cost of quality — at the cost of speed.**

When two approaches reach the same-quality result, pick the one that consumes **fewer tokens**, even if it is **slower** in wall-clock time. Latency is cheap; tokens are not. The acceptable trade-off ordering is:

**quality (never sacrifice) → tokens (minimize) → speed (sacrifice first).**

## Rules

- **Tokens over speed.** If a faster strategy costs more tokens than a slower one, choose the slower one. Do not parallelize work just to finish sooner when the parallel path burns more tokens.
- **Quality is non-negotiable.** Saving tokens must never reduce correctness, completeness, or care. Spend the tokens a task genuinely needs; only cut the *wasteful* ones.
- **Prefer sequential over parallel agents when it is cheaper.** Spawning multiple subagents (or a fan-out workflow) duplicates context and multiplies token usage. Reach for parallelism only when it does not increase total token spend, or when the user explicitly asked for speed.
- **Read narrowly.** Read only the file ranges you need, search with targeted queries, and avoid re-reading content already in context.
- **No redundant restating.** Don't echo back large inputs, re-quote files, or repeat the question. Keep responses tight.

## ✅ DO

```text
A 10-fájlos refaktort egyetlen kontextusban, szekvenciálisan végzem el —
tovább tart, de töredékannyi token, mint 10 párhuzamos subagent.
```

```text
A fájlnak csak a releváns 40 sorát olvasom be offset/limit-tel,
nem a teljes 2000 sort.
```

## ❌ DON'T

```text
5 párhuzamos agentet indítok, hogy gyorsabb legyen — pedig ugyanazt
a kontextust 5-ször töltik be, így sokszoros a tokenköltség.
```

```text
Lerövidítem az elemzést vagy kihagyok egy ellenőrzést, hogy kevesebb
token fogyjon — a minőség rovására. (Tilos: a minőség sosem áldozható fel.)
```

## When the user asks for speed

If the user explicitly prioritizes speed (e.g. "do this fast", "run it in parallel"), follow that instruction — their explicit request overrides this default. Otherwise, assume **fewer tokens, even if slower**.

## Parallel agents & fan-out workflows need explicit permission — even under ultracode

Spawning **parallel subagents** or launching a **fan-out `Workflow`** is a token-multiplying, outward-scaling action. Treat it like `git push` or `terraform apply` (see [[git-conventions]], [[terraform-terragrunt]]): **never start it on your own initiative — ask first**, unless the user authorized it in the current prompt.

- **`ultracode` does not grant this permission.** Ultracode is a standing opt-in to *author and run workflows for quality/thoroughness* and it removes the token-budget worry — but it still does **not** authorize parallel/fan-out execution without the user's say-so. When ultracode is on and a task would benefit from a fan-out, **describe the plan and ask**, then wait.
- **An explicit request to parallelize is the permission.** "Run it in parallel", "fan this out", "use a workflow" (in the current prompt) counts as authorization for that request. A vague "do it fast" does not — prefer a cheaper sequential path and ask before fanning out.
- **Sequential, single-context work needs no permission.** Do the work inline unless told to parallelize.
- **Permission does not carry over.** Approval for one request does not authorize parallel/fan-out on the next; ask again.

### ✅ DO

```text
Ultracode be van kapcsolva, és a review-t fan-out workflow-val alaposabban le tudnám fedni.
Felvázolom, mit indítanék (N finder + verify), és megkérdezlek, mielőtt elindítom.
```

### ❌ DON'T

```text
(Ultracode módban magamtól indítok egy fan-out workflow-t vagy több párhuzamos
subagentet engedély nélkül, arra hivatkozva, hogy "az ultracode úgyis ezt kéri".)
```
