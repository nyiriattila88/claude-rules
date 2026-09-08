---
name: aether-release-train
description: >
  Az Aether release train mechanikája (Nyiri Attila szabálykészlete): kézzel nyitott `release/vX.Y.0`
  branch + azonos nevű **annotated** tag minden érintett repóban, verzió-bump commit nélkül. Használd
  MINDIG, amikor Aether release-ről van szó: release branch nyitása vagy zárása, új verzió kiadása,
  train indítása, tag létrehozása, a soron következő verziószám megállapítása, a train által triggerelt
  Build és Deploy pipeline-ok követése, STG/PROD kimenetel ellenőrzése, vagy egy rosszul kiment release
  visszavonása. KRITIKUS és gyakran elrontott: a **soron következő verziót a repók legmagasabb `vX.Y.0`
  tagjéből** kell kiolvasni, NEM a branchekből, mert repónként egyszerre csak egy `release/*` él és a
  régit a train zárásakor törlik; a tag **annotated** legyen (a lightweight tagen a GitVersion elhasal);
  a branch **nem tartalmaz saját commitot**, a `develop` egy commitjára mutat; a `Frontend/Player`
  **saját, folytonos 4.x sorozatot** visz, nem a train verzióját; a rollback sorrendje kötött, a helyes
  artefaktot **előbb** ki kell vinni a stage-re, és csak utána szabad takarítani. A push és a pipeline
  indítás engedélyköteles. Trigger kulcsszavak: release train, release branch, release/v, Aether release,
  új verzió kiadása, verziószám, annotated tag, vX.Y.0, GitVersion, beta.0, STG deploy, PROD approval,
  release visszavonás, rollback, VS402946, TF900561.
---

# Aether release train

A részletes mechanika a `references/release-train.md`-ben van. **Olvasd be a `Read` tool-lal**, mielőtt
trainhez nyúlsz.

## A lényeg (mielőtt branchet nyitsz)

- **A verzió sehol nincs kódban.** Kézzel adjuk meg, és a build a **branch nevéből** számolja
  (`X.Y.0-beta.0-<rövid sha>`). Ha elvétjük, a hiba egyszerre több repóban, buildekben és
  deploy-futásokban csapódik le.
- **A soron következő verziót a legmagasabb `vX.Y.0` tagből olvasd ki, ne a branchekből.** Repónként
  egyszerre egy `release/*` él, a régit a train lezárásakor törlik, csak a tag marad. Tag csak abban a
  repóban keletkezik, amelyik részt vett az adott trainben, tehát a repók **maximumát** kell nézni, nem
  egyetlen repót.
- **Ellenőrizd, hogy a célverzió sehol nem létezik**, mielőtt bármelyik repóban létrehozod.
- **A branchen nincs saját commit.** A `release/vX.Y.0` a `develop` egy commitjára mutat, verzió-bump
  commit sehol nincs a folyamatban.
- **A tag annotated**, a neve és az üzenete is a verzió (`v1.44.0`). Lightweight tag nem elég.
- **A `Frontend/Player` külön sorozat.** Saját, folytonos 4.x számozást visz (`release/v4.9.0`), a train
  verziószámától függetlenül.
- **Push és pipeline indítás engedélyköteles.** Mindkettő outward-facing, valódi deployt indít, lásd
  [[git-conventions]] push policy és [[deployment-path]].

## Amit minden train előtt élőben ellenőrizz

A train mechanikája mozgásban van, ezért ne a leírt pipeline-neveket és id-ket vedd készpénznek:

- **Melyik deploy fut**, klasszikus AzDO release vagy YAML `deploy_pipeline.yml`. Az NX-39368 migráció a
  Backend repókat klasszikus release definíciókról YAML deploy pipeline-ra vitte, és ezzel a train
  utóélete is más lett (az egyik magától kimegy STG-re, a másiknak paraméter kell).
- **Mely repók vesznek részt** ebben a trainben. A listát az AzDO repo-listából vedd, ne a lokális
  klónokból, lásd [[lessons-learned]] és a general lessons vonatkozó bejegyzését.
- **Elindult-e minden Build.** A push a legtöbb Build pipeline-t triggereli, de nem mindet.

Részletek, lépéssor és a rollback kötött sorrendje: `references/release-train.md`.
