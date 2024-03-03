
import SwiftUI

enum TabScreen: Hashable, Identifiable, CaseIterable {
    
    case home
    case check
    case history
    case settings

    var id: TabScreen { self }
}

extension TabScreen {
    
    @ViewBuilder
    var label: some View {
        switch self {
        case .home:
            Label("Home", systemImage: "house.fill")
        case .check:
            Label("Check", systemImage: "barcode.viewfinder")
        case .history:
            Label("History", systemImage: "clock.arrow.circlepath")
        case .settings:
            Label("Settings", systemImage: "gearshape.fill")
        }
    }
    
    @MainActor @ViewBuilder
    var destination: some View {
        switch self {
        case .home:
            HomeTab()
        case .check:
            CheckTab()
        case .history:
            HistoryTab()
        case .settings:
            SettingsTab()
        }
    }
}

enum Sheets: Identifiable {

    case feedback(FeedbackConfig)

    var id: String {
        switch self {
        case .feedback:
            return "feedback"
        }
    }
}

struct CheckTabState {
    var routes: [CapturedItem] = []
    var capturedImages: [ProductImage] = []
}

struct HistoryTabState {
    var routes: [DTO.HistoryItem] = []
    var historyItems: [DTO.HistoryItem] = []
}

@Observable class AppState {
    var activeSheet: Sheets?
    var activeTab: TabScreen = .home
    var checkTabState = CheckTabState()
    var historyTabState = HistoryTabState()
}

struct LoggedInRootView: View {

    @State private var userPreferences: UserPreferences = UserPreferences()
    @State private var appState = AppState()
    
    @Environment(WebService.self) var webService

    var body: some View {
        TabView(selection: selectedTab) {
            ForEach(TabScreen.allCases) { screen in
                screen.destination
                    .tag(screen as TabScreen?)
                    .tabItem { screen.label }
            }
        }
        .environment(userPreferences)
        .environment(appState)
        .onAppear {
            if !userPreferences.preferences.isEmpty {
                appState.activeTab = .check
            }
        }
        .sheet(item: $appState.activeSheet) { sheet in
            switch sheet {
            case .feedback(let feedbackConfig):
                FeedbackView(
                    feedbackData: feedbackConfig.feedbackData,
                    feedbackCaptureOptions: feedbackConfig.feedbackCaptureOptions,
                    onSubmit: feedbackConfig.onSubmit
                )
                .environment(userPreferences)
            }
        }
    }
    
    var selectedTab: Binding<TabScreen> {
        return .init {
            return appState.activeTab
        } set: { newValue in
            if newValue == appState.activeTab {
                switch newValue {
                case .check:
                    appState.checkTabState.routes = []
                case .history:
                    appState.historyTabState.routes = []
                default:
                    break
                }
            } else {
                switch newValue {
                case .history:
                    refreshHistory()
                default:
                    break
                }
            }
            appState.activeTab = newValue
        }
    }
    
    private func refreshHistory() {
        Task {
            if let history = try? await webService.fetchHistory() {
                appState.historyTabState.historyItems = history
            }
        }
    }
}
