func megaYield() async {
    for _ in 0..<10 {
        await Task<Void, Never>.detached(priority: .background) { await Task.yield() }.value
    }
}

func taskToCollect<S: AsyncSequence>(_ sequence: S) -> Task<[S.Element], Never> {
    Task {
        print("start")
        var list: [S.Element] = []
        var i = sequence.makeAsyncIterator()
        while let next = try! await i.next() {
            list.append(next)
        }
        return list
    }
}

@available(iOS 16, *)
func taskToCollect<S: AsyncSequence, C: Clock<Duration>>(
    _ sequence: S,
    pausingAfterEachFor duration: Duration,
    clock: C
) -> Task<[S.Element], Never> {
    Task {
        var list: [S.Element] = []
        var i = sequence.makeAsyncIterator()
        while let next = try! await i.next() {
            list.append(next)
            try! await clock.sleep(for: .seconds(1))
        }
        return list
    }
}

func withScopedLifetime<Value, Result>(_ value: Value, body: (Value) async -> Result) async -> Result {
    await body(value)
}
