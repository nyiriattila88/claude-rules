# Shell path conversion: the silent CLI-argument corruption on Windows

Git Bash / MSYS2 on Windows **rewrites command-line arguments that look like absolute POSIX paths** before the target executable ever sees them. `/ENT/LMSVideo` becomes `C:/Program Files/Git/ENT/LMSVideo`. This also hits the value part of `KEY=/value` pairs, not just standalone arguments.

**The reason this needs its own rule is the failure mode, not the mechanism: it usually fails silently.** The CLI does not error, it receives a valid-looking but wrong argument, finds nothing, and returns an **empty result set**. An empty result read as "this resource does not exist" is how an audit concludes that a live resource is gone, and how a cleanup task deletes something that was in use.

## When to suspect it

**Any time a CLI query returns unexpectedly empty or errors on an argument that starts with `/`, this is the first suspect**, before you conclude anything about the remote state. Verify with a second call before you draw a conclusion.

Argument shapes that get corrupted:

| CLI | Affected argument |
|---|---|
| `aws ssm get-parameters-by-path` | `--path /ENT/...` |
| `aws ssm describe-parameters` | `--parameter-filters "...,Values=/ENT/..."` |
| `aws logs describe-log-groups` | `--log-group-name-prefix /ecs/...` |
| `aws s3api list-objects-v2` | `--prefix /some/key` |
| `aws iam create-role` and friends | `--path /service-role/` |
| `az`, `kubectl`, `gh`, `docker` | any `/`-leading path, mount, or resource-id argument |

## The fix

- **`export MSYS_NO_PATHCONV=1`** at the start of the script or call, the simplest, and it covers the whole invocation.
- Or use the **PowerShell tool** instead, which does no path conversion.
- `MSYS2_ARG_CONV_EXCL='*'` is the equivalent escape hatch on newer MSYS2 builds.

## ✅ DO

```bash
export MSYS_NO_PATHCONV=1
aws ssm get-parameters-by-path --profile dev-admin --path "/ENT/LMSVideo" --query 'Parameters[].Name'
```

```text
Az SSM lekérdezés üresen jött vissza. Mielőtt kimondom, hogy a paraméterek nem léteznek,
újrafuttatom MSYS_NO_PATHCONV=1-gyel, és tényleg: három paraméter létezik.
```

## ❌ DON'T

```bash
# A --path argumentumot a Git Bash Windows úttá írja át; a hívás csendben 0 találatot ad.
aws ssm get-parameters-by-path --profile dev-admin --path /ENT/LMSVideo
```

```text
(Az üres választ tényként kezelem:)
„Az /ENT/LMSVideo/* paraméterek már nem léteznek, a state hiába hivatkozik rájuk, törölhető."
```

That second `DON'T` is the dangerous one: the conclusion is stated confidently, and the next step is a deletion. See [[aws-orphan-resource-audit]] for why "the API returned nothing" is never sufficient evidence on its own.
