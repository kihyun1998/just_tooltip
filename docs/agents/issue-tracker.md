# Issue tracker: GitHub

Issues and PRDs for this repo live as GitHub issues. Use the `gh` CLI for all operations.

## Conventions

- **Create an issue**: `gh issue create --title "..." --body "..."`. Use a heredoc for multi-line bodies.
- **Read an issue**: `gh issue view <number> --comments`, filtering comments by `jq` and also fetching labels.
- **List issues**: `gh issue list --state open --json number,title,body,labels,comments --jq '[.[] | {number, title, body, labels: [.labels[].name], comments: [.comments[].body]}]'` with appropriate `--label` and `--state` filters.
- **Comment on an issue**: `gh issue comment <number> --body "..."`
- **Apply / remove labels**: `gh issue edit <number> --add-label "..."` / `--remove-label "..."`
- **Close**: `gh issue close <number> --comment "..."`

Infer the repo from `git remote -v` — `gh` does this automatically when run inside a clone.

## Pull requests as a triage surface

**PRs as a request surface: no.** _(Set to `yes` if this repo treats external PRs as feature requests; `/triage` reads this flag.)_

When set to `yes`, PRs run through the same labels and states as issues, using the `gh pr` equivalents:

- **Read a PR**: `gh pr view <number> --comments` and `gh pr diff <number>` for the diff.
- **List external PRs for triage**: `gh pr list --state open --json number,title,body,labels,author,authorAssociation,comments` then keep only `authorAssociation` of `CONTRIBUTOR`, `FIRST_TIME_CONTRIBUTOR`, or `NONE` (drop `OWNER`/`MEMBER`/`COLLABORATOR`).
- **Comment / label / close**: `gh pr comment`, `gh pr edit --add-label`/`--remove-label`, `gh pr close`.

GitHub shares one number space across issues and PRs, so a bare `#42` may be either — resolve with `gh pr view 42` and fall back to `gh issue view 42`.

## When a skill says "publish to the issue tracker"

Create a GitHub issue.

## When a skill says "fetch the relevant ticket"

Run `gh issue view <number> --comments`.

## Wayfinding operations

How this repo expresses what `wayfinder` uses — the map, child tickets, blocking, the frontier
query. All of it is GitHub-native. **Don't imitate it with body conventions**: only native
relations let the tracker UI draw what is blocked and what can be picked up.

- **Map** — one issue labelled `wayfinder:map`.
- **Ticket** — a **sub-issue** of the map, labelled `wayfinder:` + `research` / `prototype` /
  `grilling` / `task`.
- **Claim** — assign yourself *before* starting. An open ticket with no assignee is unclaimed.

`gh` has no sub-issue / dependency subcommands, so go through GraphQL. Get the node id first
(`52` below is an example map number — use your own map's number):

```bash
gh api graphql -f query='{repository(owner:"kihyun1998",name:"just_tooltip"){issue(number:52){id}}}' --jq '.data.repository.issue.id'
```

**Attach as a child** — `addSubIssue(issueId: <parent>, subIssueId: <child>)`.

**Blocking** — `addBlockedBy(issueId: <blocked>, blockingIssueId: <blocker>)`.
The argument names are asymmetric, so don't mix up the direction. Undo with `removeSubIssue` /
`removeBlockedBy`.

**Frontier** — children that are open, unblocked and unassigned:

```bash
gh api graphql -f query='{repository(owner:"kihyun1998",name:"just_tooltip"){issue(number:52){subIssues(first:50){nodes{number title state assignees(first:3){nodes{login}} blockedBy(first:20){nodes{number state}}}}}}}' \
  --jq '.data.repository.issue.subIssues.nodes[] | select(.state=="OPEN") | select([.assignees.nodes[]]|length==0) | select([.blockedBy.nodes[]|select(.state=="OPEN")]|length==0) | "\(.number)\t\(.title)"'
```

**Shell caveat** — the default shell here is zsh, so `set -- $pair` does not word-split. To
iterate over pairs, use `while read -r a b`.
