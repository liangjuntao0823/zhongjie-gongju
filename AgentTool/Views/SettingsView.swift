import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var showMessage = ""
    @State private var showAlert = false
    @State private var showClearSheet = false
    @State private var showRestoreList = false
    @State private var showExcelConvert = false
    @State private var autoBackupEnabled = false
    @State private var backupFrequency = "day"
    @State private var backupHour = 23
    @State private var clearType: DataBackupManager.BackupType? = nil
    @State private var showClearConfirm = false

    private let backupManager = DataBackupManager.shared

    var body: some View {
        NavigationStack {
            Form {
                Section("数据管理") {
                    Button {
                        backupData()
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
                    }

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
                    }

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
                    }

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
                        }
                    }
                    .listRowBackground(Color.red)
                }

                Section("自动备份") {
                    Toggle("启用自动备份", isOn: $autoBackupEnabled)
                        .tint(.themeAccent)
                        .onChange(of: autoBackupEnabled) { _, _ in saveAutoSettings() }

                    if autoBackupEnabled {
                        Picker("备份频率", selection: $backupFrequency) {
                            Text("每天").tag("day")
                            Text("每周").tag("week")
                            Text("每月").tag("month")
                        }
                        .onChange(of: backupFrequency) { _, _ in saveAutoSettings() }

                        Stepper(value: $backupHour, in: 0...23) {
                            HStack {
                                Text("备份时间")
                                Spacer()
                                Text(String(format: "%02d:00", backupHour))
                                    .foregroundColor(.themeText2)
                            }
                        }
                        .onChange(of: backupHour) { _, _ in saveAutoSettings() }

                        Text("自动备份将保存到总备份文件夹")
                            .font(.footnote)
                            .foregroundColor(.themeText3)
                    }
                }

                Section("关于") {
                    HStack {
                        Text("应用名称")
                        Spacer()
                        Text("中介管家").foregroundColor(.themeText2)
                    }
                    HStack {
                        Text("版本")
                        Spacer()
                        Text("2.19").foregroundColor(.themeText2)
                    }
                }

                Section {
                    Text("开发者：豆包And涛哥")
                        .font(.footnote)
                        .foregroundColor(.themeText3)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .listRowBackground(Color.clear)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.themeBg)
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { loadAutoSettings() }
            .alert("提示", isPresented: $showAlert) {
                Button("确定", role: .cancel) { }
            } message: {
                Text(showMessage)
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
        }
    }

    // 备份数据 - 保存到总备份文件夹
    private func backupData() {
        guard let data = backupManager.exportAllData(modelContext: modelContext) else {
            showMessage = "备份失败"
            showAlert = true
            return
        }
        if let url = backupManager.saveBackup(data, type: .total) {
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

        Task {
            do {
                guard url.startAccessingSecurityScopedResource() else {
                    throw NSError(domain: "ExcelConvert", code: -1, userInfo: [NSLocalizedDescriptionKey: "无法访问文件"])
                }
                defer { url.stopAccessingSecurityScopedResource() }

                let parser = try XLSXParser(fileURL: url)
                let sheets = try parser.parse()

                var deals: [[String: Any]] = []
                var incomes: [[String: Any]] = []
                var expenses: [[String: Any]] = []
                var properties: [[String: Any]] = []

                for (sheetName, rows) in sheets {
                    guard rows.count > 1 else { continue }

                    if sheetName.contains("成交") {
                        for i in 1..<rows.count {
                            let cells = rows[i]
                            guard cells.count > 1, !cells[1].isEmpty else { continue }
                            let deal: [String: Any] = [
                                "date": self.dateString(cells[safe: 0] ?? ""),
                                "roomNumber": cells[safe: 1] ?? "",
                                "landlord": cells[safe: 2] ?? "",
                                "unitType": cells[safe: 3] ?? "",
                                "leaseStart": self.dateString(cells[safe: 4] ?? ""),
                                "leaseEnd": self.dateString(cells[safe: 5] ?? ""),
                                "leaseDuration": cells[safe: 6] ?? "",
                                "rent": self.doubleValue(cells[safe: 7] ?? ""),
                                "deposit": self.doubleValue(cells[safe: 8] ?? ""),
                                "prepayment": self.doubleValue(cells[safe: 9] ?? ""),
                                "rentDueDay": self.intValue(cells[safe: 10] ?? ""),
                                "agentFeeLandlord": self.doubleValue(cells[safe: 11] ?? ""),
                                "agentFeeTenant": self.doubleValue(cells[safe: 12] ?? ""),
                                "totalFee": self.doubleValue(cells[safe: 13] ?? ""),
                                "manager": cells[safe: 14] ?? "",
                                "source": cells[safe: 15] ?? "",
                                "notes": cells[safe: 16] ?? ""
                            ]
                            deals.append(deal)
                        }
                    } else if sheetName.contains("收入") {
                        for i in 1..<rows.count {
                            let cells = rows[i]
                            guard cells.count > 1, !cells[1].isEmpty else { continue }
                            let income: [String: Any] = [
                                "date": self.dateString(cells[safe: 0] ?? ""),
                                "item": cells[safe: 1] ?? "",
                                "amount": self.doubleValue(cells[safe: 2] ?? ""),
                                "notes": cells[safe: 3] ?? ""
                            ]
                            incomes.append(income)
                        }
                    } else if sheetName.contains("支出") {
                        for i in 1..<rows.count {
                            let cells = rows[i]
                            guard cells.count > 1, !cells[1].isEmpty else { continue }
                            let expense: [String: Any] = [
                                "date": self.dateString(cells[safe: 0] ?? ""),
                                "item": cells[safe: 1] ?? "",
                                "amount": self.doubleValue(cells[safe: 2] ?? ""),
                                "notes": cells[safe: 3] ?? ""
                            ]
                            expenses.append(expense)
                        }
                    } else if sheetName.contains("收租") || sheetName.contains("交租") {
                        for i in 1..<rows.count {
                            let cells = rows[i]
                            guard cells.count > 1, !cells[1].isEmpty else { continue }

                            var monthly: [[String: Any]] = []
                            for m in 0..<12 {
                                let val = cells[safe: 14 + m] ?? ""
                                let amt = self.doubleValue(val)
                                if amt > 0 {
                                    monthly.append(["month": m + 1, "amount": amt, "isPaid": true])
                                }
                            }

                            var quarterly: [[String: Any]] = []
                            for q in 0..<4 {
                                let val = cells[safe: 26 + q] ?? ""
                                let amt = self.doubleValue(val)
                                if amt > 0 {
                                    quarterly.append(["quarter": q + 1, "electricAmount": 0, "waterAmount": amt, "isSettled": true])
                                }
                            }

                            let prop: [String: Any] = [
                                "rentDueDay": self.intValue(cells[safe: 0] ?? ""),
                                "roomNumber": cells[safe: 1] ?? "",
                                "landlord": cells[safe: 2] ?? "",
                                "unitType": cells[safe: 3] ?? "",
                                "leaseStart": self.dateString(cells[safe: 4] ?? ""),
                                "leaseEnd": self.dateString(cells[safe: 5] ?? ""),
                                "leaseDuration": cells[safe: 6] ?? "",
                                "rent": self.doubleValue(cells[safe: 7] ?? ""),
                                "prepayment": self.doubleValue(cells[safe: 8] ?? ""),
                                "deposit": self.doubleValue(cells[safe: 9] ?? ""),
                                "waterMeterBase": self.intValue(cells[safe: 10] ?? ""),
                                "electricMeterBase": self.intValue(cells[safe: 11] ?? ""),
                                "propertyType": cells[safe: 12] ?? "管理",
                                "notes": cells[safe: 13] ?? "",
                                "monthlyRentRecords": monthly,
                                "quarterlyUtilityRecords": quarterly
                            ]
                            properties.append(prop)
                        }
                    }
                }

                let dict: [String: Any] = [
                    "deals": deals,
                    "incomes": incomes,
                    "expenses": expenses,
                    "properties": properties,
                    "payouts": []
                ]

                let data = try JSONSerialization.data(withJSONObject: dict, options: .prettyPrinted)

                await MainActor.run {
                    isConverting = false
                    convertedData = data
                    convertMessage = "成交\(deals.count)条 收入\(incomes.count)条 支出\(expenses.count)条 收租\(properties.count)条"
                }
            } catch {
                await MainActor.run {
                    isConverting = false
                    convertMessage = "转换失败：\(error.localizedDescription)"
                    convertedData = nil
                }
            }
        }
    }

    // MARK: - 解析辅助
    private func doubleValue(_ s: String) -> Double {
        if let d = Double(s) { return d }
        return 0
    }

    private func intValue(_ s: String) -> Int {
        if let i = Int(s) { return i }
        if let d = Double(s) { return Int(d) }
        return 0
    }

    private func dateString(_ s: String) -> String {
        if s.isEmpty { return "" }
        // 中文日期格式
        var cleaned = s.replacingOccurrences(of: "年", with: "-")
            .replacingOccurrences(of: "月", with: "-")
            .replacingOccurrences(of: "日", with: "")
        // Excel日期序列号
        if let days = Double(cleaned), days > 20000 && days < 60000 {
            let baseDate = Date(timeIntervalSince1970: -2209161600)
            let date = baseDate.addingTimeInterval(days * 86400)
            let df = DateFormatter()
            df.dateFormat = "yyyy-MM-dd"
            return df.string(from: date)
        }
        return cleaned
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
