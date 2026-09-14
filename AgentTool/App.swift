import SwiftUI
import SwiftData

@main
struct AgentToolApp: App {
    var body: some Scene {
        WindowGroup {
            MainTabView()
                .tint(.themeAccent)
        }
        .modelContainer(for: [
            Property.self,
            RentMonthRecord.self,
            UtilityQuarterRecord.self,
            DealRecord.self,
            MiscIncome.self,
            MiscExpense.self,
            PayoutRecord.self,
            PayoutMonthRecord.self,
            ProfitCalculation.self
        ])
    }
}

struct MainTabView: View {
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
        TabView {
            DashboardView()
                .tabItem {
                    Label("工作台", systemImage: "house.fill")
                }

            DealsView()
                .tabItem {
                    Label("成交", systemImage: "doc.text.fill")
                }

            RentCollectionView()
                .tabItem {
                    Label("收租", systemImage: "creditcard.fill")
                }

            PayoutView()
                .tabItem {
                    Label("打租", systemImage: "arrow.up.circle.fill")
                }

            ProfitView()
                .tabItem {
                    Label("盈亏", systemImage: "chart.pie.fill")
                }

            UtilityView()
                .tabItem {
                    Label("水电", systemImage: "bolt.fill")
                }
        }
        .tint(.themeAccent)
    }
}
