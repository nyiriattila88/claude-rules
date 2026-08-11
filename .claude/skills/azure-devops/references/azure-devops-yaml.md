# Azure DevOps YAML — compile-time vs. runtime

A pipeline-ok legdrágább hibái abból jönnek, hogy **három különböző időpontban** történik a behelyettesítés, és a három nem látja egymást. Mielőtt bármit „paraméterezhetőre" alakítasz, dönts arról, melyik időpontban létezik az érték.

| Szintaxis | Mikor | Mit lát |
|---|---|---|
| `${{ }}` | **template expansion** (compile-time) | `parameters`, `${{ if }}` / `${{ each }}`, a YAML-ben literálisan definiált `variables` |
| `$[ ]` | **runtime expression** a `variables:` blokkban | `variables[...]`, beleértve a `- group:`-ból érkezőket |
| `$( )` | **macro**, a job queue-olásakor | a run addig feloldott változóit |

## Variable group = runtime, ezért compile-time döntést nem tud befolyásolni

A `- group:` bejegyzés változói **csak runtime** léteznek. Ez azt jelenti, hogy egy library variable group értéke **nem** tud `${{ if }}`-et, template-választást vagy paraméter-defaultot vezérelni. Ha egy „kapcsolót" a Library UI-ból akarsz működtetni, a döntésnek runtime-ra kell kerülnie — nem elég a group-ot behúzni.

A csapda azért veszélyes, mert **csendes**: a `${{ if eq(parameters.flag, ...) }}` a paraméterbe adott `$(FLAG)` *szövegre* fut, ami nem-üres string, tehát „igaz" — mindig ugyanaz az ág generálódik, hibaüzenet nélkül.

### ✅ DO

```yaml
# A group értékét runtime kifejezés olvassa, az eredmény macróként utazik tovább.
variables:
  - group: AGENT_POOLS
  - name: agent_pool_name
    value: $[ replace(replace(lower(variables['SELF_HOSTED_AGENTS_ENABLED']), 'true', variables['requested_pool_name']), 'false', 'Azure Pipelines') ]
```

```yaml
# A fogyasztó $( )-vel adja tovább, mert az érték queue-time-ban dől el.
      agent_pool_name: $(agent_pool_name)
```

### ❌ DON'T

```yaml
# A ${{ }} compile-time olvas: a $[ ]-ből származó értéket még nem látja, üres vagy nyers szöveg lesz.
      agent_pool_name: ${{ variables.agent_pool_name }}
```

```yaml
# A group flagje soha nem hat: a ${{ if }} a '$(SELF_HOSTED_AGENTS_ENABLED)' stringet kapja, ami truthy.
  ${{ if parameters.enable_self_hosted }}:
    name: 'Self Hosted'
```

**Ternary nincs** az expression nyelvben. Egy flag → érték leképezést a `replace()` láncolásával lehet megoldani: `replace(replace(lower(flag), 'true', <érték>), 'false', <másik>)`.

## A `pool` blokk — mit lehet runtime-ból és mit nem

| Elem | Macro-expandálható? |
|---|---|
| `pool.name` | **igen** — `name: $(pool_name)` a job indításakor feloldódik |
| `pool.demands` | **nem** — a `$(x)` literálisan megy be, és „no agent found … demand: `$(x)`" lesz belőle |
| `pool.vmImage` | csak compile-time érték; a kulcs jelenléte önmagában is compile-time döntés |

Ebből következik, hogy a **szerkezet** (`vmImage:` kulcs vs. `name:` + `demands:`) sosem tud runtime dőlni — csak *értékek* cserélhetők, kulcsok nem. Ha egy futásidőben eldőlő pool mellé fix demand kerül, a job nem talál agentet.

## Image-választás poolonként — nem szimmetrikus

- **Microsoft-hosted pool** (`Azure Pipelines`): az image **kizárólag** a `vmImage:` kulccsal választható. Demandként **sem** a `vmImage`, **sem** az `ImageOverride` nem talál agentet — a hosted agentek nem hirdetik ezeket capability-ként.
- **Self-hosted pool**: az agentek `vmImage` **capability**-t hirdetnek, tehát ott a `vmImage -equals <image>` demand a helyes eszköz.
- Demandra **nincs OR**, így egyetlen `demands:` blokk nem szolgálhat mindkét pool-típust.

Következmény: egy pinelt image és egy runtime pool-fallback **kizárja egymást**. Ha a fallback a cél, az image-nek üresen kell maradnia (a pool default image-ét kapod); ha a pinelés a cél, a fallback arra a jobra nem érvényesül. Ezt írd le a fogyasztó dokumentációjában, mert nem magától értetődő.

## A paraméter-továbbadás auditját grep-pel végezd, ne fejből

A hívási lánc mélyebb, mint amilyennek látszik: **job template hívhat másik job template-et** (nem csak stage → job). Egy hiányzó továbbadás nem compile-hiba, ha a paraméternek van defaultja — csak csendben a default viselkedést kapod, és ez futásban derül ki (nálunk: négy Terragrunt plan job maradt self-hosted agenten, miközben a többi átirányítódott).

### ✅ DO

```powershell
# Minden átadási pont felsorolása, majd döntés: kell-e ott továbbadni.
Select-String -Path "templates\*\*.yml" -Pattern '^\s+agent_pool: ' -Context 3,2
```

### ❌ DON'T

```text
Fejből összeírt lista a „stage → job" hívásokról, a jobs/*-on belüli hívások kihagyásával.
```

## Az agent capability-lista megtévesztő a hosted poolnál

Az `az pipelines agent list --pool-id <hosted> --include-capabilities` a hosted poolnál **offline placeholder** agenteket ad, elavult capability-készlettel (Xamarin, MSBuild 12.0, xcode). Ebből **nem** lehet következtetni arra, hogy egy demand teljesül-e. A demand-viselkedést csak **valódi futás** bizonyítja; a self-hosted poolnál viszont a lista használható (ott a `vmImage` érték valós).

## Kapcsolódások

- CLI-oldali csapdák, engedélymodell, temporary change: [`azure-devops-cli.md`](azure-devops-cli.md)
- Validáció futásokkal, revert-kötelezettség: ugyanott a *Koncepció-validálás temporary change-dzsel* szekció
