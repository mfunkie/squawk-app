import Foundation

enum DiskSpaceChecker {
    /// Check if the system has enough free disk space.
    /// - Parameter requiredBytes: Minimum free bytes required (default 1GB for model download)
    /// - Returns: `true` if enough space is available, or if the check fails (don't block on errors)
    static func hasEnoughSpace(requiredBytes: Int64 = 1_000_000_000) -> Bool {
        let homeURL = FileManager.default.homeDirectoryForCurrentUser
        do {
            let values = try homeURL.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
            let available = values.volumeAvailableCapacityForImportantUsage ?? 0
            return available > requiredBytes
        } catch {
            return true // Don't block on error
        }
    }
}
