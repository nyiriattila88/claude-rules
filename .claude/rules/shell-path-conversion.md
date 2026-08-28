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

## A másik útvonal-csapda: a Windows bináris nem érti a `/c/...` alakot

Ez **nem** az MSYS-átírás, hanem a fordítottja, és külön fejezetet kap, mert a hibaüzenet ugyanarra a
dologra, az útvonalra panaszkodik, így könnyű a fájlt hibáztatni a formátum helyett.

A Git Bash `/c/Users/...` alakját a **Windows-natív** programok nem oldják fel: az `aws.exe`
`--cli-input-json "file:///c/Users/..."` hívása „Unable to load paramfile", a `python.exe`
`open('/c/Users/...')` hívása `FileNotFoundError`, a `git.exe --file /c/...` pedig „can't open patch".

Tartsd meg mindkét alakot, és aszerint válassz, **ki nyitja meg a fájlt**:

| Ki használja | Melyik alak |
|---|---|
| shell builtin, coreutils, átirányítás (`>`, `cat`, `sed`) | `/c/Users/...` |
| Windows `.exe` argumentumként átadott útvonal (`aws`, `python`, `git`, `az`) | `C:\Users\...` |

### ✅ DO

```bash
SPU=/c/Users/nyiria/scratch          # shell-nek
SPW='C:\Users\nyiria\scratch'       # Windows binarisnak
aws cloudwatch get-metric-data --metric-data-queries "file://$SPW\q.json" > "$SPU/out.json"
```

### ❌ DON'T

```bash
# A Windows binaris nem talalja meg, es az utvonalra panaszkodik, nem a formatumra.
aws cloudwatch get-metric-data --metric-data-queries file:///c/Users/nyiria/scratch/q.json
```

## A harmadik útvonal-csapda: a Git Bash `/tmp` és a WSL `/tmp` nem ugyanaz

Egy gépen belül több külön `/tmp` létezik: a Git Bash sajátja (egy Windows temp mappa), a WSL
disztribúció sajátja, és a Windows `%TEMP%`. Ha az egyikbe írsz és a másikból olvasod, a fájl
**nincs ott**, és a hiba nem az útvonalra panaszkodik, hanem `No such file or directory`-t vagy
`exit 127`-et ad, ami elgépelésnek látszik, nem rendszer-különbségnek.

Akkor jön elő, amikor egy Bash tool-hívás ír egy scriptet vagy egy adatfájlt, és utána `wsl -e`
hívja meg. Maga a script még megtalálható `/mnt/c/...` alakban, de amit **ő** olvas be `/tmp`-ből,
az már a WSL saját `/tmp`-je, tehát üres.

**Két világ között csak `/mnt/c/...` útvonalon oszd meg a fájlt.** A scratchpad erre jó hely:
Windowsból `C:\Users\...`, WSL-ből `/mnt/c/Users/...`, ugyanaz a bájt.

Ez a [[shell-path-conversion]] többi esetétől annyiban más, hogy itt nem az útvonal *alakja* rossz,
hanem a *fájlrendszer*, amire mutat. A `/tmp/x` mindkét oldalon érvényes útvonal, csak nem ugyanaz.

### ✅ DO

```bash
SPU=/c/Users/nyiria/AppData/Local/Temp/claude/.../scratchpad     # Git Bash-nek
SPW=/mnt/c/Users/nyiria/AppData/Local/Temp/claude/.../scratchpad # WSL-nek, ugyanaz a fajl
aws ... > "$SPU/ids.txt"
wsl -e bash -lc "while read -r a b; do echo \$a; done < $SPW/ids.txt"
```

### ❌ DON'T

```bash
# A Git Bash /tmp-jebe irok, a WSL meg a sajatjaban keresi: exit 127,
# es a hibauzenet ugy hangzik, mintha elirtam volna a nevet.
cat > /tmp/script.sh <<EOF
...
EOF
wsl -e bash /tmp/script.sh
```
