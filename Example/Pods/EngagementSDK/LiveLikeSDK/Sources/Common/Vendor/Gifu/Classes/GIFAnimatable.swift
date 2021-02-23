#if os(iOS) || os(tvOS)
import Foundation
import UIKit

/// The protocol that view classes need to conform to to enable animated GIF support.
protocol GIFAnimatable: class {
  /// Responsible for managing the animation frames.
  var animator: Animator? { get set }

  /// Notifies the instance that it needs display.
  var layer: CALayer { get }

  /// View frame used for resizing the frames.
  var frame: CGRect { get set }

  /// Content mode used for resizing the frames.
  var contentMode: UIView.ContentMode { get set }
}

/// A single-property protocol that animatable classes can optionally conform to.
protocol ImageContainer {
  /// Used for displaying the animation frames.
  var image: UIImage? { get set }
}

extension GIFAnimatable where Self: ImageContainer {
  /// Returns the intrinsic content size based on the size of the image.
  var intrinsicContentSize: CGSize {
    return image?.size ?? CGSize.zero
  }
}

extension GIFAnimatable {
  /// Total duration of one animation loop
  var gifLoopDuration: TimeInterval {
    return animator?.loopDuration ?? 0
  }

  /// Returns the active frame if available.
  var activeFrame: UIImage? {
    return animator?.activeFrame()
  }

  /// Total frame count of the GIF.
  var frameCount: Int {
    return animator?.frameCount ?? 0
  }

  /// Introspect whether the instance is animating.
  var isAnimatingGIF: Bool {
    return animator?.isAnimating ?? false
  }

  /// Prepare for animation and start animating immediately.
  ///
  /// - parameter imageName: The file name of the GIF in the main bundle.
  /// - parameter loopCount: Desired number of loops, <= 0 for infinite loop.
  /// - parameter completionHandler: Completion callback function
  func animate(withGIFNamed imageName: String, loopCount: Int = 0, preparationBlock: (() -> Void)? = nil, animationBlock: (() -> Void)? = nil) {
    DispatchQueue.main.async { [weak self] in
        guard let self = self else { return }
        self.animator?.animate(withGIFNamed: imageName,
                               size: self.frame.size,
                               contentMode: self.contentMode,
                               loopCount: loopCount,
                               preparationBlock: preparationBlock,
                               animationBlock: animationBlock)
    }
  }

  /// Prepare for animation and start animating immediately.
  ///
  /// - parameter imageData: GIF image data.
  /// - parameter loopCount: Desired number of loops, <= 0 for infinite loop.
  /// - parameter completionHandler: Completion callback function
  func animate(withGIFData imageData: Data, loopCount: Int = 0, preparationBlock: (() -> Void)? = nil, animationBlock: (() -> Void)? = nil) {
    DispatchQueue.main.async { [weak self] in
        guard let self = self else { return }
        self.animator?.animate(withGIFData: imageData,
                               size: self.frame.size,
                               contentMode: self.contentMode,
                               loopCount: loopCount,
                               preparationBlock: preparationBlock,
                               animationBlock: animationBlock)
    }
  }

  /// Prepare for animation and start animating immediately.
  ///
  /// - parameter imageURL: GIF image url.
  /// - parameter loopCount: Desired number of loops, <= 0 for infinite loop.
  /// - parameter completionHandler: Completion callback function
  func animate(withGIFURL imageURL: URL, loopCount: Int = 0, preparationBlock: (() -> Void)? = nil, animationBlock: (() -> Void)? = nil) {
    let session = URLSession.shared

    let task = session.dataTask(with: imageURL) { (data, response, error) in
      switch (data, response, error) {
      case (.none, _, let error?):
        print("Error downloading gif:", error.localizedDescription, "at url:", imageURL.absoluteString)
      case (let data?, _, _):
          self.animate(withGIFData: data, loopCount: loopCount, preparationBlock: preparationBlock, animationBlock: animationBlock)
      default: ()
      }
    }

    task.resume()
  }

  /// Prepares the animator instance for animation.
  ///
  /// - parameter imageName: The file name of the GIF in the main bundle.
  /// - parameter loopCount: Desired number of loops, <= 0 for infinite loop.
  func prepareForAnimation(withGIFNamed imageName: String,
                           loopCount: Int = 0,
                           completionHandler: (() -> Void)? = nil) {
    DispatchQueue.main.async { [weak self] in
        guard let self = self else { return }
        self.animator?.prepareForAnimation(withGIFNamed: imageName,
                                           size: self.frame.size,
                                           contentMode: self.contentMode,
                                           loopCount: loopCount,
                                           completionHandler: completionHandler)
    }
  }

  /// Prepare for animation and start animating immediately.
  ///
  /// - parameter imageData: GIF image data.
  /// - parameter loopCount: Desired number of loops, <= 0 for infinite loop.
  func prepareForAnimation(withGIFData imageData: Data,
                           loopCount: Int = 0,
                           completionHandler: (() -> Void)? = nil) {
    DispatchQueue.main.async { [weak self] in
        guard let self = self else { return }
        if var imageContainer = self as? ImageContainer {
          imageContainer.image = UIImage(data: imageData)
        }

        self.animator?.prepareForAnimation(withGIFData: imageData,
                                           size: self.frame.size,
                                           contentMode: self.contentMode,
                                           loopCount: loopCount,
                                           completionHandler: completionHandler)
    }
  }

  /// Prepare for animation and start animating immediately.
  ///
  /// - parameter imageURL: GIF image url.
  /// - parameter loopCount: Desired number of loops, <= 0 for infinite loop.
  func prepareForAnimation(withGIFURL imageURL: URL,
                           loopCount: Int = 0,
                           completionHandler: (() -> Void)? = nil) {
    let session = EngagementSDK.networking.urlSession
    let task = session.dataTask(with: imageURL) { (data, response, error) in
      switch (data, response, error) {
      case (.none, _, let error?):
        print("Error downloading gif:", error.localizedDescription, "at url:", imageURL.absoluteString)
      case (let data?, _, _):
          self.prepareForAnimation(withGIFData: data,
                                   loopCount: loopCount,
                                   completionHandler: completionHandler)
      default: ()
      }
    }

    task.resume()
  }

  /// Stop animating and free up GIF data from memory.
  func prepareForReuse() {
    animator?.prepareForReuse()
  }

  /// Start animating GIF.
  func startAnimatingGIF() {
    animator?.startAnimating()
  }

  /// Stop animating GIF.
  func stopAnimatingGIF() {
    animator?.stopAnimating()
  }

  /// Whether the frame images should be resized or not. The default is `false`, which means that the frame images retain their original size.
  ///
  /// - parameter resize: Boolean value indicating whether individual frames should be resized.
  func setShouldResizeFrames(_ resize: Bool) {
    animator?.shouldResizeFrames = resize
  }

  /// Sets the number of frames that should be buffered. Default is 50. A high number will result in more memory usage and less CPU load, and vice versa.
  ///
  /// - parameter frames: The number of frames to buffer.
  func setFrameBufferCount(_ frames: Int) {
    animator?.frameBufferCount = frames
  }

  /// Updates the image with a new frame if necessary.
  func updateImageIfNeeded() {
    if var imageContainer = self as? ImageContainer {
      let container = imageContainer
      imageContainer.image = activeFrame ?? container.image
    } else {
      layer.contents = activeFrame?.cgImage
    }
  }
}

extension GIFAnimatable {
  /// Calls setNeedsDisplay on the layer whenever the animator has a new frame. Should *not* be called directly.
  func animatorHasNewFrame() {
    layer.setNeedsDisplay()
  }
}
#endif
