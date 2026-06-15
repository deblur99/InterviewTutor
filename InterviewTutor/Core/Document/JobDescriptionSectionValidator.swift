import Foundation

enum JobDescriptionRequiredSection: String, CaseIterable, Sendable {
    case postingTitle = "채용공고 이름"
    case company = "채용하는 회사"
    case unit = "모집단위"
    case location = "근무지"
    case major = "전공 요구"
    case qualifications = "지원 자격"
    case preferred = "우대 사항"
    case roleIntro = "직무 소개"
    case process = "채용 절차"

    var keywords: [String] {
        switch self {
        case .postingTitle:
            ["채용공고", "공고명", "채용명", "포지션", "모집직무", "job title"]
        case .company:
            ["채용회사", "회사명", "기업명", "회사 소개", "employer"]
        case .unit:
            ["모집단위", "모집부문", "모집조직", "조직", "부서", "사업부"]
        case .location:
            ["근무지", "근무지역", "근무 장소", "근무장소", "work location"]
        case .major:
            ["전공", "전공요건", "전공 요구", "학과", "major"]
        case .qualifications:
            ["지원 자격", "지원자격", "자격요건", "자격 요건", "필수요건", "qualification"]
        case .preferred:
            ["우대", "우대사항", "우대 사항", "우대조건", "preferred"]
        case .roleIntro:
            ["직무", "직무소개", "직무 소개", "담당업무", "업무내용", "주요업무", "role"]
        case .process:
            ["채용 절차", "채용절차", "전형절차", "전형 절차", "선발절차", "채용 프로세스"]
        }
    }

    static let preservationGuide = """
    아래 섹션은 채용공고에서 반드시 유지해야 합니다. 섹션 제목과 본문을 삭제·요약·통합하지 마세요.
    - 채용공고 이름
    - 채용하는 회사
    - 모집단위
    - 근무지
    - 전공 요구
    - 지원 자격
    - 우대 사항
    - 직무 소개
    - 채용 절차
    """
}

enum JobDescriptionSectionValidator {
    static func missingSections(in text: String) -> [JobDescriptionRequiredSection] {
        let normalized = text.lowercased()
        return JobDescriptionRequiredSection.allCases.filter { section in
            !section.keywords.contains { keyword in
                normalized.contains(keyword.lowercased())
            }
        }
    }

    static func missingSectionsMessage(for text: String) -> String? {
        let missing = missingSections(in: text)
        guard !missing.isEmpty else { return nil }

        let names = missing.map(\.rawValue).joined(separator: ", ")
        return "다음 필수 항목이 누락되었을 수 있습니다: \(names). 원문에서 해당 내용을 확인해 주세요."
    }

    static func isRequiredSectionHeader(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        return JobDescriptionRequiredSection.allCases.contains { section in
            section.keywords.contains { keyword in
                trimmed.localizedCaseInsensitiveContains(keyword)
            }
        }
    }
}
