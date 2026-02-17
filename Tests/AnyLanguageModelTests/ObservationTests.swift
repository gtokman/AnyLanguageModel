import Foundation
import Observation
import Testing

@testable import AnyLanguageModel

@Suite("Observation")
struct ObservationTests {
    @Test("Tracking transcript fires onChange when respond mutates it")
    func transcriptObservationTriggeredByRespond() async throws {
        let session = LanguageModelSession(model: MockLanguageModel.fixed("Hello"))
        let changed = ThreadSafeValue(false)

        withObservationTracking {
            _ = session.transcript
        } onChange: {
            changed.withValue { $0 = true }
        }

        try await session.respond(to: "Hi")
        #expect(changed.withValue { $0 } == true)
    }

    @Test("Tracking transcript fires onChange when streamResponse mutates it")
    func transcriptObservationTriggeredByStreamResponse() async throws {
        let session = LanguageModelSession(model: MockLanguageModel.streamingMock())
        let changed = ThreadSafeValue(false)

        withObservationTracking {
            _ = session.transcript
        } onChange: {
            changed.withValue { $0 = true }
        }

        let stream = session.streamResponse(to: "Hi")
        for try await _ in stream {}
        try await Task.sleep(for: .milliseconds(10))

        #expect(changed.withValue { $0 } == true)
    }

    @Test("Tracking isResponding fires onChange when respond mutates it")
    func isRespondingObservationTriggeredByRespond() async throws {
        let session = LanguageModelSession(model: MockLanguageModel.fixed("Hello"))
        let changed = ThreadSafeValue(false)

        withObservationTracking {
            _ = session.isResponding
        } onChange: {
            changed.withValue { $0 = true }
        }

        try await session.respond(to: "Hi")
        #expect(changed.withValue { $0 } == true)
    }

    @Test("No onChange fires when no properties are tracked")
    func noObservationWithoutTrackedRead() async throws {
        let session = LanguageModelSession(model: MockLanguageModel.fixed("Hello"))
        let changed = ThreadSafeValue(false)

        withObservationTracking {
            // Intentionally do not read any session properties
        } onChange: {
            changed.withValue { $0 = true }
        }

        try await session.respond(to: "Hi")
        #expect(changed.withValue { $0 } == false)
    }

    @Test("Re-registering observation tracks subsequent changes")
    func observationReregistersAfterChange() async throws {
        let session = LanguageModelSession(model: MockLanguageModel.fixed("Hello"))
        let changeCount = ThreadSafeValue(0)

        withObservationTracking {
            _ = session.transcript
        } onChange: {
            changeCount.withValue { $0 += 1 }
        }

        try await session.respond(to: "First")
        #expect(changeCount.withValue { $0 } == 1)

        // Re-register after the first change fires
        withObservationTracking {
            _ = session.transcript
        } onChange: {
            changeCount.withValue { $0 += 1 }
        }

        try await session.respond(to: "Second")
        #expect(changeCount.withValue { $0 } == 2)
    }
}

/// A thread-safe value wrapper for testing observation.
private final class ThreadSafeValue<Value>: @unchecked Sendable {
    private var value: Value
    private let lock = NSLock()

    init(_ value: Value) {
        self.value = value
    }

    func withValue<T>(_ body: (inout Value) -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body(&value)
    }
}
