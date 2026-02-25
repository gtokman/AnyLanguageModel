import Foundation
import Testing

@testable import AnyLanguageModel

// MARK: - ImageGenerationOptions Tests

@Suite("ImageGenerationOptions")
struct ImageGenerationOptionsTests {

    @Test func defaultInitialization() {
        let options = ImageGenerationOptions()
        #expect(options.numberOfImages == nil)
        #expect(options.size == nil)
    }

    @Test func initializationWithValues() {
        let options = ImageGenerationOptions(numberOfImages: 3, size: .square)
        #expect(options.numberOfImages == 3)
        #expect(options.size == .square)
    }

    @Test func equalityWithSameValues() {
        let options1 = ImageGenerationOptions(numberOfImages: 2, size: .landscape)
        let options2 = ImageGenerationOptions(numberOfImages: 2, size: .landscape)
        #expect(options1 == options2)
    }

    @Test func inequalityWithDifferentValues() {
        let options1 = ImageGenerationOptions(numberOfImages: 1, size: .square)
        let options2 = ImageGenerationOptions(numberOfImages: 2, size: .portrait)
        #expect(options1 != options2)
    }

    @Test func imageSizeEquality() {
        #expect(ImageGenerationOptions.ImageSize.square == .square)
        #expect(ImageGenerationOptions.ImageSize.landscape == .landscape)
        #expect(ImageGenerationOptions.ImageSize.portrait == .portrait)
        #expect(ImageGenerationOptions.ImageSize.custom(width: 512, height: 512) == .custom(width: 512, height: 512))
        #expect(ImageGenerationOptions.ImageSize.square != .landscape)
        #expect(ImageGenerationOptions.ImageSize.custom(width: 512, height: 512) != .custom(width: 1024, height: 1024))
    }
}

// MARK: - CustomImageGenerationOptions Tests

@Suite("CustomImageGenerationOptions")
struct CustomImageGenerationOptionsTests {

    @Test func neverConformsToCustomImageGenerationOptions() {
        let _: any CustomImageGenerationOptions.Type = Never.self
    }

    @Test func subscriptGetReturnsNilWhenNotSet() {
        let options = ImageGenerationOptions()
        let customOptions = options[custom: OpenAIImageGenerationModel.self]
        #expect(customOptions == nil)
    }

    @Test func subscriptSetAndGet() {
        var options = ImageGenerationOptions()
        let customOptions = OpenAIImageGenerationModel.CustomImageGenerationOptions(
            quality: .high
        )

        options[custom: OpenAIImageGenerationModel.self] = customOptions

        let retrieved = options[custom: OpenAIImageGenerationModel.self]
        #expect(retrieved != nil)
        #expect(retrieved?.quality == .high)
    }

    @Test func subscriptSetToNilRemovesValue() {
        var options = ImageGenerationOptions()
        options[custom: OpenAIImageGenerationModel.self] = .init(quality: .medium)

        #expect(options[custom: OpenAIImageGenerationModel.self] != nil)

        options[custom: OpenAIImageGenerationModel.self] = nil

        #expect(options[custom: OpenAIImageGenerationModel.self] == nil)
    }

    @Test func subscriptIsolatesModelTypes() {
        var options = ImageGenerationOptions()

        options[custom: OpenAIImageGenerationModel.self] = .init(quality: .high)

        let geminiOptions = options[custom: GeminiImagenModel.self]
        #expect(geminiOptions == nil)

        let openaiOptions = options[custom: OpenAIImageGenerationModel.self]
        #expect(openaiOptions?.quality == .high)
    }

    @Test func equalityWithNoCustomOptions() {
        let options1 = ImageGenerationOptions(numberOfImages: 2)
        let options2 = ImageGenerationOptions(numberOfImages: 2)
        #expect(options1 == options2)
    }

    @Test func equalityWithSameCustomOptions() {
        var options1 = ImageGenerationOptions()
        var options2 = ImageGenerationOptions()

        options1[custom: OpenAIImageGenerationModel.self] = .init(quality: .high)
        options2[custom: OpenAIImageGenerationModel.self] = .init(quality: .high)

        #expect(options1 == options2)
    }

    @Test func inequalityWithDifferentCustomOptions() {
        var options1 = ImageGenerationOptions()
        var options2 = ImageGenerationOptions()

        options1[custom: OpenAIImageGenerationModel.self] = .init(quality: .high)
        options2[custom: OpenAIImageGenerationModel.self] = .init(quality: .low)

        #expect(options1 != options2)
    }

    @Test func inequalityWhenOnlyOneHasCustomOptions() {
        var options1 = ImageGenerationOptions()
        let options2 = ImageGenerationOptions()

        options1[custom: OpenAIImageGenerationModel.self] = .init(quality: .high)

        #expect(options1 != options2)
    }
}

// MARK: - GeneratedImage Tests

@Suite("GeneratedImage")
struct GeneratedImageTests {

    @Test func initializationWithImages() {
        let segment = Transcript.ImageSegment(data: Data([0x89, 0x50]), mimeType: "image/png")
        let result = GeneratedImage(images: [segment])

        #expect(result.images.count == 1)
        #expect(result.revisedPrompt == nil)
    }

    @Test func initializationWithRevisedPrompt() {
        let segment = Transcript.ImageSegment(data: Data([0x89, 0x50]), mimeType: "image/png")
        let result = GeneratedImage(images: [segment], revisedPrompt: "A beautiful sunset")

        #expect(result.images.count == 1)
        #expect(result.revisedPrompt == "A beautiful sunset")
    }

    @Test func emptyImages() {
        let result = GeneratedImage(images: [])
        #expect(result.images.isEmpty)
    }

    @Test func multipleImages() {
        let segments = [
            Transcript.ImageSegment(data: Data([0x01]), mimeType: "image/png"),
            Transcript.ImageSegment(data: Data([0x02]), mimeType: "image/png"),
            Transcript.ImageSegment(data: Data([0x03]), mimeType: "image/png"),
        ]
        let result = GeneratedImage(images: segments)
        #expect(result.images.count == 3)
    }
}

// MARK: - OpenAIImageGenerationModel Tests

@Suite("OpenAIImageGenerationModel")
struct OpenAIImageGenerationModelTests {

    @Test func defaultInitialization() {
        let model = OpenAIImageGenerationModel(apiKey: "test-key")
        #expect(model.model == "gpt-image-1")
        #expect(model.baseURL.absoluteString == "https://api.openai.com/v1/")
    }

    @Test func customInitialization() {
        let model = OpenAIImageGenerationModel(
            apiKey: "test-key",
            model: "dall-e-3"
        )
        #expect(model.model == "dall-e-3")
    }

    @Test func isAlwaysAvailable() {
        let model = OpenAIImageGenerationModel(apiKey: "test-key")
        #expect(model.isAvailable)
    }

    @Test func requestBodyBasic() throws {
        let model = OpenAIImageGenerationModel(apiKey: "test-key")
        let options = ImageGenerationOptions()

        let body = try model.createRequestBody(prompt: "A cat", options: options)

        #expect(body["model"] == .string("gpt-image-1"))
        #expect(body["prompt"] == .string("A cat"))
        #expect(body["response_format"] == .string("b64_json"))
        #expect(body["n"] == nil)
        #expect(body["size"] == nil)
    }

    @Test func requestBodyWithOptions() throws {
        let model = OpenAIImageGenerationModel(apiKey: "test-key")
        let options = ImageGenerationOptions(numberOfImages: 3, size: .landscape)

        let body = try model.createRequestBody(prompt: "A sunset", options: options)

        #expect(body["n"] == .int(3))
        #expect(body["size"] == .string("1536x1024"))
    }

    @Test func requestBodySizeMapping() throws {
        let model = OpenAIImageGenerationModel(apiKey: "test-key")

        let squareBody = try model.createRequestBody(
            prompt: "test",
            options: ImageGenerationOptions(size: .square)
        )
        #expect(squareBody["size"] == .string("1024x1024"))

        let landscapeBody = try model.createRequestBody(
            prompt: "test",
            options: ImageGenerationOptions(size: .landscape)
        )
        #expect(landscapeBody["size"] == .string("1536x1024"))

        let portraitBody = try model.createRequestBody(
            prompt: "test",
            options: ImageGenerationOptions(size: .portrait)
        )
        #expect(portraitBody["size"] == .string("1024x1536"))

        let customBody = try model.createRequestBody(
            prompt: "test",
            options: ImageGenerationOptions(size: .custom(width: 512, height: 768))
        )
        #expect(customBody["size"] == .string("512x768"))
    }

    @Test func requestBodyWithCustomOptions() throws {
        let model = OpenAIImageGenerationModel(apiKey: "test-key")
        var options = ImageGenerationOptions()
        options[custom: OpenAIImageGenerationModel.self] = .init(
            quality: .high,
            background: .transparent,
            outputFormat: .png,
            style: .vivid
        )

        let body = try model.createRequestBody(prompt: "A logo", options: options)

        #expect(body["quality"] == .string("high"))
        #expect(body["background"] == .string("transparent"))
        #expect(body["output_format"] == .string("png"))
        #expect(body["style"] == .string("vivid"))
    }

    @Test func customOptionsEquality() {
        let options1 = OpenAIImageGenerationModel.CustomImageGenerationOptions(
            quality: .high,
            background: .transparent
        )
        let options2 = OpenAIImageGenerationModel.CustomImageGenerationOptions(
            quality: .high,
            background: .transparent
        )
        #expect(options1 == options2)
    }

    @Test func customOptionsInequality() {
        let options1 = OpenAIImageGenerationModel.CustomImageGenerationOptions(quality: .high)
        let options2 = OpenAIImageGenerationModel.CustomImageGenerationOptions(quality: .low)
        #expect(options1 != options2)
    }

    @Test func customOptionsNilProperties() {
        let options = OpenAIImageGenerationModel.CustomImageGenerationOptions()
        #expect(options.quality == nil)
        #expect(options.background == nil)
        #expect(options.outputFormat == nil)
        #expect(options.style == nil)
    }

    @Test func qualityRawValues() {
        #expect(OpenAIImageGenerationModel.CustomImageGenerationOptions.Quality.low.rawValue == "low")
        #expect(OpenAIImageGenerationModel.CustomImageGenerationOptions.Quality.medium.rawValue == "medium")
        #expect(OpenAIImageGenerationModel.CustomImageGenerationOptions.Quality.high.rawValue == "high")
    }

    @Test func backgroundRawValues() {
        #expect(OpenAIImageGenerationModel.CustomImageGenerationOptions.Background.opaque.rawValue == "opaque")
        #expect(
            OpenAIImageGenerationModel.CustomImageGenerationOptions.Background.transparent.rawValue == "transparent")
    }

    @Test func outputFormatRawValues() {
        #expect(OpenAIImageGenerationModel.CustomImageGenerationOptions.OutputFormat.png.rawValue == "png")
        #expect(OpenAIImageGenerationModel.CustomImageGenerationOptions.OutputFormat.jpeg.rawValue == "jpeg")
        #expect(OpenAIImageGenerationModel.CustomImageGenerationOptions.OutputFormat.webp.rawValue == "webp")
    }

    @Test func styleRawValues() {
        #expect(OpenAIImageGenerationModel.CustomImageGenerationOptions.Style.natural.rawValue == "natural")
        #expect(OpenAIImageGenerationModel.CustomImageGenerationOptions.Style.vivid.rawValue == "vivid")
    }
}

// MARK: - GeminiImagenModel Tests

@Suite("GeminiImagenModel")
struct GeminiImagenModelTests {

    @Test func defaultInitialization() {
        let model = GeminiImagenModel(apiKey: "test-key")
        #expect(model.model == "imagen-3.0-generate-002")
        #expect(model.apiVersion == "v1beta")
    }

    @Test func customInitialization() {
        let model = GeminiImagenModel(
            apiKey: "test-key",
            model: "imagen-3.0-generate-001"
        )
        #expect(model.model == "imagen-3.0-generate-001")
    }

    @Test func isAlwaysAvailable() {
        let model = GeminiImagenModel(apiKey: "test-key")
        #expect(model.isAvailable)
    }

    @Test func requestBodyBasic() {
        let model = GeminiImagenModel(apiKey: "test-key")
        let options = ImageGenerationOptions()

        let body = model.createRequestBody(prompt: "A cat", options: options)

        if case .array(let instances) = body["instances"],
            case .object(let instance) = instances.first
        {
            #expect(instance["prompt"] == .string("A cat"))
        } else {
            Issue.record("Expected instances array with prompt")
        }
    }

    @Test func requestBodyWithOptions() {
        let model = GeminiImagenModel(apiKey: "test-key")
        let options = ImageGenerationOptions(numberOfImages: 4, size: .landscape)

        let body = model.createRequestBody(prompt: "A sunset", options: options)

        if case .object(let parameters) = body["parameters"] {
            #expect(parameters["sampleCount"] == .int(4))
            #expect(parameters["aspectRatio"] == .string("16:9"))
        } else {
            Issue.record("Expected parameters object")
        }
    }

    @Test func requestBodySizeMapping() {
        let model = GeminiImagenModel(apiKey: "test-key")

        let squareBody = model.createRequestBody(
            prompt: "test",
            options: ImageGenerationOptions(size: .square)
        )
        if case .object(let params) = squareBody["parameters"] {
            #expect(params["aspectRatio"] == .string("1:1"))
        }

        let landscapeBody = model.createRequestBody(
            prompt: "test",
            options: ImageGenerationOptions(size: .landscape)
        )
        if case .object(let params) = landscapeBody["parameters"] {
            #expect(params["aspectRatio"] == .string("16:9"))
        }

        let portraitBody = model.createRequestBody(
            prompt: "test",
            options: ImageGenerationOptions(size: .portrait)
        )
        if case .object(let params) = portraitBody["parameters"] {
            #expect(params["aspectRatio"] == .string("9:16"))
        }
    }

    @Test func requestBodyWithCustomOptions() {
        let model = GeminiImagenModel(apiKey: "test-key")
        var options = ImageGenerationOptions()
        options[custom: GeminiImagenModel.self] = .init(
            outputMimeType: .jpeg,
            safetyFilterLevel: .blockOnlyHigh,
            personGeneration: .allowAdult,
            negativePrompt: "blurry"
        )

        let body = model.createRequestBody(prompt: "A portrait", options: options)

        if case .array(let instances) = body["instances"],
            case .object(let instance) = instances.first
        {
            #expect(instance["negativePrompt"] == .string("blurry"))
        }

        if case .object(let params) = body["parameters"] {
            #expect(params["outputMimeType"] == .string("image/jpeg"))
            #expect(params["safetySetting"] == .string("BLOCK_ONLY_HIGH"))
            #expect(params["personGeneration"] == .string("ALLOW_ADULT"))
        } else {
            Issue.record("Expected parameters object")
        }
    }

    @Test func customOptionsEquality() {
        let options1 = GeminiImagenModel.CustomImageGenerationOptions(
            outputMimeType: .png,
            negativePrompt: "blurry"
        )
        let options2 = GeminiImagenModel.CustomImageGenerationOptions(
            outputMimeType: .png,
            negativePrompt: "blurry"
        )
        #expect(options1 == options2)
    }

    @Test func customOptionsNilProperties() {
        let options = GeminiImagenModel.CustomImageGenerationOptions()
        #expect(options.outputMimeType == nil)
        #expect(options.safetyFilterLevel == nil)
        #expect(options.personGeneration == nil)
        #expect(options.negativePrompt == nil)
    }

    @Test func safetyFilterLevelRawValues() {
        typealias Level = GeminiImagenModel.CustomImageGenerationOptions.SafetyFilterLevel
        #expect(Level.blockLowAndAbove.rawValue == "BLOCK_LOW_AND_ABOVE")
        #expect(Level.blockMediumAndAbove.rawValue == "BLOCK_MEDIUM_AND_ABOVE")
        #expect(Level.blockOnlyHigh.rawValue == "BLOCK_ONLY_HIGH")
        #expect(Level.blockNone.rawValue == "BLOCK_NONE")
    }

    @Test func personGenerationRawValues() {
        typealias PG = GeminiImagenModel.CustomImageGenerationOptions.PersonGeneration
        #expect(PG.dontAllow.rawValue == "DONT_ALLOW")
        #expect(PG.allowAdult.rawValue == "ALLOW_ADULT")
        #expect(PG.allowAll.rawValue == "ALLOW_ALL")
    }
}

// MARK: - GeminiNativeImageGenerationModel Tests

@Suite("GeminiNativeImageGenerationModel")
struct GeminiNativeImageGenerationModelTests {

    @Test func defaultInitialization() {
        let model = GeminiNativeImageGenerationModel(apiKey: "test-key")
        #expect(model.model == "gemini-2.0-flash-preview-image-generation")
        #expect(model.apiVersion == "v1beta")
    }

    @Test func customInitialization() {
        let model = GeminiNativeImageGenerationModel(
            apiKey: "test-key",
            model: "gemini-2.0-flash-exp"
        )
        #expect(model.model == "gemini-2.0-flash-exp")
    }

    @Test func isAlwaysAvailable() {
        let model = GeminiNativeImageGenerationModel(apiKey: "test-key")
        #expect(model.isAvailable)
    }

    @Test func requestBodyBasic() {
        let model = GeminiNativeImageGenerationModel(apiKey: "test-key")
        let options = ImageGenerationOptions()

        let body = model.createRequestBody(prompt: "A robot", options: options)

        if case .array(let contents) = body["contents"],
            case .object(let content) = contents.first,
            case .array(let parts) = content["parts"],
            case .object(let part) = parts.first
        {
            #expect(part["text"] == .string("A robot"))
        } else {
            Issue.record("Expected contents with text part")
        }

        if case .object(let config) = body["generationConfig"],
            case .array(let modalities) = config["responseModalities"]
        {
            #expect(modalities.contains(.string("TEXT")))
            #expect(modalities.contains(.string("IMAGE")))
        } else {
            Issue.record("Expected generationConfig with responseModalities")
        }
    }

    @Test func requestBodyWithNumberOfImages() {
        let model = GeminiNativeImageGenerationModel(apiKey: "test-key")
        let options = ImageGenerationOptions(numberOfImages: 2)

        let body = model.createRequestBody(prompt: "test", options: options)

        if case .object(let config) = body["generationConfig"] {
            #expect(config["candidateCount"] == .int(2))
        } else {
            Issue.record("Expected generationConfig")
        }
    }

    @Test func customOptionsEquality() {
        let options1 = GeminiNativeImageGenerationModel.CustomImageGenerationOptions()
        let options2 = GeminiNativeImageGenerationModel.CustomImageGenerationOptions()
        #expect(options1 == options2)
    }
}

// MARK: - ImageGenerationModel Protocol Tests

@Suite("ImageGenerationModel Protocol")
struct ImageGenerationModelProtocolTests {

    @Test func conformanceOpenAI() {
        let _: any ImageGenerationModel = OpenAIImageGenerationModel(apiKey: "test")
    }

    @Test func conformanceGeminiImagen() {
        let _: any ImageGenerationModel = GeminiImagenModel(apiKey: "test")
    }

    @Test func conformanceGeminiNative() {
        let _: any ImageGenerationModel = GeminiNativeImageGenerationModel(apiKey: "test")
    }
}
