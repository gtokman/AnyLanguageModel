import Foundation

/// A protocol for model-specific video generation options.
///
/// Conform to this protocol to define custom options that are specific to a
/// particular video generation model implementation. These options can be accessed
/// through the ``VideoGenerationOptions`` subscript.
///
/// ```swift
/// extension MyVideoGenerationModel {
///     public struct CustomVideoGenerationOptions: AnyLanguageModel.CustomVideoGenerationOptions {
///         public var customParameter: String?
///     }
/// }
/// ```
public protocol CustomVideoGenerationOptions: Equatable, Sendable {}

extension Never: CustomVideoGenerationOptions {}

/// Options that control how a video generation model produces videos from a prompt.
///
/// Create a ``VideoGenerationOptions`` structure when you want to adjust
/// the aspect ratio, duration, or pass model-specific options.
public struct VideoGenerationOptions: Sendable, Equatable {
    /// The desired aspect ratio of the generated video.
    public enum AspectRatio: String, Sendable, Equatable {
        /// A square video (1:1).
        case square = "1:1"

        /// A landscape video (16:9).
        case landscape = "16:9"

        /// A portrait video (9:16).
        case portrait = "9:16"
    }

    /// The desired aspect ratio of the generated video.
    public var aspectRatio: AspectRatio?

    /// The desired duration of the generated video in seconds.
    public var durationSeconds: Int?

    /// Storage for model-specific custom options.
    private var customOptionsStorage: CustomVideoOptionsStorage = .init()

    /// Accesses model-specific custom video generation options.
    ///
    /// Use this subscript to set or retrieve custom options that are specific
    /// to a particular video generation model implementation.
    ///
    /// ```swift
    /// var options = VideoGenerationOptions()
    /// options[custom: OpenAIVideoGenerationModel.self] = .init(
    ///     size: "1280x720"
    /// )
    /// ```
    ///
    /// - Parameter modelType: The video generation model type to get or set custom options for.
    /// - Returns: The custom options for the specified model type, or `nil` if none are set.
    public subscript<Model: VideoGenerationModel>(
        custom modelType: Model.Type
    ) -> Model.CustomVideoGenerationOptions? {
        get {
            customOptionsStorage[Model.self]
        }
        set {
            customOptionsStorage[Model.self] = newValue
        }
    }

    /// Creates video generation options.
    ///
    /// - Parameters:
    ///   - aspectRatio: The desired aspect ratio of the generated video.
    ///   - durationSeconds: The desired duration of the generated video in seconds.
    public init(
        aspectRatio: AspectRatio? = nil,
        durationSeconds: Int? = nil
    ) {
        self.aspectRatio = aspectRatio
        self.durationSeconds = durationSeconds
    }
}

// MARK: - CustomVideoOptionsStorage

/// Storage for model-specific custom video generation options.
private struct CustomVideoOptionsStorage: Sendable, Equatable {
    private var storage: [ObjectIdentifier: AnyCustomVideoOptions] = [:]

    init() {}

    subscript<Model: VideoGenerationModel>(modelType: Model.Type) -> Model.CustomVideoGenerationOptions? {
        get {
            guard let wrapper = storage[ObjectIdentifier(modelType)] else {
                return nil
            }
            return wrapper.value as? Model.CustomVideoGenerationOptions
        }
        set {
            if let newValue {
                storage[ObjectIdentifier(modelType)] = AnyCustomVideoOptions(newValue)
            } else {
                storage.removeValue(forKey: ObjectIdentifier(modelType))
            }
        }
    }

    static func == (lhs: CustomVideoOptionsStorage, rhs: CustomVideoOptionsStorage) -> Bool {
        guard lhs.storage.count == rhs.storage.count else { return false }
        for (key, lhsWrapper) in lhs.storage {
            guard let rhsWrapper = rhs.storage[key],
                lhsWrapper.isEqual(to: rhsWrapper)
            else {
                return false
            }
        }
        return true
    }
}

// MARK: - AnyCustomVideoOptions

/// A type-erased wrapper for custom video generation options.
private struct AnyCustomVideoOptions: Sendable {
    let value: any CustomVideoGenerationOptions
    let equalsImpl: @Sendable (any CustomVideoGenerationOptions) -> Bool

    init<T: CustomVideoGenerationOptions>(_ value: T) {
        self.value = value
        self.equalsImpl = { other in
            guard let otherTyped = other as? T else { return false }
            return value == otherTyped
        }
    }

    func isEqual(to other: AnyCustomVideoOptions) -> Bool {
        equalsImpl(other.value)
    }
}
