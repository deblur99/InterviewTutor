# 면접도우미 로드맵

이 문서는 MVP 이후의 개발 방향을 정리합니다. 우선순위와 일정은 피드백에 따라 조정될 수 있습니다.

## 현재 상태 (MVP · 1단계)

### 완료된 항목

- [x] 온보딩 — 회사/직무/채용공고/이력서/자소서 입력·저장
- [x] PDF·이미지 첨부 및 텍스트 추출 (PDFKit + Vision OCR)
- [x] Foundation Models 텍스트 다듬기 + 가드레일 fallback
- [x] 채용공고 필수 섹션 검증
- [x] 서류 기반 면접 질문 생성 (Foundation Models + fallback)
- [x] 질문 풀 선생성 및 세션 시작 시간 최적화
- [x] PreSession → Session → PostSession 상태 머신
- [x] 카메라 프리뷰·세션 녹화·질문별 세그먼트
- [x] 면접관 TTS + 타이머 워크플로우
- [x] 사후 STT + 필러 워드 분석 + AI 피드백
- [x] 세션 다시보기 (질문별 seek)
- [x] 갓 연습 단계 인윈도우 프롬프터

### 알려진 제한

- 2·3단계(숙련·전문) UI는 있으나 **비활성** 상태
- 실시간 STT 없음 — 답변 중 전사·피드백은 세션 종료 후
- 시선 추적(Vision) 미구현
- NSPanel 기반 HUD 프롬프터 미구현 — 현재는 세션 창 내 패널
- Foundation Models 미지원 환경에서는 규칙 기반 fallback 질문·피드백 사용

---

## Phase 2 — 숙련 단계

**목표:** 서류 기반 질문에 더해 꼬리질문·인성·회사 관련 질문으로 난이도 상승

### 기능

- [ ] `SessionStage.skilled` 활성화
- [ ] 꼬리질문 생성 — 이전 답변 맥락을 반영한 follow-up (Foundation Models)
- [ ] 인성/상황 질문 풀 (STAR 유도)
- [ ] 지원 회사·산업 맞춤 질문 (채용공고 + 외부 지식 제한적 활용)
- [ ] 단계별 질문 수·시간 구성 프리셋
- [ ] 숙련 단계 전용 피드백 기준 (구체성, 논리 구조)

### 기술 과제

- [ ] 세션 중 답변 요약을 FM에 넘기는 경량 파이프라인 (온디바이스, 지연 최소화)
- [ ] 질문 풀을 단계별로 분리 (`CachedQuestion`에 `stage` 메타데이터)
- [ ] 숙련 단계 UI/UX — 프롬프터 힌트 축소 또는 제거 옵션

---

## Phase 3 — 전문 단계 (실전 모드)

**목표:** 면접관 페르소나·압박 질문·시간 압박 등 실전에 가까운 경험

### 기능

- [ ] `SessionStage.expert` 활성화
- [ ] 질문 카테고리 확장 (기술·인성·회사·압박·종합)
- [ ] 가변 질문 수·시간 (사용자 설정)
- [ ] 세션 난이도·면접관 톤 설정
- [ ] 연속 세션 / 약점 집중 훈련 모드

### 기술 과제

- [ ] 세션 템플릿 시스템 (SwiftData 모델 확장)
- [ ] 장기 학습 이력 — 반복 취약 주제 추적 (로컬만)

---

## Phase 4 — 실시간 피드백 & 프롬프터

**목표:** 답변 중에도 보조 정보를 제공하되, 실전 부정행위 방지 설계 유지

### 기능

- [ ] 실시간 STT — 답변 중 키워드 커버리지 표시
- [ ] NSPanel HUD 프롬프터 — 별도 플로팅 창 (갓 연습 전용)
- [ ] 필러 워드 실시간 카운트 (경고만, 세션 중단 없음)
- [ ] 시선 추적 (Vision) — 카메라 응시 비율 리포트

### 기술 과제

- [ ] `SpeechRecognizer` 스트리밍 모드 + MainActor 브릿지
- [ ] NSPanel + SwiftUI 호스팅, 다중 디스플레이 대응
- [ ] Vision `VNDetectFaceLandmarksRequest` 기반 시선 휴리스틱
- [ ] 성능 — FM·STT·Vision 동시 실행 시 CPU/GPU 부하 관리

---

## Phase 5 — 품질·배포

### 품질

- [ ] UI 테스트 (온보딩 → 세션 → 다시보기 E2E)
- [ ] SwiftData 버전 마이그레이션 전략 (`VersionedSchema`)
- [ ] 접근성 (VoiceOver, 키보드 내비게이션)
- [ ] 다국어 지원 검토 (현재 UI·질문 한국어 중심)

### 배포

- [ ] 앱 아이콘·스크린샷·App Store 메타데이터
- [ ] TestFlight / Mac App Store 심사 대응
- [ ] 크래시·성능 모니터링 (옵션)

---

## 아키텍처 개선 (지속)

| 항목 | 설명 |
|------|------|
| 질문 풀 | 단계·카테고리별 풀 분리, LRU 교체 정책 |
| FM 가드레일 | 청크 분할·permissive transform·섹션 보존 fallback 고도화 |
| 테스트 | `QuestionPoolManager`, `QuestionGenerator` fallback 단위 테스트 확대 |
| 모듈화 | Core/Features 경계 유지, 재사용 가능한 InterviewEngine 추출 검토 |

---

## 우선순위 요약

```
[완료] MVP · 갓 연습
   ↓
[다음] Phase 2 — 숙련 단계 질문·피드백
   ↓
[이후] Phase 3 — 전문/실전 모드
   ↓
[병행] Phase 4 — 실시간 STT, HUD, 시선 추적
   ↓
[마무리] Phase 5 — 테스트·배포
```

피드백이나 우선순위 변경 제안은 [GitHub Issues](https://github.com/deblur99/InterviewTutor/issues)에 남겨 주세요.
