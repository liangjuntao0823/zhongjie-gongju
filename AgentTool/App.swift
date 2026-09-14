import SwiftUI
import SwiftData

@main
struct AgentToolApp: App {
    private let container: ModelContainer

    init() {
        do {
            container = try ModelContainer(for:
                Property.self,
                RentMonthRecord.self,
                UtilityQuarterRecord.self,
                DealRecord.self,
                MiscIncome.self,
                MiscExpense.self,
                PayoutRecord.self,
                PayoutMonthRecord.self,
                ProfitCalculation.self
            )
        } catch {
            // 模型迁移失败时，清除旧存储后重建（防止闪退）
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
                Property.self,
                RentMonthRecord.self,
                UtilityQuarterRecord.self,
                DealRecord.self,
                MiscIncome.self,
                MiscExpense.self,
                PayoutRecord.self,
                PayoutMonthRecord.self,
                ProfitCalculation.self
            )
        }
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .tint(.themeAccent)
                .environment(\.locale, Locale(identifier: "zh_CN"))
                .environment(\.calendar, Calendar(identifier: .gregorian))
        }
        .modelContainer(container)
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
