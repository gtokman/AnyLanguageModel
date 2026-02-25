/// The result of an image generation request.
///
/// Contains one or more generated images and an optional revised prompt
/// that the model may have modified from the original input.
public struct GeneratedImage: Sendable {
    /// The generated images.
    public let images: [Transcript.ImageSegment]

    /// A revised version of the prompt, if the model modified it.
    ///
    /// Some models (such as DALL-E 3) may rewrite the user's prompt
    /// to improve the generated image. When available, the revised
    /// prompt is provided here.
    public let revisedPrompt: String?

    /// Creates a generated image result.
    ///
    /// - Parameters:
    ///   - images: The generated images.
    ///   - revisedPrompt: An optional revised prompt from the model.
    public init(images: [Transcript.ImageSegment], revisedPrompt: String? = nil) {
        self.images = images
        self.revisedPrompt = revisedPrompt
    }
}
