import Cocoa
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
      name: "easyshare.desktop_drop/events",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    eventChannel.setStreamHandler(dropStreamHandler)
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
}
