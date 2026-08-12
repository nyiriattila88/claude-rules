# Jira issue conventions — NX (Nexius products)

Site: `nexiuslearning.atlassian.net`, cloudId `a831ee87-1ca9-41ff-a505-c690787e4345`. Project key `NX`, id `10050`.

## Read a comparable ticket first

Field conventions live in the data, not in documentation. **Before creating anything, fetch a recent issue of the same type and copy its field usage.** `getJiraProjectIssueTypesMetadata` (with `requiredFieldsOnly: false`) tells you which fields *exist*; a real ticket tells you how the team actually fills them. Doing only the first is how the Acceptance Criteria field ends up empty while the criteria sit in the description.

## Issue types

| Type | id | Hierarchy |
|---|---|---|
| Epic | `10000` | 1 |
| Story | `10001` | 0 |
| Bug | `10002` | 0 |
| Simple Task | `10003` | 0 |
| Task | `10004` | 0 |
| Sub-task | `10005` | −1 |

A Task is attached to an Epic with the **`parent`** field (`parent: "NX-39412"`), not with an issue link. New issues start in status **`Draft`**, and the **Reporter is set automatically** to the creator — it is not on the create screen.

## Fields that are easy to get wrong

### Acceptance Criteria — `customfield_10124`

A dedicated **textarea** custom field that expects **ADF** (`{"type":"doc","version":1,"content":[...]}`), normally a single `bulletList`. This is where the team looks for criteria.

- **Do not** put a `## Definition of Done` section in the description instead. The house pattern is: description = context + task, AC field = the verifiable criteria.
- Write criteria as **observable outcomes**, not as a restatement of the work: "X nem létezik", "a plan üres diffet ad", "írásos döntés van róla" — not "töröljük X-et".
- Include the negative criteria too: what must **still** exist after the change. In a cleanup ticket that is the most valuable line.

```json
{
  "customfield_10124": {
    "type": "doc",
    "version": 1,
    "content": [
      { "type": "bulletList", "content": [
        { "type": "listItem", "content": [
          { "type": "paragraph", "content": [ { "type": "text", "text": "A shootout ECR repository nem létezik egyik accountban sem." } ] }
        ] }
      ] }
    ]
  }
}
```

Accented characters survive the MCP call as-is; no escaping needed beyond normal JSON.

### Account — `customfield_10043` (Tempo, **required**)

Expects a **plain number**: `"customfield_10043": 135`. The object form `{"id": 135}` fails with `Operation value must be a number`. Id `135` = `Aether architekturális szétválasztás (capitalized)`.

### Team — `customfield_10001` (Atlassian Teams)

Expects the team **UUID string**. Keystone: `17dba745-ee01-4f70-8764-b86f7dea7e20`. Bedrock: `4f1d749b-5f0b-46b7-acc4-f0ccc571af55`.

JQL caveat: `"Team[Team]" = "Keystone"` silently returns **0 results** — filter by UUID instead.

### Others worth knowing

`Priority` defaults to `Medium`. Useful selects: `Size` (XS–XL), `Technical complexity` / `Internal impact` / `Social impact` / `Confidence` / `Urgency` / `Importance` (Low/Medium/High), `MoSCoW` (Won't/Could/Should/Must), `Strategic alignment` (RCI/Bitwit/GDE), `Sprint` (`customfield_10010`).

## What the Atlassian MCP cannot do

- **Watchers.** There is no watcher tool, and `editJiraIssue` cannot set them either — Jira treats `watches` as read-only on the field API. The real endpoint is `POST /rest/api/3/issue/{key}/watchers`, which needs an API token.
  - **Say plainly that you cannot do it**, then offer the useful alternative: the accountIds (`lookupJiraAccountId`) so the user can add them, or a script hitting the REST endpoint with a token the user supplies via an environment variable.
  - Do **not** substitute an @mention comment and present it as equivalent — mentioning notifies but does not add a watcher.
  - The endpoint's body is a **raw JSON string** — `"557058:9b13…"`, quotes included — not an object. This is the usual reason a hand-rolled call fails.
- **`fetch`** is read-only (GET by ARI); it is not an escape hatch for arbitrary REST calls.

## Epic + grouped tasks — the shape that works

For a finding-driven epic (audit, migration, cleanup sweep), group by **theme**, not one ticket per resource:

- The **epic** carries the context, the business value, the reproducible method, a summary table, out-of-scope, and the open questions.
- Each **task** carries: why this is in scope, the exact identifiers, **the evidence** that justified the classification, an explicit "do not touch" list, and its own AC.
- Put the evidence in the ticket so the executor does not have to trust the author's word. In a deletion ticket, the "do not touch" section is what prevents the incident.
- Environment scope belongs in the body, not in a parenthetical on the summary — `(mind a 4 környezet)` in the title is noise.

## ✅ DO

```text
Lekérem NX-39368-at, látom hogy az AC a customfield_10124-ben ADF bullet-listaként van,
és ugyanígy töltöm ki az új ticketeket.
```

## ❌ DON'T

```text
(A mezőlistát megnéztem, de egy valódi ticketet nem — így a „Definition of Done" a leírásba került,
a dedikált Acceptance Criteria mező pedig üresen maradt mind a 13 issue-n.)
```

```text
(Watcher helyett @mention kommentet írok, és úgy jelentem, mintha felvettem volna őket watchernek.)
```
