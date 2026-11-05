import BackgroundTasks
import Foundation
import UIKit
import UserNotifications

/// Atualização em segundo plano e badge. O iOS decide quando rodar; o app só
/// agenda e aproveita a janela para sincronizar estado e atualizar o badge.
enum BackgroundRefresh {
    static let identifier = "com.samflix.sonda.refresh"

    @MainActor
    static func register(store: AppStore) {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: identifier, using: nil) { task in
            guard let refresh = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            Task { @MainActor in
                await store.refresh()
                updateBadge(store: store)
                refresh.setTaskCompleted(success: true)
                schedule()
            }
        }
    }

    static func schedule() {
        let request = BGAppRefreshTaskRequest(identifier: identifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }

    @MainActor
    static func updateBadge(store: AppStore) {
        guard store.isSignedIn else {
            UNUserNotificationCenter.current().setBadgeCount(0) { _ in }
            return
        }
        let pending = store.unreadTotal + store.activeDownloads.count
        UNUserNotificationCenter.current().setBadgeCount(pending) { _ in }
    }

    static func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.badge, .alert, .sound]) { _, _ in }
    }
}

/// Registrar BGTask tem de acontecer antes do fim do launch; por isso o delegate.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        MainActor.assumeIsolated {
            BackgroundRefresh.register(store: AppStore.shared)
            BackgroundRefresh.requestAuthorization()
        }
        return true
    }
}
