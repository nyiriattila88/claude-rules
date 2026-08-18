---
name: jira
description: >
  Jira (Atlassian Cloud) issue-kezelési szabályok az NX projekthez (Nyiri Attila szabálykészlete).
  Használd MINDIG, amikor Jira issue-t létrehozol vagy szerkesztesz: Task/Story/Epic létrehozás, EPIC +
  alárendelt taskok felvétele, Acceptance Criteria írása, leírás szerkesztése, mezőkitöltés (Account,
  Team, label, priority), watcher, JQL keresés, vagy az Atlassian MCP tool-jainak használata
  (`createJiraIssue`, `editJiraIssue`, `searchJiraIssuesUsingJql`, `addCommentToJiraIssue`).
  KRITIKUS és gyakran elrontott: az **Acceptance Criteria dedikált mező** (`customfield_10124`, ADF
  bullet-lista), NEM a leírásba írt „Definition of Done" szakasz; az **Account** (`customfield_10043`)
  sima számot vár, a **Team** (`customfield_10001`) UUID stringet; a **watcher-endpoint nincs kitéve** az
  MCP-ben, és a `watches` mező read-only a field API-n. A konvenciókat egy friss, hasonló ticketből
  olvasd ki, ne találgasd. Trigger kulcsszavak: Jira, NX-, issue, ticket, EPIC, Acceptance Criteria, AC,
  Definition of Done, work item, JQL, Atlassian, atlassian.net, createJiraIssue, editJiraIssue, watcher,
  story point, sprint, backlog.
---

# Jira: NX projekt issue-konvenciók

A részletes szabály a `references/jira-issue-conventions.md`-ben van. **Olvasd be a `Read` tool-lal**, mielőtt issue-t létrehozol vagy szerkesztesz.

## A lényeg (mielőtt issue-t írsz)

- **Nézz meg egy friss, hasonló ticketet.** A mezőkonvenciók az adatban élnek, nem a dokumentációban: kérd le egy nemrég létrehozott, ugyanolyan típusú issue-t `getJiraIssue`-val (`fields: ["*all"]` vagy célzott lista), és abból másold a mezőhasználatot. Ez a leggyakoribb hibaforrás elkerülése.
- **Az Acceptance Criteria dedikált mező**, nem szövegrész. Az NX projektben `customfield_10124` (textarea), és **ADF `bulletList`-et** vár. A leírásba írt „Definition of Done" szakasz nem helyettesíti, ott meg sem jelenik, ahol a csapat keresi.
- **Kötelező mezők Task-nál:** `Account` (`customfield_10043`), **sima szám**, nem objektum; `Team` (`customfield_10001`), team **UUID** string.
- **Amit az MCP nem tud:** watcher hozzáadása. Nincs rá endpoint, és az `editJiraIssue` sem megy, mert a `watches` read-only. Ilyenkor **mondd ki, hogy nem tudod**, adj accountId-t vagy scriptet, ne csinálj helyette „közelítést" (pl. @mention komment), mert az értesít, de nem tesz watcherré.
- **Nyelv:** a leírás és az AC a beszélgetés nyelvén (magyarul), a technikai nevek verbatim, lásd [[communication-language]] és [[documentation-style]]. Kivétel a **PR-leírás**, ami angol, mert a merge commit viszi tovább; a PR-komment viszont magyar, lásd [[git-conventions]].
- **Létrehozás engedélyköteles-e?** Az issue-létrehozás outward-facing, csapatnak látható művelet. Explicit kérésre szabad; magadtól ne hozz létre ticketet. Több issue egyszerre (EPIC + N task) is csak explicit kérésre.

Kapcsolódás: az AWS-oldali takarítási ticketek tartalmához [[aws-orphan-resource-audit]]; commit/PR konvenciók [[git-conventions]]. Részletek: `references/jira-issue-conventions.md`.
