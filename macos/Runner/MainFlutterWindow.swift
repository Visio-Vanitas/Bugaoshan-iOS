import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    registerBugaoshanMethodChannel(flutterViewController: flutterViewController)

    super.awakeFromNib()
  }

  private func registerBugaoshanMethodChannel(flutterViewController: FlutterViewController) {
    let channel = FlutterMethodChannel(
      name: "bugaoshan/update",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "importIcsToCalendar":
        guard
          let arguments = call.arguments as? [String: Any],
          let path = arguments["path"] as? String
        else {
          result(FlutterError(
            code: "INVALID_ARGUMENT",
            message: "Path is null",
            details: nil
          ))
          return
        }
        self.importIcsToCalendar(path: path, result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func importIcsToCalendar(path: String, result: @escaping FlutterResult) {
    let fileURL = URL(fileURLWithPath: path)
    guard FileManager.default.fileExists(atPath: fileURL.path) else {
      result(FlutterError(
        code: "FILE_NOT_FOUND",
        message: "ICS file not found",
        details: path
      ))
      return
    }

    // macOS Calendar supports importing local .ics files, so opening the file
    // lets the user's default calendar handler present the native import flow.
    let opened = NSWorkspace.shared.open(fileURL)
    if opened {
      result("opened")
    } else {
      result(FlutterError(
        code: "OPEN_FAILED",
        message: "Unable to open ICS file",
        details: path
      ))
    }
  }
}
