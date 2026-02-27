/// The result of a video generation request.
///
/// Contains one or more generated videos and an optional revised prompt
/// that the model may have modified from the original input.
public struct GeneratedVideo: Sendable {
    /// The generated videos.
    public let videos: [Transcript.VideoSegment]

    /// A revised version of the prompt, if the model modified it.
    ///
    /// Some models may rewrite the user's prompt to improve the generated
    /// video. When available, the revised prompt is provided here.
    public let revisedPrompt: String?

    /// Creates a generated video result.
    ///
    /// - Parameters:
    ///   - videos: The generated videos.
    ///   - revisedPrompt: An optional revised prompt from the model.
    public init(videos: [Transcript.VideoSegment], revisedPrompt: String? = nil) {
        self.videos = videos
        self.revisedPrompt = revisedPrompt
    }
}
