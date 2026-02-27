import Foundation
import JSONSchema

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

/// A video generation model that connects to Google's Veo API.
///
/// Use this model to generate videos using Google's Veo models through the
/// Gemini API's predictLongRunning endpoint.
///
/// ```swift
/// let model = GeminiVideoGenerationModel(
///     apiKey: "your-api-key",
///     model: "veo-3.1-generate-preview"
/// )
///
/// let result = try await model.generateVideo(
///     for: "A timelapse of clouds moving over a mountain",
///     options: VideoGenerationOptions(aspectRatio: .landscape, durationSeconds: 8)
/// )
/// ```
public struct GeminiVideoGenerationModel: VideoGenerationModel {
    public typealias UnavailableReason = Never

    /// The default base URL for the Gemini API.
    public static let defaultBaseURL = URL(string: "https://generativelanguage.googleapis.com")!

    /// The default API version.
    public static let defaultAPIVersion = "v1beta"

    /// Custom video generation options specific to Gemini Veo.
    public struct CustomVideoGenerationOptions: AnyLanguageModel.CustomVideoGenerationOptions {
        /// The resolution of the generated video.
        public var resolution: Resolution?

        /// A negative prompt describing what to exclude from the video.
        public var negativePrompt: String?

        /// Controls whether people can appear in generated videos.
        public var personGeneration: PersonGeneration?

        /// The polling interval in seconds.
        public var pollInterval: TimeInterval?

        /// Video resolution options.
        public enum Resolution: String, Sendable, Equatable {
            case _720p = "720p"
            case _1080p = "1080p"
            case _4k = "4k"
        }

        /// Person generation settings.
        public enum PersonGeneration: String, Sendable, Equatable {
            case dontAllow = "dont_allow"
            case allowAdult = "allow_adult"
            case allowAll = "allow_all"
        }

        /// Creates custom video generation options for Gemini Veo.
        ///
        /// - Parameters:
        ///   - resolution: The resolution of the generated video.
        ///   - negativePrompt: A negative prompt for exclusions.
        ///   - personGeneration: Controls person appearance in videos.
        ///   - pollInterval: The polling interval in seconds.
        public init(
            resolution: Resolution? = nil,
            negativePrompt: String? = nil,
            personGeneration: PersonGeneration? = nil,
            pollInterval: TimeInterval? = nil
        ) {
            self.resolution = resolution
            self.negativePrompt = negativePrompt
            self.personGeneration = personGeneration
            self.pollInterval = pollInterval
        }
    }

    /// The base URL for the API endpoint.
    public let baseURL: URL

    /// The API version to use.
    public let apiVersion: String

    /// The closure providing the API key for authentication.
    private let tokenProvider: @Sendable () -> String

    /// The model identifier to use for generation.
    public let model: String

    private let urlSession: URLSession

    /// Creates a Gemini video generation model.
    ///
    /// - Parameters:
    ///   - baseURL: The base URL for the Gemini API.
    ///   - apiVersion: The API version to use.
    ///   - apiKey: Your Gemini API key or a closure that returns it.
    ///   - model: The model identifier (for example, "veo-3.1-generate-preview").
    ///   - session: The URL session to use for network requests.
    public init(
        baseURL: URL = defaultBaseURL,
        apiVersion: String = defaultAPIVersion,
        apiKey tokenProvider: @escaping @autoclosure @Sendable () -> String,
        model: String = "veo-3.1-generate-preview",
        session: URLSession = URLSession(configuration: .default)
    ) {
        var baseURL = baseURL
        if !baseURL.path.hasSuffix("/") {
            baseURL = baseURL.appendingPathComponent("")
        }

        self.baseURL = baseURL
        self.apiVersion = apiVersion
        self.tokenProvider = tokenProvider
        self.model = model
        self.urlSession = session
    }

    public func generateVideo(
        for prompt: String,
        options: VideoGenerationOptions
    ) async throws -> GeneratedVideo {
        let url =
            baseURL
            .appendingPathComponent(apiVersion)
            .appendingPathComponent("models/\(model):predictLongRunning")
        let body = createRequestBody(prompt: prompt, options: options)
        let bodyData = try JSONEncoder().encode(body)

        let headers = ["x-goog-api-key": tokenProvider()]

        // Create the long-running operation
        let createResponse: GeminiOperationResponse = try await urlSession.fetch(
            .post,
            url: url,
            headers: headers,
            body: bodyData
        )

        let customOptions = options[custom: GeminiVideoGenerationModel.self]
        let pollInterval = customOptions?.pollInterval ?? 10

        // Poll until complete
        let operationName = createResponse.name
        let pollURL =
            baseURL
            .appendingPathComponent(apiVersion)
            .appendingPathComponent(operationName)

        let operationResponse: GeminiOperationResponse = try await urlSession.poll(
            url: pollURL,
            headers: headers,
            interval: pollInterval
        ) { (response: GeminiOperationResponse) in
            response.done == true
        }

        var videos: [Transcript.VideoSegment] = []

        if let videoResponse = operationResponse.response,
            let generateVideoResponse = videoResponse.generateVideoResponse,
            let generatedSamples = generateVideoResponse.generatedSamples
        {
            for sample in generatedSamples {
                if let uri = sample.video?.uri, let videoURL = URL(string: uri) {
                    videos.append(Transcript.VideoSegment(url: videoURL))
                }
            }
        }

        return GeneratedVideo(videos: videos)
    }
}

// MARK: - Request Body

extension GeminiVideoGenerationModel {
    func createRequestBody(
        prompt: String,
        options: VideoGenerationOptions
    ) -> [String: JSONValue] {
        var instances: [String: JSONValue] = [
            "prompt": .string(prompt)
        ]

        let customOptions = options[custom: GeminiVideoGenerationModel.self]

        if let negativePrompt = customOptions?.negativePrompt {
            instances["negativePrompt"] = .string(negativePrompt)
        }

        var parameters: [String: JSONValue] = [:]

        if let aspectRatio = options.aspectRatio {
            // Veo supports "16:9" (default) and "9:16" only.
            // Map .square to "16:9" as a fallback since "1:1" is not supported.
            switch aspectRatio {
            case .landscape:
                parameters["aspectRatio"] = .string("16:9")
            case .portrait:
                parameters["aspectRatio"] = .string("9:16")
            case .square:
                parameters["aspectRatio"] = .string("16:9")
            }
        }

        // durationSeconds is a string enum: "4", "6", or "8"
        if let durationSeconds = options.durationSeconds {
            parameters["durationSeconds"] = .string(String(durationSeconds))
        }

        if let resolution = customOptions?.resolution {
            parameters["resolution"] = .string(resolution.rawValue)
        }

        if let personGeneration = customOptions?.personGeneration {
            parameters["personGeneration"] = .string(personGeneration.rawValue)
        }

        var body: [String: JSONValue] = [
            "instances": .array([.object(instances)])
        ]

        if !parameters.isEmpty {
            body["parameters"] = .object(parameters)
        }

        return body
    }
}

// MARK: - Response Types

private struct GeminiOperationResponse: Decodable, Sendable {
    let name: String
    let done: Bool?
    let response: GeminiOperationResult?
}

private struct GeminiOperationResult: Decodable, Sendable {
    let generateVideoResponse: GeminiGenerateVideoResponse?
}

private struct GeminiGenerateVideoResponse: Decodable, Sendable {
    let generatedSamples: [GeminiGeneratedSample]?
}

private struct GeminiGeneratedSample: Decodable, Sendable {
    let video: GeminiVideoData?
}

private struct GeminiVideoData: Decodable, Sendable {
    let uri: String?
}
