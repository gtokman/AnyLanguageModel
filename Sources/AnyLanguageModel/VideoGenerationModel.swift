/// A model that generates videos from text prompts.
///
/// Conform to this protocol to provide text-to-video generation capabilities
/// through a specific provider such as OpenAI (Sora), xAI (Grok), or Gemini (Veo).
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
public protocol VideoGenerationModel: Sendable {
    associatedtype UnavailableReason

    /// The type of custom video generation options this model accepts.
    ///
    /// Models can define their own custom options types with extended properties
    /// by setting this to a custom type conforming to ``CustomVideoGenerationOptions``.
    /// The default is `Never`, indicating no custom options are supported.
    associatedtype CustomVideoGenerationOptions: AnyLanguageModel.CustomVideoGenerationOptions = Never

    /// The availability status for this video generation model.
    var availability: Availability<UnavailableReason> { get }

    /// Generates a video from a text prompt.
    ///
    /// - Parameters:
    ///   - prompt: The text description of the video to generate.
    ///   - options: Options controlling video generation behavior.
    /// - Returns: A ``GeneratedVideo`` containing the generated videos.
    func generateVideo(
        for prompt: String,
        options: VideoGenerationOptions
    ) async throws -> GeneratedVideo
}

// MARK: - Default Implementations

extension VideoGenerationModel {
    /// Whether this video generation model is currently available.
    public var isAvailable: Bool {
        if case .available = availability {
            return true
        } else {
            return false
        }
    }
}

extension VideoGenerationModel where UnavailableReason == Never {
    public var availability: Availability<UnavailableReason> {
        return .available
    }
}
