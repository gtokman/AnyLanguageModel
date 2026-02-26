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
/// Supported models include `gemini-2.5-flash-image` and `gemini-3-pro-image-preview`.
///
/// ```swift
/// let model = GeminiNativeImageGenerationModel(
///     apiKey: "your-api-key",
///     model: "gemini-2.5-flash-image"
/// )
///
/// var options = ImageGenerationOptions()
/// options[custom: GeminiNativeImageGenerationModel.self] = .init(
///     aspectRatio: .widescreen,
///     outputMimeType: .png
/// )
///
/// let result = try await model.generateImages(
///     for: "Draw a cute robot waving hello",
///     options: options
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
        /// The aspect ratio of the generated image.
        public var aspectRatio: AspectRatio?

        /// The resolution of the generated image.
        ///
        /// `gemini-3-pro-image-preview` supports all resolutions including `.ultraHD`.
        /// Other models support up to `.hd`.
        public var imageSize: ImageResolution?

        /// The MIME type of the output image.
        public var outputMimeType: OutputMimeType?

        /// Supported aspect ratios for Gemini native image generation.
        public enum AspectRatio: String, Sendable, Hashable {
            /// Square (1:1).
            case square = "1:1"
            /// Portrait (2:3).
            case portrait2x3 = "2:3"
            /// Landscape (3:2).
            case landscape3x2 = "3:2"
            /// Standard portrait (3:4).
            case standardPortrait = "3:4"
            /// Standard landscape (4:3).
            case standard = "4:3"
            /// Tall portrait (4:5).
            case portrait4x5 = "4:5"
            /// Short landscape (5:4).
            case landscape5x4 = "5:4"
            /// Widescreen portrait (9:16).
            case widescreenPortrait = "9:16"
            /// Widescreen landscape (16:9).
            case widescreen = "16:9"
            /// Ultra-wide landscape (21:9).
            case ultraWide = "21:9"
        }

        /// Supported image resolutions for Gemini native image generation.
        public enum ImageResolution: String, Sendable, Hashable {
            /// 512px resolution.
            case small = "512px"
            /// 1K resolution (1024px).
            case standard = "1K"
            /// 2K resolution (2048px).
            case hd = "2K"
            /// 4K resolution (4096px). Only available with `gemini-3-pro-image-preview`.
            case ultraHD = "4K"
        }

        /// Supported output MIME types for Gemini native image generation.
        public enum OutputMimeType: String, Sendable, Hashable {
            case png = "image/png"
            case jpeg = "image/jpeg"
        }

        /// Creates custom image generation options for Gemini native image generation.
        ///
        /// - Parameters:
        ///   - aspectRatio: The aspect ratio of the generated image.
        ///   - imageSize: The resolution of the generated image.
        ///   - outputMimeType: The MIME type of the output image.
        public init(
            aspectRatio: AspectRatio? = nil,
            imageSize: ImageResolution? = nil,
            outputMimeType: OutputMimeType? = nil
        ) {
            self.aspectRatio = aspectRatio
            self.imageSize = imageSize
            self.outputMimeType = outputMimeType
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
        model: String = "gemini-2.5-flash-image",
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
                        if part.thought == true { continue }
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
        var parts: [JSONValue] = []

        // Add input images as inlineData parts before the text prompt
        for image in options.inputImages {
            switch image.source {
            case .data(let data, let mimeType):
                parts.append(.object([
                    "inlineData": .object([
                        "mimeType": .string(mimeType),
                        "data": .string(data.base64EncodedString()),
                    ])
                ]))
            case .url:
                // URL-based images are not supported by Gemini's inlineData format
                break
            }
        }

        parts.append(.object(["text": .string(prompt)]))

        let contents: JSONValue = .object([
            "role": .string("user"),
            "parts": .array(parts),
        ])

        var generationConfig: [String: JSONValue] = [
            "responseModalities": .array([.string("TEXT"), .string("IMAGE")])
        ]

        if let n = options.numberOfImages {
            generationConfig["candidateCount"] = .int(n)
        }

        let customOptions = options[custom: GeminiNativeImageGenerationModel.self]

        var imageConfig: [String: JSONValue] = [:]

        // Custom aspect ratio takes precedence over standard size
        if let aspectRatio = customOptions?.aspectRatio {
            imageConfig["aspectRatio"] = .string(aspectRatio.rawValue)
        } else if let size = options.size {
            imageConfig["aspectRatio"] = .string(nativeAspectRatio(size))
        }

        if let imageSize = customOptions?.imageSize {
            imageConfig["imageSize"] = .string(imageSize.rawValue)
        }

        if let outputMimeType = customOptions?.outputMimeType {
            imageConfig["outputMimeType"] = .string(outputMimeType.rawValue)
        }

        if !imageConfig.isEmpty {
            generationConfig["imageConfig"] = .object(imageConfig)
        }

        return [
            "contents": .array([contents]),
            "generationConfig": .object(generationConfig),
        ]
    }

    private func nativeAspectRatio(_ size: ImageGenerationOptions.ImageSize) -> String {
        switch size {
        case .square:
            return "1:1"
        case .landscape:
            return "16:9"
        case .portrait:
            return "9:16"
        case .custom(let width, let height):
            return "\(width):\(height)"
        }
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
    let thought: Bool?
}

private struct GeminiNativeInlineData: Decodable, Sendable {
    let mimeType: String
    let data: String
}
