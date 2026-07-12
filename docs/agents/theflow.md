# theflow bindings — just_tooltip

`theflow` 스킬(kihyun-skills)이 런타임에 읽는 **이 repo 전용 값**. 스킬은 *method*(프로젝트
불문), 이 파일은 *bindings*(프로젝트 고유). 스킬의 각 스텝이 참조하는 구체값 — 모듈 맵,
레퍼런스 소스, 경계 규칙, 증명 방법, 게이트, 소비처 — 이 여기 산다.

just_tooltip 은 theflow 의 대상 그 자체다: **정체성이 경계인 코어**(툴팁 엔진) — 소비처의
관심사(hover 정책·배치 선택·테마·콘텐츠)를 흡수하지 *않음*으로써 옳게 남는다.

---

## Crate / module map

단일 Flutter 패키지(워크스페이스 아님). 공개 표면은 `lib/just_tooltip.dart` 배럴.

| 모듈 (`lib/src/`) | 역할 | 공개? |
|---|---|---|
| `just_tooltip.dart` | 위젯 (진입점) | ✅ 공개 |
| `just_tooltip_controller.dart` | attach 기반 컨트롤러 (ADR-0002, ChangeNotifier 아님) | ✅ 공개 |
| `enums.dart` | `TooltipAnchor`·`TooltipAlignment`·`TooltipDirection` — **dartdoc 이 pub.dev API 문서로 나감** | ✅ 공개 |
| `just_tooltip_theme.dart` | 테마 (소비처가 주입하는 정책) | ✅ 공개 |
| `tooltip_visibility_scheduler.dart` | *언제* 보일지 — wall-clock 타이머, intent (ADR-0001) | 내부 |
| `tooltip_registry.dart` | at-most-one-visible + **중첩 억제(innermost wins, #22 계약)** | 내부 |
| `tooltip_position_utils.dart` | position delegate + **Visible Rect 클립 walk** | 내부 |
| `just_tooltip_overlay.dart` | overlay entry (position·config 를 build 마다 resolve) | 내부 |
| `tooltip_transitions.dart` | fade/scale 애니메이션 | 내부 |
| `tooltip_shape_painter.dart` | **fill 후 stroke** (투명 배경 + borderColor = 외곽선, #31) | 내부 |

용어의 source of truth 는 `CONTEXT.md` 용어집(Visibility Scheduler / Hover Bridge / Anchor /
Visible Rect / Target Tracking / Hover Intent / Content) + `docs/adr/0001–0004`.

## Step 1 — reference routing table

변경 유형별로 *어느 실제 소스*를 읽는가:

| 변경 유형 | 레퍼런스 소스 |
|---|---|
| 렌더/클립/좌표계 | Flutter SDK: `/d/flutter/packages/flutter/lib/src/rendering/` (예: `object.dart` `describeApproximatePaintClip` — *부모* 좌표계 반환; `viewport.dart` — 파라미터를 `RenderSliver` 로 좁힘) |
| hover/pointer 의미 | Flutter SDK: `widgets/` `MouseRegion`, `gestures/` — edge(`onEnter`/`onExit`) vs state |
| API 도입 버전 | `cd /d/flutter && git log -S "<시그니처>"` → `git tag --contains <sha>` |
| 하류 버그 주장 | **소비처 repo 를 직접 확인** (`../flutter_table_plus`, `../flutter_folderview`, `../flutter_password_input`) — 있으리라 추정 금지 (#33) |
| 도메인 숨은 상태 | `CONTEXT.md` 용어집 — 테스트가 새 도메인 사실을 가르치면 여기 추가 (예: 리사이즈 시 `onExit`) |
| 외부 사실 | pub.dev: `curl https://pub.dev/api/packages/just_tooltip` |

## Step 2 — boundary rule

- **메커니즘(코어 = just_tooltip 소유):** Visible Rect 계산(클립 walk), position delegate,
  anchor freezing, Target Tracking(per-frame 재조준), 중첩 억제(innermost wins), Hover Intent
  파생, 스케줄러 타이밍, shape painting. — *전체 트리/상태를 손에 쥐어야만 옳은* 것들.
- **정책(소비처가 주입):** anchor 선택(`child` vs `pointer`), 테마 값, `controller.show()` 호출
  시점, `message`/`tooltipBuilder`, hover 활성 여부.
- **소비처가 정의상 소유:** 배치 *선택*, 콘텐츠, 언제 띄울지. 이건 우회가 아니라 경계다.
- **계약 ≠ 결함 (핵심 함정):** 중첩 툴팁이 조상을 억제하는 것(innermost wins)과, *그릴
  Content 가 없는* 툴팁은 Hover Intent 가 없어 안 뜨는 것 — 둘 다 #22 가 도입한 **계약**이다.
  소비처가 "셀 툴팁이 행 카드를 죽인다"(`table_plus#88`)를 들고 왔을 때 깨진 불변식은
  그쪽 것이었다(그릴 게 없는 툴팁을 지음). 이걸 결함으로 오진하면 우회가 아니라 계약을 지운다.

## Step 4 — proof method per layer

- **순수 로직**(scheduler, position utils, registry): 공개 seam 에서 관찰하는 widget/unit
  테스트 — pump 후 렌더 결과, private 멤버 직접 접근 금지.
- **실제 round-trip (가장 강한 증명):** 소비처에 로컬 빌드를 물려 **전체 스위트**를 돌린다.

  ```yaml
  # 소비처 repo 에 임시로 두고, 검증 후 삭제 (pubspec.yaml 은 안 건드린다)
  dependency_overrides:
    just_tooltip:
      path: ../just_tooltip
  ```

  가장 강한 증거 = 소비처가 버그를 기대값으로 박제한 테스트가 *깨지는 것*(예: folderview
  `tooltip_offscreen_test.dart`). 나머지 스위트 통과 = 회귀 없음. 끝나면 `pubspec_overrides.yaml`
  과 `flutter pub get` 이 건드린 생성 파일(`example/*/generated_plugin_*`)을 되돌린다.
- **함정:** 합성 in-repo 재현은 *상상한 트리*에서만 통과한다 — 실제 소비처 트리는 다를 수
  있다(#34: 부모-좌표계 버그가 최소 재현은 통과, 실제 트리에서만 어긋남).

## Step 6 — behavior-describing surfaces

동작을 바꾸면 아래가 전부 drift 한다. 아무도 컴파일로 안 잡아준다:

- **public dartdoc** — `enums.dart`·위젯 필드·컨트롤러의 `///` → pub.dev API 문서로 그대로.
  가장 늦게까지 옛 동작을 계약으로 기술하기 쉬움(#37).
- **`CHANGELOG.md`** — pub.dev 는 발행 시점 스냅샷. 발행된 항목 고치지 말고 새 버전을 연다.
- **`README.md`** — `## Migration to X.Y.Z` 섹션(관례), `## Install` 버전 예시.
- **`CONTEXT.md` 용어집 + `docs/adr/`** — 도메인 용어 정의를 바꿨으면 같은 변경에서 갱신(#33).
- **`example/` + spike 헤더 주석** — 사양이다. 보여줄 수 있는 것만 약속.
- **`pubspec.yaml` `environment` 하한** — 새 SDK API 쓰면 도입 버전으로 올린다. `flutter
  analyze`(설치 SDK)·pub.dev 둘 다 안 잡음(#38: `>=3.10.0` 선언 채 `RenderObject? get parent` 3.13+ 사용).
- **낡은 근거 회수** — 연속 PR 에서 앞 PR·CHANGELOG·이슈 근거가 뒤 PR 로 거짓이 됨. 명시 훑기.

## Step 7 — gate matrix + release + downstream loop

**게이트 (전부 통과):**

```
flutter test
flutter analyze
dart format --set-exit-if-changed lib/ test/
cd example && flutter analyze
flutter pub publish --dry-run      # 경고 0개
```

**브랜치/PR:** `fix(<scope>): … (#issue)` → squash PR(`Closes #issue`) → CI 그린 → 머지.
**스택 PR 은 `--delete-branch` 를 머지 호출에 묶지 마라** — 자식 PR 이 CLOSED 된다(#48→#49).
안전 순서: `gh pr merge <아래> --squash` → 자식이 main 으로 옮겨진 것 확인 → *그 다음* 삭제.

**릴리스 판단:**
- 발행 전 pub.dev 실제 상태 조회(로컬 `version:` 이 이미 발행된 번호일 수 있음).
- blast radius = *도달 범위* × *변화 크기*. 도달 범위가 넓어도 "언제나 옳은 쪽으로만 움직임"
  이면 patch(#33).
- **0.x 대역 `^0.4.0` 은 `0.5.0` 을 허용 안 함** — 버그 수정을 minor 로 내면 아무에게도 도달 못 함.
- **`flutter pub publish` 는 되돌릴 수 없다(retract 만). 에이전트가 실행하지 않는다 — 사용자가 직접.**

**하류 루프 닫기 (발행 후):** 소비처는 추정 말고 도출 —
`for d in ../*/; do grep -l '^  just_tooltip:' "$d/pubspec.yaml"; done`.
현재: `flutter_folderview`, `flutter_table_plus`, `flutter_password_input`. 각 소비처에서
① 제약을 새 버전으로 올림 ② 불필요해진 우회 제거 ③ 버그 박제 테스트 뒤집기(Step 4 에서 깨진 것)
④ *여전히 옳은* 우회는 이유를 주석에 남김 — 예: 행 툴팁 `TooltipAnchor.pointer` 는 버그
회피가 아니라 "커서 옆을 가리킨다" 는 본래 의도. 순수 추가 릴리스는 하류가 아무것도 안 해도 됨(명시).

## War-story index

각 규칙이 실제 결함을 잡은 실증(#22, #30–#39, #48)은 **[`lessons.md`](lessons.md)** 에
단계 번호로 색인돼 있다. 규칙이 추상으로 읽히지 않게 하는 근거 — 착수 전에 읽어라.
