# blogman 프로젝트 게시글 초안

## 공통

### slug 추천
- `just-tooltip`
- `just-tooltip-flutter`
- `flutter-just-tooltip`

### 기술스택
Flutter, Dart

### 링크
| type | url | label |
|------|-----|-------|
| github | https://github.com/kihyun1998/just_tooltip | GitHub |
| website | https://pub.dev/packages/just_tooltip | pub.dev |

### 카테고리
미지정

---

## 한국어 버전 (language: ko)

### title
just_tooltip

### description
20가지 배치 조합과 화살표, 뷰포트 자동 보정을 지원하는 경량 Flutter 툴팁 위젯

### content

## 개요

just_tooltip은 Flutter에서 사용할 수 있는 경량 커스터마이징 툴팁 위젯입니다. 방향(top/bottom/left/right) 4가지와 정렬(start/center/end/startTargetCenter/endTargetCenter) 5가지를 조합하여 총 20가지 배치를 지원하며, 화살표 인디케이터, 뷰포트 자동 보정, 프로그래밍 방식의 제어까지 갖추고 있습니다.

Flutter 기본 Tooltip 위젯의 제한적인 위치 지정과 커스터마이징의 불편함을 해결하기 위해 만들어졌습니다.

## 주요 기능

- **20가지 배치 조합** — 4방향 × 5정렬로 세밀한 위치 지정
- **재사용 가능한 테마** — `JustTooltipTheme`으로 스타일링을 그룹화하고 `copyWith()`로 파생
- **화살표 인디케이터** — 툴팁 본체와 통합된 형태로 렌더링되어 배경, 그림자, 테두리가 자연스럽게 이어짐
- **뷰포트 오버플로우 보호** — 공간이 부족하면 자동으로 반대 방향으로 플립하고 위치를 클램핑
- **호버 & 탭 트리거** — 독립적으로 토글 가능
- **인터랙티브 모드** — 툴팁 위에 마우스를 올려도 사라지지 않음
- **프로그래밍 제어** — `JustTooltipController`로 show/hide/toggle
- **7가지 애니메이션** — none, fade, scale, slide, fadeScale, fadeSlide, rotation
- **RTL 지원** — top/bottom 방향에서 start/end가 자동 반전
- **싱글 인스턴스** — 한 번에 하나의 툴팁만 표시

## 지원 플랫폼

Android, iOS, Web, macOS, Windows, Linux — 6개 플랫폼 모두 지원합니다.

## 기술적 특징

- **외부 의존성 없음** — Flutter SDK만으로 구현되어 추가 패키지 설치가 불필요합니다. 최소 Flutter 3.10.0, Dart 3.0.0을 요구합니다.
- **통합 Shape 렌더링** — 화살표와 툴팁 본체를 하나의 `CustomPainter` 경로로 그려 테두리와 그림자가 자연스럽게 연결됩니다.
- **테마 객체 분리** — 12개의 시각적 파라미터를 `JustTooltipTheme` 데이터 클래스로 묶어 재사용성과 `==`/`hashCode` 비교를 지원합니다.
- **뷰포트 인식 배치** — Overlay 내에서 화면 경계를 계산하여 자동 플립 및 위치 클램핑을 수행합니다.
- **startTargetCenter / endTargetCenter 정렬** — 화살표가 타겟 위젯의 중심을 동적으로 추적하여, 툴팁이 타겟보다 넓을 때도 정확한 포인팅이 가능합니다.

---

## 영어 버전 (language: en)

### title
just_tooltip

### description
Lightweight Flutter tooltip with 20 placement combos, arrow indicator, and viewport-aware auto-flipping

### content

## Overview

just_tooltip is a lightweight, customizable tooltip widget for Flutter. It combines 4 directions (top/bottom/left/right) with 5 alignments (start/center/end/startTargetCenter/endTargetCenter) for 20 positioning combinations, complete with arrow indicators, viewport-aware auto-flipping, and programmatic control.

It was built to address the limited positioning options and customization constraints of Flutter's built-in Tooltip widget.

## Key Features

- **20 positioning combinations** — 4 directions × 5 alignments for precise placement
- **Reusable theme** — group all styling in `JustTooltipTheme` with `copyWith()` derivation
- **Arrow indicator** — rendered as a unified shape with the tooltip body, so background, shadow, and border follow the combined outline
- **Viewport overflow protection** — auto-flips direction and clamps position when space is insufficient
- **Hover & tap triggers** — independently toggleable
- **Interactive mode** — tooltip stays visible while hovering over its content
- **Programmatic control** — show/hide/toggle via `JustTooltipController`
- **7 animation types** — none, fade, scale, slide, fadeScale, fadeSlide, rotation
- **RTL support** — start/end automatically swapped for top/bottom directions
- **Single instance** — only one tooltip visible at a time

## Supported Platforms

Android, iOS, Web, macOS, Windows, Linux — all 6 platforms are supported.

## Technical Highlights

- **Zero external dependencies** — built entirely with the Flutter SDK, requiring no additional packages. Minimum Flutter 3.10.0 and Dart 3.0.0.
- **Unified shape rendering** — the arrow and tooltip body are drawn as a single `CustomPainter` path, ensuring borders and shadows flow seamlessly.
- **Theme object separation** — 12 visual parameters are encapsulated in a `JustTooltipTheme` data class with `==`/`hashCode` support for reusability.
- **Viewport-aware positioning** — calculates screen boundaries within the Overlay to perform auto-flipping and position clamping.
- **startTargetCenter / endTargetCenter alignment** — the arrow dynamically tracks the target widget's center, enabling accurate pointing even when the tooltip is wider than the target.
