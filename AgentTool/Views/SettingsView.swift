import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
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
                        showClearConfirm = true
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
                        Text("2.14").foregroundColor(.themeText2)
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
            .alert("确认清空", isPresented: $showClearConfirm) {
                Button("取消", role: .cancel) { }
                Button("确定清空", role: .destructive) { clearData() }
            } message: {
                Text("确定要清空所有数据吗？此操作不可恢复，建议先备份数据。")
            }
            .sheet(isPresented: $showRestoreList) {
                RestoreBackupView(folder: backupFolder) { url in
                    restoreData(from: url)
                }
            }
        }
    }

    // 备份数据 - 文件名格式 20260915-1853
    private func backupData() {
        guard let data = DataBackupManager.shared.exportAllData(modelContext: modelContext) else {
            showMessage = "备份失败"
            showAlert = true
            return
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmm"
        let filename = "\(formatter.string(from: Date())).json"
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

    // 恢复数据
    private func restoreData(from url: URL) {
        guard let data = try? Data(contentsOf: url) else {
            showMessage = "读取备份文件失败"
            showAlert = true
            return
        }
        DataBackupManager.shared.importAllData(from: data, modelContext: modelContext) { success in
            DispatchQueue.main.async {
                showMessage = success ? "数据恢复成功" : "数据恢复失败"
                showAlert = true
            }
        }
    }

    // 清空数据
    private func clearData() {
        if let deals = try? modelContext.fetch(FetchDescriptor<DealRecord>()) {
            for item in deals { modelContext.delete(item) }
        }
        if let incomes = try? modelContext.fetch(FetchDescriptor<MiscIncome>()) {
            for item in incomes { modelContext.delete(item) }
        }
        if let expenses = try? modelContext.fetch(FetchDescriptor<MiscExpense>()) {
            for item in expenses { modelContext.delete(item) }
        }
        if let properties = try? modelContext.fetch(FetchDescriptor<Property>()) {
            for item in properties { modelContext.delete(item) }
        }
        if let payouts = try? modelContext.fetch(FetchDescriptor<PayoutRecord>()) {
            for item in payouts { modelContext.delete(item) }
        }
        try? modelContext.save()
        UserDefaults.standard.removeObject(forKey: "initialDataImported")
        showMessage = "数据已清空"
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
    let onSelect: (URL) -> Void
    @State private var files: [URL] = []
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
                    .onDelete(perform: deleteFile)
                }
            }
            .navigationTitle("选择备份")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .topBarLeading) {
                    EditButton()
                }
            }
            .onAppear {
                loadFiles()
            }
        }
    }

    private func deleteFile(at offsets: IndexSet) {
        for index in offsets {
            let url = files[index]
            try? FileManager.default.removeItem(at: url)
        }
        loadFiles()
    }

    private func loadFiles() {
        do {
            let allFiles = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.creationDateKey], options: [.skipsHiddenFiles])
            files = allFiles.filter { $0.pathExtension == "json" }.sorted {
                $0.lastPathComponent > $1.lastPathComponent
            }
        } catch {
            files = []
        }
    }
}
