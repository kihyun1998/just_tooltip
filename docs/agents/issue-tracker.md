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

`wayfinder` 가 쓰는 것들 — 지도, 자식 티켓, blocking, 프론티어 질의 — 이 repo 에서의 표현.
전부 GitHub 네이티브다. **본문 관례로 흉내내지 마라**: 네이티브라야 트래커 UI 가 무엇이 막혔고
무엇이 집을 수 있는지를 그림으로 보여준다.

- **지도** — `wayfinder:map` 라벨을 단 이슈 하나.
- **티켓** — 지도의 **sub-issue**. 라벨은 `wayfinder:` + `research` / `prototype` /
  `grilling` / `task`.
- **claim** — 착수 *전에* 자신에게 assign 한다. assign 안 된 열린 티켓이 unclaimed 다.

`gh` 에 sub-issue / dependency 서브커맨드가 없으므로 GraphQL 로 간다. node id 부터 얻는다
(아래 `52` 는 예시로 쓴 지도의 번호다 — 자기 지도 번호로 바꿔라):

```bash
gh api graphql -f query='{repository(owner:"kihyun1998",name:"just_tooltip"){issue(number:52){id}}}' --jq '.data.repository.issue.id'
```

**자식으로 붙이기** — `addSubIssue(issueId: <부모>, subIssueId: <자식>)`.

**blocking** — `addBlockedBy(issueId: <막힌 쪽>, blockingIssueId: <막는 쪽>)`.
인자 이름이 비대칭이니 방향을 헷갈리지 마라. 해제는 `removeSubIssue` / `removeBlockedBy`.

**프론티어** — 열려 있고, 막히지 않았고, assign 안 된 자식들:

```bash
gh api graphql -f query='{repository(owner:"kihyun1998",name:"just_tooltip"){issue(number:52){subIssues(first:50){nodes{number title state assignees(first:3){nodes{login}} blockedBy(first:20){nodes{number state}}}}}}}' \
  --jq '.data.repository.issue.subIssues.nodes[] | select(.state=="OPEN") | select([.assignees.nodes[]]|length==0) | select([.blockedBy.nodes[]|select(.state=="OPEN")]|length==0) | "\(.number)\t\(.title)"'
```

**셸 주의** — 이 환경의 기본 셸은 zsh 라 `set -- $pair` 가 단어 분리를 하지 않는다. 쌍을
반복할 때는 `while read -r a b` 를 써라.
