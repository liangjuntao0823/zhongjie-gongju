import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var showMessage = ""
    @State private var showAlert = false
    @State private var showClearSheet = false
    @State private var showBackupSheet = false
    @State private var showRestoreList = false
    @State private var showExcelConvert = false
    @State private var autoBackupEnabled = false
    @State private var backupFrequency = "day"
    @State private var backupHour = 23
    @State private var clearType: DataBackupManager.BackupType? = nil
    @State private var showClearConfirm = false
    @State private var showVersionHistory = false

    private let backupManager = DataBackupManager.shared

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "2.26"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("数据管理") {
                    Button {
                        showBackupSheet = true
                    } label: {
                        HStack {
                            Image(systemName: "square.and.arrow.down.fill")
                                .foregroundColor(.themeAccent)
                                .frame(width: 24)
                            Text("备份数据")
                                .foregroundColor(.themeText)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.themeText3)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color(hex: "F2F2F7"))
                        .cornerRadius(12)
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)

                    Button {
                        showRestoreList = true
                    } label: {
                        HStack {
                            Image(systemName: "square.and.arrow.up.fill")
                                .foregroundColor(.themeAccent)
                                .frame(width: 24)
                            Text("恢复数据")
                                .foregroundColor(.themeText)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.themeText3)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color(hex: "F2F2F7"))
                        .cornerRadius(12)
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)

                    Button {
                        showExcelConvert = true
                    } label: {
                        HStack {
                            Image(systemName: "arrow.right.doc.on.clipboard")
                                .foregroundColor(.themeAccent)
                                .frame(width: 24)
                            Text("Excel转备份")
                                .foregroundColor(.themeText)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.themeText3)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color(hex: "F2F2F7"))
                        .cornerRadius(12)
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)

                    Button {
                        showClearSheet = true
                    } label: {
                        HStack {
                            Image(systemName: "trash.fill")
                                .foregroundColor(.white)
                                .frame(width: 24)
                            Text("清空数据")
                                .foregroundColor(.white)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.white.opacity(0.7))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color.red)
                        .cornerRadius(12)
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }

                Section("自动备份") {
                    HStack {
                        Text("启用自动备份")
                            .foregroundColor(.themeText)
                        Spacer()
                        Toggle("", isOn: $autoBackupEnabled)
                            .tint(.themeAccent)
                            .labelsHidden()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color(hex: "F2F2F7"))
                    .cornerRadius(12)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .onChange(of: autoBackupEnabled) { _, _ in saveAutoSettings() }

                    if autoBackupEnabled {
                        HStack {
                            Text("备份频率")
                                .foregroundColor(.themeText)
                            Spacer()
                            Picker("", selection: $backupFrequency) {
                                Text("每天").tag("day")
                                Text("每周").tag("week")
                                Text("每月").tag("month")
                            }
                            .labelsHidden()
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color(hex: "F2F2F7"))
                        .cornerRadius(12)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .onChange(of: backupFrequency) { _, _ in saveAutoSettings() }

                        HStack {
                            Text("备份时间")
                                .foregroundColor(.themeText)
                            Spacer()
                            Stepper(value: $backupHour, in: 0...23) {
                                Text(String(format: "%02d:00", backupHour))
                                    .foregroundColor(.themeText2)
                            }
                            .labelsHidden()
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color(hex: "F2F2F7"))
                        .cornerRadius(12)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .onChange(of: backupHour) { _, _ in saveAutoSettings() }

                        Text("自动备份将保存到总备份文件夹")
                            .font(.footnote)
                            .foregroundColor(.themeText3)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }
                }

                Section("关于") {
                    HStack {
                        Text("应用名称")
                        Spacer()
                        Text("中介管家").foregroundColor(.themeText2)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color(hex: "F2F2F7"))
                    .cornerRadius(12)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    HStack {
                        Text("版本")
                        Spacer()
                        Text(appVersion).foregroundColor(.themeText2)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color(hex: "F2F2F7"))
                    .cornerRadius(12)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    HStack {
                        Text("开发者")
                        Spacer()
                        Text("豆包And涛哥").foregroundColor(.themeText2)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color(hex: "F2F2F7"))
                    .cornerRadius(12)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    HStack {
                        Text("软件说明")
                        Spacer()
                        Text("米兰公馆中介和二房东工作平台").foregroundColor(.themeText2)
                            .font(.system(size: 14))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color(hex: "F2F2F7"))
                    .cornerRadius(12)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    HStack {
                        Text("数据安全")
                        Spacer()
                        Text("本地存储，纯单机无网络接口").foregroundColor(.themeText2)
                            .font(.system(size: 14))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color(hex: "F2F2F7"))
                    .cornerRadius(12)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)

                    Button {
                        showVersionHistory = true
                    } label: {
                        HStack {
                            Text("版本更新介绍")
                                .foregroundColor(.themeText)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.themeText3)
                                .font(.system(size: 12))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color(hex: "F2F2F7"))
                        .cornerRadius(12)
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .buttonStyle(.plain)
                }
            }
            .listRowSpacing(0)
            .listSectionSpacing(8)
            .scrollContentBackground(.hidden)
            .background(Color.white)
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { loadAutoSettings() }
            .alert("提示", isPresented: $showAlert) {
                Button("确定", role: .cancel) { }
            } message: {
                Text(showMessage)
            }
            .confirmationDialog("选择要备份的板块", isPresented: $showBackupSheet, titleVisibility: .visible) {
                Button("备份成交数据") { backupData(type: .deals) }
                Button("备份收租数据") { backupData(type: .properties) }
                Button("备份包租数据") { backupData(type: .payouts) }
                Button("备份全部数据") { backupData(type: .total) }
                Button("取消", role: .cancel) { }
            }
            .confirmationDialog("选择要清空的板块", isPresented: $showClearSheet, titleVisibility: .visible) {
                Button("清空成交数据") { clearType = .deals; showClearConfirm = true }
                Button("清空收租数据") { clearType = .properties; showClearConfirm = true }
                Button("清空包租数据") { clearType = .payouts; showClearConfirm = true }
                Button("清空全部数据", role: .destructive) { clearType = .total; showClearConfirm = true }
                Button("取消", role: .cancel) { }
            }
            .alert("确认清空", isPresented: $showClearConfirm) {
                Button("取消", role: .cancel) { clearType = nil }
                Button("确定清空", role: .destructive) {
                    if let type = clearType {
                        clearData(type: type)
                    }
                    clearType = nil
                }
            } message: {
                if let type = clearType {
                    Text(type == .total ? "确定要清空所有数据吗？此操作不可恢复，建议先备份数据。" : "确定要清空\(type == .deals ? "成交数据" : type == .properties ? "收租数据" : "包租数据")吗？此操作不可恢复。")
                } else {
                    Text("")
                }
            }
            .sheet(isPresented: $showRestoreList) {
                RestoreBackupView(type: .total) { success in
                    showRestoreList = false
                }
            }
            .sheet(isPresented: $showExcelConvert) {
                ExcelConvertView()
            }
            .sheet(isPresented: $showVersionHistory) {
                VersionHistoryView()
            }
        }
    }

    // 备份数据 - 按板块备份
    private func backupData(type: DataBackupManager.BackupType) {
        let data: Data?
        switch type {
        case .deals:
            data = backupManager.exportDeals(modelContext: modelContext)
        case .properties:
            data = backupManager.exportProperties(modelContext: modelContext)
        case .payouts:
            data = backupManager.exportPayouts(modelContext: modelContext)
        case .total:
            data = backupManager.exportAllData(modelContext: modelContext)
        }
        guard let backupData = data else {
            showMessage = "备份失败"
            showAlert = true
            return
        }
        if let url = backupManager.saveBackup(backupData, type: type) {
            showMessage = "备份成功：\(url.lastPathComponent)"
        } else {
            showMessage = "备份失败"
        }
        showAlert = true
    }

    // 清空数据
    private func clearData(type: DataBackupManager.BackupType) {
        switch type {
        case .deals:
            backupManager.clearDeals(modelContext: modelContext)
        case .properties:
            backupManager.clearProperties(modelContext: modelContext)
        case .payouts:
            backupManager.clearPayouts(modelContext: modelContext)
        case .total:
            backupManager.clearAll(modelContext: modelContext)
        }
        showMessage = "\(type.rawValue)已清空"
        showAlert = true
    }

    private func saveAutoSettings() {
        let settings = AutoBackupSettings(enabled: autoBackupEnabled, frequency: backupFrequency, hour: backupHour, minute: 0)
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: "autoBackupSettings")
        }
    }

    private func loadAutoSettings() {
        if let data = UserDefaults.standard.data(forKey: "autoBackupSettings"),
           let settings = try? JSONDecoder().decode(AutoBackupSettings.self, from: data) {
            autoBackupEnabled = settings.enabled
            backupFrequency = settings.frequency
            backupHour = settings.hour
        }
    }
}

// MARK: - Excel转备份视图
struct ExcelConvertView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var showFilePicker = false
    @State private var isConverting = false
    @State private var convertMessage = ""
    @State private var convertedData: Data? = nil
    @State private var showSaveSheet = false
    @State private var selectedFileName = ""

    private let backupManager = DataBackupManager.shared

    var body: some View {
        NavigationStack {
            ZStack {
                Color.themeBg.ignoresSafeArea()
                VStack(spacing: 20) {
                    if isConverting {
                        ProgressView("正在转换Excel...")
                    } else if let data = convertedData {
                        VStack(spacing: 16) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 48))
                                .foregroundColor(.themeAccent)
                            Text("转换成功！")
                                .font(.title2)
                                .foregroundColor(.themeText)
                            Text("文件：\(selectedFileName)")
                                .font(.subheadline)
                                .foregroundColor(.themeText2)
                            Text("请选择保存到哪个备份文件夹")
                                .font(.subheadline)
                                .foregroundColor(.themeText3)

                            VStack(spacing: 12) {
                                Button {
                                    saveBackup(data, type: .deals)
                                } label: {
                                    HStack {
                                        Image(systemName: "doc.text")
                                        Text("保存到成交备份")
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                    }
                                    .padding()
                                    .background(Color.themePanel)
                                    .cornerRadius(10)
                                }
                                Button {
                                    saveBackup(data, type: .properties)
                                } label: {
                                    HStack {
                                        Image(systemName: "doc.text")
                                        Text("保存到收租备份")
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                    }
                                    .padding()
                                    .background(Color.themePanel)
                                    .cornerRadius(10)
                                }
                                Button {
                                    saveBackup(data, type: .payouts)
                                } label: {
                                    HStack {
                                        Image(systemName: "doc.text")
                                        Text("保存到包租备份")
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                    }
                                    .padding()
                                    .background(Color.themePanel)
                                    .cornerRadius(10)
                                }
                                Button {
                                    saveBackup(data, type: .total)
                                } label: {
                                    HStack {
                                        Image(systemName: "doc.text")
                                        Text("保存到总备份")
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                    }
                                    .padding()
                                    .background(Color.themePanel)
                                    .cornerRadius(10)
                                }
                            }
                            .padding(.horizontal)
                        }
                    } else {
                        VStack(spacing: 16) {
                            Image(systemName: "tablecells")
                                .font(.system(size: 48))
                                .foregroundColor(.themeText3)
                            Text("选择Excel文件转换为备份")
                                .font(.title3)
                                .foregroundColor(.themeText)
                            Text("支持.xlsx格式，转换后可选择保存到对应备份文件夹")
                                .font(.subheadline)
                                .foregroundColor(.themeText3)
                                .multilineTextAlignment(.center)
                            Button {
                                showFilePicker = true
                            } label: {
                                HStack {
                                    Image(systemName: "folder")
                                    Text("选择Excel文件")
                                }
                                .padding()
                                .background(Color.themeAccent)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                            }
                        }
                        .padding(.horizontal, 40)
                    }
                }
            }
            .navigationTitle("Excel转备份")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") { dismiss() }
                        .foregroundColor(.themeAccent)
                }
            }
            .fileImporter(isPresented: $showFilePicker, allowedContentTypes: [.spreadsheet]) { result in
                switch result {
                case .success(let url):
                    convertExcel(url)
                case .failure:
                    convertMessage = "选择文件失败"
                }
            }
        }
    }

    private func convertExcel(_ url: URL) {
        selectedFileName = url.lastPathComponent
        isConverting = true
        convertMessage = ""

        DispatchQueue.global(qos: .userInitiated).async {
            // 简化版：直接读取文件内容，后续可集成CoreXLSX
            // 目前先提示用户使用桌面转换工具
            DispatchQueue.main.async {
                isConverting = false
                convertMessage = "请使用桌面端的转换工具将Excel转为JSON后，通过文件APP放入对应备份文件夹"
                convertedData = nil
            }
        }
    }

    private func saveBackup(_ data: Data, type: DataBackupManager.BackupType) {
        if let url = backupManager.saveBackup(data, type: type) {
            convertMessage = "已保存到\(type.rawValue)：\(url.lastPathComponent)"
            dismiss()
        } else {
            convertMessage = "保存失败"
        }
    }
}

// MARK: - 版本更新介绍
struct VersionHistoryView: View {
    let versions: [(version: String, date: String, changes: [String])] = [
        ("v2.29", "2026-09-15", [
            "收租卡片：交租日只显示X号，月租改租/XXX，预存改预/XXX",
            "收租卡片第三行租期字体调大",
            "收租卡片累计水电改累计收水电:XXX元，数字加粗深绿色",
            "收租排序优化：拖租未交的优先排在最前",
            "详情页分享功能修复",
            "包租卡片右侧改已付X次租金、已付XXXX元、已付水电费X元，全部胶囊化",
            "包租卡片去掉管理和免租期，改为房号+户型+付款方式 / X号+年租 / 备注",
            "包租卡片删除左侧图标区域",
            "包租详情页新增按月水电费结算",
            "包租详情页新增水电底数（水表+电表）",
            "包租详情页新增交租日",
            "包租详情页打租计划按付款方式动态显示（月12期/季4期/半年2期/年1期）",
            "设置页三大板块间距缩小"
        ]),
        ("v2.28", "2026-09-15", [
            "收租管理卡片全部胶囊配底色",
            "收租卡片新布局：房号+房东 / 交租日+租金+预存 / 租期",
            "收租卡片已收X个月数字加粗",
            "收租卡片动态排序：未收租优先，离交租日近排前",
            "包租管理卡片全部胶囊配底色",
            "详情页左上角新增分享功能：图片分享，自动剔除敏感信息"
        ]),
        ("v2.27", "2026-09-15", [
            "设置页版本号动态读取",
            "版本介绍箭头移入胶囊内部",
            "设置页间距大幅缩小",
            "成交卡片统一高度，备注始终显示，超出用..."
        ]),
        ("v2.23", "2026-09-15", [
            "设置页关于部分完善，新增开发者、软件说明、数据安全",
            "汇总月度列表默认降序排列，最新月份在最前",
            "汇总筛选默认显示全年数据",
            "汇总KPI新布局：左边2x2，右边净总收入跨两行",
            "净总收入统一配红色",
            "汇总下方卡片净收入胶囊化，配色对应KPI",
            "包租表单付款方式新增半年付、年付",
            "成交卡片时间恢复显示并胶囊化"
        ]),
        ("v2.22", "2026-09-15", [
            "备份数据新增分板块选择（成交/收租/包租/全部）",
            "成交卡片胶囊化：房东、租金、押金、备注全部加底色",
            "成交金额改为红色，房号永不换行",
            "杂收入/杂支出配色对调：收入红色，支出绿色",
            "汇总KPI和月度数据全部胶囊加底色",
            "成交和中介费KPI配黄色"
        ]),
        ("v2.21", "2026-09-15", [
            "回退到稳定版本",
            "Excel转备份暂用桌面端转换工具"
        ]),
        ("v2.20", "2026-09-15", [
            "清空数据对话框文字修正",
            "右滑卡片改为iOS原生swipeActions，流畅度提升",
            "杂项收入卡片优化：绿色圆形收字图标，备注为空不显示",
            "成交记录卡片三行标签式布局",
            "杂项支出卡片优化",
            "汇总顶部3数据改5数据，字体放大加黑",
            "工作台时间卡片收窄"
        ]),
        ("v2.19", "2026-09-15", [
            "备份文件夹细分为4个：成交备份/收租备份/包租备份/总备份",
            "各板块左上角导入数据改为恢复数据",
            "设置页增加分板块清空（带二次确认）",
            "设置页增加Excel转备份入口",
            "自动备份固定为总备份"
        ]),
        ("v2.18", "2026-09-15", [
            "修复收租数据导入闪退问题",
            "SwiftData关系对象先insert再关联",
            "支持收租表表名（原交租表）"
        ]),
        ("v2.17", "2026-09-15", [
            "修复日期格式问题",
            "日期统一使用yyyy-MM-dd格式"
        ]),
        ("v2.16", "2026-09-15", [
            "分批导入优化，每批2条",
            "降低主线程阻塞风险"
        ]),
        ("v2.15", "2026-09-15", [
            "数据导入改为异步后台执行",
            "避免UI卡顿"
        ]),
        ("v2.14", "2026-09-15", [
            "数据导入功能优化",
            "支持Excel模板导入"
        ]),
        ("v2.13", "2026-09-15", [
            "收租管理界面优化",
            "收租进度展示"
        ]),
        ("v2.12", "2026-09-15", [
            "成交管理界面优化",
            "新增筛选和搜索功能"
        ]),
        ("v2.11", "2026-09-15", [
            "应用名称改为中介管家",
            "APP图标优化"
        ]),
        ("v2.10", "2026-09-15", [
            "新增包租管理板块",
            "支持打租记录和月打租"
        ]),
        ("v2.9", "2026-09-15", [
            "新增汇总板块",
            "月度收支汇总统计"
        ]),
        ("v2.8", "2026-09-15", [
            "工作台KPI看板",
            "在管房间、即将到期、中介费等指标"
        ]),
        ("v2.7", "2026-09-15", [
            "数据备份和恢复功能",
            "支持分板块备份"
        ]),
        ("v2.6", "2026-09-15", [
            "新增杂项收入和支出管理",
            "支持自定义分类"
        ]),
        ("v2.5", "2026-09-15", [
            "水电结算功能",
            "按季度结算水电费"
        ]),
        ("v2.4", "2026-09-15", [
            "收租管理板块",
            "月度收租记录和提醒"
        ]),
        ("v2.3", "2026-09-15", [
            "成交管理板块",
            "支持成交记录录入和查询"
        ]),
        ("v2.2", "2026-09-15", [
            "基础UI优化",
            "深绿色主题"
        ]),
        ("v2.1", "2026-09-15", [
            "基础功能完善",
            "数据持久化优化"
        ]),
        ("v2.0", "2026-09-15", [
            "重大版本更新",
            "全新架构，SwiftData数据存储",
            "6大功能板块"
        ]),
        ("v1.0", "2026-09-01", [
            "初始版本发布",
            "基础房产中介管理功能"
        ])
    ]

    var body: some View {
        NavigationStack {
            List {
                ForEach(versions, id: \.version) { ver in
                    Section(header: HStack {
                        Text(ver.version)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.themeAccent)
                        Spacer()
                        Text(ver.date)
                            .font(.system(size: 12))
                            .foregroundColor(.themeText3)
                    }) {
                        ForEach(ver.changes, id: \.self) { change in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "circle.fill")
                                    .font(.system(size: 6))
                                    .foregroundColor(.themeAccent)
                                    .padding(.top, 6)
                                Text(change)
                                    .font(.system(size: 14))
                                    .foregroundColor(.themeText)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.themeBg)
            .navigationTitle("版本更新介绍")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
