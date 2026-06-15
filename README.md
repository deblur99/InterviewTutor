# 면접도우미 (InterviewTutor)

macOS용 화상면접 연습 앱입니다. 지원 회사·채용공고·이력서·자기소개서를 바탕으로 **온디바이스 AI**가 맞춤 질문을 생성하고, 카메라 녹화·TTS·타이머·사후 STT 분석·피드백·다시보기까지 한 번에 제공합니다.

> **현재 버전:** MVP (1단계 · 갓 연습)  
> **플랫폼:** macOS 26.0+  
> **개인정보:** Foundation Models, Speech, AVFoundation 등 Apple 온디바이스 API 중심 — 서버 전송 없음

## 주요 기능

### 온보딩 & 프로필
- 지원 회사, 산업, 직무, 채용공고, 이력서, 자기소개서 입력
- PDF·PNG·JPEG·HEIC 첨부 → PDFKit 텍스트 추출, 부족 시 Vision OCR
- Foundation Models 기반 텍스트 다듬기 (가드레일 대응 fallback 포함)
- 채용공고 9개 필수 섹션 검증 (`JobDescriptionSectionValidator`)

### 면접 세션 (갓 연습)
- **질문 구성:** 자기소개 → 서류 기반 5문항 → 마무리 발언
- **질문 풀 선생성:** 홈 진입 시 백그라운드로 8개 질문 미리 생성, 세션 시작 시 즉시 로드
- 카메라 프리뷰 + 세션 전체 녹화 (질문별 타임스탬프 세그먼트)
- 면접관 TTS 음성 재생 → 1.5초 정적 → 타이머 기반 답변
- 인윈도우 프롬프터 (키워드 힌트)

### 사후 분석 & 다시보기
- 온디바이스 Speech Framework STT (세그먼트별 전사)
- 필러 워드(어, 음, 그러니까 등) 분석
- Foundation Models 기반 질문별 AI 피드백
- 세션별 다시보기 — 질문 클릭 시 해당 구간 seek

## 기술 스택

| 영역 | 기술 |
|------|------|
| UI | SwiftUI |
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
│   ├── Speech/             # STT, 필러 워드 분석
│   ├── Storage/            # 영상 저장, 프로필 fingerprint
│   ├── TTS/                # 면접관 음성
│   └── Concurrency/        # Sendable DTO, 큐 격리 유틸
├── Features/
│   ├── Onboarding/         # 온보딩·프로필 수정·첨부 검토
│   ├── Home/               # 홈, 단계 선택, 질문 풀 리필
│   ├── Session/            # PreSession → Session → PostSession
│   └── Replay/             # 세션 목록·다시보기
└── SharedUI/               # 타이머 링, 단계 배지 등 공용 컴포넌트
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
| 홈 진입 / 온보딩 완료 | 백그라운드로 unused 질문 8개까지 채움 |
| PreSession 진입 | 풀에서 5개 `reserved` → FM 호출 없이 즉시 표시 |
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
| 2 | 숙련 (꼬리질문·인성·회사) | 🔜 예정 |
| 3 | 전문 (실전 모드) | 🔜 예정 |

## 라이선스

[MIT License](./LICENSE) — 자세한 내용은 LICENSE 파일을 참고하세요.

## 기여

이슈·PR 환영합니다. 큰 변경은 먼저 이슈로 논의해 주세요.
