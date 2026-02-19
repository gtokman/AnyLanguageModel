import Testing

@testable import AnyLanguageModel

@Suite("URLSession Extensions")
struct URLSessionExtensionsTests {
    @Test func invalidResponseDescriptionMatchesExpectedText() {
        let error = URLSessionError.invalidResponse
        #expect(error.description == "Invalid response")
    }

    @Test func httpErrorDescriptionIncludesStatusCodeAndDetail() {
        let error = URLSessionError.httpError(statusCode: 429, detail: "rate limit")
        #expect(error.description == "HTTP error (Status 429): rate limit")
    }

    @Test func decodingErrorDescriptionIncludesDetail() {
        let error = URLSessionError.decodingError(detail: "keyNotFound")
        #expect(error.description == "Decoding error: keyNotFound")
    }
}

#if canImport(FoundationNetworking)
    private actor GateCounter {
        private(set) var current = 0
        private(set) var maxConcurrent = 0

        func enter() {
            current += 1
            maxConcurrent = max(maxConcurrent, current)
        }

        func leave() {
            current -= 1
        }
    }

    private enum GateTestError: Error {
        case expected
    }

    extension URLSessionExtensionsTests {
        @Test func linuxGateSerializesConcurrentOperations() async throws {
            let counter = GateCounter()

            try await withThrowingTaskGroup(of: Void.self) { group in
                for _ in 0 ..< 8 {
                    group.addTask {
                        try await withLinuxRequestLock {
                            await counter.enter()
                            do {
                                try await Task.sleep(for: .milliseconds(20))
                                await counter.leave()
                            } catch {
                                await counter.leave()
                                throw error
                            }
                        }
                    }
                }
                try await group.waitForAll()
            }

            #expect(await counter.maxConcurrent == 1)
        }

        @Test func linuxGateReleasesAfterError() async throws {
            do {
                try await withLinuxRequestLock {
                    throw GateTestError.expected
                }
                Issue.record("Expected error was not thrown")
            } catch GateTestError.expected {
                // expected
            }

            var ranSecondOperation = false
            try await withLinuxRequestLock {
                ranSecondOperation = true
            }
            #expect(ranSecondOperation)
        }

        @Test func linuxGateReleasesAfterCancellation() async throws {
            let longTask = Task {
                try await withLinuxRequestLock {
                    try await Task.sleep(for: .seconds(10))
                }
            }

            try await Task.sleep(for: .milliseconds(30))
            longTask.cancel()
            _ = await longTask.result

            var acquiredAfterCancellation = false
            try await withLinuxRequestLock {
                acquiredAfterCancellation = true
            }

            #expect(acquiredAfterCancellation)
        }
    }
#endif
