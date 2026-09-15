import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct PayoutView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PayoutRecord.roomNumber) private var payouts: [PayoutRecord]
    @State private var showingAddPayout = false
    @State private var editingPayout: PayoutRecord?
    @State private var selectedPayout: PayoutRecord?
    @State private var exportURL: ExportURL?
    @State private var showingRestore = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(payouts) { payout in
                    PayoutRow(payout: payout)
                        .contentShape(Rectangle())
                        .onTapGesture { selectedPayout = payout }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                if let idx = payouts.firstIndex(where: { $0.id == payout.id }) {
                                    modelContext.delete(payouts[idx])
                                }
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                            Button {
                                editingPayout = payout
                            } label: {
                                Label("修改", systemImage: "pencil")
                            }
                            .tint(.themeBlue)
                        }
                        .listRowBackground(Color.themeBg)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color.themeBg)
            .overlay {
                if payouts.isEmpty {
                    ContentUnavailableView("暂无打租记录", systemImage: "arrow.up.circle", description: Text("点击右上角 + 添加包租打租记录"))
                }
            }
            .navigationTitle("包租管理")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Menu {
                        Button { exportToImage() } label: {
                            Label("导出图片", systemImage: "photo")
                        }
                        Button { exportToExcel() } label: {
                            Label("导出Excel", systemImage: "tablecells")
                        }
                        Button { exportTemplate() } label: {
                            Label("导出Excel模板", systemImage: "doc.text")
                        }
                        Button { showingRestore = true } label: {
                            Label("恢复数据", systemImage: "square.and.arrow.down")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle").foregroundColor(.themeAccent)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showingAddPayout = true } label: {
                        Image(systemName: "plus.circle.fill").foregroundColor(.themeAccent)
                    }
                }
            }
            .sheet(isPresented: $showingAddPayout) { AddPayoutView() }
            .sheet(item: $editingPayout) { payout in AddPayoutView(payout: payout) }
            .sheet(item: $selectedPayout) { payout in PayoutDetailView(payout: payout) }
            .sheet(item: $exportURL) { url in ShareSheet(activityItems: [url.url]) }
            .sheet(isPresented: $showingRestore) {
                RestoreBackupView(type: .payouts) { success in
                    showingRestore = false
                }
            }
        }
    }

    private func deletePayout(at offsets: IndexSet) {
        for index in offsets { modelContext.delete(payouts[index]) }
    }

    private func exportToImage() {
        let df = DateFormatter()
        df.locale = Locale(identifier: "zh_CN")
        df.dateFormat = "yyyy年M月d日 HH:mm"
        let dateStr = df.string(from: Date())
        let rows = payouts.map { p -> [String] in
            let monthlyPayout = p.annualRent / 12
            return [p.roomNumber, p.manager, p.unitType, "¥\(Int(p.annualRent))",
                    "¥\(Int(monthlyPayout))", "\(p.rentFreeDays)天", p.paymentMethod]
        }
        let view = ExportTableView(
            title: "包租记录", dateStr: dateStr,
            headers: ["房号","管理人","户型","年租金","月打租","免租期","支付方式"],
            rows: rows
        )
        let renderer = ImageRenderer(content: view.frame(width: 700))
        renderer.scale = 2.0
        if let image = renderer.uiImage {
            let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("包租记录-\(Int(Date().timeIntervalSince1970)).png")
            if let data = image.pngData() {
                try? data.write(to: fileURL)
                exportURL = ExportURL(url: fileURL)
            }
        }
    }

    private func exportToExcel() {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        let headers = ["房号","管理人","户型","起租日","到期日","年租金","免租期","支付方式","备注"]
        let rows = payouts.map { [
            $0.roomNumber, $0.manager, $0.unitType,
            df.string(from: $0.leaseStartDate), df.string(from: $0.leaseEndDate),
            "\(Int($0.annualRent))", "\($0.rentFreeDays)", $0.paymentMethod, $0.notes
        ]}
        let html = makeExcelHTML(title: "包租记录", headers: headers, rows: rows)
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("包租记录-\(Int(Date().timeIntervalSince1970)).xls")
        try? html.write(to: fileURL, atomically: true, encoding: .utf8)
        exportURL = ExportURL(url: fileURL)
    }

    private func exportTemplate() {
        let headers = ["房号","管理人","户型","起租日","到期日","年租金","免租期","支付方式","备注"]
        let rows = [["1-101","李四","单间上层","2026-01-01","2027-12-31","12000","15","月付","示例"]]
        let html = makeExcelHTML(title: "包租记录", headers: headers, rows: rows)
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("包租记录-模板.xls")
        try? html.write(to: fileURL, atomically: true, encoding: .utf8)
        exportURL = ExportURL(url: fileURL)
    }

    private func importFromFile(url: URL) {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer { if didAccess { url.stopAccessingSecurityScopedResource() } }
        var content: String?
        if var data = try? Data(contentsOf: url) {
            if data.count >= 3 && data[0] == 0xEF && data[1] == 0xBB && data[2] == 0xBF {
                data = data.subdata(in: 3..<data.count)
            }
            content = String(data: data, encoding: .utf8)
            if content == nil {
                let gbk = CFStringEncodings.GB_18030_2000.rawValue
                let encoding = CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(gbk))
                content = String(data: data, encoding: String.Encoding(rawValue: encoding))
            }
        }
        guard let text = content else { return }

        var rows: [[String]] = []
        if text.contains("<tr") {
            let trPattern = try? NSRegularExpression(pattern: "<tr[^>]*>(.*?)</tr>", options: [.dotMatchesLineSeparators, .caseInsensitive])
            let tdPattern = try? NSRegularExpression(pattern: "<t[dh][^>]*>(.*?)</t[dh]>", options: [.dotMatchesLineSeparators, .caseInsensitive])
            if let trMatches = trPattern?.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
                for trMatch in trMatches {
                    if let trRange = Range(trMatch.range(at: 1), in: text) {
                        let trContent = String(text[trRange])
                        var row: [String] = []
                        if let tdMatches = tdPattern?.matches(in: trContent, range: NSRange(trContent.startIndex..., in: trContent)) {
                            for tdMatch in tdMatches {
                                if let tdRange = Range(tdMatch.range(at: 1), in: trContent) {
                                    var cell = String(trContent[tdRange])
                                    cell = cell.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                                    cell = cell.trimmingCharacters(in: .whitespacesAndNewlines)
                                    row.append(cell)
                                }
                            }
                        }
                        if !row.isEmpty { rows.append(row) }
                    }
                }
            }
            if !rows.isEmpty { rows.removeFirst() }
        } else {
            let lines = text.components(separatedBy: .newlines).dropFirst()
            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { continue }
                rows.append(trimmed.components(separatedBy: ","))
            }
        }

        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
        for cols in rows {
            guard cols.count >= 6 else { continue }
            let p = PayoutRecord(
                roomNumber: cols[0], manager: cols[1], unitType: cols[2],
                leaseStartDate: df.date(from: cols[3]) ?? Date(),
                leaseEndDate: df.date(from: cols[4]) ?? Date(),
                rentFreeDays: cols.count > 6 ? Int(cols[6]) ?? 0 : 0,
                annualRent: Double(cols[5]) ?? 0,
                paymentMethod: cols.count > 7 ? cols[7] : "月付",
                notes: cols.count > 8 ? cols[8] : ""
            )
            modelContext.insert(p)
        }
    }
}

struct PayoutRow: View {
    let payout: PayoutRecord

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(hex: "F0E8FE"))
                    .frame(width: 44, height: 44)
                Image(systemName: "arrow.up.circle.fill")
                    .foregroundColor(Color(hex: "6B3FA0"))
                    .font(.system(size: 18))
            }
            VStack(alignment: .leading, spacing: 5) {
                // 第一行：房号 + 户型 + 付款方式
                HStack(spacing: 6) {
                    Text(payout.roomNumber)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.themeText)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color(hex: "F0F0F0"))
                        .cornerRadius(.infinity)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                    Text(payout.unitType)
                        .font(.system(size: 11))
                        .foregroundColor(.themeText2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color(hex: "E3F2FD"))
                        .cornerRadius(.infinity)
                    Text(payout.paymentMethod)
                        .font(.system(size: 10))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color(hex: "F0E8FE"))
                        .foregroundColor(Color(hex: "6B3FA0"))
                        .cornerRadius(.infinity)
                }
                // 第二行：管理 + 年租金
                HStack(spacing: 6) {
                    Text("管理：\(payout.manager)")
                        .font(.system(size: 12))
                        .foregroundColor(.themeText2)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color(hex: "E8F0FE"))
                        .cornerRadius(.infinity)
                    Text("年租¥\(Int(payout.annualRent))")
                        .font(.system(size: 12))
                        .foregroundColor(.themeText2)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color(hex: "FFF3E0"))
                        .cornerRadius(.infinity)
                }
                // 第三行：免租期 + 备注
                HStack(spacing: 6) {
                    if payout.rentFreeDays > 0 {
                        Text("免租\(payout.rentFreeDays)天")
                            .font(.system(size: 11))
                            .foregroundColor(.themeAmber)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 3)
                            .background(Color(hex: "FFF8E1"))
                            .cornerRadius(.infinity)
                    }
                    if !payout.notes.isEmpty {
                        Text(payout.notes)
                            .font(.system(size: 11))
                            .foregroundColor(.themeText2)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 3)
                            .background(Color(hex: "F3E5F5"))
                            .cornerRadius(.infinity)
                            .lineLimit(1)
                    }
                }
            }
            Spacer()
            let paidCount = payout.monthlyPayouts.filter { $0.isPaid }.count
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(paidCount)/12月")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.themeText2)
                Text("已打¥\(Int(payout.monthlyPayouts.filter { $0.isPaid }.reduce(0) { $0 + $1.amount }))")
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "6B3FA0"))
            }
        }
        .padding(14)
        .background(Color.themePanel)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.themeBorder, lineWidth: 1))
    }
}

// MARK: - 打租详情
struct PayoutDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let payout: PayoutRecord
    private let months = ["1月","2月","3月","4月","5月","6月","7月","8月","9月","10月","11月","12月"]

    private var dateFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "yyyy年M月d日"
        return f
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("基本信息") {
                    LabeledContent("房号", value: payout.roomNumber)
                    LabeledContent("管理", value: payout.manager)
                    LabeledContent("户型", value: payout.unitType)
                    LabeledContent("年租金", value: "¥\(Int(payout.annualRent))")
                    LabeledContent("押金", value: "¥\(Int(payout.deposit))")
                    LabeledContent("付款方式", value: payout.paymentMethod)
                    LabeledContent("免租期", value: payout.rentFreeDays > 0 ? "\(payout.rentFreeDays)天" : "无")
                    LabeledContent("起租期", value: dateFormatter.string(from: payout.leaseStartDate))
                    LabeledContent("到期日", value: dateFormatter.string(from: payout.leaseEndDate))
                    if !payout.leaseDuration.isEmpty { LabeledContent("租期", value: payout.leaseDuration) }
                    LabeledContent("水表底数", value: "\(payout.waterMeterBase)")
                    if !payout.notes.isEmpty { LabeledContent("备注", value: payout.notes) }
                }
                Section("月度打租（金额可修改，打勾可取消）") {
                    ForEach(0..<12, id: \.self) { idx in
                        MonthPayoutRow(payout: payout, month: idx + 1, label: months[idx], defaultAmount: payout.annualRent / 12)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.themeBg)
            .navigationTitle(payout.roomNumber)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() }.foregroundColor(.themeAccent) } }
        }
    }
}

// MARK: - 月度打租行（可编辑金额+可取消打勾）
struct MonthPayoutRow: View {
    let payout: PayoutRecord
    let month: Int
    let label: String
    let defaultAmount: Double
    @State private var amountText: String
    @State private var isPaid: Bool

    init(payout: PayoutRecord, month: Int, label: String, defaultAmount: Double) {
        self.payout = payout
        self.month = month
        self.label = label
        self.defaultAmount = defaultAmount
        let record = payout.monthlyPayouts.first { $0.month == month }
        let amt = record?.amount ?? defaultAmount
        _amountText = State(initialValue: amt > 0 ? String(Int(amt)) : "")
        _isPaid = State(initialValue: record?.isPaid ?? false)
    }

    var body: some View {
        HStack {
            Text(label).foregroundColor(.themeText).frame(width: 40, alignment: .leading)
            Spacer()
            TextField("金额", text: $amountText)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .foregroundColor(.themeText)
                .frame(width: 90)
                .onChange(of: amountText) { _, _ in updateRecord() }
            Text("元").foregroundColor(.themeText3)
            Button {
                isPaid.toggle()
                updateRecord()
            } label: {
                Image(systemName: isPaid ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isPaid ? .themeAccent : .themeText3)
                    .font(.system(size: 22))
            }
            .buttonStyle(.plain)
        }
    }

    private func updateRecord() {
        let amount = Double(amountText) ?? 0
        if let index = payout.monthlyPayouts.firstIndex(where: { $0.month == month }) {
            payout.monthlyPayouts[index].amount = amount
            payout.monthlyPayouts[index].isPaid = isPaid
            payout.monthlyPayouts[index].paidDate = isPaid ? Date() : nil
        } else {
            let record = PayoutMonthRecord(month: month, amount: amount, isPaid: isPaid)
            record.paidDate = isPaid ? Date() : nil
            payout.monthlyPayouts.append(record)
        }
    }
}

// MARK: - 新增打租记录
struct AddPayoutView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    private let editingPayout: PayoutRecord?

    @State private var roomNumber: String
    @State private var manager: String
    @State private var unitType: String
    @State private var leaseStartDate: Date
    @State private var leaseEndDate: Date
    @State private var leaseDuration: String
    @State private var rentFreeDaysText: String
    @State private var annualRentText: String
    @State private var depositText: String
    @State private var waterMeterText: String
    @State private var paymentMethod: String
    @State private var notes: String

    private let unitTypes = ["单间上层","单间下层","独立厨房上层","独立厨房下层","复式","中空复式","平层","双钥匙一套","三房"]
    private let methods = ["月付","季付","半年付","年付"]

    init(payout: PayoutRecord? = nil) {
        editingPayout = payout
        _roomNumber = State(initialValue: payout?.roomNumber ?? "")
        _manager = State(initialValue: payout?.manager ?? "")
        _unitType = State(initialValue: payout?.unitType ?? "")
        _leaseStartDate = State(initialValue: payout?.leaseStartDate ?? Date())
        _leaseEndDate = State(initialValue: payout?.leaseEndDate ?? Date())
        _leaseDuration = State(initialValue: payout?.leaseDuration ?? "")
        _rentFreeDaysText = State(initialValue: payout.map { $0.rentFreeDays > 0 ? String($0.rentFreeDays) : "" } ?? "")
        _annualRentText = State(initialValue: payout.map { $0.annualRent > 0 ? String(Int($0.annualRent)) : "" } ?? "")
        _depositText = State(initialValue: payout.map { $0.deposit > 0 ? String(Int($0.deposit)) : "" } ?? "")
        _waterMeterText = State(initialValue: payout.map { $0.waterMeterBase > 0 ? String($0.waterMeterBase) : "" } ?? "")
        _paymentMethod = State(initialValue: payout?.paymentMethod ?? "月付")
        _notes = State(initialValue: payout?.notes ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("基本信息") {
                    TextField("房号", text: $roomNumber)
                    TextField("管理人", text: $manager)
                    Picker("户型", selection: $unitType) { Text("请选择").tag(""); ForEach(unitTypes, id: \.self) { Text($0).tag($0) } }
                }
                Section("租赁信息") {
                    WheelDateField(label: "起租期", date: $leaseStartDate)
                    WheelDateField(label: "到期日", date: $leaseEndDate)
                    TextField("租期（自由输入）", text: $leaseDuration)
                    TextField("免租期（天）", text: $rentFreeDaysText)
                        .keyboardType(.numberPad)
                    Picker("付款方式", selection: $paymentMethod) { ForEach(methods, id: \.self) { Text($0).tag($0) } }
                }
                Section("金额") {
                    AmountField(label: "年租金", text: $annualRentText)
                    AmountField(label: "押金", text: $depositText)
                    TextField("水表底数", text: $waterMeterText)
                        .keyboardType(.numberPad)
                }
                Section("备注") { TextField("备注", text: $notes, axis: .vertical) }
            }
            .scrollContentBackground(.hidden)
            .background(Color.themeBg)
            .navigationTitle(editingPayout == nil ? "新增包租" : "编辑包租")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        if let p = editingPayout {
                            p.roomNumber = roomNumber
                            p.manager = manager
                            p.unitType = unitType
                            p.leaseStartDate = leaseStartDate
                            p.leaseEndDate = leaseEndDate
                            p.leaseDuration = leaseDuration
                            p.rentFreeDays = Int(rentFreeDaysText) ?? 0
                            p.annualRent = Double(annualRentText) ?? 0
                            p.deposit = Double(depositText) ?? 0
                            p.waterMeterBase = Int(waterMeterText) ?? 0
                            p.paymentMethod = paymentMethod
                            p.notes = notes
                        } else {
                            let payout = PayoutRecord(
                                roomNumber: roomNumber, manager: manager, unitType: unitType,
                                leaseStartDate: leaseStartDate, leaseEndDate: leaseEndDate,
                                leaseDuration: leaseDuration, rentFreeDays: Int(rentFreeDaysText) ?? 0,
                                annualRent: Double(annualRentText) ?? 0,
                                deposit: Double(depositText) ?? 0,
                                waterMeterBase: Int(waterMeterText) ?? 0, paymentMethod: paymentMethod, notes: notes)
                            modelContext.insert(payout)
                        }
                        dismiss()
                    }
                    .disabled(roomNumber.isEmpty)
                    .foregroundColor(.themeAccent)
                }
            }
        }
    }
}
