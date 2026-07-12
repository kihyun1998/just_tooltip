## 작업 규율 — `flutter_flow`

Substantive 변경(버그 수정·기능 추가·동작 변경)은 **`flutter_flow` 스킬로 짠다** —
변경 시작 시 실행한다. 그 스킬이 10단계 flow 와 두 상위 법칙(우회 금지·추측 금지)을
담는다. 순수 대화·문서 오타·런타임 표면 없는 편집엔 해당 없다.

**이 리포의 실증**(어느 단계에서 무엇을 놓쳤나 — #22, #30–#39, #48 …)은
`docs/agents/lessons.md` 에 산다. 착수 전에 읽고, 새 실증이 나오면 거기 남긴다.

이 리포는 **발행 패키지**이므로 flutter_flow 의 Step 7(하류 실검증)·Step 10(하류
마이그레이션)이 모두 해당한다.

## 이 리포 고유 설정

- **소비처:** `flutter_folderview`, `flutter_table_plus`, `flutter_password_input`.
  (도출: `for d in ../*/; do grep -l '^  just_tooltip:' "$d/pubspec.yaml"; done`)
- **하류 실검증** (Step 7): 소비처 repo 에 임시로 아래를 두고, 전체 스위트를 돌린 뒤
  삭제한다. `pubspec.yaml` 은 안 건드린다. `flutter pub get` 이 건드린 생성 파일
  (`example/*/generated_plugin_*`)도 되돌린다.

  ```yaml
  dependency_overrides:
    just_tooltip:
      path: ../just_tooltip
  ```

- **여전히 옳은 우회:** 행 툴팁의 `TooltipAnchor.pointer` 는 버그 회피가 아니라 "커서
  옆을 가리킨다" 는 본래 의도 — 마이그레이션 때 제거하지 말고 이유를 주석에 남긴다.

## Agent skills

- **Issue tracker** — 이 repo 의 GitHub Issues (`kihyun1998/just_tooltip`), `gh` CLI
  로 관리. 외부 PR 은 triage 대상이 아니다. `docs/agents/issue-tracker.md`.
- **Triage labels** — 다섯 canonical 역할의 기본 라벨 문자열(`needs-triage`,
  `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`).
  `docs/agents/triage-labels.md`.
- **Domain docs** — 단일 컨텍스트: repo 루트의 `CONTEXT.md` + `docs/adr/`.
  `docs/agents/domain.md`.
