import SwiftUI
import SwiftData

@main
struct 中介工具App: App {
    var body: some Scene {
        WindowGroup {
            MainTabView()
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
    var body: some View {
        TabView {
            DashboardView()
                .tabItem {
                    Label("首页", systemImage: "house.fill")
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
        .tint(.blue)
    }
}
