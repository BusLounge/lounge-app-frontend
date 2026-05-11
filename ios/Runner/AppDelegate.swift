import Flutter
import UIKit
import GoogleMaps

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let channelName = "lounge_owner_app/system_time_updates"
  private var eventSink: FlutterEventSink?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Initialize Google Maps SDK with API key from Info.plist
    if let apiKey = Bundle.main.object(forInfoDictionaryKey: "GOOGLE_MAPS_API_KEY") as? String {
      GMSServices.provideAPIKey(apiKey)
    }
    GeneratedPluginRegistrant.register(with: self)

    if let controller = window?.rootViewController as? FlutterViewController {
      let eventChannel = FlutterEventChannel(
        name: channelName,
        binaryMessenger: controller.binaryMessenger
      )
      eventChannel.setStreamHandler(self)
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}

extension AppDelegate: FlutterStreamHandler {
  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    eventSink = events
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(emitCurrentTime),
      name: NSNotification.Name.NSSystemClockDidChange,
      object: nil
    )
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(emitCurrentTime),
      name: UIApplication.significantTimeChangeNotification,
      object: nil
    )
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(emitCurrentTime),
      name: NSNotification.Name.NSSystemTimeZoneDidChange,
      object: nil
    )
    emitCurrentTime()
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil
    NotificationCenter.default.removeObserver(self)
    return nil
  }

  @objc private func emitCurrentTime() {
    eventSink?(Int(Date().timeIntervalSince1970 * 1000))
  }
}
