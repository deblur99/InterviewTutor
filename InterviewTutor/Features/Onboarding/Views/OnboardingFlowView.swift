import SwiftUI
import SwiftData

struct OnboardingFlowView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var viewModel: OnboardingViewModel
    @State private var showFileImporter = false

    init(profile: CandidateProfile? = nil) {
        _viewModel = State(initialValue: OnboardingViewModel(profile: profile))
    }

    private var navigationTitle: String {
        viewModel.isEditingExistingProfile ? "프로필 수정" : "온보딩"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                progressIndicator
                    .padding()

                Form {
                    switch viewModel.currentStep {
                    case 0:
                        companyStep
                    case 1:
                        documentInputStep(
                            title: "채용공고",
                            text: $viewModel.jobDescription,
                            field: .jobDescription,
                            hint: "채용공고 전문을 붙여넣거나 PDF·이미지를 첨부해 주세요."
                        )
                    case 2:
                        documentInputStep(
                            title: "이력서",
                            text: $viewModel.resumeText,
                            field: .resume,
                            hint: "이력서 내용을 입력하거나 PDF·이미지를 첨부해 주세요."
                        )
                    case 3:
                        documentInputStep(
                            title: "자기소개서",
                            text: $viewModel.coverLetterText,
                            field: .coverLetter,
                            hint: "자기소개서 내용을 입력하거나 PDF·이미지를 첨부해 주세요."
                        )
                    default:
                        EmptyView()
                    }
                }
                .formStyle(.grouped)

                footerButtons
                    .padding()
            }
            .navigationTitle(navigationTitle)
            .frame(minWidth: 600, minHeight: 500)
            .overlay {
                if viewModel.isImporting {
                    importOverlay
                }
            }
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: OnboardingViewModel.supportedContentTypes,
                allowsMultipleSelection: false
            ) { result in
                handleImportResult(result)
            }
            .sheet(item: $viewModel.pendingReview, onDismiss: {
                viewModel.dismissPendingReview()
            }) { review in
                ExtractedTextReviewSheet(
                    fieldTitle: review.field.title,
                    usedOCR: review.usedOCR,
                    sourceDescription: review.sourceDescription,
                    hadExistingContent: review.hadExistingContent,
                    reviewedText: $viewModel.reviewDraftText,
                    textBeforeRefinement: viewModel.reviewTextBeforeRefinement,
                    removedCharacterCount: viewModel.reviewDraftRemovedCharacterCount,
                    isRefining: viewModel.isRefiningReviewText,
                    warningMessage: viewModel.refinementWarningMessage,
                    onRefine: {
                        await viewModel.refineReviewDraftText()
                    },
                    onUndoRefinement: {
                        viewModel.undoReviewDraftRefinement()
                    }
                ) {
                    viewModel.applyPendingReview()
                }
            }
            .alert("파일 가져오기 실패", isPresented: Binding(
                get: { viewModel.importErrorMessage != nil },
                set: { if !$0 { viewModel.clearImportError() } }
            )) {
                Button("확인") { viewModel.clearImportError() }
            } message: {
                Text(viewModel.importErrorMessage ?? "")
            }
        }
    }

    private var progressIndicator: some View {
        HStack(spacing: 8) {
            ForEach(Array(OnboardingViewModel.steps.enumerated()), id: \.offset) { index, title in
                VStack(spacing: 4) {
                    Circle()
                        .fill(index <= viewModel.currentStep ? Color.accentColor : Color.secondary.opacity(0.3))
                        .frame(width: 10, height: 10)
                    Text(title)
                        .font(.caption2)
                        .foregroundStyle(index <= viewModel.currentStep ? .primary : .secondary)
                }
                if index < OnboardingViewModel.steps.count - 1 {
                    Rectangle()
                        .fill(index < viewModel.currentStep ? Color.accentColor : Color.secondary.opacity(0.3))
                        .frame(height: 2)
                }
            }
        }
    }

    private var companyStep: some View {
        Group {
            Section("지원 회사") {
                TextField("회사명", text: $viewModel.company)
                TextField("산업군 (예: 핀테크, 게임, 커머스)", text: $viewModel.industry)
                TextField("직무 (예: iOS 개발자)", text: $viewModel.role)
            }
        }
    }

    private func documentInputStep(
        title: String,
        text: Binding<String>,
        field: OnboardingTextField,
        hint: String
    ) -> some View {
        Section {
            TextEditor(text: text)
                .frame(minHeight: 200)
            Text(hint)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("지원 형식: PDF, PNG, JPEG, HEIC")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        } header: {
            HStack {
                Text(title)
                Spacer()
                Button {
                    viewModel.beginImport(for: field)
                    showFileImporter = true
                } label: {
                    Label("첨부", systemImage: "paperclip")
                        .labelStyle(.titleAndIcon)
                }
                .buttonStyle(.borderless)
                .disabled(viewModel.isImporting)
            }
        }
    }

    private var importOverlay: some View {
        ZStack {
            Color.black.opacity(0.2)
                .ignoresSafeArea()
            VStack(spacing: 12) {
                ProgressView()
                    .controlSize(.large)
                Text("문서 분석 중...")
                    .font(.headline)
            }
            .padding(24)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
    }

    private var footerButtons: some View {
        HStack {
            if viewModel.currentStep > 0 {
                Button("이전") {
                    viewModel.currentStep -= 1
                }
            }

            Spacer()

            Button("취소") {
                dismiss()
            }

            if viewModel.isLastStep {
                Button("완료") {
                    viewModel.save(context: modelContext)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!viewModel.canProceedFromCurrentStep())
            } else {
                Button("다음") {
                    viewModel.currentStep += 1
                }
                .buttonStyle(.borderedProminent)
                .disabled(!viewModel.canProceedFromCurrentStep())
            }
        }
    }

    private func handleImportResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            Task {
                await viewModel.importDocument(from: url)
            }
        case .failure(let error):
            viewModel.importErrorMessage = error.localizedDescription
        }
    }
}

#Preview {
    OnboardingFlowView()
        .modelContainer(for: CandidateProfile.self, inMemory: true)
}
