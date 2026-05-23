import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate, UIDocumentPickerDelegate {
  private var pendingConfigPickResult: FlutterResult?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    registerConfigFilePicker(messenger: engineBridge.applicationRegistrar.messenger())
  }

  private func registerConfigFilePicker(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "queue_monitor/config_file_picker",
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "pickJsonText":
        self?.pickJsonText(result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func pickJsonText(result: @escaping FlutterResult) {
    guard pendingConfigPickResult == nil else {
      result(
        FlutterError(
          code: "BUSY",
          message: "A config file picker is already open.",
          details: nil
        )
      )
      return
    }
    guard let presenter = topViewController() else {
      result(
        FlutterError(
          code: "NO_PRESENTING_VIEW",
          message: "Cannot present the file picker from the current view.",
          details: nil
        )
      )
      return
    }

    pendingConfigPickResult = result
    let picker = UIDocumentPickerViewController(
      documentTypes: ["public.json", "public.text", "public.data"],
      in: .import
    )
    picker.delegate = self
    picker.allowsMultipleSelection = false
    presenter.present(picker, animated: true)
  }

  func documentPicker(
    _ controller: UIDocumentPickerViewController,
    didPickDocumentsAt urls: [URL]
  ) {
    guard let result = pendingConfigPickResult else {
      return
    }
    pendingConfigPickResult = nil
    guard let url = urls.first else {
      result(nil)
      return
    }

    let accessing = url.startAccessingSecurityScopedResource()
    defer {
      if accessing {
        url.stopAccessingSecurityScopedResource()
      }
    }

    do {
      result(try String(contentsOf: url, encoding: .utf8))
    } catch {
      result(
        FlutterError(
          code: "READ_FAILED",
          message: error.localizedDescription,
          details: nil
        )
      )
    }
  }

  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    pendingConfigPickResult?(nil)
    pendingConfigPickResult = nil
  }

  private func topViewController() -> UIViewController? {
    let root = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap(\.windows)
      .first { $0.isKeyWindow }?
      .rootViewController

    var current = root
    while let presented = current?.presentedViewController {
      current = presented
    }
    return current
  }
}
