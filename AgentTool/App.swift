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
        // 强制应用内系统控件使用中文
        UserDefaults.standard.set(["zh-Hans", "zh_CN"], forKey: "AppleLanguages")
        UserDefaults.standard.synchronize()

        // 尝试初始化ModelContainer，失败则删除旧store重试
        do {
            container = try ModelContainer(for:
                Property.self, RentMonthRecord.self, UtilityQuarterRecord.self,
                DealRecord.self, MiscIncome.self, MiscExpense.self,
                PayoutRecord.self, PayoutMonthRecord.self, ProfitCalculation.self
            )
        } catch {
            print("ModelContainer init failed: \(error)")
            // 删除所有可能的SwiftData store文件
            let fileManager = FileManager.default
            if let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
                if let files = try? fileManager.contentsOfDirectory(at: appSupport, includingPropertiesForKeys: nil) {
                    for file in files {
                        let name = file.lastPathComponent
                        if name.hasSuffix(".store") || name.hasSuffix(".store-wal") ||
                           name.hasSuffix(".store-shm") || name.contains("AgentTool") {
                            try? fileManager.removeItem(at: file)
                            print("Removed: \(name)")
                        }
                    }
                }
            }
            // 再试一次，不行就用空配置
            do {
                container = try ModelContainer(for:
                    Property.self, RentMonthRecord.self, UtilityQuarterRecord.self,
                    DealRecord.self, MiscIncome.self, MiscExpense.self,
                    PayoutRecord.self, PayoutMonthRecord.self, ProfitCalculation.self
                )
            } catch {
                print("Second init also failed: \(error)")
                // 使用内存存储，确保不会崩溃
                let config = ModelConfiguration(isStoredInMemoryOnly: true)
                container = try! ModelContainer(for:
                    Property.self, RentMonthRecord.self, UtilityQuarterRecord.self,
                    DealRecord.self, MiscIncome.self, MiscExpense.self,
                    PayoutRecord.self, PayoutMonthRecord.self, ProfitCalculation.self,
                    configurations: config
                )
            }
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

            // 底部导航
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
            // 启动时将预置备份文件复制到Backups文件夹
            copyPresetBackupIfNeeded()
        }
    }

    private func copyPresetBackupIfNeeded() {
        guard let sourceURL = Bundle.main.url(forResource: "presetBackup", withExtension: "json") else {
            print("presetBackup.json not found in bundle")
            return
        }
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let backupFolder = docs.appendingPathComponent("Backups", isDirectory: true)
        try? FileManager.default.createDirectory(at: backupFolder, withIntermediateDirectories: true)
        let destURL = backupFolder.appendingPathComponent("初始数据备份.json")
        if !FileManager.default.fileExists(atPath: destURL.path) {
            do {
                try FileManager.default.copyItem(at: sourceURL, to: destURL)
                print("预置备份已复制到Backups文件夹")
            } catch {
                print("复制预置备份失败: \(error)")
            }
        }
    }
}
