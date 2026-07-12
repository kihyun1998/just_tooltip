# Lessons — just_tooltip 실증

이 리포가 `flutter_flow` 의 각 단계에서 실제로 **무엇을 놓쳤나** 의 기록.
스킬(`flutter_flow`)은 규칙을, 이 파일은 증거를 담는다 — 규칙만 보면 추상적이라 같은
실수가 반복되므로, 여기 산 사건들이 그 규칙에 무게를 준다. 전부 이 repo 에서 실제로
일어났다. 단계 번호는 `flutter_flow` SKILL.md 의 번호와 일치한다.

새 substantive 변경에서 어느 단계를 건너뛰어 대가를 치렀다면, 그 사건을 여기 해당
단계 밑에 `#이슈번호` 와 함께 남겨라.

---

## 두 상위 법칙

### 우회 금지 — 근본 층에서 고쳐라

- **#33 (역방향 신호).** folderview 와 table_plus 가 각각 `TooltipAnchor.pointer` 를
  하드코딩했고(table_plus 는 테마 dartdoc 에 "긴 ellipsized 셀엔 pointer 를 써라" 라고
  적기까지 했다), 그 사이 아무도 상류 이슈를 열지 않았다. 둘 이상의 소비처가 독립적으로
  같은 우회에 도달한 것 = 상류 기본값이 함정이라는 증거. 이 사실이 "`visibleChild` 를
  추가하고 기본값은 두자" 안을 기각하는 근거가 됐다.

- **#22 (계약을 결함으로 오진 금지).** 중첩 툴팁이 조상을 억제하는 건(`innermost wins`)
  결함이 아니라 #22 가 명시적으로 도입한 계약이다. table_plus 가 "셀 툴팁이 행 카드를
  죽인다"(`table_plus#88`) 를 들고 왔을 때 깨진 불변식은 *그쪽* 것이었다 — 그릴 게 없는
  툴팁을 지었다. 고칠 자리는 거기였고, 거기서 고쳤다. 계약을 결함으로 오진했다면 우회를
  없애는 대신 계약을 없앴을 것이다.

- **#38 (막(membrane) 전파).** 클립 walk 가 Flutter 3.13 을 요구해 이쪽 `environment`
  하한이 올라갔고, `^0.4.0` 은 0.4.2 를 이미 해석하므로 그 하한이 **하류로 그대로
  전파됐다**(`table_plus#69` 가 떠안았다). 의존성은 벽이 아니라 양방향으로 새는 막이다.

---

## Step 1 — 이슈 먼저 (실측 숫자·기각한 대안·부정 결과)

- **#30 (부정 결과는 조건과 함께).** `bare()` 의 투명 `Material` 이 `InkWell` splash 를
  잘못 클립한다는 우려를 철회하면서, *"단, `bare()` 에 padding 이 생기면 이 논리가
  깨진다"* 는 조건을 명시했다. 근거 없이 "여긴 문제 없다" 로 넘겼다면 다음 사람이 같은
  걱정을 반복했을 것이다.

- **#33 (하류 버그는 추정 말고 확인).** `flutter_table_plus` 에 같은 버그가 있다고
  적었으나 확인하니 없었다 — 셀 툴팁이 `Text(overflow: ellipsis)` 를 감싸 rect 가 컬럼
  폭을 못 넘는다. 2분이면 확인되고, 안 했다면 이슈에 틀린 후속 항목이 남았다.

---

## Step 2 — 추측 금지, spike 로 실측

- **0.4.2 (외부 사실도 조회).** "pub.dev 최신은 0.4.0" 이라는 *남이 써준 문장*을 검증
  없이 믿고 릴리스 전략을 얹었으나, `0.4.1` 은 이미 발행돼 있었다. `curl
  https://pub.dev/api/packages/just_tooltip` 한 번이면 됐다.

- **#31 (PR·이슈 본문의 근거도 실측 대상).** `surface: false` 를 "화살표인데 칠할
  배경이 없는 모순" 으로 기각했으나, `tooltip_shape_painter.dart:59-73` 은 fill 후
  stroke 한다 — 투명 배경 + `borderColor` = 정당한 외곽선 툴팁. 코멘트로 정정했다. 틀린
  근거가 리포 기록에 남으면 나중에 그걸 믿고 판단한다.

---

## Step 3 — 설계 판단은 코드 전에 확정 (결정 유형으로 라우팅)

- **#34 (순수 메커니즘 → 직접 결정).** `describeApproximatePaintClip` 이 *부모*
  좌표계로 반환한다는 사실은 `rendering/object.dart:3598` 주석("Returns a rect in
  **this object's** coordinate system")에, viewport 가 파라미터를 `RenderSliver` 로
  좁힌다는 사실은 `rendering/viewport.dart:738` 에 있었다. 둘 다 소스로 도출 가능 —
  반대로 알면 최소 재현에서는 통과하고 실제 트리에서만 어긋난다.

- **#35 (계약·정책 → 묻는다).** "child 가 완전히 클립되면 숨길 것인가 경계에 붙일
  것인가" 는 red 테스트를 쓰기 *전에* 정해야 했다.

---

## Step 4 — /tdd RED→GREEN 수직 슬라이스

- **#35 (관찰 지점 설계).** 리사이즈 추적 테스트가 **추가 코드 없이** 통과했다 —
  `ScrollNotification` 구독을 기각하고 post-frame 콜백을 고른 판단의 증거. "스크롤" 이
  아니라 "child 가 움직이면" 으로 짰기에 리사이즈·애니메이션·리플로가 공짜로 따라온다.

- **#35 (테스트가 도메인을 가르치면 CONTEXT.md 에).** 그 테스트 초안이 hover 로 툴팁을
  띄웠다가 실패했는데, 버그가 아니라 도메인 사실이었다 — 창이 줄면 child 가 멈춘 커서
  밑에서 빠져나가고 Flutter 가 레이아웃 후 히트테스트를 다시 돌려 `onExit` 을 쏜다.

---

## Step 5 — 테스트 신뢰 게이트 (구분력 + 옳은 이유)

- **#34 (구분력).** 클립 로직을 끄면 `450.0`, transform 을 되돌리면 `50.0` — 다섯
  테스트 각각의 구분력을 확인했다. 통과하는 테스트는 그 자체로 아무것도 증명하지 않는다.

- **#39 (옳은 이유로 통과).** `findsOneWidget` 이 참이었으나 그 참을 만든 건 `forward()`
  가 `0.0` 에 걸린 `reverse()` 를 덮은 **순서 사고**였다. `onHide` 미호출까지 단언하고서야
  추적 사망 버그가 드러났다.

- **#37 (헤더 주석은 사양 — 보여줄 수 있는 것만 약속).** spike 에 "스크롤하면
  재조준되는 걸 보라" 를 쓸 뻔했으나, 행이 뷰포트를 항상 덮어 `행 ∩ 클립` 이 상수다
  (offset 0/1000/2600 모두 툴팁 중심 `200.0`).

---

## Step 7 — 하류 실검증 (pubspec_overrides.yaml)

- **#34 (하류가 박제한 버그가 깨지는 게 최강 증거).** folderview 의
  `tooltip_offscreen_test.dart`(`"with the default anchor the tooltip is painted
  outside the view"`)가 `Expected: > 400.0 / Actual: 170.0` 으로 실패했고, 나머지 148
  개는 통과 = 회귀 없음.

---

## Step 8 — 정합성 스윕

- **#38 (`environment` 하한은 아무도 안 잡아준다).** `flutter: ">=3.10.0"` 을 선언한 채
  `RenderObject? get parent`(3.13+)를 썼다. `flutter analyze` 는 설치된 SDK 로만
  검사하고 pub.dev 는 하한에서 빌드하지 않는다.

- **#37 (public dartdoc 이 마지막까지 버그를 계약으로 기술).** 코드가 고쳐진 뒤에도
  `TooltipAnchor.child` 의 dartdoc 이 버그를 계약으로 기술하고 있었다.

- **#33 (용어집 갱신 누락).** Anchor 의 정의를 바꿔놓고 `CONTEXT.md` 용어집을 갱신하지
  않아 한 릴리스 내내 "child 의 rect" 라고 말하고 있었다.

- **낡은 근거 회수.** `0.4.1` CHANGELOG 가 클립된 `show()` 를 거부하지 않는 이유로
  *"이미 떠 있는 툴팁은 child 가 나가도 남으니까"* 를 들었는데, #36 이 추적으로 숨기게
  만들면서 거짓이 됐다. 살아남는 근거는 전이 규칙(*가진 적 없는 대상을 잃을 수는 없다*).

---

## Step 9 — 게이트 & PR & 릴리스

- **#48→#49 (스택 PR + `--delete-branch` 금지).** 삭제를 머지에 묶어 자식 PR 이
  CLOSED 됐다. 지워진 base 를 원본 SHA 로 원격에 복원 → reopen → `--base main` →
  `git rebase --onto origin/main <옛 base head>` → force-push → 임시 브랜치 재삭제로 겨우
  풀었다. 안전한 순서는 머지와 삭제를 둘로 나누는 것.

- **#33 (blast radius = 도달 범위 × 변화 크기 → patch).** viewport 는 오버플로 여부와
  무관하게 클립을 보고하므로(`viewport.dart:744-753`) 모든 `ListView` 안 툴팁이 도달
  범위지만, 움직임은 언제나 "보이는 쪽" 이라 *올바른 위치는 하나도 안 망가진다* → minor
  가 아니라 patch. (0.x 대역에서 `^0.4.0` 은 `0.5.0` 을 허용 안 하므로 버그 수정을
  minor 로 내면 아무에게도 도달 못 한다.)

---

## Step 10 — 하류 마이그레이션

- **소비처 (2026-07 기준):** `flutter_folderview`, `flutter_table_plus`,
  `flutter_password_input`. (도출: `for d in ../*/; do grep -l '^  just_tooltip:'
  "$d/pubspec.yaml"; done`)

- **여전히 옳은 우회는 남긴다.** 행 툴팁의 `TooltipAnchor.pointer` 는 버그 회피가 아니라
  "커서 옆을 가리킨다" 는 본래 의도다 — 제거하지 말고 이유를 주석에 남긴다.
