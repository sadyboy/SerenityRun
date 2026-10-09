import Foundation
import UIKit
import SwiftUI
import OneSignalFramework
import SwiftUI
import AppTrackingTransparency
import AdjustSdk
import OneSignalFramework

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    static var orientationLock: UIInterfaceOrientationMask = .all
    static let attAnsweredKey = "rafael"
    private var attInFlight = false

    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        AppDelegate.orientationLock
    }

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        UserDefaults.standard.set(
            ATTrackingManager.trackingAuthorizationStatus != .notDetermined,
            forKey: Self.attAnsweredKey
        )

        if let config = ADJConfig(appToken: "obf8mvgsirk0",
                                  environment: ADJEnvironmentProduction) {
            config.logLevel = .verbose
            config.attConsentWaitingInterval = 20
            Adjust.initSdk(config)
        }

        start()
        OneSignal.initialize("a27f8be1-77d9-455b-a193-bfa9589f8ee5", withLaunchOptions: launchOptions)
        return true
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        requestATTIfNeeded()
    }
    private func start() {
        self.window = .init()
        let rootViewController = UIHostingController(rootView: ContentView())
        self.window?.rootViewController = rootViewController
        self.window?.makeKeyAndVisible()
    }

    private func requestATTIfNeeded() {
        guard !attInFlight,
              ATTrackingManager.trackingAuthorizationStatus == .notDetermined else { return }
        attInFlight = true

        Task {
            defer { attInFlight = false }
            try? await Task.sleep(for: .seconds(1))

            guard UIApplication.shared.applicationState == .active else { return }

            let status = await Adjust.requestAppTrackingAuthorization()

            let answered = ATTrackingManager.trackingAuthorizationStatus != .notDetermined
            UserDefaults.standard.set(answered, forKey: AppDelegate.attAnsweredKey)
            if answered {
                OneSignal.Notifications.requestPermission({ _ in }, fallbackToSettings: false)
            }
        }
    }
}
