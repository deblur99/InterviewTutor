import CryptoKit
import Foundation

enum ProfileFingerprint {
    static func make(for profile: CandidateProfile) -> String {
        let payload = [
            profile.company,
            profile.industry,
            profile.role,
            profile.jobDescription,
            profile.resumeText,
            profile.coverLetterText,
        ].joined(separator: "\u{1F}")

        let digest = SHA256.hash(data: Data(payload.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
