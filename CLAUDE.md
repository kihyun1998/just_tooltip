## Agent skills

### Issue tracker

Issues live in this repo's GitHub Issues (`kihyun1998/just_tooltip`), managed via the `gh` CLI. External PRs are **not** a triage surface. See `docs/agents/issue-tracker.md`.

### Triage labels

The five canonical triage roles use their default label strings (`needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`). See `docs/agents/triage-labels.md`.

### Domain docs

Single-context layout: one `CONTEXT.md` + `docs/adr/` at the repo root. See `docs/agents/domain.md`.

## 우회 금지 (근본 층에서 고쳐라)

소비처에서 이 패키지의 결함을 발견하면 — 소비처에서 *덮지 마라*. 우회는 ① 상류 버그를 가려 고칠 압력을 없애고, ② 같은 지식을 두 층에 복제해 divergence 씨앗이 되고, ③ 상류의 잘못된 기본값을 영원히 기본값으로 남긴다. **우회하고 싶은 충동 = 멈추고 사용자에게 온다** — 무슨 상황인지 설명하고("상류가 X 를 이렇게 넘겨서 소비처가 Y 해야 통과, 근본은 상류 문제") 근본 수정 여부를 *묻는다*. 혼자 우회하지도, 혼자 이슈만 파고 넘어가지도 마라.

**역방향도 신호다: 둘 이상의 소비처가 *독립적으로 같은 우회*에 도달했다면, 그건 상류 API 의 기본값이 함정이라는 증거다.** 사람들이 올바른 옵션을 발견하는 게 아니라 버그를 발견하고 돌아간 것이다. 실증(#33): folderview 와 table_plus 가 각각 `TooltipAnchor.pointer` 를 하드코딩했고(table_plus 는 테마 dartdoc 에 "긴 ellipsized 셀엔 pointer 를 써라" 라고 적기까지 했다), 그 사이 아무도 상류 이슈를 열지 않았다. 이 사실이 "`visibleChild` 를 추가하고 기본값은 두자" 는 안을 기각하는 근거가 됐다.

## 작업 flow ("그 flow")

*Substantive 변경*(버그 수정·기능 추가·동작 변경)이면 이 10단계로 짠다. 단계를 *생략*하려면 (건너뛰는 게 아니라) *왜 이 변경엔 해당 없는지를 명시*한다 — 조용한 스킵 금지.

괄호 안 실증은 그 단계를 건너뛰었다면 놓쳤을 것이다. 전부 이 repo 에서 실제로 일어났다.

### 1. 이슈 먼저 — 실측 숫자·기각한 대안·부정 결과

측정한 숫자를 이슈에 박고, **기각한 대안과 그 이유**를 함께 적는다. 안 그러면 같은 대안이 다시 제안된다.

- **부정 결과도 조건과 함께 기록한다.** "여긴 문제 없다" 를 근거 없이 넘기면 다음 사람이 같은 걱정을 반복한다. 실증(#30): `bare()` 의 투명 `Material` 이 `InkWell` splash 를 잘못 클립한다는 우려를 철회하면서, *"단, `bare()` 에 padding 이 생기면 이 논리가 깨진다"* 는 조건을 명시했다.
- **하류에 같은 버그가 있으리라 추정하지 말고 확인한다.** 실증(#33): `flutter_table_plus` 에 있다고 적었으나 확인하니 없었다 — 셀 툴팁이 `Text(overflow: ellipsis)` 를 감싸 rect 가 컬럼 폭을 못 넘는다. 2분이면 확인되고, 안 했다면 이슈에 틀린 후속 항목이 남았다.

### 2. 추측 금지 — spike 로 실측한다

**코드를 *읽어서* 얻은 확신은 확신이 아니다.** 세 종류의 spike 로 사실을 박는다.

- **버리는 프로브 테스트** (`test/zz_*.dart`, 확인 후 삭제). 실제 rect·좌표·호출 순서를 `debugPrint` 로 뽑는다. 프로브는 버리되 **숫자는 이슈/PR 에 남긴다**.
- **Flutter SDK 소스를 직접 `grep`/`sed`** (`/d/flutter/packages/flutter/lib/src/…`). 기억·요약 금지. API 도입 버전은 `git log -S "<시그니처>"` + `git tag --contains` 로 찾는다.
- **외부 사실도 조회 대상이다.** pub.dev 상태는 `curl https://pub.dev/api/packages/just_tooltip`. 실증(0.4.2): "pub.dev 최신은 0.4.0" 이라는 *남이 써준 문장*을 검증 없이 믿고 릴리스 전략을 얹었으나, `0.4.1` 은 이미 발행돼 있었다.

**"확인 못 했다" ≠ "없다".** 미확인 사실은 갭이다. 이슈로 surfacing 하거나 사용자에게 묻는다 — 조용히 설계 가정으로 승격시키지 마라.

**PR·이슈 본문에 쓰는 근거도 실측 대상이다.** 틀린 근거가 리포 기록에 남으면 나중에 그걸 믿고 판단한다. 실증(#31): `surface: false` 를 "화살표인데 칠할 배경이 없는 모순" 으로 기각했으나, `tooltip_shape_painter.dart:59-73` 은 fill 후 stroke 한다 — 투명 배경 + `borderColor` = 정당한 외곽선 툴팁. 코멘트로 정정했다.

### 3. 설계 판단은 코드 전에 사용자와 확정

**TDD 는 "무엇이 옳은가" 를 답해주지 않는다.** 기대값을 발명하기 전에 정책을 못 박는다. *결정 유형으로 라우팅*한다.

- **순수 메커니즘**(좌표계·훅 선택·자료구조 — 소스로 도출 가능) → 직접 결정하고 **검증 결과만** 제시. 답이 코드에 있는 걸 묻는 건 일 떠넘기기다. 실증(#34): `describeApproximatePaintClip` 이 *부모* 좌표계로 반환한다는 사실은 `rendering/object.dart:3598` 주석("Returns a rect in **this object's** coordinate system")에 있었고, viewport 가 파라미터를 `RenderSliver` 로 좁힌다는 사실은 `rendering/viewport.dart:738` 에 있었다. 둘 다 반대로 알면 최소 재현에서는 통과하고 실제 트리에서만 어긋난다.
- **계약·정책**(테스트 seam, 폴백 동작, 공개 API 표면, 동작 변경 허용 여부) → **묻는다.** 실증(#35): "child 가 완전히 클립되면 숨길 것인가 경계에 붙일 것인가" 는 red 테스트를 쓰기 *전에* 정해야 했다.

### 4. `/tdd` 로 RED→GREEN 수직 슬라이스

한 번에 하나 — 테스트 하나 → 최소 구현 → 반복. **공개 seam 에서 관찰**하고 private 멤버를 직접 찌르지 않는다(위젯이면 pump 후 렌더 결과, 순수 모듈이면 반환값).

- 실증(#35): 리사이즈 추적 테스트가 **추가 코드 없이** 통과했다. 그게 `ScrollNotification` 구독을 기각하고 post-frame 콜백을 고른 판단의 증거다 — "스크롤" 이 아니라 "child 가 움직이면" 으로 짰기에 리사이즈·애니메이션·리플로가 공짜로 따라온다.
- 실증(#35): 그 테스트 초안이 hover 로 툴팁을 띄웠다가 실패했는데, 버그가 아니라 **도메인 사실**이었다 — 창이 줄면 child 가 멈춘 커서 밑에서 빠져나가고 Flutter 가 레이아웃 후 히트테스트를 다시 돌려 `onExit` 을 쏜다. 테스트가 도메인을 가르치면 `CONTEXT.md` 에 적는다.

### 5. 테스트 신뢰 게이트 — 두 질문은 다르다

- **구분력이 있는가.** 수정을 *일시적으로 끄고* 테스트가 실패하는지 확인한다. 통과하는 테스트는 그 자체로 아무것도 증명하지 않는다. 실증(#34): 클립 로직을 끄면 `450.0`, transform 을 되돌리면 `50.0` — 다섯 테스트 각각의 구분력을 확인했다.
- **옳은 이유로 통과하는가.** 부수 조건(콜백 미호출·위젯 수·애니메이션 상태)까지 단언해 우연한 순서로 통과할 수 없게 만든다. 실증(#39): `findsOneWidget` 이 참이었으나 그 참을 만든 건 `forward()` 가 `0.0` 에 걸린 `reverse()` 를 덮은 **순서 사고**였다. `onHide` 미호출까지 단언하고서야 추적 사망 버그가 드러났다.
- **예제·spike 의 헤더 주석은 사양이다.** 그 예제가 *실제로 보여줄 수 있는 것만* 약속한다. 실증(#37): spike 에 "스크롤하면 재조준되는 걸 보라" 를 쓸 뻔했으나, 행이 뷰포트를 항상 덮어 `행 ∩ 클립` 이 상수다(offset 0/1000/2600 모두 툴팁 중심 `200.0`).

### 6. `/code-review`

구현·테스트가 끝나고 하류 검증 전에 돌린다. 지적은 고치거나, 안 고치면 *왜 안 고치는지*를 남긴다.

### 7. 하류 실검증 (`pubspec_overrides.yaml`)

합성 재현이 통과하는 건 "내가 상상한 시나리오에서 동작한다" 일 뿐이다. 소비처 repo 에 로컬 경로를 물려 **전체 스위트**를 돌린다.

```yaml
# 소비처 repo 에 임시로 두고, 검증 후 지운다 (pubspec.yaml 은 안 건드린다)
dependency_overrides:
  just_tooltip:
    path: ../just_tooltip
```

**가장 강한 증거는 하류가 버그를 기대값으로 박제해둔 테스트가 *깨지는* 것이다** — 하류가 독립적으로 관찰해 고정한 증상이 사라졌다는 뜻이니까. 실증(#34): folderview 의 `tooltip_offscreen_test.dart`(`"with the default anchor the tooltip is painted outside the view"`)가 `Expected: > 400.0 / Actual: 170.0` 으로 실패했고, 나머지 148 개는 통과 = 회귀 없음.

끝나면 `pubspec_overrides.yaml` 을 지우고 `flutter pub get` 이 건드린 생성 파일(`example/*/generated_plugin_*`)도 되돌린다.

### 8. 정합성 스윕 — 동작을 기술하는 모든 표면

코드만 고치고 끝나는 변경은 없다.

- **`CHANGELOG.md`** — pub.dev 는 *발행 시점의* CHANGELOG 를 스냅샷으로 박는다. 이미 발행된 버전의 항목을 고치지 말고 새 버전을 연다. 리포와 pub.dev 가 같은 번호에 다른 내용을 주장하게 두지 마라.
- **`pubspec.yaml` 의 `environment` 하한** — 새 SDK API 를 쓰면 도입 버전을 찾아 올린다. **아무도 안 잡아준다**: `flutter analyze` 는 *설치된* SDK 로만 검사하고 pub.dev 는 하한에서 빌드하지 않는다. 실증(#38): `flutter: ">=3.10.0"` 을 선언한 채 `RenderObject? get parent`(3.13+)를 썼다.
- **`README.md`** — 동작 변경이면 `## Migration to X.Y.Z` 섹션(관례), `## Install` 의 버전 예시.
- **public dartdoc** — `enums.dart`·위젯 필드·컨트롤러의 `///` 는 **pub.dev API 문서로 그대로 나간다**. 실증(#37): 코드가 고쳐진 뒤에도 `TooltipAnchor.child` 의 dartdoc 이 *마지막까지 버그를 계약으로 기술*하고 있었다.
- **`example/` 과 spike 의 헤더 주석** (Step 5 참조).
- **`CONTEXT.md` 용어집 + `docs/adr/`** — 도메인 용어의 source of truth. 실증(#33): Anchor 의 정의를 바꿔놓고 용어집을 갱신하지 않아 한 릴리스 내내 "child 의 rect" 라고 말하고 있었다.
- **낡은 근거 회수** — 연속 PR 에서 앞선 PR·CHANGELOG·이슈에 적은 근거가 뒤 PR 에 의해 거짓이 된다. 아무도 안 보므로 명시적으로 훑는다. 실증: `0.4.1` CHANGELOG 가 클립된 `show()` 를 거부하지 않는 이유로 *"이미 떠 있는 툴팁은 child 가 나가도 남으니까"* 를 들었는데, #36 이 추적으로 숨기게 만들면서 거짓이 됐다. 살아남는 근거는 전이 규칙(*가진 적 없는 대상을 잃을 수는 없다*).

### 9. 게이트 & PR & 릴리스

게이트 전부: `flutter test` + `flutter analyze` + `dart format --set-exit-if-changed lib/ test/` + `cd example && flutter analyze` + `flutter pub publish --dry-run`(경고 0개).

브랜치 → `fix(<scope>): … (#issue)` → squash PR(`Closes #issue`) → CI 그린 확인 → 머지.

**버전 결정:**

- **발행 전 pub.dev 의 실제 상태를 조회한다**(Step 2). 로컬 `version:` 이 이미 발행된 번호일 수 있다.
- **동작 변경의 blast radius 를 *도달 범위*와 *변화 크기*로 나눠 재라.** 실증(#33): viewport 는 오버플로 여부와 무관하게 클립을 보고하므로(`viewport.dart:744-753`) 모든 `ListView` 안 툴팁이 도달 범위지만, 움직임은 언제나 "보이는 쪽" 이라 *올바른 위치는 하나도 안 망가진다* → minor 가 아니라 patch.
- **0.x 대역에서 `^0.4.0` 은 `0.5.0` 을 허용하지 않는다.** 버그 수정을 minor 로 내면 **아무에게도 도달하지 않는다** — semver 상 정직해 보이는 선택이 무용한 릴리스가 된다.
- **`flutter pub publish` 는 되돌릴 수 없고 pub.dev 는 버전 삭제가 없다(retract 만).** 에이전트가 실행하지 않는다 — 사용자가 직접.

### 10. 하류 마이그레이션 (발행 후, 이 repo 한정)

발행에서 끝내면 상류를 고쳐놓고도 하류는 영원히 우회를 들고 있는다. 소비처 목록은 추정하지 말고 도출한다 — `for d in ../*/; do grep -l '^  just_tooltip:' $d/pubspec.yaml; done`. 현재: `flutter_folderview`, `flutter_table_plus`, `flutter_password_input`. 각 소비처에서:

1. `pubspec.yaml` 의 제약을 새 버전으로 올린다.
2. **이제 불필요해진 우회를 제거한다** — 손수 중화한 테마 값, 상류 버그를 피하려 고른 옵션.
3. **버그를 기대값으로 박제한 테스트를 뒤집는다**(Step 7 에서 깨진 그 테스트).
4. 우회가 *여전히 옳은* 곳은 남기고 이유를 주석에 적는다 — 예: 행 툴팁의 `TooltipAnchor.pointer` 는 버그 회피가 아니라 "커서 옆을 가리킨다" 는 본래 의도다.

순수 추가(새 생성자·새 옵션)만 담은 릴리스는 하류가 아무것도 안 해도 된다 — 그 사실도 명시한다.
