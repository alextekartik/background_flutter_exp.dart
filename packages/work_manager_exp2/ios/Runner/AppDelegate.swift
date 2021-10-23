import UIKit
import Flutter
import workmanager

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    // Other intialization code…

    // Allow plugins in work manager
    WorkmanagerPlugin.setPluginRegistrantCallback { registry in
                 // The following code will be called upon WorkmanagerPlugin's registration.
                 // Note : all of the app's plugins may not be required in this context ;
                 // instead of using GeneratedPluginRegistrant.register(with: registry),
                 // you may want to register only specific plugins.
        GeneratedPluginRegistrant.register(with: registry)
             }
    // Flutter local notification
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
    }
    UIApplication.shared.setMinimumBackgroundFetchInterval(TimeInterval(60*15))
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
