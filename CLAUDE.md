## 작업 규율 — `theflow`

Substantive 변경(버그 수정·기능 추가·동작 변경)은 **`theflow` 스킬**로 짠다(non-trivial
변경에 model-invoked). 이 repo 전용 바인딩 — 모듈 맵·레퍼런스 소스·경계 규칙·증명 방법·
게이트·소비처 — 은 **`docs/agents/theflow.md`** 에, 각 규칙이 실제 결함을 잡은 실증(#22,
#30–#39, #48 …)은 **`docs/agents/lessons.md`** 에 산다. 착수 전에 둘 다 읽고, 새 실증이
나오면 lessons 에 단계 번호와 함께 남긴다.

## 정체성 / 불변식 (경계)

just_tooltip 은 **정체성이 경계인 코어** — 툴팁 엔진이다. 소비처의 관심사를 흡수하지
*않음*으로써 옳게 남는다. theflow Step 2 의 경계 판단은 여기서 근거한다.

- **코어가 소유(메커니즘):** Visible Rect 계산(조상 클립 walk), position delegate, anchor
  freezing, Target Tracking(per-frame 재조준), 중첩 억제, Hover Intent 파생, 스케줄러 타이밍,
  shape painting — *전체 트리·상태를 쥐어야만 옳은* 것들.
- **소비처가 소유(정책):** anchor 선택(`child`/`pointer`), 테마 값, `show()` 시점, 콘텐츠,
  hover 활성. 이건 우회가 아니라 경계다.
- **계약(결함 아님):** `innermost wins`(중첩 시 안쪽이 조상 억제)와 *그릴 Content 없는 툴팁은
  안 뜸* — 둘 다 #22 가 도입한 계약이다. 하류가 이걸 "버그" 로 들고 와도 깨진 불변식은
  그쪽 것일 수 있다. 계약을 결함으로 오진하면 우회가 아니라 계약을 지운다. (ADR-0001–0004,
  `CONTEXT.md` 용어집이 source of truth.)

## Agent skills

- **Issue tracker** — 이 repo 의 GitHub Issues (`kihyun1998/just_tooltip`), `gh` CLI
  로 관리. 외부 PR 은 triage 대상이 아니다. `docs/agents/issue-tracker.md`.
- **Triage labels** — 다섯 canonical 역할의 기본 라벨 문자열(`needs-triage`,
  `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`).
  `docs/agents/triage-labels.md`.
- **Domain docs** — 단일 컨텍스트: repo 루트의 `CONTEXT.md` + `docs/adr/`.
  `docs/agents/domain.md`.
