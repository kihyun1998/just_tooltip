# thegraph — just_tooltip

## What this project is

Flutter 툴팁 패키지(pub.dev `just_tooltip`) — 정체성이 경계인 코어. 툴팁 엔진이고,
소비처의 관심사를 흡수하지 *않음*으로써 옳게 남는다.

## References

| Source | Informs | Reached by | Binding |
|---|---|---|---|
| Flutter SDK `rendering/` | how it works | `~/development/flutter/packages/flutter/lib/src/rendering/` — git 체크아웃, raw | **binding** |
| Flutter `widgets/raw_tooltip.dart` (+ `material/tooltip.dart` 는 얇은 Material 껍데기) | how it works | 같은 체크아웃 — raw | example |
| `super_tooltip` | how it works | `github.com/bensonarafat/super_tooltip` — raw 트리 | example |
| `flutter_portal` | how it works | `github.com/fzyzcjy/flutter_portal` — raw 트리 | example |
| `el_tooltip` | how it works | `github.com/marcelogil/el_tooltip` — raw 트리 | example |
| 위 패키지들의 `lib/src/` 배치 | where files go | 같은 트리 — raw | example |

**Visible Rect(조상 클립 walk)는 위 서드파티 패키지 중 아무도 안 한다** — 확인함
(`describeApproximatePaintClip` 히트 0, `material/tooltip.dart` 포함). 유일한 구현처는
Flutter `rendering/`. peer 쪽으로 맞추는 것은 수정이 아니라 메커니즘 삭제다.

## 증명 · 게이트 · 릴리스

은퇴한 `theflow` 바인딩에서 건져온 것(git history 참조) — 이 repo 가 실제 결함으로 배웠고, 다른 어떤 파일도
적지 않는다.

- **증명은 소비처 왕복이 가장 강하다.** 소비처 repo 에 `dependency_overrides` 로 로컬 빌드를
  임시로 물려(`pubspec.yaml` 은 안 건드린다) 전체 스위트를 돌린다. 최강 증거 = 소비처가 버그를
  기대값으로 박제한 테스트가 *깨지는 것*; 나머지 통과 = 회귀 없음. 끝나면
  `pubspec_overrides.yaml` 과 `flutter pub get` 이 만든 생성 파일을 되돌린다.
  **합성 in-repo 재현은 *상상한 트리*에서만 통과한다** (#34).
- **CI 가 안 돌리는 게이트 — 발행 전 손수.** `cd example && flutter analyze`,
  `flutter pub publish --dry-run`(경고 0). CI(`.github/workflows/ci.yml`, 실제 소스)는 Flutter
  **3.41.9 핀**이라 `environment` 하한(3.13)에서 **빌드하지 않는다** — 새 SDK API 를 쓰면
  하한을 손수 올리고 확인한다. `flutter analyze` 도 pub.dev 도 안 잡아준다 (#38).
- **`flutter pub publish` 는 되돌릴 수 없다(retract 만). 에이전트가 실행하지 않는다 — 사용자가 직접.**
- **0.x 대역에서 `^0.4.0` 은 `0.5.0` 을 허용 안 한다** — 버그 수정을 minor 로 내면 아무에게도
  도달 못 한다. blast radius = 도달 범위 × 변화 크기; 넓어도 "언제나 옳은 쪽으로만 움직임"
  이면 patch (#33).
- **스택 PR 은 `--delete-branch` 를 머지 호출에 묶지 마라** — 자식 PR 이 CLOSED 된다 (#48→#49).
  순서: `gh pr merge <아래> --squash` → 자식이 main 으로 옮겨진 것 확인 → *그 다음* 삭제.
