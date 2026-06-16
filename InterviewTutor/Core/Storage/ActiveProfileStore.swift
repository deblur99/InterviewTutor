import Foundation

@Observable
final class ActiveProfileStore {
    private static let storageKey = "activeProfileID"

    var activeProfileID: UUID? {
        didSet {
            if let activeProfileID {
                UserDefaults.standard.set(activeProfileID.uuidString, forKey: Self.storageKey)
            } else {
                UserDefaults.standard.removeObject(forKey: Self.storageKey)
            }
        }
    }

    init() {
        if let raw = UserDefaults.standard.string(forKey: Self.storageKey),
           let id = UUID(uuidString: raw) {
            activeProfileID = id
        }
    }

    func activeProfile(in profiles: [CandidateProfile]) -> CandidateProfile? {
        profiles.forEach { $0.ensureProfileID() }

        if let activeProfileID,
           let match = profiles.first(where: { $0.profileID == activeProfileID }) {
            return match
        }

        let fallback = profiles.first(where: \.isComplete) ?? profiles.first
        if let fallback {
            activeProfileID = fallback.profileID
        }
        return fallback
    }

    func select(_ profile: CandidateProfile) {
        profile.ensureProfileID()
        activeProfileID = profile.profileID
    }

    func clearSelectionIfDeleted(_ profile: CandidateProfile) {
        profile.ensureProfileID()
        if activeProfileID == profile.profileID {
            activeProfileID = nil
        }
    }

    func isActive(_ profile: CandidateProfile) -> Bool {
        profile.ensureProfileID()
        return activeProfileID == profile.profileID
    }
}
