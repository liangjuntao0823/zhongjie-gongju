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
        // 强制应用内系统控件使用中文（包括分享界面、日期选择器等）
        UserDefaults.standard.set(["zh-Hans", "zh_CN"], forKey: "AppleLanguages")
        UserDefaults.standard.synchronize()
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

// 自定义6个Tab的底部导航
struct MainTabView: View {
    @EnvironmentObject private var tabRouter: TabRouter
    @Environment(\.modelContext) private var modelContext
    @State private var hasImported = false

    private let tabs = [
        (title: "工作台", icon: "house.fill"),
        (title: "成交", icon: "doc.text.fill"),
        (title: "收租", icon: "creditcard.fill"),
        (title: "包租", icon: "arrow.up.circle.fill"),
        (title: "汇总", icon: "chart.pie.fill"),
        (title: "设置", icon: "gearshape.fill")
    ]

    init() {
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()
        navAppearance.backgroundColor = UIColor(Color.themeBg)
        navAppearance.titleTextAttributes = [.foregroundColor: UIColor(Color.themeText)]
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
    }

    var body: some View {
        VStack(spacing: 0) {
            // 内容区域
            ZStack {
                Color.themeBg.ignoresSafeArea()
                Group {
                    switch tabRouter.selectedTab {
                    case 0: DashboardView()
                    case 1: DealsView()
                    case 2: RentCollectionView()
                    case 3: PayoutView()
                    case 4: ProfitView()
                    case 5: SettingsView()
                    default: DashboardView()
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // 自定义底部导航
            VStack(spacing: 0) {
                Divider().background(Color.themeBorder)
                HStack(spacing: 0) {
                    ForEach(0..<tabs.count, id: \.self) { index in
                        Button {
                            tabRouter.selectedTab = index
                        } label: {
                            VStack(spacing: 2) {
                                Image(systemName: tabs[index].icon)
                                    .font(.system(size: 18))
                                Text(tabs[index].title)
                                    .font(.system(size: 10))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 6)
                            .padding(.bottom, 6)
                            .foregroundColor(tabRouter.selectedTab == index ? .themeAccent : .themeText3)
                        }
                    }
                }
                .background(Color.themePanel)
            }
        }
        .onAppear {
            // 首次启动导入初始数据（只执行一次）
            if !hasImported && !UserDefaults.standard.bool(forKey: "initialDataImported") {
                hasImported = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    if DataBackupManager.shared.importInitialData(modelContext: modelContext) {
                        UserDefaults.standard.set(true, forKey: "initialDataImported")
                        print("初始数据导入成功")
                    } else {
                        print("初始数据导入失败或文件不存在")
                    }
                }
            }
        }
    }
}
