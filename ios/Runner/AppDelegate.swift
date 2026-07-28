import Flutter
import FamilyControls
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var screenTimeChannel: FlutterMethodChannel?
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "QuestimeScreenTime") else {
      return
    }
    let channel = FlutterMethodChannel(
      name: "com.powerwyze.questime/screen_time",
      binaryMessenger: registrar.messenger()
    )
    screenTimeChannel = channel
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handleScreenTime(call, result: result)
    }
  }

  private func handleScreenTime(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "status":
      result(screenTimeStatus())
    case "requestAuthorization":
      guard #available(iOS 16.0, *) else {
        result(FlutterError(code: "UNAVAILABLE", message: "Screen Time requires iOS 16 or newer.", details: nil))
        return
      }
      Task { @MainActor in
        do {
          try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
          result(nil)
        } catch {
          result(FlutterError(code: "AUTHORIZATION_FAILED", message: error.localizedDescription, details: nil))
        }
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func screenTimeStatus() -> [String: Any] {
    var authorized = false
    if #available(iOS 15.0, *) {
      authorized = AuthorizationCenter.shared.authorizationStatus == .approved
    }
    return [
      "supported": true,
      "authorized": authorized,
      "deviceName": UIDevice.current.model,
      "osVersion": UIDevice.current.systemVersion
    ]
  }
}
