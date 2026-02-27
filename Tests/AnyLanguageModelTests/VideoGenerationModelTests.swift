import Foundation
import Testing

@testable import AnyLanguageModel

// MARK: - VideoGenerationOptions Tests

@Suite("VideoGenerationOptions")
struct VideoGenerationOptionsTests {

    @Test func defaultInitialization() {
        let options = VideoGenerationOptions()
        #expect(options.aspectRatio == nil)
        #expect(options.durationSeconds == nil)
    }

    @Test func initializationWithValues() {
        let options = VideoGenerationOptions(aspectRatio: .landscape, durationSeconds: 10)
        #expect(options.aspectRatio == .landscape)
        #expect(options.durationSeconds == 10)
    }

    @Test func equalityWithSameValues() {
        let options1 = VideoGenerationOptions(aspectRatio: .landscape, durationSeconds: 8)
        let options2 = VideoGenerationOptions(aspectRatio: .landscape, durationSeconds: 8)
        #expect(options1 == options2)
    }

    @Test func inequalityWithDifferentValues() {
        let options1 = VideoGenerationOptions(aspectRatio: .square, durationSeconds: 5)
        let options2 = VideoGenerationOptions(aspectRatio: .portrait, durationSeconds: 10)
        #expect(options1 != options2)
    }

    @Test func aspectRatioRawValues() {
        #expect(VideoGenerationOptions.AspectRatio.square.rawValue == "1:1")
        #expect(VideoGenerationOptions.AspectRatio.landscape.rawValue == "16:9")
        #expect(VideoGenerationOptions.AspectRatio.portrait.rawValue == "9:16")
    }

    @Test func aspectRatioEquality() {
        #expect(VideoGenerationOptions.AspectRatio.square == .square)
        #expect(VideoGenerationOptions.AspectRatio.landscape == .landscape)
        #expect(VideoGenerationOptions.AspectRatio.portrait == .portrait)
        #expect(VideoGenerationOptions.AspectRatio.square != .landscape)
    }
}

// MARK: - CustomVideoGenerationOptions Tests

@Suite("CustomVideoGenerationOptions")
struct CustomVideoGenerationOptionsTests {

    @Test func neverConformsToCustomVideoGenerationOptions() {
        let _: any CustomVideoGenerationOptions.Type = Never.self
    }

    @Test func subscriptGetReturnsNilWhenNotSet() {
        let options = VideoGenerationOptions()
        let customOptions = options[custom: OpenAIVideoGenerationModel.self]
        #expect(customOptions == nil)
    }

    @Test func subscriptSetAndGet() {
        var options = VideoGenerationOptions()
        let customOptions = OpenAIVideoGenerationModel.CustomVideoGenerationOptions(
            size: "1280x720"
        )

        options[custom: OpenAIVideoGenerationModel.self] = customOptions

        let retrieved = options[custom: OpenAIVideoGenerationModel.self]
        #expect(retrieved != nil)
        #expect(retrieved?.size == "1280x720")
    }

    @Test func subscriptSetToNilRemovesValue() {
        var options = VideoGenerationOptions()
        options[custom: OpenAIVideoGenerationModel.self] = .init(size: "1080x1080")

        #expect(options[custom: OpenAIVideoGenerationModel.self] != nil)

        options[custom: OpenAIVideoGenerationModel.self] = nil

        #expect(options[custom: OpenAIVideoGenerationModel.self] == nil)
    }

    @Test func subscriptIsolatesModelTypes() {
        var options = VideoGenerationOptions()

        options[custom: OpenAIVideoGenerationModel.self] = .init(size: "1280x720")

        let xaiOptions = options[custom: XAIVideoGenerationModel.self]
        #expect(xaiOptions == nil)

        let geminiOptions = options[custom: GeminiVideoGenerationModel.self]
        #expect(geminiOptions == nil)

        let openaiOptions = options[custom: OpenAIVideoGenerationModel.self]
        #expect(openaiOptions?.size == "1280x720")
    }

    @Test func equalityWithNoCustomOptions() {
        let options1 = VideoGenerationOptions(durationSeconds: 8)
        let options2 = VideoGenerationOptions(durationSeconds: 8)
        #expect(options1 == options2)
    }

    @Test func equalityWithSameCustomOptions() {
        var options1 = VideoGenerationOptions()
        var options2 = VideoGenerationOptions()

        options1[custom: OpenAIVideoGenerationModel.self] = .init(size: "1280x720")
        options2[custom: OpenAIVideoGenerationModel.self] = .init(size: "1280x720")

        #expect(options1 == options2)
    }

    @Test func inequalityWithDifferentCustomOptions() {
        var options1 = VideoGenerationOptions()
        var options2 = VideoGenerationOptions()

        options1[custom: OpenAIVideoGenerationModel.self] = .init(size: "1280x720")
        options2[custom: OpenAIVideoGenerationModel.self] = .init(size: "1080x1080")

        #expect(options1 != options2)
    }

    @Test func inequalityWhenOnlyOneHasCustomOptions() {
        var options1 = VideoGenerationOptions()
        let options2 = VideoGenerationOptions()

        options1[custom: OpenAIVideoGenerationModel.self] = .init(size: "1280x720")

        #expect(options1 != options2)
    }
}

// MARK: - GeneratedVideo Tests

@Suite("GeneratedVideo")
struct GeneratedVideoTests {

    @Test func initializationWithVideos() {
        let segment = Transcript.VideoSegment(data: Data([0x00, 0x01]), mimeType: "video/mp4")
        let result = GeneratedVideo(videos: [segment])

        #expect(result.videos.count == 1)
        #expect(result.revisedPrompt == nil)
    }

    @Test func initializationWithRevisedPrompt() {
        let segment = Transcript.VideoSegment(data: Data([0x00, 0x01]), mimeType: "video/mp4")
        let result = GeneratedVideo(videos: [segment], revisedPrompt: "A cinematic drone shot")

        #expect(result.videos.count == 1)
        #expect(result.revisedPrompt == "A cinematic drone shot")
    }

    @Test func emptyVideos() {
        let result = GeneratedVideo(videos: [])
        #expect(result.videos.isEmpty)
    }

    @Test func multipleVideos() {
        let segments = [
            Transcript.VideoSegment(data: Data([0x01]), mimeType: "video/mp4"),
            Transcript.VideoSegment(data: Data([0x02]), mimeType: "video/mp4"),
        ]
        let result = GeneratedVideo(videos: segments)
        #expect(result.videos.count == 2)
    }
}

// MARK: - VideoSegment Tests

@Suite("Transcript.VideoSegment")
struct VideoSegmentTests {

    @Test func initFromData() {
        let data = Data([0x00, 0x01, 0x02])
        let segment = Transcript.VideoSegment(data: data, mimeType: "video/mp4")

        if case .data(let segmentData, let mimeType) = segment.source {
            #expect(segmentData == data)
            #expect(mimeType == "video/mp4")
        } else {
            Issue.record("Expected data source")
        }
    }

    @Test func initFromURL() {
        let url = URL(string: "https://example.com/video.mp4")!
        let segment = Transcript.VideoSegment(url: url)

        if case .url(let segmentURL) = segment.source {
            #expect(segmentURL == url)
        } else {
            Issue.record("Expected url source")
        }
    }

    @Test func initFromSource() {
        let data = Data([0x00])
        let source = Transcript.VideoSegment.Source.data(data, mimeType: "video/webm")
        let segment = Transcript.VideoSegment(source: source)

        #expect(segment.source == source)
    }

    @Test func equality() {
        let segment1 = Transcript.VideoSegment(id: "test-id", data: Data([0x01]), mimeType: "video/mp4")
        let segment2 = Transcript.VideoSegment(id: "test-id", data: Data([0x01]), mimeType: "video/mp4")
        #expect(segment1 == segment2)
    }

    @Test func inequality() {
        let segment1 = Transcript.VideoSegment(id: "id-1", data: Data([0x01]), mimeType: "video/mp4")
        let segment2 = Transcript.VideoSegment(id: "id-2", data: Data([0x02]), mimeType: "video/mp4")
        #expect(segment1 != segment2)
    }

    @Test func codableRoundTripData() throws {
        let original = Transcript.VideoSegment(id: "test", data: Data([0xDE, 0xAD]), mimeType: "video/mp4")
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Transcript.VideoSegment.self, from: encoded)
        #expect(original == decoded)
    }

    @Test func codableRoundTripURL() throws {
        let original = Transcript.VideoSegment(id: "test", url: URL(string: "https://example.com/video.mp4")!)
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Transcript.VideoSegment.self, from: encoded)
        #expect(original == decoded)
    }
}

// MARK: - OpenAIVideoGenerationModel Tests

@Suite("OpenAIVideoGenerationModel")
struct OpenAIVideoGenerationModelTests {

    @Test func defaultInitialization() {
        let model = OpenAIVideoGenerationModel(apiKey: "test-key")
        #expect(model.model == "sora-2")
        #expect(model.baseURL.absoluteString == "https://api.openai.com/v1/")
    }

    @Test func customInitialization() {
        let model = OpenAIVideoGenerationModel(
            apiKey: "test-key",
            model: "sora-2-pro"
        )
        #expect(model.model == "sora-2-pro")
    }

    @Test func isAlwaysAvailable() {
        let model = OpenAIVideoGenerationModel(apiKey: "test-key")
        #expect(model.isAvailable)
    }

    @Test func requestBodyBasic() {
        let model = OpenAIVideoGenerationModel(apiKey: "test-key")
        let options = VideoGenerationOptions()

        let body = model.createRequestBody(prompt: "A sunset", options: options)

        #expect(body["model"] == .string("sora-2"))
        #expect(body["prompt"] == .string("A sunset"))
        #expect(body["seconds"] == nil)
        #expect(body["size"] == nil)
    }

    @Test func requestBodyWithOptions() {
        let model = OpenAIVideoGenerationModel(apiKey: "test-key")
        let options = VideoGenerationOptions(aspectRatio: .landscape, durationSeconds: 10)

        let body = model.createRequestBody(prompt: "A drone shot", options: options)

        #expect(body["seconds"] == .int(10))
        #expect(body["size"] == .string("1280x720"))
    }

    @Test func requestBodySizeMapping() {
        let model = OpenAIVideoGenerationModel(apiKey: "test-key")

        let squareBody = model.createRequestBody(
            prompt: "test",
            options: VideoGenerationOptions(aspectRatio: .square)
        )
        #expect(squareBody["size"] == .string("1080x1080"))

        let landscapeBody = model.createRequestBody(
            prompt: "test",
            options: VideoGenerationOptions(aspectRatio: .landscape)
        )
        #expect(landscapeBody["size"] == .string("1280x720"))

        let portraitBody = model.createRequestBody(
            prompt: "test",
            options: VideoGenerationOptions(aspectRatio: .portrait)
        )
        #expect(portraitBody["size"] == .string("720x1280"))
    }

    @Test func requestBodyWithCustomOptions() {
        let model = OpenAIVideoGenerationModel(apiKey: "test-key")
        var options = VideoGenerationOptions()
        options[custom: OpenAIVideoGenerationModel.self] = .init(
            size: "1920x1080"
        )

        let body = model.createRequestBody(prompt: "A scene", options: options)

        #expect(body["size"] == .string("1920x1080"))
    }

    @Test func customSizeOverridesAspectRatio() {
        let model = OpenAIVideoGenerationModel(apiKey: "test-key")
        var options = VideoGenerationOptions(aspectRatio: .square)
        options[custom: OpenAIVideoGenerationModel.self] = .init(
            size: "1920x1080"
        )

        let body = model.createRequestBody(prompt: "test", options: options)

        // Custom size should override the aspect ratio mapping
        #expect(body["size"] == .string("1920x1080"))
    }

    @Test func extraBodyMergedIntoRequest() {
        let model = OpenAIVideoGenerationModel(apiKey: "test-key")
        var options = VideoGenerationOptions()
        options[custom: OpenAIVideoGenerationModel.self] = .init(
            extraBody: [
                "n_variants": .int(2),
                "style": .string("cinematic"),
            ]
        )

        let body = model.createRequestBody(prompt: "test", options: options)

        #expect(body["n_variants"] == .int(2))
        #expect(body["style"] == .string("cinematic"))
    }

    @Test func extraBodyOverridesStandardParams() {
        let model = OpenAIVideoGenerationModel(apiKey: "test-key")
        var options = VideoGenerationOptions(durationSeconds: 5)
        options[custom: OpenAIVideoGenerationModel.self] = .init(
            extraBody: [
                "seconds": .int(15)
            ]
        )

        let body = model.createRequestBody(prompt: "test", options: options)

        // extraBody should override the standard duration
        #expect(body["seconds"] == .int(15))
    }

    @Test func customOptionsEquality() {
        let options1 = OpenAIVideoGenerationModel.CustomVideoGenerationOptions(
            size: "1280x720",
            pollInterval: 5
        )
        let options2 = OpenAIVideoGenerationModel.CustomVideoGenerationOptions(
            size: "1280x720",
            pollInterval: 5
        )
        #expect(options1 == options2)
    }

    @Test func customOptionsInequality() {
        let options1 = OpenAIVideoGenerationModel.CustomVideoGenerationOptions(size: "1280x720")
        let options2 = OpenAIVideoGenerationModel.CustomVideoGenerationOptions(size: "1080x1080")
        #expect(options1 != options2)
    }

    @Test func customOptionsNilProperties() {
        let options = OpenAIVideoGenerationModel.CustomVideoGenerationOptions()
        #expect(options.size == nil)
        #expect(options.pollInterval == nil)
        #expect(options.extraBody == nil)
    }
}

// MARK: - XAIVideoGenerationModel Tests

@Suite("XAIVideoGenerationModel")
struct XAIVideoGenerationModelTests {

    @Test func defaultInitialization() {
        let model = XAIVideoGenerationModel(apiKey: "test-key")
        #expect(model.model == "grok-imagine-video")
        #expect(model.baseURL.absoluteString == "https://api.x.ai/v1/")
    }

    @Test func customInitialization() {
        let model = XAIVideoGenerationModel(
            apiKey: "test-key",
            model: "grok-imagine-video-2"
        )
        #expect(model.model == "grok-imagine-video-2")
    }

    @Test func isAlwaysAvailable() {
        let model = XAIVideoGenerationModel(apiKey: "test-key")
        #expect(model.isAvailable)
    }

    @Test func requestBodyBasic() {
        let model = XAIVideoGenerationModel(apiKey: "test-key")
        let options = VideoGenerationOptions()

        let body = model.createRequestBody(prompt: "A cat", options: options)

        #expect(body["model"] == .string("grok-imagine-video"))
        #expect(body["prompt"] == .string("A cat"))
        #expect(body["duration"] == nil)
        #expect(body["aspect_ratio"] == nil)
        #expect(body["resolution"] == nil)
    }

    @Test func requestBodyWithOptions() {
        let model = XAIVideoGenerationModel(apiKey: "test-key")
        let options = VideoGenerationOptions(aspectRatio: .landscape, durationSeconds: 8)

        let body = model.createRequestBody(prompt: "A sunset", options: options)

        #expect(body["duration"] == .int(8))
        #expect(body["aspect_ratio"] == .string("16:9"))
    }

    @Test func requestBodyAspectRatioMapping() {
        let model = XAIVideoGenerationModel(apiKey: "test-key")

        let squareBody = model.createRequestBody(
            prompt: "test",
            options: VideoGenerationOptions(aspectRatio: .square)
        )
        #expect(squareBody["aspect_ratio"] == .string("1:1"))

        let landscapeBody = model.createRequestBody(
            prompt: "test",
            options: VideoGenerationOptions(aspectRatio: .landscape)
        )
        #expect(landscapeBody["aspect_ratio"] == .string("16:9"))

        let portraitBody = model.createRequestBody(
            prompt: "test",
            options: VideoGenerationOptions(aspectRatio: .portrait)
        )
        #expect(portraitBody["aspect_ratio"] == .string("9:16"))
    }

    @Test func requestBodyWithCustomOptions() {
        let model = XAIVideoGenerationModel(apiKey: "test-key")
        var options = VideoGenerationOptions()
        options[custom: XAIVideoGenerationModel.self] = .init(
            resolution: ._720p
        )

        let body = model.createRequestBody(prompt: "A scene", options: options)

        #expect(body["resolution"] == .string("720p"))
    }

    @Test func resolutionRawValues() {
        #expect(XAIVideoGenerationModel.CustomVideoGenerationOptions.Resolution._480p.rawValue == "480p")
        #expect(XAIVideoGenerationModel.CustomVideoGenerationOptions.Resolution._720p.rawValue == "720p")
    }

    @Test func extraBodyMergedIntoRequest() {
        let model = XAIVideoGenerationModel(apiKey: "test-key")
        var options = VideoGenerationOptions()
        options[custom: XAIVideoGenerationModel.self] = .init(
            extraBody: [
                "custom_param": .string("value")
            ]
        )

        let body = model.createRequestBody(prompt: "test", options: options)

        #expect(body["custom_param"] == .string("value"))
    }

    @Test func extraBodyOverridesStandardParams() {
        let model = XAIVideoGenerationModel(apiKey: "test-key")
        var options = VideoGenerationOptions(aspectRatio: .square)
        options[custom: XAIVideoGenerationModel.self] = .init(
            extraBody: [
                "aspect_ratio": .string("4:3")
            ]
        )

        let body = model.createRequestBody(prompt: "test", options: options)

        // extraBody should override the standard aspect ratio
        #expect(body["aspect_ratio"] == .string("4:3"))
    }

    @Test func customOptionsEquality() {
        let options1 = XAIVideoGenerationModel.CustomVideoGenerationOptions(
            resolution: ._720p,
            pollInterval: 5
        )
        let options2 = XAIVideoGenerationModel.CustomVideoGenerationOptions(
            resolution: ._720p,
            pollInterval: 5
        )
        #expect(options1 == options2)
    }

    @Test func customOptionsInequality() {
        let options1 = XAIVideoGenerationModel.CustomVideoGenerationOptions(resolution: ._480p)
        let options2 = XAIVideoGenerationModel.CustomVideoGenerationOptions(resolution: ._720p)
        #expect(options1 != options2)
    }

    @Test func customOptionsNilProperties() {
        let options = XAIVideoGenerationModel.CustomVideoGenerationOptions()
        #expect(options.resolution == nil)
        #expect(options.pollInterval == nil)
        #expect(options.extraBody == nil)
    }
}

// MARK: - GeminiVideoGenerationModel Tests

@Suite("GeminiVideoGenerationModel")
struct GeminiVideoGenerationModelTests {

    @Test func defaultInitialization() {
        let model = GeminiVideoGenerationModel(apiKey: "test-key")
        #expect(model.model == "veo-3.1-generate-preview")
        #expect(model.apiVersion == "v1beta")
    }

    @Test func customInitialization() {
        let model = GeminiVideoGenerationModel(
            apiKey: "test-key",
            model: "veo-2.0-generate-001"
        )
        #expect(model.model == "veo-2.0-generate-001")
    }

    @Test func isAlwaysAvailable() {
        let model = GeminiVideoGenerationModel(apiKey: "test-key")
        #expect(model.isAvailable)
    }

    @Test func requestBodyBasic() {
        let model = GeminiVideoGenerationModel(apiKey: "test-key")
        let options = VideoGenerationOptions()

        let body = model.createRequestBody(prompt: "A sunset", options: options)

        if case .array(let instances) = body["instances"],
            case .object(let instance) = instances.first
        {
            #expect(instance["prompt"] == .string("A sunset"))
        } else {
            Issue.record("Expected instances array with prompt")
        }
    }

    @Test func requestBodyWithOptions() {
        let model = GeminiVideoGenerationModel(apiKey: "test-key")
        let options = VideoGenerationOptions(aspectRatio: .landscape, durationSeconds: 8)

        let body = model.createRequestBody(prompt: "A drone shot", options: options)

        if case .object(let parameters) = body["parameters"] {
            #expect(parameters["aspectRatio"] == .string("16:9"))
            #expect(parameters["durationSeconds"] == .int(8))
        } else {
            Issue.record("Expected parameters object")
        }
    }

    @Test func requestBodyAspectRatioMapping() {
        let model = GeminiVideoGenerationModel(apiKey: "test-key")

        let squareBody = model.createRequestBody(
            prompt: "test",
            options: VideoGenerationOptions(aspectRatio: .square)
        )
        if case .object(let params) = squareBody["parameters"] {
            #expect(params["aspectRatio"] == .string("1:1"))
        }

        let landscapeBody = model.createRequestBody(
            prompt: "test",
            options: VideoGenerationOptions(aspectRatio: .landscape)
        )
        if case .object(let params) = landscapeBody["parameters"] {
            #expect(params["aspectRatio"] == .string("16:9"))
        }

        let portraitBody = model.createRequestBody(
            prompt: "test",
            options: VideoGenerationOptions(aspectRatio: .portrait)
        )
        if case .object(let params) = portraitBody["parameters"] {
            #expect(params["aspectRatio"] == .string("9:16"))
        }
    }

    @Test func requestBodyWithCustomOptions() {
        let model = GeminiVideoGenerationModel(apiKey: "test-key")
        var options = VideoGenerationOptions()
        options[custom: GeminiVideoGenerationModel.self] = .init(
            resolution: ._1080p,
            negativePrompt: "blurry, low quality",
            personGeneration: .allowAdult
        )

        let body = model.createRequestBody(prompt: "A portrait", options: options)

        if case .array(let instances) = body["instances"],
            case .object(let instance) = instances.first
        {
            #expect(instance["negativePrompt"] == .string("blurry, low quality"))
        }

        if case .object(let params) = body["parameters"] {
            #expect(params["resolution"] == .string("1080p"))
            #expect(params["personGeneration"] == .string("ALLOW_ADULT"))
        } else {
            Issue.record("Expected parameters object")
        }
    }

    @Test func noParametersWhenNoOptionsSet() {
        let model = GeminiVideoGenerationModel(apiKey: "test-key")
        let options = VideoGenerationOptions()

        let body = model.createRequestBody(prompt: "test", options: options)

        #expect(body["parameters"] == nil)
    }

    @Test func resolutionRawValues() {
        typealias R = GeminiVideoGenerationModel.CustomVideoGenerationOptions.Resolution
        #expect(R._720p.rawValue == "720p")
        #expect(R._1080p.rawValue == "1080p")
        #expect(R._4k.rawValue == "4k")
    }

    @Test func personGenerationRawValues() {
        typealias PG = GeminiVideoGenerationModel.CustomVideoGenerationOptions.PersonGeneration
        #expect(PG.dontAllow.rawValue == "DONT_ALLOW")
        #expect(PG.allowAdult.rawValue == "ALLOW_ADULT")
        #expect(PG.allowAll.rawValue == "ALLOW_ALL")
    }

    @Test func customOptionsEquality() {
        let options1 = GeminiVideoGenerationModel.CustomVideoGenerationOptions(
            resolution: ._1080p,
            negativePrompt: "blurry"
        )
        let options2 = GeminiVideoGenerationModel.CustomVideoGenerationOptions(
            resolution: ._1080p,
            negativePrompt: "blurry"
        )
        #expect(options1 == options2)
    }

    @Test func customOptionsInequality() {
        let options1 = GeminiVideoGenerationModel.CustomVideoGenerationOptions(resolution: ._720p)
        let options2 = GeminiVideoGenerationModel.CustomVideoGenerationOptions(resolution: ._1080p)
        #expect(options1 != options2)
    }

    @Test func customOptionsNilProperties() {
        let options = GeminiVideoGenerationModel.CustomVideoGenerationOptions()
        #expect(options.resolution == nil)
        #expect(options.negativePrompt == nil)
        #expect(options.personGeneration == nil)
        #expect(options.pollInterval == nil)
    }
}

// MARK: - VideoGenerationModel Protocol Tests

@Suite("VideoGenerationModel Protocol")
struct VideoGenerationModelProtocolTests {

    @Test func conformanceOpenAI() {
        let _: any VideoGenerationModel = OpenAIVideoGenerationModel(apiKey: "test")
    }

    @Test func conformanceXAI() {
        let _: any VideoGenerationModel = XAIVideoGenerationModel(apiKey: "test")
    }

    @Test func conformanceGemini() {
        let _: any VideoGenerationModel = GeminiVideoGenerationModel(apiKey: "test")
    }
}
