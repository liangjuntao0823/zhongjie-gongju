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

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                // 读取XLSX文件
                guard url.startAccessingSecurityScopedResource() else {
                    throw NSError(domain: "ExcelConvert", code: -1, userInfo: [NSLocalizedDescriptionKey: "无法访问文件"])
                }
                defer { url.stopAccessingSecurityScopedResource() }

                let file = try XLSXFile(filepath: url.path)
                guard let xlsxFile = file else {
                    throw NSError(domain: "ExcelConvert", code: -2, userInfo: [NSLocalizedDescriptionKey: "无法打开Excel文件"])
                }
                var deals: [[String: Any]] = []
                var incomes: [[String: Any]] = []
                var expenses: [[String: Any]] = []
                var properties: [[String: Any]] = []

                for wbk in try xlsxFile.parseWorkbooks() {
                    for (name, path) in try xlsxFile.parseWorksheetPathsAndNames(workbook: wbk) {
                        let worksheet = try xlsxFile.parseWorksheet(at: path)
                        let rows = worksheet.data?.rows ?? []
                        guard rows.count > 1 else { continue }

                        let sheetName = name ?? ""

                        // 解析成交记录
                        if sheetName.contains("成交") {
                            for i in 1..<rows.count {
                                let cells = rows[i].cells
                                guard cells.count > 1, let room = cells[safe: 1]?.value else { continue }
                                let deal: [String: Any] = [
                                    "date": self.cellDateString(cells[safe: 0]?.value),
                                    "roomNumber": self.cellString(room),
                                    "landlord": self.cellString(cells[safe: 2]?.value),
                                    "unitType": self.cellString(cells[safe: 3]?.value),
                                    "leaseStart": self.cellDateString(cells[safe: 4]?.value),
                                    "leaseEnd": self.cellDateString(cells[safe: 5]?.value),
                                    "leaseDuration": self.cellString(cells[safe: 6]?.value),
                                    "rent": self.cellDouble(cells[safe: 7]?.value),
                                    "deposit": self.cellDouble(cells[safe: 8]?.value),
                                    "prepayment": self.cellDouble(cells[safe: 9]?.value),
                                    "rentDueDay": self.cellInt(cells[safe: 10]?.value),
                                    "agentFeeLandlord": self.cellDouble(cells[safe: 11]?.value),
                                    "agentFeeTenant": self.cellDouble(cells[safe: 12]?.value),
                                    "totalFee": self.cellDouble(cells[safe: 13]?.value),
                                    "manager": self.cellString(cells[safe: 14]?.value),
                                    "source": self.cellString(cells[safe: 15]?.value),
                                    "notes": self.cellString(cells[safe: 16]?.value)
                                ]
                                deals.append(deal)
                            }
                        }
                        // 解析杂项收入
                        else if sheetName.contains("收入") {
                            for i in 1..<rows.count {
                                let cells = rows[i].cells
                                guard cells.count > 1, let item = cells[safe: 1]?.value else { continue }
                                let income: [String: Any] = [
                                    "date": self.cellDateString(cells[safe: 0]?.value),
                                    "item": self.cellString(item),
                                    "amount": self.cellDouble(cells[safe: 2]?.value),
                                    "notes": self.cellString(cells[safe: 3]?.value)
                                ]
                                incomes.append(income)
                            }
                        }
                        // 解析杂项支出
                        else if sheetName.contains("支出") {
                            for i in 1..<rows.count {
                                let cells = rows[i].cells
                                guard cells.count > 1, let item = cells[safe: 1]?.value else { continue }
                                let expense: [String: Any] = [
                                    "date": self.cellDateString(cells[safe: 0]?.value),
                                    "item": self.cellString(item),
                                    "amount": self.cellDouble(cells[safe: 2]?.value),
                                    "notes": self.cellString(cells[safe: 3]?.value)
                                ]
                                expenses.append(expense)
                            }
                        }
                        // 解析收租表
                        else if sheetName.contains("收租") || sheetName.contains("交租") {
                            for i in 1..<rows.count {
                                let cells = rows[i].cells
                                guard cells.count > 1, let room = cells[safe: 1]?.value else { continue }

                                var monthly: [[String: Any]] = []
                                for m in 0..<12 {
                                    if let val = cells[safe: 14 + m]?.value {
                                        let amt = self.cellDouble(val)
                                        if amt > 0 {
                                            monthly.append(["month": m + 1, "amount": amt, "isPaid": true])
                                        }
                                    }
                                }

                                var quarterly: [[String: Any]] = []
                                for q in 0..<4 {
                                    if let val = cells[safe: 26 + q]?.value {
                                        let amt = self.cellDouble(val)
                                        if amt > 0 {
                                            quarterly.append(["quarter": q + 1, "electricAmount": 0, "waterAmount": amt, "isSettled": true])
                                        }
                                    }
                                }

                                let prop: [String: Any] = [
                                    "rentDueDay": self.cellInt(cells[safe: 0]?.value),
                                    "roomNumber": self.cellString(room),
                                    "landlord": self.cellString(cells[safe: 2]?.value),
                                    "unitType": self.cellString(cells[safe: 3]?.value),
                                    "leaseStart": self.cellDateString(cells[safe: 4]?.value),
                                    "leaseEnd": self.cellDateString(cells[safe: 5]?.value),
                                    "leaseDuration": self.cellString(cells[safe: 6]?.value),
                                    "rent": self.cellDouble(cells[safe: 7]?.value),
                                    "prepayment": self.cellDouble(cells[safe: 8]?.value),
                                    "deposit": self.cellDouble(cells[safe: 9]?.value),
                                    "waterMeterBase": self.cellInt(cells[safe: 10]?.value),
                                    "electricMeterBase": self.cellInt(cells[safe: 11]?.value),
                                    "propertyType": self.cellString(cells[safe: 12]?.value) ?? "管理",
                                    "notes": self.cellString(cells[safe: 13]?.value),
                                    "monthlyRentRecords": monthly,
                                    "quarterlyUtilityRecords": quarterly
                                ]
                                properties.append(prop)
                            }
                        }
                    }
                }

                // 组装数据
                let dict: [String: Any] = [
                    "deals": deals,
                    "incomes": incomes,
                    "expenses": expenses,
                    "properties": properties,
                    "payouts": []
                ]

                let data = try JSONSerialization.data(withJSONObject: dict, options: .prettyPrinted)

                DispatchQueue.main.async {
                    isConverting = false
                    convertedData = data
                    convertMessage = "成交\(deals.count)条 收入\(incomes.count)条 支出\(expenses.count)条 收租\(properties.count)条"
                }
            } catch {
                DispatchQueue.main.async {
                    isConverting = false
                    convertMessage = "转换失败：\(error.localizedDescription)"
                    convertedData = nil
                }
            }
        }
    }

    // MARK: - Cell解析辅助
    private func cellString(_ value: Any?) -> String {
        guard let v = value else { return "" }
        if let s = v as? String { return s }
        if let n = v as? NSNumber { return n.stringValue }
        return "\(v)"
    }

    private func cellDouble(_ value: Any?) -> Double {
        guard let v = value else { return 0 }
        if let n = v as? NSNumber { return n.doubleValue }
        if let s = v as? String, let d = Double(s) { return d }
        return 0
    }

    private func cellInt(_ value: Any?) -> Int {
        guard let v = value else { return 0 }
        if let n = v as? NSNumber { return n.intValue }
        if let s = v as? String, let i = Int(s) { return i }
        return 0
    }

    private func cellDateString(_ value: Any?) -> String {
        guard let v = value else { return "" }
        if let s = v as? String {
            // 处理中文日期格式
            let cleaned = s.replacingOccurrences(of: "年", with: "-")
                .replacingOccurrences(of: "月", with: "-")
                .replacingOccurrences(of: "日", with: "")
            return cleaned
        }
        if let n = v as? NSNumber {
            // Excel日期序列号转换
            let days = n.doubleValue
            if days > 20000 && days < 60000 {
                let baseDate = Date(timeIntervalSince1970: -2209161600) // 1900-01-01
                let date = baseDate.addingTimeInterval(days * 86400)
                let df = DateFormatter()
                df.dateFormat = "yyyy-MM-dd"
                return df.string(from: date)
            }
            return n.stringValue
        }
        return ""
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
