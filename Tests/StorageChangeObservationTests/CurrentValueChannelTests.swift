import XCTest
import Clocks
@testable import StorageChangeObservation

@available(iOS 16, *)
final class CurrentValueChannelTests: XCTestCase {
    func testSingleConsumer() async {
        let channel = CurrentValueChannel<Int>()
        let task = taskToCollect(channel)

        for i in 0..<4 {
            await channel.send(i)
            await megaYield()
        }
        await channel.finish()

        let taskResult = await task.value
        XCTAssertEqual(taskResult, [0, 1, 2, 3])
    }

    func testMultipleConsumers() async {
        let channel = CurrentValueChannel<Int>()
        let tasks = (0..<3).map { _ in taskToCollect(channel) }

        for i in 0..<4 {
            await channel.send(i)
            await megaYield()
        }
        await channel.finish()

        let taskResults = await [
            tasks[0].value,
            tasks[1].value,
            tasks[2].value
        ]

        for result in taskResults {
            XCTAssertEqual(result, [0, 1, 2, 3])
        }
    }

    func testBufferingBehavior() async {
        let clock = TestClock()
        let channel = CurrentValueChannel<Int>()
        let task = taskToCollect(channel, pausingAfterEachFor: .seconds(1), clock: clock)

        await channel.send(0)
        await megaYield()
        await channel.send(1)
        await megaYield()
        await channel.send(2)

        await clock.advance(by: .seconds(1))

        await megaYield()
        await channel.send(3)
        await megaYield()
        await channel.send(4)

        await clock.advance(by: .seconds(1))

        await channel.finish()

        await clock.advance(by: .seconds(1))

        let taskResult = await task.value
        XCTAssertEqual(taskResult, [0, 2, 4])
    }

    func testQuickConsumerWillNotInterfereSlowOne() async {
        // When some value is being consumed by some consumer
        // and another subscribed consumer has not pulled the value,
        // we want the other consumer to still get the value.

        let clock = TestClock()
        let channel = CurrentValueChannel<Int>()

        let quickTask = taskToCollect(channel)
        let slowTask = taskToCollect(channel, pausingAfterEachFor: .seconds(1), clock: clock)

        await channel.send(0)
        await megaYield()

        await channel.send(1)
        await megaYield()

        await clock.advance(by: .seconds(1))

        await channel.finish()

        await clock.advance(by: .seconds(1))

        let quickList = await quickTask.value
        let slowList = await slowTask.value

        XCTAssertEqual(quickList, [0, 1])
        XCTAssertEqual(slowList, [0, 1])
    }

    func testValueBufferedForNewConsumer() async {
        let channel = CurrentValueChannel<Int>()
        await channel.send(0)
        await megaYield()

        let task = taskToCollect(channel)

        await megaYield()
        await channel.finish()

        let taskResult = await task.value
        XCTAssertEqual(taskResult, [0])
    }
}
