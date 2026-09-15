import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var backupFiles: [URL] = []
    @State private var showMessage = ""
    @State private var showAlert = false
    @State private var showClearConfirm = false
    @State private var showRestoreList = false
    @State private var autoBackupEnabled = false
    @State private var backupFrequency = "day"
    @State private var backupHour = 23

    private let backupFolder: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let folder = docs.appendingPathComponent("Backups", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }()

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
                                .frame(width: 30)
                            Text("备份数据")
                                .foregroundColor(.themeText)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.themeText3)
                        }
                    }

                    Button {
                        loadBackupFiles()
                        showRestoreList = true
                    } label: {
                        HStack {
                            Image(systemName: "square.and.arrow.up.fill")
                                .foregroundColor(.themeAccent)
                                .frame(width: 30)
                            Text("恢复数据")
                                .foregroundColor(.themeText)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.themeText3)
                        }
                    }

                    Button {
                        showClearConfirm = true
                    } label: {
                        HStack {
                            Image(systemName: "trash.fill")
                                .foregroundColor(.white)
                                .frame(width: 30)
                            Text("清空数据")
                                .foregroundColor(.white)
                            Spacer()
                        }
                        .listRowBackground(Color.red)
                    }

                    Button {
                        importInitialData()
                    } label: {
                        HStack {
                            Image(systemName: "arrow.down.doc.fill")
                                .foregroundColor(.themeAccent)
                                .frame(width: 30)
                            Text("导入初始数据")
                                .foregroundColor(.themeText)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.themeText3)
                        }
                    }
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
                        Text("2.13").foregroundColor(.themeText2)
                    }
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
            .alert("确认清空", isPresented: $showClearConfirm) {
                Button("取消", role: .cancel) { }
                Button("确定清空", role: .destructive) { clearData() }
            } message: {
                Text("确定要清空所有数据吗？此操作不可恢复，建议先备份数据。")
            }
            .sheet(isPresented: $showRestoreList) {
                RestoreBackupView(folder: backupFolder, files: backupFiles) { url in
                    restoreData(from: url)
                }
            }
        }
    }

    // 备份数据
    private func backupData() {
        guard let data = DataBackupManager.shared.exportAllData(modelContext: modelContext) else {
            showMessage = "备份失败"
            showAlert = true
            return
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let filename = "备份-\(formatter.string(from: Date())).json"
        let fileURL = backupFolder.appendingPathComponent(filename)
        do {
            try data.write(to: fileURL)
            showMessage = "备份成功：\(filename)"
            showAlert = true
        } catch {
            showMessage = "备份失败：\(error.localizedDescription)"
            showAlert = true
        }
    }

    // 加载备份文件列表
    private func loadBackupFiles() {
        do {
            let files = try FileManager.default.contentsOfDirectory(at: backupFolder, includingPropertiesForKeys: [.creationDateKey], options: [.skipsHiddenFiles])
            backupFiles = files.filter { $0.pathExtension == "json" }.sorted {
                ($0.pathComponents.last ?? "") > ($1.pathComponents.last ?? "")
            }
        } catch {
            backupFiles = []
        }
    }

    // 恢复数据
    private func restoreData(from url: URL) {
        guard let data = try? Data(contentsOf: url) else {
            showMessage = "读取备份文件失败"
            showAlert = true
            return
        }
        if DataBackupManager.shared.importAllData(from: data, modelContext: modelContext) {
            showMessage = "数据恢复成功"
        } else {
            showMessage = "数据恢复失败"
        }
        showAlert = true
    }

    // 清空数据
    private func clearData() {
        try? modelContext.delete(model: DealRecord.self)
        try? modelContext.delete(model: MiscIncome.self)
        try? modelContext.delete(model: MiscExpense.self)
        try? modelContext.delete(model: Property.self)
        try? modelContext.delete(model: PayoutRecord.self)
        try? modelContext.save()
        UserDefaults.standard.removeObject(forKey: "initialDataImported")
        showMessage = "数据已清空"
        showAlert = true
    }

    private func importInitialData() {
        if DataBackupManager.shared.importInitialData(modelContext: modelContext) {
            UserDefaults.standard.set(true, forKey: "initialDataImported")
            showMessage = "初始数据导入成功"
        } else {
            showMessage = "初始数据导入失败，请检查文件是否存在"
        }
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

// 恢复备份列表视图
struct RestoreBackupView: View {
    let folder: URL
    let files: [URL]
    let onSelect: (URL) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if files.isEmpty {
                    Text("暂无备份文件")
                        .foregroundColor(.themeText3)
                        .frame(maxWidth: .infinity, alignment: .center)
                } else {
                    ForEach(files, id: \.self) { url in
                        Button {
                            onSelect(url)
                            dismiss()
                        } label: {
                            HStack {
                                Image(systemName: "doc.fill")
                                    .foregroundColor(.themeAccent)
                                Text(url.deletingPathExtension().lastPathComponent)
                                    .foregroundColor(.themeText)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.themeText3)
                            }
                        }
                    }
                }
            }
            .navigationTitle("选择备份")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }
}
