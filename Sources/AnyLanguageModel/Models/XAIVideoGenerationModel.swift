import Foundation
import JSONSchema

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

/// A video generation model that connects to xAI's video generation API.
///
/// Use this model to generate videos using xAI's Grok video models.
/// Video generation is asynchronous — a job is created, polled until
/// complete, and then the video is downloaded from the returned URL.
///
/// ```swift
/// let model = XAIVideoGenerationModel(
///     apiKey: "your-api-key",
///     model: "grok-imagine-video"
/// )
///
/// let result = try await model.generateVideo(
///     for: "A cat playing with a ball of yarn",
///     options: VideoGenerationOptions(aspectRatio: .landscape)
/// )
/// ```
public struct XAIVideoGenerationModel: VideoGenerationModel {
    public typealias UnavailableReason = Never

    /// The default base URL for xAI's API.
    public static let defaultBaseURL = URL(string: "https://api.x.ai/v1/")!

    /// Custom video generation options specific to xAI.
    public struct CustomVideoGenerationOptions: AnyLanguageModel.CustomVideoGenerationOptions {
        /// The resolution of the generated video.
        public var resolution: Resolution?

        /// The polling interval in seconds.
        public var pollInterval: TimeInterval?

        /// Additional parameters to include in the request body.
        public var extraBody: [String: JSONValue]?

        /// Video resolution options.
        public enum Resolution: String, Sendable, Equatable {
            case _480p = "480p"
            case _720p = "720p"
        }

        /// Creates custom video generation options for xAI.
        ///
        /// - Parameters:
        ///   - resolution: The resolution of the generated video.
        ///   - pollInterval: The polling interval in seconds.
        ///   - extraBody: Additional parameters for the request body.
        public init(
            resolution: Resolution? = nil,
            pollInterval: TimeInterval? = nil,
            extraBody: [String: JSONValue]? = nil
        ) {
            self.resolution = resolution
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

    /// Creates an xAI video generation model.
    ///
    /// - Parameters:
    ///   - baseURL: The base URL for the API endpoint. Defaults to xAI's official API.
    ///   - apiKey: Your xAI API key or a closure that returns it.
    ///   - model: The model identifier (for example, "grok-imagine-video").
    ///   - session: The URL session to use for network requests.
    public init(
        baseURL: URL = defaultBaseURL,
        apiKey tokenProvider: @escaping @autoclosure @Sendable () -> String,
        model: String = "grok-imagine-video",
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
        let url = baseURL.appendingPathComponent("videos/generations")
        let body = createRequestBody(prompt: prompt, options: options)
        let bodyData = try JSONEncoder().encode(body)

        let headers = ["Authorization": "Bearer \(tokenProvider())"]

        // Create the video generation job
        let createResponse: XAIVideoCreateResponse = try await urlSession.fetch(
            .post,
            url: url,
            headers: headers,
            body: bodyData
        )

        let requestId = createResponse.request_id
        let customOptions = options[custom: XAIVideoGenerationModel.self]
        let pollInterval = customOptions?.pollInterval ?? 10

        // Poll until complete
        let pollURL = baseURL.appendingPathComponent("videos/\(requestId)")
        let statusResponse: XAIVideoStatusResponse = try await urlSession.poll(
            url: pollURL,
            headers: headers,
            interval: pollInterval
        ) { (response: XAIVideoStatusResponse) in
            response.status == "done" || response.status == "expired"
        }

        guard statusResponse.status == "done" else {
            throw URLSessionError.httpError(
                statusCode: 500,
                detail: "Video generation failed with status: \(statusResponse.status)"
            )
        }

        var videos: [Transcript.VideoSegment] = []

        if let videoInfo = statusResponse.video, let urlString = videoInfo.url,
            let videoURL = URL(string: urlString)
        {
            // Download the video from the returned URL
            var request = URLRequest(url: videoURL)
            request.httpMethod = "GET"

            let (data, response) = try await urlSession.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                (200..<300).contains(httpResponse.statusCode)
            else {
                throw URLSessionError.httpError(
                    statusCode: (response as? HTTPURLResponse)?.statusCode ?? 500,
                    detail: "Failed to download video content"
                )
            }

            videos.append(Transcript.VideoSegment(data: data, mimeType: "video/mp4"))
        }

        return GeneratedVideo(videos: videos)
    }
}

// MARK: - Request Body

extension XAIVideoGenerationModel {
    func createRequestBody(
        prompt: String,
        options: VideoGenerationOptions
    ) -> [String: JSONValue] {
        var body: [String: JSONValue] = [
            "model": .string(model),
            "prompt": .string(prompt),
        ]

        if let durationSeconds = options.durationSeconds {
            body["duration"] = .int(durationSeconds)
        }

        if let aspectRatio = options.aspectRatio {
            body["aspect_ratio"] = .string(aspectRatio.rawValue)
        }

        let customOptions = options[custom: XAIVideoGenerationModel.self]

        if let resolution = customOptions?.resolution {
            body["resolution"] = .string(resolution.rawValue)
        }

        // Merge extraBody last to allow overrides
        if let extraBody = customOptions?.extraBody {
            for (key, value) in extraBody {
                body[key] = value
            }
        }

        return body
    }
}

// MARK: - Response Types

private struct XAIVideoCreateResponse: Decodable, Sendable {
    let request_id: String
}

private struct XAIVideoStatusResponse: Decodable, Sendable {
    let status: String
    let video: XAIVideoInfo?
}

private struct XAIVideoInfo: Decodable, Sendable {
    let url: String?
}
