import Foundation

/// A protocol for model-specific image generation options.
///
/// Conform to this protocol to define custom options that are specific to a
/// particular image generation model implementation. These options can be accessed
/// through the ``ImageGenerationOptions`` subscript.
///
/// ```swift
/// extension MyImageGenerationModel {
///     public struct CustomImageGenerationOptions: AnyLanguageModel.CustomImageGenerationOptions {
///         public var customParameter: String?
///     }
/// }
/// ```
public protocol CustomImageGenerationOptions: Equatable, Sendable {}

extension Never: CustomImageGenerationOptions {}

/// Options that control how an image generation model produces images from a prompt.
///
/// Create an ``ImageGenerationOptions`` structure when you want to adjust
/// the number of images generated, their size, or pass model-specific options.
public struct ImageGenerationOptions: Sendable, Equatable {
    /// The desired dimensions of the generated image.
    public enum ImageSize: Sendable, Equatable {
        /// A square image (1024x1024 / 1:1).
        case square

        /// A landscape image (1536x1024 / 16:9).
        case landscape

        /// A portrait image (1024x1536 / 9:16).
        case portrait

        /// A custom size with explicit width and height.
        case custom(width: Int, height: Int)
    }

    /// The number of images to generate.
    public var numberOfImages: Int?

    /// The desired size of the generated images.
    public var size: ImageSize?

    /// Storage for model-specific custom options.
    private var customOptionsStorage: CustomImageOptionsStorage = .init()

    /// Accesses model-specific custom image generation options.
    ///
    /// Use this subscript to set or retrieve custom options that are specific
    /// to a particular image generation model implementation.
    ///
    /// ```swift
    /// var options = ImageGenerationOptions()
    /// options[custom: OpenAIImageGenerationModel.self] = .init(
    ///     quality: .high
    /// )
    /// ```
    ///
    /// - Parameter modelType: The image generation model type to get or set custom options for.
    /// - Returns: The custom options for the specified model type, or `nil` if none are set.
    public subscript<Model: ImageGenerationModel>(
        custom modelType: Model.Type
    ) -> Model.CustomImageGenerationOptions? {
        get {
            customOptionsStorage[Model.self]
        }
        set {
            customOptionsStorage[Model.self] = newValue
        }
    }

    /// Creates image generation options.
    ///
    /// - Parameters:
    ///   - numberOfImages: The number of images to generate.
    ///   - size: The desired size of the generated images.
    public init(
        numberOfImages: Int? = nil,
        size: ImageSize? = nil
    ) {
        self.numberOfImages = numberOfImages
        self.size = size
    }
}

// MARK: - CustomImageOptionsStorage

/// Storage for model-specific custom image generation options.
private struct CustomImageOptionsStorage: Sendable, Equatable {
    private var storage: [ObjectIdentifier: AnyCustomImageOptions] = [:]

    init() {}

    subscript<Model: ImageGenerationModel>(modelType: Model.Type) -> Model.CustomImageGenerationOptions? {
        get {
            guard let wrapper = storage[ObjectIdentifier(modelType)] else {
                return nil
            }
            return wrapper.value as? Model.CustomImageGenerationOptions
        }
        set {
            if let newValue {
                storage[ObjectIdentifier(modelType)] = AnyCustomImageOptions(newValue)
            } else {
                storage.removeValue(forKey: ObjectIdentifier(modelType))
            }
        }
    }

    static func == (lhs: CustomImageOptionsStorage, rhs: CustomImageOptionsStorage) -> Bool {
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

// MARK: - AnyCustomImageOptions

/// A type-erased wrapper for custom image generation options.
private struct AnyCustomImageOptions: Sendable {
    let value: any CustomImageGenerationOptions
    let equalsImpl: @Sendable (any CustomImageGenerationOptions) -> Bool

    init<T: CustomImageGenerationOptions>(_ value: T) {
        self.value = value
        self.equalsImpl = { other in
            guard let otherTyped = other as? T else { return false }
            return value == otherTyped
        }
    }

    func isEqual(to other: AnyCustomImageOptions) -> Bool {
        equalsImpl(other.value)
    }
}
