# Aether release train: mechanika, lépéssor, rollback

A leírás a 2026-08-10-i és 2026-08-12-i állapotot rögzíti. A pipeline-nevek, definition id-k és a deploy
útvonal azóta változhattak (NX-39368), ezért a konkrét számokat minden train előtt élőben ellenőrizd.

## Mi a train

Kézzel indított, több repót átfogó kiadás. Minden érintett repóban létrejön ugyanaz a `release/vX.Y.0`
branch és egy azonos nevű **annotated** tag, majd mindkettő felmegy a remote-ra. Onnantól a CI és a deploy
saját maga viszi tovább.

Két dolog teszi hibaérzékennyé:

- **A verzió sehol nincs kódban rögzítve.** Nincs verzió-bump commit, nincs manifest, amit frissítenénk.
  A build a **branch nevéből** számol (`X.Y.0-beta.0-<rövid sha>`), tehát az elgépelt branchnév
  egy az egyben elgépelt verzió.
- **A branch nem tartalmaz saját commitot.** A `develop` egy commitjára mutat, tehát a train tartalmát az
  határozza meg, hol állt a `develop`, amikor a branch készült.

## 1. A soron következő verzió megállapítása

**A repók legmagasabb `vX.Y.0` tagjéből olvasd ki, ne a branchekből.** Repónként egyszerre egy `release/*`
él, és a régit a train lezárásakor törlik, tehát a branchek nem őrzik a történetet.

Tag **csak abban a repóban** keletkezik, amelyik részt vett az adott trainben. Egyetlen repo tagja ezért
nem elég, a részt vevő repók **maximumát** kell venni. Példa: 2026-08-10-én az utolsó lezárt train a
`v1.43.0` volt, és abban csak a contentmanagement kapott taget.

Mielőtt bármit létrehozol, **ellenőrizd, hogy a célverzió sehol nem létezik** sem tagként, sem branchként.
Egy 2026-08-10-i tévesztés (1.44.0 helyett 1.45.0) egyszerre három repóban, a buildjeikben és az AzDO
release-ekben csapódott le.

### A `Frontend/Player` kivétel

A Player **saját, folytonos 4.x sorozatot** visz (`release/v4.9.0`), nem a train verziószámát. A train
verziójának elvétése nem érinti, és fordítva, a Player számozásából nem lehet a train verziójára
következtetni.

## 2. Branch és tag létrehozása

Repónként, lokálisan, a friss `develop`-ról:

```bash
git checkout develop
git pull
git checkout -b release/v1.44.0
git tag -a v1.44.0 -m "v1.44.0"
```

A tag **annotated** (`-a`), és az üzenete maga a verzió. Lightweight tag nem elég, a GitVersion arra nem
számol verziót.

## 3. Push

A push **engedélyköteles**, lásd [[git-conventions]]. Egy trainben a push valódi deployt indít, tehát ez
nem formalitás.

A push a legtöbb Build pipeline-t `individualCI`-vel triggereli. **Nem mindet**: a 2026-08-10-i állapotban
az `infrastructure - Build` (definition id 70, Backend project) kézi indítást igényelt,
`agent_image=ubuntu-24.04` és `agent_pool=SelfHosted` template paraméterekkel.

Push után **ellenőrizd, hogy minden érintett repóban elindult a Build**, ne feltételezd. Egy elmaradt
trigger csendben marad ki a trainből.

## 4. Deploy útvonal

Itt vált a leginkább a kép, ezért ez az első, amit élőben tisztázni kell.

**Klasszikus AzDO release** (a 2026-08-10-i állapot): a release automatikusan létrejön, és **magától
kimegy STG-re**. A PROD pre-deploy approvalon áll meg, az Infrastructure-nél az STG Apply is. A DEV és QA
stage-ek `notStarted` maradnak.

**YAML `deploy_pipeline.yml`** (NX-39368 iránya): a stage-ek env-paraméterre futnak
(`deploy_dev`…`deploy_prod`), tehát **paraméter nélkül indítva egyetlen stage sem fut le, a run mégis
zöld lesz**. Deploy után az eredményt a cél-rendszerből ellenőrizd, ne a futás státuszából.

## 5. A train lezárása

A `release/*` branchet törlik, **a tag marad**. Ez a tag lesz a következő train kiindulópontja, lásd az
1. pontot.

## 6. Rollback: a sorrend kötött

Egy már deployolt klasszikus release nem törölhető csak úgy. A **git-oldali javításnak és az új deploynak
meg kell előznie a takarítást**, mert mindkét blokkoló hiba csak a törlés pillanatában derül ki.

1. **Pending approvalok elutasítása.** Enélkül `VS402996`. A bulk PATCH `release/approvals` body-jában
   **csak egy release approvaljai** lehetnek.
2. **Az új, helyes release deployolása ugyanarra a stage-re.** Amíg a régi az adott stage `currently
   deployed` verziója, a törlés `VS402946`-tal bukik. Nincs "unmark deployed" művelet, ez az egyetlen
   feloldás.
3. **Release törlése** (`DELETE release/releases/{id}`).
4. **Retention lease-ek törlése, és csak utána a build.** A release branch buildjein örök lease-ek ülnek
   (`Branch:<repoGuid>:refs/heads/release/...`, `Pipeline:<defId>`, RM owner-ű `protectPipeline`),
   enélkül a build törlése `TF900561`-gyel bukik. A `build/leases` lekérdezéshez `definitionId` és `runId`
   **együtt** kötelező.

Ugyanez a lease blokkolja egy build pipeline törlését is. A részletek és az `az devops invoke --in-file`
BOM-csapdája: [[azure-devops-cli]] és [[powershell]].

## Kapcsolódó

Push és branch konvenciók: [[git-conventions]]. Deploy útvonal választása: [[deployment-path]]. AzDO CLI
használat: [[azure-devops-cli]].
