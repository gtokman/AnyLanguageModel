import Foundation
import JSONSchema

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

/// An image generation model that connects to OpenAI's Images API.
///
/// Use this model to generate images using OpenAI's DALL-E or GPT Image models.
///
/// ```swift
/// let model = OpenAIImageGenerationModel(
///     apiKey: "your-api-key",
///     model: "gpt-image-1"
/// )
///
/// let result = try await model.generateImages(
///     for: "A watercolor painting of a sunset over mountains",
///     options: ImageGenerationOptions(size: .landscape)
/// )
/// ```
public struct OpenAIImageGenerationModel: ImageGenerationModel {
    public typealias UnavailableReason = Never

    /// The default base URL for OpenAI's API.
    public static let defaultBaseURL = URL(string: "https://api.openai.com/v1/")!

    /// Custom image generation options specific to OpenAI.
    public struct CustomImageGenerationOptions: AnyLanguageModel.CustomImageGenerationOptions {
        /// The quality of the generated image.
        public var quality: Quality?

        /// The background style of the generated image.
        public var background: Background?

        /// The output format of the generated image.
        public var outputFormat: OutputFormat?

        /// The style of the generated image (DALL-E 3 only).
        public var style: Style?

        /// A mask image for inpainting (transparent areas indicate where to edit).
        ///
        /// Only used when `inputImages` is non-empty on the parent options.
        public var mask: Transcript.ImageSegment?

        /// The fidelity level for input images.
        ///
        /// Only used when `inputImages` is non-empty on the parent options.
        public var inputFidelity: InputFidelity?

        /// Additional parameters to include in the request body.
        ///
        /// These parameters are merged into the top-level request JSON,
        /// allowing you to pass vendor-specific options for OpenAI-compatible
        /// image generation APIs (for example, `aspect_ratio` and `resolution`
        /// for xAI's Grok).
        ///
        /// ```swift
        /// options[custom: OpenAIImageGenerationModel.self] = .init(
        ///     extraBody: [
        ///         "aspect_ratio": .string("16:9"),
        ///         "resolution": .string("2k")
        ///     ]
        /// )
        /// ```
        public var extraBody: [String: JSONValue]?

        /// Image quality levels.
        public enum Quality: String, Sendable, Equatable {
            case low
            case medium
            case high
        }

        /// Background transparency options.
        public enum Background: String, Sendable, Equatable {
            case opaque
            case transparent
        }

        /// Output image formats.
        public enum OutputFormat: String, Sendable, Equatable {
            case png
            case jpeg
            case webp
        }

        /// Image style options (DALL-E 3).
        public enum Style: String, Sendable, Equatable {
            case natural
            case vivid
        }

        /// Input image fidelity levels.
        public enum InputFidelity: String, Sendable, Equatable {
            case high
            case low
        }

        /// Creates custom image generation options for OpenAI.
        ///
        /// - Parameters:
        ///   - quality: The quality of the generated image.
        ///   - background: The background style.
        ///   - outputFormat: The output image format.
        ///   - style: The image style (DALL-E 3 only).
        ///   - mask: A mask image for inpainting.
        ///   - inputFidelity: The fidelity level for input images.
        ///   - extraBody: Additional parameters for the request body.
        public init(
            quality: Quality? = nil,
            background: Background? = nil,
            outputFormat: OutputFormat? = nil,
            style: Style? = nil,
            mask: Transcript.ImageSegment? = nil,
            inputFidelity: InputFidelity? = nil,
            extraBody: [String: JSONValue]? = nil
        ) {
            self.quality = quality
            self.background = background
            self.outputFormat = outputFormat
            self.style = style
            self.mask = mask
            self.inputFidelity = inputFidelity
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

    /// Creates an OpenAI image generation model.
    ///
    /// - Parameters:
    ///   - baseURL: The base URL for the API endpoint. Defaults to OpenAI's official API.
    ///   - apiKey: Your OpenAI API key or a closure that returns it.
    ///   - model: The model identifier (for example, "gpt-image-1" or "dall-e-3").
    ///   - session: The URL session to use for network requests.
    public init(
        baseURL: URL = defaultBaseURL,
        apiKey tokenProvider: @escaping @autoclosure @Sendable () -> String,
        model: String = "gpt-image-1",
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

    public func generateImages(
        for prompt: String,
        options: ImageGenerationOptions
    ) async throws -> GeneratedImage {
        let isEdit = !options.inputImages.isEmpty
        let endpoint = isEdit ? "images/edits" : "images/generations"
        let url = baseURL.appendingPathComponent(endpoint)
        let body = try createRequestBody(prompt: prompt, options: options)
        let bodyData = try JSONEncoder().encode(body)

        let response: OpenAIImagesResponse = try await urlSession.fetch(
            .post,
            url: url,
            headers: [
                "Authorization": "Bearer \(tokenProvider())"
            ],
            body: bodyData
        )

        let customOptions = options[custom: OpenAIImageGenerationModel.self]
        let mimeType = mimeTypeForFormat(customOptions?.outputFormat)

        var images: [Transcript.ImageSegment] = []
        var revisedPrompt: String?

        for item in response.data {
            if let b64 = item.b64_json {
                // Strip data URI prefix (e.g. "data:image/png;base64,…") that some
                // OpenAI-compatible providers like xAI return.
                let raw = b64.hasPrefix("data:")
                    ? String(b64[b64.range(of: ",")!.upperBound...])
                    : b64
                if let data = Data(base64Encoded: raw) {
                    images.append(Transcript.ImageSegment(data: data, mimeType: mimeType))
                }
            } else if let urlString = item.url, let url = URL(string: urlString) {
                images.append(Transcript.ImageSegment(url: url))
            }
            if revisedPrompt == nil, let rp = item.revised_prompt {
                revisedPrompt = rp
            }
        }

        return GeneratedImage(images: images, revisedPrompt: revisedPrompt)
    }
}

// MARK: - Request Body

extension OpenAIImageGenerationModel {
    func createRequestBody(
        prompt: String,
        options: ImageGenerationOptions
    ) throws -> [String: JSONValue] {
        var body: [String: JSONValue] = [
            "model": .string(model),
            "prompt": .string(prompt),
        ]

        // gpt-image-1 doesn't support response_format (always returns b64);
        // DALL-E models need it explicitly to get base64 instead of URLs.
        if !model.hasPrefix("gpt-image") {
            body["response_format"] = .string("b64_json")
        }

        if let n = options.numberOfImages {
            body["n"] = .int(n)
        }

        if let size = options.size {
            body["size"] = .string(openAISizeString(size))
        }

        // Add input images for editing
        if !options.inputImages.isEmpty {
            body["image"] = .array(options.inputImages.map { imageSegmentToJSON($0) })
        }

        if let customOptions = options[custom: OpenAIImageGenerationModel.self] {
            if let quality = customOptions.quality {
                body["quality"] = .string(quality.rawValue)
            }
            if let background = customOptions.background {
                body["background"] = .string(background.rawValue)
            }
            if let outputFormat = customOptions.outputFormat {
                body["output_format"] = .string(outputFormat.rawValue)
            }
            if let style = customOptions.style {
                body["style"] = .string(style.rawValue)
            }

            // Add mask for inpainting
            if let mask = customOptions.mask {
                body["mask"] = imageSegmentToJSON(mask)
            }

            // Add input fidelity
            if let inputFidelity = customOptions.inputFidelity {
                body["input_fidelity"] = .string(inputFidelity.rawValue)
            }

            // Merge extraBody last to allow overrides
            if let extraBody = customOptions.extraBody {
                for (key, value) in extraBody {
                    body[key] = value
                }
            }
        }

        return body
    }

    private func imageSegmentToJSON(_ segment: Transcript.ImageSegment) -> JSONValue {
        switch segment.source {
        case .data(let data, let mimeType):
            return .object([
                "type": .string("base64"),
                "media_type": .string(mimeType),
                "data": .string(data.base64EncodedString()),
            ])
        case .url(let url):
            return .object([
                "type": .string("url"),
                "url": .string(url.absoluteString),
            ])
        }
    }

    private func openAISizeString(_ size: ImageGenerationOptions.ImageSize) -> String {
        switch size {
        case .square:
            return "1024x1024"
        case .landscape:
            return "1536x1024"
        case .portrait:
            return "1024x1536"
        case .custom(let width, let height):
            return "\(width)x\(height)"
        }
    }

    private func mimeTypeForFormat(_ format: CustomImageGenerationOptions.OutputFormat?) -> String {
        switch format {
        case .jpeg:
            return "image/jpeg"
        case .webp:
            return "image/webp"
        case .png, .none:
            return "image/png"
        }
    }
}

// MARK: - Response Types

private struct OpenAIImagesResponse: Decodable, Sendable {
    let data: [OpenAIImageData]
}

private struct OpenAIImageData: Decodable, Sendable {
    let b64_json: String?
    let url: String?
    let revised_prompt: String?
}
