import Foundation

/// Serial queue helper for confining non-Sendable framework objects.
nonisolated enum QueueConfined {
    static func run<T: Sendable>(
        on queue: DispatchQueue,
        _ work: @escaping @Sendable () throws -> T
    ) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do {
                    continuation.resume(returning: try work())
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    static func run<T: Sendable>(
        on queue: DispatchQueue,
        _ work: @escaping @Sendable () -> T
    ) async -> T {
        await withCheckedContinuation { continuation in
            queue.async {
                continuation.resume(returning: work())
            }
        }
    }
}
