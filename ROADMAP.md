# 면접도우미 로드맵

이 문서는 MVP 이후의 개발 방향을 정리합니다. 우선순위와 일정은 피드백에 따라 조정될 수 있습니다.

## 현재 상태 (v1.1)

**Phase 0~4와 v1.1 확장 기능(자유 연습·면접 일정·모의면접 기록·About)까지 구현 완료.** 다음 초점은 Phase 5(품질·배포)입니다.

### 완료된 항목

- [x] 온보딩 — 회사/직무/채용공고/이력서/자소서 입력·저장
- [x] **다중 프로필** — 추가·수정·삭제·전환 (`ActiveProfileStore`, `ProfileManagementView`)
- [x] PDF·이미지 첨부 및 텍스트 추출 (PDFKit + Vision OCR)
- [x] Foundation Models 텍스트 다듬기 + 가드레일 fallback
- [x] 채용공고 필수 섹션 검증
- [x] 서류 기반 면접 질문 생성 (Foundation Models + fallback)
- [x] 질문 풀 선생성 및 세션 시작 시간 최적화 (갓·숙련·전문 단계별)
- [x] PreSession → Session → PostSession 상태 머신
- [x] 카메라 프리뷰·세션 녹화·질문별 세그먼트
- [x] 면접관 TTS + 타이머 워크플로우
- [x] 사후 STT + 필러 워드 분석 + AI 피드백
- [x] **다차원 점수·등급** — 발화·내용·자세 100점, 종합 S~F 등급
- [x] Vision 기반 자세·응시 분석 (세션 종료 후 영상 배치 분석)
- [x] 프로필별 연습 추이 차트 (날짜·회차)
- [x] 세션 다시보기 (질문별 seek)
- [x] 갓 연습 단계 인윈도우 프롬프터
- [x] **Phase 4 — 실시간 코치** (아래 참고)
- [x] **Phase 2 — 숙련 단계** (아래 참고)
- [x] **Phase 3 — 전문 단계** (아래 참고)
- [x] **자유 연습** — 항목 다중 선택, 문항별·종합 피드백, 이직 사유 항목 (아래 참고)
- [x] **면접 일정** — D-Day 카운트다운, 준비 팁, 로컬 알림 (아래 참고)
- [x] **모의면접 기록** — 홈 요약 카드, 히스토리 시트 (아래 참고)
- [x] **About** — 시스템 메뉴 About 창, GitHub·개인정보처리방침·연락처 링크
- [x] **Release entitlements** — App Store 샌드박스·알림 권한
- [x] **CI** — GitHub Actions 단위·UI 테스트 (`macos-26`)

### 알려진 제한

- 프로필별 질문 풀·세션은 분리되어 있으나, 프로필 간 이력서/자소서 **공유 복사** 기능은 없음
- 실시간 코치·HUD는 **갓 연습(beginner)** 세션에 최적화 — 숙련·전문 단계는 코치·HUD 기본 off, 프롬프터 힌트 축소
- Foundation Models 미지원 환경에서는 규칙 기반 fallback 질문·피드백 사용

---

## Phase 4 — 실시간 피드백 & 프롬프터 ✅

**목표:** 답변 중에도 보조 정보를 제공하되, 실전 부정행위 방지 설계 유지

### 기능

- [x] 실시간 STT — 답변 중 키워드 커버리지 표시 (`StreamingSpeechRecognizer`, `KeywordCoverageTracker`)
- [x] NSPanel HUD 프롬프터 — 별도 플로팅 창 (갓 연습 전용, 토글)
- [x] 필러 워드 실시간 카운트 (경고만, 세션 중단 없음)
- [x] 실시간 시선 HUD (Vision) — 세션 중 응시 비율 표시
- [x] 코치 힌트 오버레이 — 카메라 하단 반투명 뷰, 토글 on/off
- [x] 트리거 — 무음 4초+, 시선 이탈 2초+, 필러 급증, 키워드 미커버리지

### 기술 과제

- [x] `StreamingSpeechRecognizer` 스트리밍 모드 + MainActor 브릿지 (`SessionCoachMonitor`)
- [x] NSPanel + SwiftUI 호스팅 (`PrompterHUDController`)
- [x] 실시간 Vision `FaceGazeEstimator` 파이프라인 (`LiveGazeMonitor`, `CameraManager` 샘플 핸들러)
- [x] 오디오 RMS 무음 감지 (`AudioLevelMonitor`)
- [ ] 성능 프로파일링 — 저사양 Mac에서 STT·Vision 동시 실행 부하 튜닝

> **사후 분석:** 세션 종료 후 Vision·점수화 (`SegmentVisionAnalyzer`, `PostureScorer`) — 별도 완료

---

## Phase 2 — 숙련 단계 ✅

**목표:** 서류 기반 질문에 더해 꼬리질문·인성·회사 관련 질문으로 난이도 상승

### 기능

- [x] `SessionStage.skilled` 활성화
- [x] 꼬리질문 생성 — 이전 답변 맥락을 반영한 follow-up (Foundation Models)
- [x] 인성/상황 질문 풀 (STAR 유도)
- [x] 지원 회사·산업 맞춤 질문 (채용공고 + 외부 지식 제한적 활용)
- [x] 단계별 질문 수·시간 구성 프리셋 (`SessionStagePreset`)
- [x] 숙련 단계 전용 피드백 기준 (구체성, 논리 구조)
- [x] 숙련 단계 코치 정책 — 프롬프터 축소, 코치·HUD 기본 off

### 기술 과제

- [x] 세션 중 답변 전사를 FM에 넘기는 경량 파이프라인 (`FollowUpQuestionGenerator`, `SessionCoachMonitor.consumeLastTranscript`)
- [x] 질문 풀을 단계별로 분리 (`CachedQuestion.stage` / `category`)
- [x] 숙련 단계 UI/UX — 프롬프터 힌트 축소, 코치 기본 off

---

## Phase 3 — 전문 단계 (실전 모드) ✅

**목표:** 면접관 페르소나·압박 질문·시간 압박 등 실전에 가까운 경험

### 기능

- [x] `SessionStage.expert` 활성화
- [x] 질문 카테고리 확장 (기술·인성·회사·압박·종합)
- [x] 가변 질문 수·시간 (사용자 설정 — `ExpertSessionSetupView`)
- [x] 세션 난이도·면접관 톤 설정 (`InterviewerTone` → TTS 속도·피치·준비 시간)
- [x] 약점 집중 훈련 모드 (`WeakTopicAnalyzer` + 설정 토글)

### 기술 과제

- [x] 세션 템플릿 시스템 — 프로필별 `ExpertSessionConfiguration` JSON 저장
- [x] 장기 학습 이력 — 반복 취약 주제 추적 (로컬 세션 `contentScore` 집계)

---

## v1.1 확장 — 자유 연습 ✅

**목표:** 구조화 단계와 별도로, 원하는 항목만 골라 집중 훈련

### 기능

- [x] `SessionStage.freePractice` — 홈에서 자유 연습 진입
- [x] 항목 다중 선택 (`PracticeTopic`, `practiceOrder` 고정 순서)
- [x] 문항 수 1~10 (기본 2), 라운드로빈 주제 배치
- [x] 이직 사유 전용 질문 (`careerChangeReason`)
- [x] 문항별 피드백 시트 + 종합 피드백 (`FreePracticeViewModel`)
- [x] 옵션 변경 디바운스 — 불필요한 질문 재생성 방지

---

## v1.1 확장 — 면접 일정 ✅

**목표:** 면접 D-Day 카운트다운과 준비 리마인더

### 기능

- [x] 프로필별 면접 일시 저장 (`CandidateProfile.interviewDate`)
- [x] 홈 카운트다운 카드·편집 시트 (`InterviewScheduleCard`, `InterviewScheduleEditorSheet`)
- [x] D-7~D-1 준비 팁 카드 (`InterviewPrepGuide`, `InterviewPrepTipsCard`)
- [x] 로컬 알림 — D-7~D-1 09:00, D-Day 06:00 (`InterviewNotificationScheduler`)
- [x] 프로필 관리 화면 D-Day 표시

---

## v1.1 확장 — 모의면접 기록 ✅

**목표:** 홈에서 연습 이력을 한눈에 보고 상세 기록으로 이동

### 기능

- [x] 프로필 세션 통계 집계 (`ProfileSessionStats`)
- [x] 홈 요약 카드 — 최근 점수·등급, 최근 3회 (`ProfileSessionSummaryCard`)
- [x] 히스토리 시트 — 차트 + 역대 세션 목록 (`ProfileSessionHistorySheet`)

---

## Phase 5 — 품질·배포

### 품질

- [x] GitHub Actions CI — 단위·UI 테스트 (`test.yml`)
- [ ] UI 테스트 E2E 시나리오 확대 (온보딩 → 세션 → 다시보기)
- [ ] SwiftData 버전 마이그레이션 전략 (`VersionedSchema`)
- [ ] 접근성 (VoiceOver, 키보드 내비게이션)
- [ ] 다국어 지원 검토 (현재 UI·질문 한국어 중심)

### 배포

- [x] Release entitlements
- [ ] 앱 아이콘·스크린샷·App Store 메타데이터
- [ ] TestFlight / Mac App Store 심사 대응
- [ ] 크래시·성능 모니터링 (옵션)

---

## 아키텍처 개선 (지속)

| 항목        | 설명                                                                 |
| ----------- | -------------------------------------------------------------------- |
| 질문 풀     | 단계·카테고리별 풀 분리, LRU 교체 정책                               |
| FM 가드레일 | 청크 분할·permissive transform·섹션 보존 fallback 고도화             |
| 테스트      | `QuestionPoolManager`, `QuestionGenerator` fallback 단위 테스트 확대 |
| 모듈화      | Core/Features 경계 유지, 재사용 가능한 InterviewEngine 추출 검토     |

---

## 우선순위 요약

```
[완료] MVP · 갓 연습
   ↓
[완료] Phase 4 — 실시간 STT, HUD, 시선·코치 힌트
   ↓
[완료] Phase 2 — 숙련 단계 질문·피드백
   ↓
[완료] Phase 3 — 전문/실전 모드
   ↓
[완료] v1.1 — 자유 연습, 면접 일정, 모의면접 기록, About
   ↓
[다음] Phase 5 — 배포·품질 고도화
```

피드백이나 우선순위 변경 제안은 [GitHub Issues](https://github.com/deblur99/InterviewTutor/issues)에 남겨 주세요.
