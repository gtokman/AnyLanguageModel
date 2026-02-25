import Foundation
import JSONSchema
import Testing

@testable import AnyLanguageModel

private let openResponsesAPIKey: String? = ProcessInfo.processInfo.environment["OPEN_RESPONSES_API_KEY"]
private let openResponsesBaseURL: URL? = ProcessInfo.processInfo.environment["OPEN_RESPONSES_BASE_URL"].flatMap {
    URL(string: $0)
}

@Suite("OpenResponsesLanguageModel")
struct OpenResponsesLanguageModelTests {
    @Test func customHost() throws {
        let customURL = URL(string: "https://example.com")!
        let model = OpenResponsesLanguageModel(baseURL: customURL, apiKey: "test", model: "test-model")
        #expect(model.baseURL.absoluteString.hasSuffix("/"))
    }

    @Test func modelParameter() throws {
        let baseURL = URL(string: "https://api.example.com/v1/")!
        let model = OpenResponsesLanguageModel(baseURL: baseURL, apiKey: "test-key", model: "my-model")
        #expect(model.model == "my-model")
    }

    @Suite(
        "OpenResponsesLanguageModel API",
        .enabled(if: openResponsesAPIKey?.isEmpty == false && openResponsesBaseURL != nil)
    )
    struct APITests {
        private let apiKey = openResponsesAPIKey!
        private var baseURL: URL { openResponsesBaseURL! }

        private var model: OpenResponsesLanguageModel {
            OpenResponsesLanguageModel(
                baseURL: baseURL,
                apiKey: apiKey,
                model: "gpt-4o-mini"
            )
        }

        @Test func basicResponse() async throws {
            let session = LanguageModelSession(model: model)
            let response = try await session.respond(to: "Say hello")
            #expect(!response.content.isEmpty)
        }

        @Test func withInstructions() async throws {
            let session = LanguageModelSession(
                model: model,
                instructions: "You are a helpful assistant. Be concise."
            )
            let response = try await session.respond(to: "What is 2+2?")
            #expect(!response.content.isEmpty)
        }

        @Test func streaming() async throws {
            let session = LanguageModelSession(model: model)
            let stream = session.streamResponse(to: "Count to 5")
            var chunks: [String] = []
            for try await response in stream {
                chunks.append(response.content)
            }
            #expect(!chunks.isEmpty)
        }

        @Test func streamingString() async throws {
            let session = LanguageModelSession(model: model)
            let stream = session.streamResponse(to: "Say 'Hello' slowly")
            var snapshots: [LanguageModelSession.ResponseStream<String>.Snapshot] = []
            for try await snapshot in stream {
                snapshots.append(snapshot)
            }
            #expect(!snapshots.isEmpty)
            #expect(!snapshots.last!.rawContent.jsonString.isEmpty)
        }

        @Test func withGenerationOptions() async throws {
            let session = LanguageModelSession(model: model)
            let options = GenerationOptions(
                temperature: 0.7,
                maximumResponseTokens: 50
            )
            let response = try await session.respond(
                to: "Tell me a fact",
                options: options
            )
            #expect(!response.content.isEmpty)
        }

        @Test func withCustomGenerationOptions() async throws {
            let session = LanguageModelSession(model: model)
            var options = GenerationOptions(
                temperature: 0.7,
                maximumResponseTokens: 50
            )
            options[custom: OpenResponsesLanguageModel.self] = .init(
                extraBody: ["user": .string("test-user-id")]
            )
            let response = try await session.respond(
                to: "Say hello",
                options: options
            )
            #expect(!response.content.isEmpty)
        }

        @Test func multimodalWithImageURL() async throws {
            let session = LanguageModelSession(model: model)
            let response = try await session.respond(
                to: "Describe this image",
                image: .init(url: testImageURL)
            )
            #expect(!response.content.isEmpty)
        }

        @Test func multimodalWithImageData() async throws {
            let session = LanguageModelSession(model: model)
            let response = try await session.respond(
                to: "Describe this image",
                image: .init(data: testImageData, mimeType: "image/png")
            )
            #expect(!response.content.isEmpty)
        }

        @Test func conversationContext() async throws {
            let session = LanguageModelSession(model: model)
            let firstResponse = try await session.respond(to: "My favorite color is blue")
            #expect(!firstResponse.content.isEmpty)
            let secondResponse = try await session.respond(to: "What did I just tell you?")
            #expect(secondResponse.content.contains("color"))
        }

        @Test func withTools() async throws {
            let weatherTool = WeatherTool()
            let session = LanguageModelSession(model: model, tools: [weatherTool])
            let response = try await session.respond(to: "How's the weather in San Francisco?")
            var foundToolOutput = false
            for case let .toolOutput(toolOutput) in response.transcriptEntries {
                #expect(toolOutput.toolName == "getWeather")
                foundToolOutput = true
            }
            #expect(foundToolOutput)
        }

        @Suite("Structured Output")
        struct StructuredOutputTests {
            @Generable
            struct Person {
                @Guide(description: "The person's full name")
                var name: String

                @Guide(description: "The person's age in years")
                var age: Int

                @Guide(description: "The person's email address")
                var email: String?
            }

            @Generable
            struct Book {
                @Guide(description: "The book's title")
                var title: String

                @Guide(description: "The book's author")
                var author: String

                @Guide(description: "The publication year")
                var year: Int
            }

            private var model: OpenResponsesLanguageModel {
                OpenResponsesLanguageModel(
                    baseURL: openResponsesBaseURL!,
                    apiKey: openResponsesAPIKey!,
                    model: "gpt-4o-mini"
                )
            }

            @Test func basicStructuredOutput() async throws {
                let session = LanguageModelSession(model: model)
                let response = try await session.respond(
                    to: "Generate a person named John Doe, age 30, email john@example.com",
                    generating: Person.self
                )
                #expect(!response.content.name.isEmpty)
                #expect(response.content.name.contains("John") || response.content.name.contains("Doe"))
                #expect(response.content.age > 0)
                #expect(response.content.age <= 100)
                #expect(response.content.email != nil)
            }

            @Test func structuredOutputWithOptionalField() async throws {
                let session = LanguageModelSession(model: model)
                let response = try await session.respond(
                    to: "Generate a person named Jane Smith, age 25, with no email",
                    generating: Person.self
                )
                #expect(!response.content.name.isEmpty)
                #expect(response.content.email == nil || response.content.email?.isEmpty == true)
            }

            @Test func structuredOutputWithNestedTypes() async throws {
                let session = LanguageModelSession(model: model)
                let response = try await session.respond(
                    to: "Generate a book titled 'The Swift Programming Language' by 'Apple Inc.' published in 2024",
                    generating: Book.self
                )
                #expect(!response.content.title.isEmpty)
                #expect(!response.content.author.isEmpty)
                #expect(response.content.year >= 2020)
            }

            @Test func streamingStructuredOutput() async throws {
                let session = LanguageModelSession(model: model)
                let stream = session.streamResponse(
                    to: "Generate a person named Alice, age 28, email alice@example.com",
                    generating: Person.self
                )
                var snapshots: [LanguageModelSession.ResponseStream<Person>.Snapshot] = []
                for try await snapshot in stream {
                    snapshots.append(snapshot)
                }
                #expect(!snapshots.isEmpty)
                let finalSnapshot = snapshots.last!
                #expect((finalSnapshot.content.name?.isEmpty ?? true) == false)
                #expect((finalSnapshot.content.age ?? 0) > 0)
            }
        }
    }

    @Suite("Image Generation Tool")
    struct ImageGenerationToolTests {
        typealias ImageGenerationTool = OpenResponsesLanguageModel.CustomGenerationOptions.ImageGenerationTool

        @Test func defaultInitialization() {
            let tool = ImageGenerationTool()
            #expect(tool.quality == nil)
            #expect(tool.size == nil)
            #expect(tool.background == nil)
            #expect(tool.outputFormat == nil)
            #expect(tool.outputCompression == nil)
            #expect(tool.inputFidelity == nil)
            #expect(tool.partialImages == nil)
        }

        @Test func initializationWithParameters() {
            let tool = ImageGenerationTool(
                quality: .high,
                size: .square,
                background: .transparent,
                outputFormat: .png,
                outputCompression: 80,
                inputFidelity: .high,
                partialImages: 3
            )
            #expect(tool.quality == .high)
            #expect(tool.size == .square)
            #expect(tool.background == .transparent)
            #expect(tool.outputFormat == .png)
            #expect(tool.outputCompression == 80)
            #expect(tool.inputFidelity == .high)
            #expect(tool.partialImages == 3)
        }

        @Test func imageSizeRawValues() {
            #expect(ImageGenerationTool.ImageSize.square.rawValue == "1024x1024")
            #expect(ImageGenerationTool.ImageSize.landscape.rawValue == "1536x1024")
            #expect(ImageGenerationTool.ImageSize.portrait.rawValue == "1024x1536")
            #expect(ImageGenerationTool.ImageSize.auto.rawValue == "auto")
        }

        @Test func requestBodyIncludesImageGenerationTool() throws {
            var options = GenerationOptions()
            options[custom: OpenResponsesLanguageModel.self] = .init(
                imageGeneration: .init(quality: .high, size: .landscape)
            )
            let body = try OpenResponsesLanguageModel._testCreateRequestBody(
                model: "gpt-4.1",
                options: options
            )
            guard case .object(let dict) = body,
                case .array(let tools) = dict["tools"]
            else {
                Issue.record("Expected tools array in body")
                return
            }
            #expect(tools.count == 1)
            guard case .object(let toolObj) = tools.first else {
                Issue.record("Expected tool object")
                return
            }
            #expect(toolObj["type"] == .string("image_generation"))
            #expect(toolObj["quality"] == .string("high"))
            #expect(toolObj["size"] == .string("1536x1024"))
        }

        @Test func requestBodyIncludesAllImageGenerationParams() throws {
            var options = GenerationOptions()
            options[custom: OpenResponsesLanguageModel.self] = .init(
                imageGeneration: .init(
                    quality: .medium,
                    size: .portrait,
                    background: .opaque,
                    outputFormat: .webp,
                    outputCompression: 90,
                    inputFidelity: .low,
                    partialImages: 2
                )
            )
            let body = try OpenResponsesLanguageModel._testCreateRequestBody(
                model: "gpt-4.1",
                options: options
            )
            guard case .object(let dict) = body,
                case .array(let tools) = dict["tools"],
                case .object(let toolObj) = tools.first
            else {
                Issue.record("Expected tools array with tool object")
                return
            }
            #expect(toolObj["type"] == .string("image_generation"))
            #expect(toolObj["quality"] == .string("medium"))
            #expect(toolObj["size"] == .string("1024x1536"))
            #expect(toolObj["background"] == .string("opaque"))
            #expect(toolObj["output_format"] == .string("webp"))
            #expect(toolObj["output_compression"] == .int(90))
            #expect(toolObj["input_fidelity"] == .string("low"))
            #expect(toolObj["partial_images"] == .int(2))
        }

        @Test func requestBodyWithFunctionAndImageGenerationTools() throws {
            var options = GenerationOptions()
            options[custom: OpenResponsesLanguageModel.self] = .init(
                imageGeneration: .init(quality: .auto)
            )
            let body = try OpenResponsesLanguageModel._testCreateRequestBody(
                model: "gpt-4.1",
                options: options,
                tools: [WeatherTool()]
            )
            guard case .object(let dict) = body,
                case .array(let tools) = dict["tools"]
            else {
                Issue.record("Expected tools array in body")
                return
            }
            #expect(tools.count == 2)
            // First should be the function tool
            if case .object(let firstTool) = tools[0] {
                #expect(firstTool["type"] == .string("function"))
            }
            // Second should be image_generation
            if case .object(let secondTool) = tools[1] {
                #expect(secondTool["type"] == .string("image_generation"))
                #expect(secondTool["quality"] == .string("auto"))
            }
        }

        @Test func requestBodyWithoutImageGeneration() throws {
            let options = GenerationOptions()
            let body = try OpenResponsesLanguageModel._testCreateRequestBody(
                model: "gpt-4.1",
                options: options
            )
            guard case .object(let dict) = body else {
                Issue.record("Expected object body")
                return
            }
            #expect(dict["tools"] == nil)
        }

        @Test func extractImagesFromOutput() throws {
            let base64Data = Data("test image data".utf8).base64EncodedString()
            let output: [JSONValue] = [
                .object([
                    "type": .string("image_generation_call"),
                    "id": .string("ig_123"),
                    "status": .string("completed"),
                    "result": .string(base64Data),
                    "revised_prompt": .string("A detailed image of a cat"),
                ])
            ]
            let images = OpenResponsesLanguageModel._testExtractImages(from: output)
            #expect(images.count == 1)
            #expect(images[0].revisedPrompt == "A detailed image of a cat")
            if case .data(let data, let mimeType) = images[0].image.source {
                #expect(mimeType == "image/png")
                #expect(data == Data(base64Encoded: base64Data))
            } else {
                Issue.record("Expected data source")
            }
        }

        @Test func extractImagesWithCustomMimeType() throws {
            let base64Data = Data("jpeg data".utf8).base64EncodedString()
            let output: [JSONValue] = [
                .object([
                    "type": .string("image_generation_call"),
                    "id": .string("ig_456"),
                    "result": .string(base64Data),
                ])
            ]
            let images = OpenResponsesLanguageModel._testExtractImages(from: output, mimeType: "image/jpeg")
            #expect(images.count == 1)
            #expect(images[0].revisedPrompt == nil)
            if case .data(_, let mimeType) = images[0].image.source {
                #expect(mimeType == "image/jpeg")
            } else {
                Issue.record("Expected data source")
            }
        }

        @Test func extractImagesIgnoresNonImageItems() throws {
            let output: [JSONValue] = [
                .object([
                    "type": .string("message"),
                    "role": .string("assistant"),
                    "content": .array([
                        .object(["type": .string("output_text"), "text": .string("Hello")])
                    ]),
                ]),
                .object([
                    "type": .string("function_call"),
                    "call_id": .string("call_1"),
                    "name": .string("test"),
                    "arguments": .string("{}"),
                ]),
            ]
            let images = OpenResponsesLanguageModel._testExtractImages(from: output)
            #expect(images.isEmpty)
        }

        @Test func generatedImagesFromTranscriptEntries() {
            let imageData = Data("test".utf8)
            let imageSegment = Transcript.ImageSegment(data: imageData, mimeType: "image/png")
            let entries: [Transcript.Entry] = [
                .response(Transcript.Response(
                    assetIDs: [],
                    segments: [
                        .image(imageSegment),
                        .text(.init(content: "A revised prompt")),
                    ]
                ))
            ]
            let response = LanguageModelSession.Response<String>(
                content: "",
                rawContent: GeneratedContent(""),
                transcriptEntries: ArraySlice(entries)
            )
            #expect(response.generatedImages.count == 1)
            #expect(response.generatedImages[0].id == imageSegment.id)
        }

        @Test func generatedImagesEmptyWhenNoImages() {
            let entries: [Transcript.Entry] = [
                .response(Transcript.Response(
                    assetIDs: [],
                    segments: [.text(.init(content: "Just text"))]
                ))
            ]
            let response = LanguageModelSession.Response<String>(
                content: "Just text",
                rawContent: GeneratedContent("Just text"),
                transcriptEntries: ArraySlice(entries)
            )
            #expect(response.generatedImages.isEmpty)
        }

        @Test func imageGenerationToolCodable() throws {
            let tool = ImageGenerationTool(
                quality: .high,
                size: .square,
                background: .transparent,
                outputFormat: .png,
                outputCompression: 75
            )
            let data = try JSONEncoder().encode(tool)
            let decoded = try JSONDecoder().decode(ImageGenerationTool.self, from: data)
            #expect(decoded == tool)
        }
    }
}
