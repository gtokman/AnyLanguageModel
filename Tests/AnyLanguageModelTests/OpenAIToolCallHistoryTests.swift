import Foundation
import Testing

@testable import AnyLanguageModel

#if canImport(Darwin) && !canImport(AsyncHTTPClient)
    @Suite("OpenAI tool call history", .serialized)
    struct OpenAIToolCallHistoryTests {
        private let chatCompletion = """
            {"id": "chatcmpl-1", "object": "chat.completion", "created": 0, "model": "test",
             "choices": [{"index": 0, "finish_reason": "stop",
                          "message": {"role": "assistant", "content": "Done."}}]}
            """

        private let responsesResponse = """
            {"id": "resp-1", "object": "response", "created_at": 0, "model": "test", "status": "completed",
             "output": [{"type": "message", "id": "msg-1", "role": "assistant", "status": "completed",
                         "content": [{"type": "output_text", "text": "Done.", "annotations": []}]}]}
            """

        private func transcript() throws -> Transcript {
            let call = Transcript.ToolCall(
                id: "call-1",
                toolName: "getWeather",
                arguments: try GeneratedContent(json: #"{"city":"Paris"}"#)
            )
            return Transcript(entries: [
                .prompt(Transcript.Prompt(segments: [.text(.init(content: "Weather in Paris?"))])),
                .toolCalls(Transcript.ToolCalls([call])),
                .toolOutput(
                    Transcript.ToolOutput(
                        id: "call-1",
                        toolName: "getWeather",
                        segments: [.text(.init(content: "Sunny"))]
                    )
                ),
                .response(Transcript.Response(assetIDs: [], segments: [.text(.init(content: "It's sunny."))])),
            ])
        }

        /// The arguments a replayed tool call carries, parsed back from the request body.
        private func replayedArguments(in body: Data) throws -> [String] {
            let json = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
            if let messages = json["messages"] as? [[String: Any]] {
                return messages.flatMap { message in
                    (message["tool_calls"] as? [[String: Any]] ?? []).compactMap {
                        ($0["function"] as? [String: Any])?["arguments"] as? String
                    }
                }
            }
            let input = try #require(json["input"] as? [[String: Any]])
            return input.filter { $0["type"] as? String == "function_call" }.compactMap { $0["arguments"] as? String }
        }

        @Test(arguments: [OpenAILanguageModel.APIVariant.chatCompletions, .responses])
        func replayedToolCallArgumentsArePlainJSON(variant: OpenAILanguageModel.APIVariant) async throws {
            ToolCallHistoryURLProtocol.reset(
                responses: [variant == .chatCompletions ? chatCompletion : responsesResponse]
            )
            let model = OpenAILanguageModel(
                apiKey: "test",
                model: "test",
                apiVariant: variant,
                session: ToolCallHistoryURLProtocol.makeSession()
            )
            let session = LanguageModelSession(model: model, transcript: try transcript())
            _ = try await session.respond(to: "And tomorrow?")

            let body = try #require(ToolCallHistoryURLProtocol.recordedBodies.last)
            let arguments = try replayedArguments(in: body)
            #expect(arguments.count == 1)
            let decoded = try #require(
                arguments.first.flatMap { try? JSONSerialization.jsonObject(with: Data($0.utf8)) as? [String: String] }
            )
            #expect(decoded == ["city": "Paris"])
        }
    }

    /// A `URLProtocol` with its own queue of JSON responses,
    /// so this suite doesn't share state with suites that run in parallel.
    private final class ToolCallHistoryURLProtocol: URLProtocol {
        private struct State: Sendable {
            var pending: [String] = []
            var recordedBodies: [Data] = []
        }

        private static let state = Locked(State())

        static func reset(responses: [String]) {
            state.withLock { $0 = State(pending: responses) }
        }

        static var recordedBodies: [Data] {
            state.withLock { $0.recordedBodies }
        }

        static func makeSession() -> URLSession {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.protocolClasses = [ToolCallHistoryURLProtocol.self]
            return URLSession(configuration: configuration)
        }

        override class func canInit(with request: URLRequest) -> Bool { true }

        override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

        override func startLoading() {
            // URLSession moves `httpBody` to `httpBodyStream` before the protocol sees the request.
            let body = request.httpBody ?? request.httpBodyStream.map(Self.readAll) ?? Data()
            let next = Self.state.withLock { state -> String? in
                state.recordedBodies.append(body)
                return state.pending.isEmpty ? nil : state.pending.removeFirst()
            }
            guard let next, let url = request.url else {
                client?.urlProtocol(self, didFailWithError: URLError(.resourceUnavailable))
                return
            }
            let response = HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "application/json"]
            )!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: Data(next.utf8))
            client?.urlProtocolDidFinishLoading(self)
        }

        override func stopLoading() {}

        private static func readAll(_ stream: InputStream) -> Data {
            stream.open()
            defer { stream.close() }
            var data = Data()
            var buffer = [UInt8](repeating: 0, count: 4096)
            while true {
                let read = stream.read(&buffer, maxLength: buffer.count)
                guard read > 0 else { break }
                data.append(buffer, count: read)
            }
            return data
        }
    }
#endif
