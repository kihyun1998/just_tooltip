# just_tooltip - Flutter 커스텀 툴팁 패키지

## 왜 만들었는가

Flutter 기본 `Tooltip`은 간단한 텍스트 힌트 용도로는 괜찮지만, 실제 프로젝트에서 쓰다 보면 한계에 금방 부딪힌다.

- 툴팁이 위에만 뜨거나, 위치 제어가 사실상 불가능하다
- 화살표(arrow indicator)를 붙일 수 없다
- 호버와 탭을 독립적으로 제어할 수 없다
- 툴팁 위에 마우스를 올리면 바로 사라져서 인터랙티브한 콘텐츠를 넣을 수 없다
- 프로그래밍 방식으로 show/hide를 제어하기 어렵다

매번 `Overlay`와 `CompositedTransformFollower`를 직접 조합해서 만들기엔 반복이 너무 심하다. 그래서 이 모든 걸 하나의 위젯으로 정리한 패키지를 만들었다.

## 핵심 설계

### 위치 계산: CustomSingleChildLayout + LayoutDelegate

툴팁 위치 계산의 핵심은 `JustTooltipPositionDelegate`다. `SingleChildLayoutDelegate`를 상속하여 `getPositionForChild()`에서 다음 로직을 수행한다.

1. RTL 환경이면 start/end 정렬을 반전
2. 선호 방향에 공간이 있는지 `_hasSpace()`로 검사 → 부족하면 반대쪽으로 flip
3. 방향 + 정렬 조합으로 이상적인 좌표 계산
4. `screenMargin`을 고려하여 뷰포트 경계 안으로 clamp
5. `startTargetCenter`/`endTargetCenter`일 경우, clamp된 좌표 기준으로 화살표가 가리킬 타겟 중심 좌표를 콜백으로 전달

4가지 방향(top, bottom, left, right) x 5가지 정렬(start, center, end, startTargetCenter, endTargetCenter) = **20가지 조합**을 지원한다. `crossAxisOffset`까지 더하면 사실상 무한한 위치 조정이 가능하다.

### 화살표 렌더링: 통합 Path 방식

화살표를 별도 위젯으로 그리면 배경/테두리/그림자가 본체와 분리되어 어색해진다. `TooltipShapePainter`는 둥근 사각형(RRect)과 삼각형 화살표를 **하나의 Path**로 합쳐서 그린다.

`_tracePath()` 메서드가 시계 방향으로 RRect를 순회하면서, 지정된 변(top/bottom/left/right)에 도달하면 화살표 삼각형을 Path에 삽입한다. 이 하나의 Path로 `canvas.drawPath()`를 세 번 호출한다:

1. 그림자 (boxShadow 또는 elevation)
2. 배경 fill
3. 테두리 stroke

이 방식 덕분에 화살표까지 포함한 전체 외곽선에 테두리와 그림자가 자연스럽게 적용된다.

### 오버레이 관리: 단일 인스턴스

`_JustTooltipState`에 `static final Set<_JustTooltipState> _visibleInstances`를 두어, `_show()` 호출 시 기존에 열려 있는 다른 툴팁을 먼저 닫는다. 화면에 동시에 여러 툴팁이 뜨는 문제를 원천 차단한다.

### 애니메이션: 7가지 타입

`SingleTickerProviderStateMixin`으로 `AnimationController`를 하나 관리하고, `_buildAnimatedChild()`에서 `TooltipAnimation` enum에 따라 `FadeTransition`, `ScaleTransition`, `SlideTransition`, `RotationTransition`을 조합한다.

| 타입 | 구현 |
|------|------|
| `none` | 애니메이션 없이 즉시 표시 |
| `fade` | `FadeTransition` |
| `scale` | `ScaleTransition` |
| `slide` | `SlideTransition` (방향 자동 계산) |
| `fadeScale` | `FadeTransition` + `ScaleTransition` 중첩 |
| `fadeSlide` | `FadeTransition` + `SlideTransition` 중첩 |
| `rotation` | `FadeTransition` + `RotationTransition` 중첩 |

`animationCurve`를 지정하면 `CurvedAnimation`으로 감싸고, `fadeBegin`, `scaleBegin`, `slideOffset`, `rotationBegin` 파라미터로 시작값을 세밀하게 조정할 수 있다.

### 테마 시스템: JustTooltipTheme

12개의 시각적 속성(backgroundColor, borderRadius, padding, elevation, boxShadow, borderColor, borderWidth, textStyle, showArrow, arrowBaseWidth, arrowLength, arrowPositionRatio)을 `JustTooltipTheme` 데이터 클래스로 묶었다. `==`/`hashCode`를 구현하여 비교가 가능하고, `copyWith()`로 파생 테마를 만들 수 있다.

0.1.x에서는 이 속성들이 `JustTooltip` 위젯에 직접 있었는데, 0.2.0에서 테마 클래스로 분리했다. 하나의 테마 객체를 정의해두면 여러 툴팁에 재사용할 수 있어서 코드 중복이 줄어든다.

### 트리거 & 인터랙티브

호버(`MouseRegion`)와 탭(`GestureDetector`)을 `enableHover`, `enableTap` 플래그로 독립 제어한다. `build()` 메서드에서 플래그에 따라 래퍼 위젯을 조건부로 감싸는 구조다.

`interactive: true`일 때, 마우스가 대상 위젯을 벗어나면 100ms 타이머를 걸고, 그 사이에 툴팁 위로 마우스가 진입하면 타이머를 취소한다. `showDuration`과 조합되면 자동 숨김 타이머도 일시정지된다.

컨트롤러(`JustTooltipController`)는 `ChangeNotifier`를 상속하여 `show()`, `hide()`, `toggle()`을 제공한다. 호버 아웃이나 자동 숨김으로 툴팁이 닫힌 경우 `resetShouldShow()`로 내부 상태를 동기화하여, 이후 `show()` 호출이 정상 작동하도록 한다.

## 버전 히스토리

| 버전 | 변경사항 |
|------|---------|
| **0.1.0** | 핵심 구현 - 방향/정렬 12조합, 컨트롤러, 호버/탭 트리거, 페이드 애니메이션, 커스텀 콘텐츠, 단일 인스턴스 |
| **0.1.1** | `crossAxisOffset` 파라미터 추가 |
| **0.1.2** | `interactive`, `waitDuration`, `showDuration` 추가 |
| **0.1.3** | `boxShadow` 커스텀 그림자 지원 |
| **0.1.4** | interactive 모드에서 자동 숨김 타이머 일시정지 버그 수정 |
| **0.1.5** | 뷰포트 오버플로우 보호 (자동 flip + clamp), `screenMargin` 추가 |
| **0.1.6** | 화살표 통합 렌더링, `arrowBaseWidth`/`arrowLength`/`arrowPositionRatio`, 테두리 지원 |
| **0.1.7** | 컨트롤러 `show()` 재호출 버그 수정 |
| **0.2.0** | **Breaking** - 12개 스타일 속성을 `JustTooltipTheme`으로 분리, `copyWith()` 지원 |
| **0.2.1** | 7가지 애니메이션 타입 추가, 세부 파라미터 조정 지원 |
| **0.2.2** | Flutter 3.32 SDK 이름 충돌 수정 (`TooltipPositionDelegate` → `JustTooltipPositionDelegate`) |
| **0.2.3** | 화살표 없는 툴팁에서 `borderColor` 안 보이는 버그 수정 (`Material`이 `DecoratedBox` 테두리를 가림) |
| **0.2.4** | `hideOnEmptyMessage` 옵션 추가 (빈 메시지일 때 툴팁 억제) |
| **0.2.5** | `startTargetCenter`/`endTargetCenter` 정렬 추가 → 총 20가지 조합 |
