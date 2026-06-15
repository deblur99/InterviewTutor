import Foundation

enum VideoStorageManager {
    static var sessionsDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("InterviewTutor/Sessions", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func newVideoURL(sessionID: UUID) -> URL {
        sessionsDirectory.appendingPathComponent("\(sessionID.uuidString).mp4")
    }

    static func videoURL(for path: String) -> URL {
        if path.hasPrefix("/") {
            return URL(fileURLWithPath: path)
        }
        return sessionsDirectory.appendingPathComponent(path)
    }

    static func relativePath(for url: URL) -> String {
        url.lastPathComponent
    }
}
