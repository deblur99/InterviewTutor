# 면접도우미 (InterviewTutor)

macOS용 화상면접 연습 앱입니다. 지원 회사·채용공고·이력서·자기소개서를 바탕으로 **온디바이스 AI**가 맞춤 질문을 생성하고, 카메라 녹화·TTS·타이머·사후 STT 분석·피드백·다시보기까지 한 번에 제공합니다.

> **현재 버전:** MVP + 숙련·전문 단계 (1~3단계)  
> **플랫폼:** macOS 26.0+  
> **개인정보:** Foundation Models, Speech, AVFoundation 등 Apple 온디바이스 API 중심 — 서버 전송 없음

## 주요 기능

### 온보딩 & 프로필
- **다중 프로필 관리** — 회사별 프로필 추가·수정·삭제·전환
- 지원 회사, 산업, 직무, 채용공고, 이력서, 자기소개서 입력
- 온보딩 완료 후 **다른 프로필 추가** 계속 진행 가능
- PDF·PNG·JPEG·HEIC 첨부 → PDFKit 텍스트 추출, 부족 시 Vision OCR (**이미지 다중 선택**, PDF는 1개)
- Foundation Models 기반 텍스트 다듬기 (가드레일 대응 fallback 포함)
- 채용공고 9개 필수 섹션 검증 (`JobDescriptionSectionValidator`)

### 면접 세션 (갓 연습)
- **질문 구성:** 자기소개 → 서류 기반 5문항 → 마무리 발언
- **질문 풀 선생성:** 홈 진입 시 백그라운드로 8개 질문 미리 생성, 세션 시작 시 즉시 로드
- 카메라 프리뷰 + 세션 전체 녹화 (질문별 타임스탬프 세그먼트)
- 면접관 TTS 음성 재생 → 1.5초 정적 → 타이머 기반 답변
- 인윈도우 프롬프터 (키워드 힌트)
- **실시간 코치 (Phase 4)** — 답변 중 필러·키워드·응시 비율 HUD, 카메라 하단 코치 힌트(토글), NSPanel HUD 프롬프터(토글)

### 면접 세션 (숙련)
- **질문 구성:** 자기소개 → 서류 3문항 + 꼬리질문 → 인성 2 → 회사 1 → 마무리
- 서류 답변 직후 **꼬리질문** 자동 삽입 (스트리밍 STT → Foundation Models)
- 인성·회사 맞춤 질문 풀 (단계별 `CachedQuestion` 분리)
- 코치·HUD **기본 off**, 프롬프터 힌트 축소
- 숙련 단계 전용 피드백·내용 점수 기준 (구체성·논리 구조)

### 면접 세션 (전문 · 실전)
- **질문 구성:** 서류 + 꼬리질문 → 기술 → 인성 → 회사 → 압박 → 종합 → 마무리 (카테고리별 문항 수 사용자 설정)
- **면접관 톤:** 차분 / 표준 / 압박 — TTS 속도·피치·답변 준비 시간 연동
- **시간 압박:** 권장 답변 시간 배율 조절 (압박 질문은 추가 단축)
- **약점 집중 훈련:** 이전 세션 취약 카테고리 자동 감지 후 해당 유형 질문 비중 상향
- 프로필별 **세션 템플릿** 저장 (`ExpertSessionConfiguration`)

### 자유 연습
- **항목 선택:** 서류 / 인성 / 회사 / 자기소개 / 역질문 / 마지막으로 할 말 (복수 선택 가능)
- **문항 수:** 1~10개 (기본 2개)
- **문항별 피드백:** 답변 직후 STT·점수·AI 코치 피드백 제공
- **종합 피드백:** 연습 종료 시 전체 요약 피드백

### 면접 일정
- 프로필별 **면접 일시** 등록 및 **D-n · N시간** 카운트다운 (메인 화면)
- **D-7~D-1** 매일 오전 9시 준비 알림 (한 문장)
- **D-Day** 오전 6시 응원 알림
- D-7~D-1 기간 메인 화면에 **오늘의 준비 포인트** 표시

### 사후 분석 & 다시보기
- 온디바이스 Speech Framework STT (세그먼트별 전사)
- 필러 워드(어, 음, 그러니까 등) 분석
- Foundation Models 기반 질문별 AI 피드백
- **다차원 평가** — 발화·내용·자세 항목별 100점 + 세션 종합 등급(S~F)
- **연습 추이 차트** — 프로필별 날짜·회차 기준 점수 추이 (Swift Charts)
- Vision 기반 자세·응시 분석 (세션 종료 후 영상 분석)
- 세션별 다시보기 — 질문 클릭 시 해당 구간 seek

## 기술 스택

| 영역 | 기술 |
|------|------|
| UI | SwiftUI, Swift Charts |
| 데이터 | SwiftData (`CandidateProfile`, `InterviewSession`, `QuestionRecord`, `CachedQuestion`) |
| AI | Foundation Models (`SystemLanguageModel`, `@Generable`) |
| 미디어 | AVFoundation (카메라·녹화), AVSpeechSynthesizer (TTS) |
| 문서 | PDFKit, Vision (OCR) |
| 음성 | Speech Framework (사후 STT) |
| 동시성 | `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, `nonisolated` + serial queue (`CameraManager`, `SpeechRecognizer`) |

## 프로젝트 구조

```
InterviewTutor/
├── App/                    # 앱 진입점, SwiftData Schema
├── Core/
│   ├── AI/                 # 질문·피드백 생성, 질문 풀, 문서 다듬기
│   ├── Camera/             # 카메라 세션, 녹화, 프리뷰
│   ├── Document/           # PDF/OCR 추출, JD 섹션 검증
│   ├── Speech/             # STT, 필러 워드, 스트리밍 STT, 오디오 레벨
│   ├── Coach/              # 실시간 코치 힌트, 키워드 커버리지
│   ├── Scoring/            # 발화·내용·자세 점수, 등급, 세션 집계
│   ├── Vision/             # 세션 영상·라이브 자세·응시 분석
│   ├── Storage/            # 영상 저장, 프로필 fingerprint
│   ├── TTS/                # 면접관 음성
│   └── Concurrency/        # Sendable DTO, 큐 격리 유틸
├── Features/
│   ├── Onboarding/         # 온보딩·프로필 추가/수정·첨부 검토
│   ├── Home/               # 홈, 프로필 관리·전환, 단계 선택, 질문 풀 리필
│   ├── Session/            # PreSession → Session → PostSession
│   ├── Progress/           # 연습 추이 차트
│   └── Replay/             # 세션 목록·다시보기
└── SharedUI/               # 타이머 링, 단계·등급 배지, 점수 패널
```

## 요구 사항

- **macOS 26.0** 이상 (Tahoe)
- **Xcode 26** (beta) 이상
- Apple Silicon Mac 권장 (Foundation Models 온디바이스 실행)
- 카메라·마이크·음성 인식 권한

## 빌드 & 실행

```bash
git clone https://github.com/deblur99/InterviewTutor.git
cd InterviewTutor
open InterviewTutor.xcodeproj
```

Xcode에서 `InterviewTutor` 스킴을 선택하고 **My Mac** 대상으로 실행합니다.

### 테스트

```bash
xcodebuild test \
  -scheme InterviewTutor \
  -destination 'platform=macOS' \
  -only-testing:InterviewTutorTests
```

## 질문 풀 최적화

프로필 fingerprint(SHA-256)가 동일하면 미리 생성된 질문을 재사용합니다.

| 시점 | 동작 |
|------|------|
| 홈 진입 / 프로필 전환·온보딩 완료 | **현재 프로필** 기준 갓 연습·숙련 풀 각각 백그라운드 리필 |
| PreSession 진입 | 단계별 풀에서 질문 `reserved` → FM 호출 최소화 |
| 풀 부족 | 부족분만 Foundation Models로 생성 |
| 프로필 수정 | fingerprint 변경 → 기존 풀 무효화·재생성 |
| 세션 완료 | `answered` 처리 후 풀 리필 |
| PreSession 이탈 | `reserved` → `unused` 복귀 |

## 개인정보 & 샌드박스

- App Sandbox 활성화
- 사용자가 선택한 파일만 읽기 (`files.user-selected.read-only`)
- 카메라·마이크는 세션 녹화·분석에만 사용
- 면접 영상은 로컬 `Application Support`에 저장

## 로드맵

향후 개발 계획은 [ROADMAP.md](./ROADMAP.md)를 참고하세요.

| 단계 | 이름 | 상태 |
|------|------|------|
| 0 | 온보딩 | ✅ 완료 |
| 1 | 갓 연습 (서류 기반 + 프롬프터) | ✅ MVP |
| 2 | 숙련 (꼬리질문·인성·회사) | ✅ 완료 |
| 3 | 전문 (실전 모드) | ✅ 완료 |

## 라이선스

[MIT License](./LICENSE) — 자세한 내용은 LICENSE 파일을 참고하세요.

## 기여

이슈·PR 환영합니다. 큰 변경은 먼저 이슈로 논의해 주세요.
