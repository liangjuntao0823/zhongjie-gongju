import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var autoBackupEnabled = false
    @State private var backupFrequency = "day"
    @State private var backupHour = 23
    @State private var showExportShare = false
    @State private var exportURL: URL?
    @State private var showMessage = ""
    @State private var showAlert = false

    private let frequencies = ["day": "每天", "week": "每周", "month": "每月"]

    var body: some View {
        NavigationStack {
            Form {
                Section("数据备份") {
                    Button {
                        exportData()
                    } label: {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundColor(.themeAccent)
                            Text("导出数据备份")
                                .foregroundColor(.themeText)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.themeText3)
                        }
                    }

                    Button {
                        presentDocumentPicker { url in
                            importData(from: url)
                        }
                    } label: {
                        HStack {
                            Image(systemName: "square.and.arrow.down")
                                .foregroundColor(.themeAccent)
                            Text("导入数据备份")
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
                        .onChange(of: autoBackupEnabled) { _, newValue in
                            saveSettings()
                        }

                    if autoBackupEnabled {
                        Picker("备份频率", selection: $backupFrequency) {
                            Text("每天").tag("day")
                            Text("每周").tag("week")
                            Text("每月").tag("month")
                        }
                        .onChange(of: backupFrequency) { _, _ in saveSettings() }

                        Stepper(value: $backupHour, in: 0...23) {
                            HStack {
                                Text("备份时间")
                                Spacer()
                                Text(String(format: "%02d:00", backupHour))
                                    .foregroundColor(.themeText2)
                            }
                        }
                        .onChange(of: backupHour) { _, _ in saveSettings() }
                    }
                }

                Section("关于") {
                    HStack {
                        Text("应用名称")
                        Spacer()
                        Text("中介管家")
                            .foregroundColor(.themeText2)
                    }
                    HStack {
                        Text("版本")
                        Spacer()
                        Text("2.12")
                            .foregroundColor(.themeText2)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.themeBg)
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { loadSettings() }
            .alert("提示", isPresented: $showAlert) {
                Button("确定", role: .cancel) { }
            } message: {
                Text(showMessage)
            }
            .sheet(isPresented: $showExportShare) {
                if let url = exportURL {
                    ShareSheet(activityItems: [url])
                }
            }
        }
    }

    private func exportData() {
        if let data = DataBackupManager.shared.exportAllData(modelContext: modelContext) {
            let dateStr = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .none).replacingOccurrences(of: "/", with: "-")
            let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("中介管家-数据备份-\(dateStr).json")
            do {
                try data.write(to: fileURL)
                exportURL = fileURL
                showExportShare = true
            } catch {
                showMessage = "导出失败：\(error.localizedDescription)"
                showAlert = true
            }
        } else {
            showMessage = "导出失败"
            showAlert = true
        }
    }

    private func importData(from url: URL) {
        guard url.startAccessingSecurityScopedResource() else {
            showMessage = "无法访问文件"
            showAlert = true
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }

        guard let data = try? Data(contentsOf: url) else {
            showMessage = "读取文件失败"
            showAlert = true
            return
        }

        if DataBackupManager.shared.importAllData(from: data, modelContext: modelContext) {
            showMessage = "数据导入成功"
        } else {
            showMessage = "数据导入失败，请检查文件格式"
        }
        showAlert = true
    }

    private func saveSettings() {
        let settings = AutoBackupSettings(enabled: autoBackupEnabled, frequency: backupFrequency, hour: backupHour, minute: 0)
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: "autoBackupSettings")
        }
    }

    private func loadSettings() {
        if let data = UserDefaults.standard.data(forKey: "autoBackupSettings"),
           let settings = try? JSONDecoder().decode(AutoBackupSettings.self, from: data) {
            autoBackupEnabled = settings.enabled
            backupFrequency = settings.frequency
            backupHour = settings.hour
        }
    }
}
