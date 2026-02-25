/// A model that generates images from text prompts.
///
/// Conform to this protocol to provide text-to-image generation capabilities
/// through a specific provider such as OpenAI or Gemini.
///
/// ```swift
/// let model = OpenAIImageGenerationModel(
///     apiKey: "your-api-key",
///     model: "gpt-image-1"
/// )
///
/// let result = try await model.generateImages(
///     for: "A cat sitting on a windowsill at sunset",
///     options: ImageGenerationOptions(numberOfImages: 1, size: .square)
/// )
/// ```
public protocol ImageGenerationModel: Sendable {
    associatedtype UnavailableReason

    /// The type of custom image generation options this model accepts.
    ///
    /// Models can define their own custom options types with extended properties
    /// by setting this to a custom type conforming to ``CustomImageGenerationOptions``.
    /// The default is `Never`, indicating no custom options are supported.
    associatedtype CustomImageGenerationOptions: AnyLanguageModel.CustomImageGenerationOptions = Never

    /// The availability status for this image generation model.
    var availability: Availability<UnavailableReason> { get }

    /// Generates images from a text prompt.
    ///
    /// - Parameters:
    ///   - prompt: The text description of the image to generate.
    ///   - options: Options controlling image generation behavior.
    /// - Returns: A ``GeneratedImage`` containing the generated images.
    func generateImages(
        for prompt: String,
        options: ImageGenerationOptions
    ) async throws -> GeneratedImage
}

// MARK: - Default Implementations

extension ImageGenerationModel {
    /// Whether this image generation model is currently available.
    public var isAvailable: Bool {
        if case .available = availability {
            return true
        } else {
            return false
        }
    }
}

extension ImageGenerationModel where UnavailableReason == Never {
    public var availability: Availability<UnavailableReason> {
        return .available
    }
}
