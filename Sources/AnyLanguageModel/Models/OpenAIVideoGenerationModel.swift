import Foundation
import JSONSchema

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

/// A video generation model that connects to OpenAI's Sora API.
///
/// Use this model to generate videos using OpenAI's Sora models.
/// Video generation is asynchronous — a job is created, polled until
/// complete, and then the video is downloaded.
///
/// ```swift
/// let model = OpenAIVideoGenerationModel(
///     apiKey: "your-api-key",
///     model: "sora-2"
/// )
///
/// let result = try await model.generateVideo(
///     for: "A drone shot of a sunset over the ocean",
///     options: VideoGenerationOptions(aspectRatio: .landscape, durationSeconds: 8)
/// )
/// ```
public struct OpenAIVideoGenerationModel: VideoGenerationModel {
    public typealias UnavailableReason = Never

    /// The default base URL for OpenAI's API.
    public static let defaultBaseURL = URL(string: "https://api.openai.com/v1/")!

    /// Custom video generation options specific to OpenAI Sora.
    public struct CustomVideoGenerationOptions: AnyLanguageModel.CustomVideoGenerationOptions {
        /// The size of the generated video (for example, `"1280x720"`).
        ///
        /// Supported sizes: `480x480`, `720x720`, `1080x1080`,
        /// `720x1280`, `1280x720`, `1080x1920`, `1920x1080`.
        public var size: String?

        /// The polling interval in seconds.
        public var pollInterval: TimeInterval?

        /// Additional parameters to include in the request body.
        public var extraBody: [String: JSONValue]?

        /// Creates custom video generation options for OpenAI Sora.
        ///
        /// - Parameters:
        ///   - size: The size of the generated video.
        ///   - pollInterval: The polling interval in seconds.
        ///   - extraBody: Additional parameters for the request body.
        public init(
            size: String? = nil,
            pollInterval: TimeInterval? = nil,
            extraBody: [String: JSONValue]? = nil
        ) {
            self.size = size
            self.pollInterval = pollInterval
            self.extraBody = extraBody
        }
    }

    /// The base URL for the API endpoint.
    public let baseURL: URL

    /// The closure providing the API key for authentication.
    private let tokenProvider: @Sendable () -> String

    /// The model identifier to use for generation.
    public let model: String

    private let urlSession: URLSession

    /// Creates an OpenAI video generation model.
    ///
    /// - Parameters:
    ///   - baseURL: The base URL for the API endpoint. Defaults to OpenAI's official API.
    ///   - apiKey: Your OpenAI API key or a closure that returns it.
    ///   - model: The model identifier (for example, "sora-2" or "sora-2-pro").
    ///   - session: The URL session to use for network requests.
    public init(
        baseURL: URL = defaultBaseURL,
        apiKey tokenProvider: @escaping @autoclosure @Sendable () -> String,
        model: String = "sora-2",
        session: URLSession = URLSession(configuration: .default)
    ) {
        var baseURL = baseURL
        if !baseURL.path.hasSuffix("/") {
            baseURL = baseURL.appendingPathComponent("")
        }

        self.baseURL = baseURL
        self.tokenProvider = tokenProvider
        self.model = model
        self.urlSession = session
    }

    public func generateVideo(
        for prompt: String,
        options: VideoGenerationOptions
    ) async throws -> GeneratedVideo {
        let url = baseURL.appendingPathComponent("videos")
        let body = createRequestBody(prompt: prompt, options: options)
        let bodyData = try JSONEncoder().encode(body)

        let headers = ["Authorization": "Bearer \(tokenProvider())"]

        // Create the video generation job
        let createResponse: OpenAIVideoCreateResponse = try await urlSession.fetch(
            .post,
            url: url,
            headers: headers,
            body: bodyData
        )

        let videoId = createResponse.id
        let customOptions = options[custom: OpenAIVideoGenerationModel.self]
        let pollInterval = customOptions?.pollInterval ?? 20

        // Poll until complete
        let pollURL = baseURL.appendingPathComponent("videos/\(videoId)")
        let statusResponse: OpenAIVideoStatusResponse = try await urlSession.poll(
            url: pollURL,
            headers: headers,
            interval: pollInterval
        ) { (response: OpenAIVideoStatusResponse) in
            response.status == "completed" || response.status == "failed"
        }

        guard statusResponse.status == "completed" else {
            throw URLSessionError.httpError(
                statusCode: 500,
                detail: "Video generation failed with status: \(statusResponse.status)"
            )
        }

        // Download the video content
        let contentURL = baseURL.appendingPathComponent("videos/\(videoId)/content")
        var contentURLComponents = URLComponents(url: contentURL, resolvingAgainstBaseURL: false)!
        contentURLComponents.queryItems = [URLQueryItem(name: "variant", value: "video")]

        var request = URLRequest(url: contentURLComponents.url!)
        request.httpMethod = "GET"
        request.addValue("Bearer \(tokenProvider())", forHTTPHeaderField: "Authorization")

        let (data, response) = try await urlSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
            (200..<300).contains(httpResponse.statusCode)
        else {
            throw URLSessionError.httpError(
                statusCode: (response as? HTTPURLResponse)?.statusCode ?? 500,
                detail: "Failed to download video content"
            )
        }

        let video = Transcript.VideoSegment(data: data, mimeType: "video/mp4")
        return GeneratedVideo(videos: [video])
    }
}

// MARK: - Request Body

extension OpenAIVideoGenerationModel {
    func createRequestBody(
        prompt: String,
        options: VideoGenerationOptions
    ) -> [String: JSONValue] {
        var body: [String: JSONValue] = [
            "model": .string(model),
            "prompt": .string(prompt),
        ]

        // seconds is a string enum: "4", "8", or "12"
        if let durationSeconds = options.durationSeconds {
            body["seconds"] = .string(String(durationSeconds))
        }

        let customOptions = options[custom: OpenAIVideoGenerationModel.self]

        if let size = customOptions?.size {
            body["size"] = .string(size)
        } else if let aspectRatio = options.aspectRatio {
            body["size"] = .string(openAISizeString(aspectRatio))
        }

        // Merge extraBody last to allow overrides
        if let extraBody = customOptions?.extraBody {
            for (key, value) in extraBody {
                body[key] = value
            }
        }

        return body
    }

    private func openAISizeString(_ aspectRatio: VideoGenerationOptions.AspectRatio) -> String {
        switch aspectRatio {
        case .square:
            return "1080x1080"
        case .landscape:
            return "1280x720"
        case .portrait:
            return "720x1280"
        }
    }
}

// MARK: - Response Types

private struct OpenAIVideoCreateResponse: Decodable, Sendable {
    let id: String
}

private struct OpenAIVideoStatusResponse: Decodable, Sendable {
    let id: String
    let status: String
}
