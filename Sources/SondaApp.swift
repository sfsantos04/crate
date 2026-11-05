import SwiftUI

@main
struct SondaApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = AppStore.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .task { await store.bootstrap() }
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if store.isSignedIn {
                MainTabs()
            } else {
                LoginView()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                if store.isSignedIn {
                    store.startMonitoring()
                    store.startRealtime()
                    BackgroundRefresh.updateBadge(store: store)
                }
            case .background:
                store.stopMonitoring()
                store.stopRealtime()
                BackgroundRefresh.updateBadge(store: store)
                BackgroundRefresh.schedule()
            case .inactive:
                break
            @unknown default:
                break
            }
        }
        .task {
            BackgroundRefresh.schedule()
        }
    }
}

struct MainTabs: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        TabView {
            DashboardView()
                .tabItem { Label("Servidor", systemImage: "antenna.radiowaves.left.and.right") }
            SearchView()
                .tabItem { Label("Buscar", systemImage: "magnifyingglass") }
            TransfersView()
                .tabItem { Label("Transferências", systemImage: "arrow.down.circle") }
            SocialView()
                .tabItem { Label("Social", systemImage: "bubble.left.and.bubble.right") }
                .badge(store.unreadTotal)
            SettingsView()
                .tabItem { Label("Ajustes", systemImage: "gearshape") }
        }
    }
}

struct StatusBadge: View {
    let connected: Bool
    let loggedIn: Bool

    private var text: String {
        if loggedIn { return "conectado e logado" }
        if connected { return "conectado, sem login" }
        return "desconectado"
    }

    private var color: Color {
        if loggedIn { return .green }
        if connected { return .orange }
        return .red
    }

    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 9, height: 9)
            Text(text).font(.caption).foregroundStyle(.secondary)
        }
    }
}

struct ErrorBanner: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.footnote)
            .foregroundStyle(.red)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
    }
}
