import XCTest
@testable import ClipnoteCore

final class DebouncerTests: XCTestCase {
    func testRapidCallsCollapseToOne() {
        let finished = expectation(description: "debounced work ran once")
        finished.assertForOverFulfill = true
        let debouncer = Debouncer(interval: 0.12, queue: .main)

        for _ in 0..<6 {
            debouncer.schedule {
                finished.fulfill()
            }
        }

        wait(for: [finished], timeout: 1.0)
    }

    func testCancelPreventsWork() {
        let finished = expectation(description: "should not run")
        finished.isInverted = true
        let debouncer = Debouncer(interval: 0.2, queue: .main)
        debouncer.schedule {
            finished.fulfill()
        }
        debouncer.cancel()
        wait(for: [finished], timeout: 0.35)
    }
}
