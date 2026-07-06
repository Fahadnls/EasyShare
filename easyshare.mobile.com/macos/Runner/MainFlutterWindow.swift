import Cocoa
import AVFoundation
import FlutterMacOS

final class DesktopDropStreamHandler: NSObject, FlutterStreamHandler {
  private var eventSink: FlutterEventSink?

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    eventSink = events
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil
    return nil
  }

  func send(paths: [String]) {
    guard !paths.isEmpty else { return }
    eventSink?(paths)
  }
}

class MainFlutterWindow: NSWindow, NSDraggingDestination {
  private let dropStreamHandler = DesktopDropStreamHandler()

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    let eventChannel = FlutterEventChannel(
      name: "nextshare.desktop_drop/events",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    eventChannel.setStreamHandler(dropStreamHandler)
    let platformChannel = FlutterMethodChannel(
      name: "nextshare/platform_files",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    platformChannel.setMethodCallHandler { call, result in
      switch call.method {
      case "openPath":
        guard
          let arguments = call.arguments as? [String: Any],
          let path = arguments["path"] as? String
        else {
          result(false)
          return
        }
        result(NSWorkspace.shared.open(URL(fileURLWithPath: path)))
      case "fileThumbnail":
        guard
          let arguments = call.arguments as? [String: Any],
          let path = arguments["path"] as? String
        else {
          result(nil)
          return
        }
        let maxSize = (arguments["maxSize"] as? NSNumber)?.doubleValue ?? 160
        DispatchQueue.global(qos: .userInitiated).async {
          let bytes = Self.createThumbnail(path: path, maxSize: maxSize)
          DispatchQueue.main.async {
            result(bytes)
          }
        }
      case "persistFolderAccess":
        guard
          let arguments = call.arguments as? [String: Any],
          let path = arguments["path"] as? String
        else {
          result(false)
          return
        }
        do {
          let url = URL(fileURLWithPath: path, isDirectory: true)
          let bookmark = try url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
          )
          UserDefaults.standard.set(bookmark, forKey: "nextshare.saveFolderBookmark")
          result(true)
        } catch {
          result(false)
        }
      case "restoreFolderAccess":
        guard
          let bookmark = UserDefaults.standard.data(forKey: "nextshare.saveFolderBookmark")
        else {
          result(nil)
          return
        }
        do {
          var stale = false
          let url = try URL(
            resolvingBookmarkData: bookmark,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &stale
          )
          if stale {
            let refreshed = try url.bookmarkData(
              options: .withSecurityScope,
              includingResourceValuesForKeys: nil,
              relativeTo: nil
            )
            UserDefaults.standard.set(refreshed, forKey: "nextshare.saveFolderBookmark")
          }
          _ = url.startAccessingSecurityScopedResource()
          result(url.path)
        } catch {
          result(nil)
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    registerForDraggedTypes([.fileURL])

    super.awakeFromNib()
  }

  @objc(draggingEntered:)
  func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
    return .copy
  }

  @objc(prepareForDragOperation:)
  func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
    return true
  }

  @objc(performDragOperation:)
  func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
    let pasteboard = sender.draggingPasteboard
    let options: [NSPasteboard.ReadingOptionKey: Any] = [
      .urlReadingFileURLsOnly: true,
    ]
    guard
      let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: options) as? [URL]
    else {
      return false
    }

    let paths = urls.map(\.path)
    dropStreamHandler.send(paths: paths)
    return !paths.isEmpty
  }

  private static func createThumbnail(path: String, maxSize: Double) -> FlutterStandardTypedData? {
    let url = URL(fileURLWithPath: path)
    guard FileManager.default.fileExists(atPath: url.path) else {
      return nil
    }
    let ext = url.pathExtension.lowercased()
    let imageExts = ["jpg", "jpeg", "png", "gif", "webp", "heic", "heif", "bmp"]
    let videoExts = ["mp4", "mov", "mkv", "avi", "webm", "3gp", "m4v"]

    let image: NSImage?
    if imageExts.contains(ext) {
      image = NSImage(contentsOf: url)
    } else if videoExts.contains(ext) {
      let asset = AVAsset(url: url)
      let generator = AVAssetImageGenerator(asset: asset)
      generator.appliesPreferredTrackTransform = true
      generator.maximumSize = NSSize(width: maxSize, height: maxSize)
      do {
        let cgImage = try generator.copyCGImage(at: .zero, actualTime: nil)
        image = NSImage(cgImage: cgImage, size: NSSize(width: maxSize, height: maxSize))
      } catch {
        image = nil
      }
    } else {
      image = nil
    }

    guard
      let nsImage = image,
      let data = pngData(from: nsImage, maxSize: maxSize)
    else {
      return nil
    }
    return FlutterStandardTypedData(bytes: data)
  }

  private static func pngData(from image: NSImage, maxSize: Double) -> Data? {
    let targetSize = NSSize(width: maxSize, height: maxSize)
    let output = NSImage(size: targetSize)
    output.lockFocus()
    image.draw(
      in: NSRect(origin: .zero, size: targetSize),
      from: .zero,
      operation: .copy,
      fraction: 1
    )
    output.unlockFocus()
    guard
      let tiff = output.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff)
    else {
      return nil
    }
    return bitmap.representation(using: .png, properties: [:])
  }
}
