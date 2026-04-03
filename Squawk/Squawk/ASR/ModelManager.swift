import Observation

@Observable
final class ModelManager {
    var isDownloaded = false
    var downloadProgress: Double = 0.0
}
