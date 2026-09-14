import SwiftUI
import SwiftData

// Tab 路由，用于工作台快捷操作跳转
final class TabRouter: ObservableObject {
    @Published var selectedTab: Int = 0
}

@main
struct AgentToolApp: App {
    private let container: ModelContainer
    @StateObject private var tabRouter = TabRouter()

    init() {
        do {
            container = try ModelContainer(for:
                Property.self, RentMonthRecord.self, UtilityQuarterRecord.self,
                DealRecord.self, MiscIncome.self, MiscExpense.self,
                PayoutRecord.self, PayoutMonthRecord.self, ProfitCalculation.self
            )
        } catch {
            let fileManager = FileManager.default
            if let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
                let files = try? fileManager.contentsOfDirectory(at: appSupport, includingPropertiesForKeys: nil)
                for file in files ?? [] {
                    if file.lastPathComponent.hasSuffix(".store") ||
                       file.lastPathComponent.hasSuffix(".store-wal") ||
                       file.lastPathComponent.hasSuffix(".store-shm") {
                        try? fileManager.removeItem(at: file)
                    }
                }
            }
            container = try! ModelContainer(for:
                Property.self, RentMonthRecord.self, UtilityQuarterRecord.self,
                DealRecord.self, MiscIncome.self, MiscExpense.self,
                PayoutRecord.self, PayoutMonthRecord.self, ProfitCalculation.self
            )
        }
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .tint(.themeAccent)
                .environment(\.locale, Locale(identifier: "zh_CN"))
                .environment(\.calendar, Calendar(identifier: .gregorian))
                .environmentObject(tabRouter)
        }
        .modelContainer(container)
    }
}

struct MainTabView: View {
    @EnvironmentObject private var tabRouter: TabRouter

    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(Color.themePanel)
        appearance.selectionIndicatorTintColor = UIColor(Color.themeAccent)
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
        UITabBar.appearance().tintColor = UIColor(Color.themeAccent)
        UITabBar.appearance().unselectedItemTintColor = UIColor(Color.themeText3)

        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()
        navAppearance.backgroundColor = UIColor(Color.themeBg)
        navAppearance.titleTextAttributes = [.foregroundColor: UIColor(Color.themeText)]
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
    }

    var body: some View {
        TabView(selection: $tabRouter.selectedTab) {
            DashboardView()
                .tabItem { Label("工作台", systemImage: "house.fill") }
                .tag(0)

            DealsView()
                .tabItem { Label("成交", systemImage: "doc.text.fill") }
                .tag(1)

            RentCollectionView()
                .tabItem { Label("收租", systemImage: "creditcard.fill") }
                .tag(2)

            PayoutView()
                .tabItem { Label("打租", systemImage: "arrow.up.circle.fill") }
                .tag(3)

            ProfitView()
                .tabItem { Label("盈亏", systemImage: "chart.pie.fill") }
                .tag(4)
        }
        .tint(.themeAccent)
    }
}
