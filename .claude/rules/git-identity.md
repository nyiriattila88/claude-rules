# Git identity — which GitHub account commits and pushes

A machine can have several GitHub accounts logged in at the same time (a work one and a personal one). Git and `gh` resolve them **independently**, so *who authors the commit* and *who authenticates the push* are two separate decisions — and either one can silently be the wrong account.

## Personal repositories — `nyiriattila88`

This repository (`claude-rules`) and everything else under `github.com/nyiriattila88/` is Nyiri Attila's **personal** work. Commits and pushes here go through the **`nyiriattila88`** GitHub account — never the work account (`nyiri-attila-nxkey`, `Nyiri.Attila@nexius.hu`).

Two settings must line up:

| What | Where it is set | Expected value in this repo |
|---|---|---|
| Commit author | repo-local `user.name` / `user.email` | `Attila Nyiri` / `nyiriattila88@gmail.com` |
| Push credential | active `gh` account + user-scoped remote URL | `nyiriattila88` / `https://nyiriattila88@github.com/nyiriattila88/claude-rules.git` |

The repo-local `user.email` **deliberately overrides** the global (work) one. Do not "fix" it to match the global config.

## The `gh` multi-account trap — a 403 is the active account, not a missing scope

`gh auth status` can list both accounts as logged in while only one is `Active account: true`. Git's credential helper hands the **active** account's token to the push, so pushing a personal repo while the work account is active fails with **403** even though that token has `repo` scope.

The fix is to switch accounts, not to re-authenticate or mint a new token:

```bash
gh auth switch --hostname github.com --user nyiriattila88
```

Keep the remote **user-scoped** (`https://nyiriattila88@github.com/...`) so the credential helper is asked for that user instead of for whatever happens to be active.

### ✅ DO

```bash
gh auth status                                              # which account is active?
gh auth switch --hostname github.com --user nyiriattila88   # switch, then push
git push
```

### ❌ DON'T

```text
(A 403-at scope- vagy jogosultsági hibának olvasom, és új PAT-ot generálok —
a token jó volt, csak a rossz fiók volt aktív.)
```

```bash
# Felülírom a szándékos repo-local identityt a munkahelyivel.
git config --local user.email Nyiri.Attila@nexius.hu
```

## Establish the identity before the first commit

Check `git remote -v`, `git config --local user.email`, and `gh auth status` **before** committing in an unfamiliar repo, not after a push fails. A push made from the wrong account needs only a switch; a commit **authored** by the wrong account needs a history rewrite to fix.

Push itself still requires explicit permission — see [[git-conventions]] (push policy). This rule only says *which identity* to push with once that permission is given.
