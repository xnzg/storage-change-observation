import TestableOSLog

enum LogMessages<Observer: StorageObserver>: Equatable {
    typealias Version = Observer.Version

    case initialFetchingStarted
    case initialFetchingCompleted
    case initialFetchingError(Duration)
    case initialFetchingFailed
    case willRetry(Duration)
    case versionMisalignment(Version, Version, Version)
    case reducerRequestedRetry
    case reducerError
}

extension LogMessages: LogMessageConvertible {
    func toLogMessage() -> LogMessage {
        switch self {
        case .initialFetchingStarted:
            return "Initial fetching started."

        case .initialFetchingCompleted:
            return "Initial fetching completed."

        case .initialFetchingError(let duration):
            return "Initial fetching encountered an error. Will retry in \(duration.description)."

        case .initialFetchingFailed:
            return "Initial fetching failed."

        case .willRetry(let duration):
            return "Will retry observation in \(duration.description)."

        case .reducerRequestedRetry:
            return "Reducer requested retry."

        case .reducerError:
            return "Reducer encountered an error."

        case let .versionMisalignment(current, old, new):
            return """
            Version misalignment. Current: \(current.description, privacy: .public). Change from \(old, privacy: .public) to \(new, privacy: .public).
            """
        }
    }
}
