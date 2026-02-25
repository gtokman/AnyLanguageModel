import Foundation
import JSONSchema

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

/// An image generation model that connects to Google's Imagen API.
///
/// Use this model to generate images using Imagen models through the
/// Gemini API's predict endpoint.
///
/// ```swift
/// let model = GeminiImagenModel(
///     apiKey: "your-api-key",
///     model: "imagen-3.0-generate-002"
/// )
///
/// let result = try await model.generateImages(
///     for: "A photorealistic image of a mountain lake",
///     options: ImageGenerationOptions(size: .landscape)
/// )
/// ```
public struct GeminiImagenModel: ImageGenerationModel {
    public typealias UnavailableReason = Never

    /// The default base URL for the Gemini API.
    public static let defaultBaseURL = URL(string: "https://generativelanguage.googleapis.com")!

    /// The default API version.
    public static let defaultAPIVersion = "v1beta"

    /// Custom image generation options specific to Gemini Imagen.
    public struct CustomImageGenerationOptions: AnyLanguageModel.CustomImageGenerationOptions {
        /// The MIME type of the output image.
        public var outputMimeType: OutputMimeType?

        /// The safety filter level for generated images.
        public var safetyFilterLevel: SafetyFilterLevel?

        /// Controls whether people can appear in generated images.
        public var personGeneration: PersonGeneration?

        /// A negative prompt describing what to exclude from the image.
        public var negativePrompt: String?

        /// Output image MIME types.
        public enum OutputMimeType: String, Sendable, Equatable {
            case jpeg = "image/jpeg"
            case png = "image/png"
        }

        /// Safety filter levels for image generation.
        public enum SafetyFilterLevel: String, Sendable, Equatable {
            case blockLowAndAbove = "BLOCK_LOW_AND_ABOVE"
            case blockMediumAndAbove = "BLOCK_MEDIUM_AND_ABOVE"
            case blockOnlyHigh = "BLOCK_ONLY_HIGH"
            case blockNone = "BLOCK_NONE"
        }

        /// Person generation settings.
        public enum PersonGeneration: String, Sendable, Equatable {
            case dontAllow = "DONT_ALLOW"
            case allowAdult = "ALLOW_ADULT"
            case allowAll = "ALLOW_ALL"
        }

        /// Creates custom image generation options for Gemini Imagen.
        ///
        /// - Parameters:
        ///   - outputMimeType: The MIME type of the output image.
        ///   - safetyFilterLevel: The safety filter level.
        ///   - personGeneration: Controls person appearance in images.
        ///   - negativePrompt: A negative prompt for exclusions.
        public init(
            outputMimeType: OutputMimeType? = nil,
            safetyFilterLevel: SafetyFilterLevel? = nil,
            personGeneration: PersonGeneration? = nil,
            negativePrompt: String? = nil
        ) {
            self.outputMimeType = outputMimeType
            self.safetyFilterLevel = safetyFilterLevel
            self.personGeneration = personGeneration
            self.negativePrompt = negativePrompt
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

    /// Creates a Gemini Imagen model.
    ///
    /// - Parameters:
    ///   - baseURL: The base URL for the Gemini API.
    ///   - apiVersion: The API version to use.
    ///   - apiKey: Your Gemini API key or a closure that returns it.
    ///   - model: The model identifier (for example, "imagen-3.0-generate-002").
    ///   - session: The URL session to use for network requests.
    public init(
        baseURL: URL = defaultBaseURL,
        apiVersion: String = defaultAPIVersion,
        apiKey tokenProvider: @escaping @autoclosure @Sendable () -> String,
        model: String = "imagen-3.0-generate-002",
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
            .appendingPathComponent("models/\(model):predict")
        let body = createRequestBody(prompt: prompt, options: options)
        let bodyData = try JSONEncoder().encode(body)

        let response: ImagenPredictResponse = try await urlSession.fetch(
            .post,
            url: url,
            headers: [
                "x-goog-api-key": tokenProvider()
            ],
            body: bodyData
        )

        let customOptions = options[custom: GeminiImagenModel.self]
        let mimeType = customOptions?.outputMimeType?.rawValue ?? "image/png"

        var images: [Transcript.ImageSegment] = []
        if let predictions = response.predictions {
            for prediction in predictions {
                if let b64 = prediction.bytesBase64Encoded,
                    let data = Data(base64Encoded: b64)
                {
                    images.append(Transcript.ImageSegment(data: data, mimeType: prediction.mimeType ?? mimeType))
                }
            }
        }

        return GeneratedImage(images: images)
    }
}

// MARK: - Request Body

extension GeminiImagenModel {
    func createRequestBody(
        prompt: String,
        options: ImageGenerationOptions
    ) -> [String: JSONValue] {
        var instances: [String: JSONValue] = [
            "prompt": .string(prompt)
        ]

        let customOptions = options[custom: GeminiImagenModel.self]

        if let negativePrompt = customOptions?.negativePrompt {
            instances["negativePrompt"] = .string(negativePrompt)
        }

        var parameters: [String: JSONValue] = [:]

        if let n = options.numberOfImages {
            parameters["sampleCount"] = .int(n)
        }

        if let size = options.size {
            parameters["aspectRatio"] = .string(imagenAspectRatio(size))
        }

        if let outputMimeType = customOptions?.outputMimeType {
            parameters["outputMimeType"] = .string(outputMimeType.rawValue)
        }

        if let safetyFilterLevel = customOptions?.safetyFilterLevel {
            parameters["safetySetting"] = .string(safetyFilterLevel.rawValue)
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

    private func imagenAspectRatio(_ size: ImageGenerationOptions.ImageSize) -> String {
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

private struct ImagenPredictResponse: Decodable, Sendable {
    let predictions: [ImagenPrediction]?
}

private struct ImagenPrediction: Decodable, Sendable {
    let bytesBase64Encoded: String?
    let mimeType: String?
}
