public final actor CurrentValueChannel<Output> {
    var versionedValue: (Output, UInt64)?
    var isFinished: Bool = false
    var continuations: [UnsafeContinuation<(Output, UInt64)?, Never>] = []

    deinit {
        for continuation in continuations {
            continuation.resume(returning: nil)
        }
    }

    public func finish() {
        isFinished = true
        for continuation in continuations {
            continuation.resume(returning: nil)
        }
        continuations = []
    }

    func next(after lastVersion: UInt64) async -> (Output, UInt64)? {
        guard !isFinished else { return nil }
        if let (value, currentVersion) = versionedValue,
            currentVersion > lastVersion
        {
            return (value, currentVersion)
        }
        return await withUnsafeContinuation {
            continuations.append($0)
        }
    }

    public func send(_ output: Output) {
        guard !isFinished else { return }
        let lastVersion = versionedValue?.1 ?? 0
        versionedValue = (output, lastVersion + 1)
        for continuation in continuations {
            continuation.resume(returning: (output, lastVersion + 1))
        }
        continuations = []
    }
}

extension CurrentValueChannel: AsyncSequence {
    public typealias Element = Output

    public nonisolated func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(channel: self)
    }

    public struct AsyncIterator: AsyncIteratorProtocol {
        let channel: CurrentValueChannel
        var version: UInt64 = 0

        public mutating func next() async -> Element? {
            guard !Task.isCancelled,
                  await !channel.isFinished,
                  let (nextValue, nextVersion) = await channel.next(after: version)
            else { return nil }
            version = nextVersion
            return nextValue
        }
    }
}
