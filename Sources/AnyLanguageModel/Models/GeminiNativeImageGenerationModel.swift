import Foundation
import JSONSchema

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

/// An image generation model that uses Gemini's native generateContent API
/// with image output modalities.
///
/// This model uses Gemini models that support image generation through the
/// standard `generateContent` endpoint with `responseModalities: ["TEXT", "IMAGE"]`.
///
/// ```swift
/// let model = GeminiNativeImageGenerationModel(
///     apiKey: "your-api-key",
///     model: "gemini-2.0-flash-preview-image-generation"
/// )
///
/// let result = try await model.generateImages(
///     for: "Draw a cute robot waving hello",
///     options: ImageGenerationOptions()
/// )
/// ```
public struct GeminiNativeImageGenerationModel: ImageGenerationModel {
    public typealias UnavailableReason = Never

    /// The default base URL for the Gemini API.
    public static let defaultBaseURL = URL(string: "https://generativelanguage.googleapis.com")!

    /// The default API version.
    public static let defaultAPIVersion = "v1beta"

    /// Custom image generation options specific to Gemini native image generation.
    public struct CustomImageGenerationOptions: AnyLanguageModel.CustomImageGenerationOptions {
        /// Creates custom image generation options for Gemini native image generation.
        public init() {}
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

    /// Creates a Gemini native image generation model.
    ///
    /// - Parameters:
    ///   - baseURL: The base URL for the Gemini API.
    ///   - apiVersion: The API version to use.
    ///   - apiKey: Your Gemini API key or a closure that returns it.
    ///   - model: The model identifier.
    ///   - session: The URL session to use for network requests.
    public init(
        baseURL: URL = defaultBaseURL,
        apiVersion: String = defaultAPIVersion,
        apiKey tokenProvider: @escaping @autoclosure @Sendable () -> String,
        model: String = "gemini-2.0-flash-preview-image-generation",
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

    public func generateImages(
        for prompt: String,
        options: ImageGenerationOptions
    ) async throws -> GeneratedImage {
        let url =
            baseURL
            .appendingPathComponent(apiVersion)
            .appendingPathComponent("models/\(model):generateContent")
        let body = createRequestBody(prompt: prompt, options: options)
        let bodyData = try JSONEncoder().encode(body)

        let response: GeminiNativeResponse = try await urlSession.fetch(
            .post,
            url: url,
            headers: [
                "x-goog-api-key": tokenProvider()
            ],
            body: bodyData
        )

        var images: [Transcript.ImageSegment] = []
        var revisedPrompt: String?

        if let candidates = response.candidates {
            for candidate in candidates {
                if let parts = candidate.content?.parts {
                    for part in parts {
                        if let inlineData = part.inlineData,
                            let data = Data(base64Encoded: inlineData.data)
                        {
                            images.append(
                                Transcript.ImageSegment(
                                    data: data,
                                    mimeType: inlineData.mimeType
                                )
                            )
                        } else if let text = part.text {
                            if revisedPrompt == nil {
                                revisedPrompt = text
                            } else {
                                revisedPrompt = (revisedPrompt ?? "") + text
                            }
                        }
                    }
                }
            }
        }

        return GeneratedImage(images: images, revisedPrompt: revisedPrompt)
    }
}

// MARK: - Request Body

extension GeminiNativeImageGenerationModel {
    func createRequestBody(
        prompt: String,
        options: ImageGenerationOptions
    ) -> [String: JSONValue] {
        let contents: JSONValue = .object([
            "role": .string("user"),
            "parts": .array([
                .object(["text": .string(prompt)])
            ]),
        ])

        var generationConfig: [String: JSONValue] = [
            "responseModalities": .array([.string("TEXT"), .string("IMAGE")])
        ]

        if let n = options.numberOfImages {
            generationConfig["candidateCount"] = .int(n)
        }

        return [
            "contents": .array([contents]),
            "generationConfig": .object(generationConfig),
        ]
    }
}

// MARK: - Response Types

private struct GeminiNativeResponse: Decodable, Sendable {
    let candidates: [GeminiNativeCandidate]?
}

private struct GeminiNativeCandidate: Decodable, Sendable {
    let content: GeminiNativeContent?
}

private struct GeminiNativeContent: Decodable, Sendable {
    let parts: [GeminiNativePart]?
}

private struct GeminiNativePart: Decodable, Sendable {
    let text: String?
    let inlineData: GeminiNativeInlineData?
}

private struct GeminiNativeInlineData: Decodable, Sendable {
    let mimeType: String
    let data: String
}
