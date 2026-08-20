import Flutter
import FamilyControls
import ManagedSettings
import SwiftUI
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
    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "ScreenGateScreenTime") else {
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
    case "pickApps":
      guard #available(iOS 16.0, *) else {
        result(FlutterError(code: "UNAVAILABLE", message: "App picking requires iOS 16 or newer.", details: nil))
        return
      }
      presentAppPicker(result: result)
    case "getConfiguration":
      guard #available(iOS 16.0, *) else {
        result(["packages": [], "remainingSeconds": 0])
        return
      }
      let selection = savedSelection()
      result([
        "packages": selection.applicationTokens.isEmpty ? [] : ["ios-selection"],
        "remainingSeconds": UserDefaults.standard.integer(forKey: "screengate_remaining_seconds")
      ])
    case "configure":
      let minutes = call.arguments as? [String: Any]
      let awardedMinutes = minutes?["awardedMinutes"] as? Int ?? 0
      UserDefaults.standard.set(awardedMinutes * 60, forKey: "screengate_remaining_seconds")
      updateShields(shouldBlock: awardedMinutes <= 0)
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  @available(iOS 16.0, *)
  private func presentAppPicker(result: @escaping FlutterResult) {
    guard AuthorizationCenter.shared.authorizationStatus == .approved else {
      result(FlutterError(code: "NOT_AUTHORIZED", message: "A parent must turn on Screen Time first.", details: nil))
      return
    }
    guard let root = UIApplication.shared.connectedScenes
      .compactMap({ $0 as? UIWindowScene })
      .flatMap({ $0.windows })
      .first(where: { $0.isKeyWindow })?.rootViewController else {
      result(FlutterError(code: "NO_WINDOW", message: "The app picker could not open.", details: nil))
      return
    }
    let picker = ScreenGatePicker(
      initialSelection: savedSelection(),
      onSave: { [weak self] selection in
        self?.saveSelection(selection)
        self?.updateShields(shouldBlock: UserDefaults.standard.integer(forKey: "screengate_remaining_seconds") <= 0)
        root.dismiss(animated: true) { result(true) }
      },
      onCancel: { root.dismiss(animated: true) { result(false) } }
    )
    root.present(UIHostingController(rootView: picker), animated: true)
  }

  @available(iOS 16.0, *)
  private func savedSelection() -> FamilyActivitySelection {
    guard let data = UserDefaults.standard.data(forKey: "screengate_family_selection"),
          let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) else {
      return FamilyActivitySelection()
    }
    return selection
  }

  @available(iOS 16.0, *)
  private func saveSelection(_ selection: FamilyActivitySelection) {
    if let data = try? JSONEncoder().encode(selection) {
      UserDefaults.standard.set(data, forKey: "screengate_family_selection")
    }
  }

  private func updateShields(shouldBlock: Bool) {
    guard #available(iOS 16.0, *) else { return }
    let store = ManagedSettingsStore(named: .init("screengate"))
    let selection = savedSelection()
    store.shield.applications = shouldBlock ? selection.applicationTokens : nil
    store.shield.applicationCategories = shouldBlock
      ? .specific(selection.categoryTokens)
      : nil
    store.shield.webDomains = shouldBlock ? selection.webDomainTokens : nil
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

@available(iOS 16.0, *)
private struct ScreenGatePicker: View {
  @State private var selection: FamilyActivitySelection
  let onSave: (FamilyActivitySelection) -> Void
  let onCancel: () -> Void

  init(
    initialSelection: FamilyActivitySelection,
    onSave: @escaping (FamilyActivitySelection) -> Void,
    onCancel: @escaping () -> Void
  ) {
    _selection = State(initialValue: initialSelection)
    self.onSave = onSave
    self.onCancel = onCancel
  }

  var body: some View {
    NavigationStack {
      FamilyActivityPicker(selection: $selection)
        .navigationTitle("Pick apps to block")
        .toolbar {
          ToolbarItem(placement: .cancellationAction) {
            Button("Cancel", action: onCancel)
          }
          ToolbarItem(placement: .confirmationAction) {
            Button("Save") { onSave(selection) }
          }
        }
    }
  }
}
