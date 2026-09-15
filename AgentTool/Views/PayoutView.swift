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

    private var paidCount: Int {
        payout.monthlyPayouts.filter { $0.isPaid }.count
    }

    private var paidAmount: Double {
        payout.monthlyPayouts.filter { $0.isPaid }.reduce(0) { $0 + $1.amount }
    }

    private var paidUtility: Double {
        payout.monthlyUtilityRecords.filter { $0.isSettled }.reduce(0) { $0 + $1.waterAmount + $1.electricAmount }
    }

    // 根据付款方式计算付款期数
    private var periodCount: Int {
        switch payout.paymentMethod {
        case "季付": return 4
        case "半年付": return 2
        case "年付": return 1
        default: return 12
        }
    }

    // 根据付款方式获取每期对应的月份
    private func periodMonth(for index: Int) -> Int {
        switch payout.paymentMethod {
        case "季付": return (index + 1) * 3
        case "半年付": return (index + 1) * 6
        case "年付": return 12
        default: return index + 1
        }
    }

    // 下次打租信息
    private var nextPayout: (month: Int, amount: Double)? {
        for i in 0..<periodCount {
            let month = periodMonth(for: i)
            if let record = payout.monthlyPayouts.first(where: { $0.month == month }), !record.isPaid {
                return (month, record.amount)
            } else if payout.monthlyPayouts.first(where: { $0.month == month }) == nil {
                // 没有记录说明还未付，计算默认金额
                let defaultAmount = calculatePeriodAmount(for: i)
                return (month, defaultAmount)
            }
        }
        return nil
    }

    // 根据免租期计算每期金额
    private func calculatePeriodAmount(for index: Int) -> Double {
        let monthlyRent = payout.annualRent / 12.0
        let rentFreeDays = payout.rentFreeDays
        let periodMonths = 12 / periodCount

        if index == 0 && rentFreeDays > 0 {
            // 第一期扣除免租期
            let totalDays = periodMonths * 30
            let freeDays = min(rentFreeDays, totalDays)
            let payableDays = totalDays - freeDays
            return (monthlyRent / 30.0) * Double(payableDays)
        }
        return monthlyRent * Double(periodMonths)
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                // 第一行：房号 + 户型 + 付款方式
                HStack(spacing: 6) {
                    Text(payout.roomNumber)
                        .font(.system(size: 16, weight: .semibold))
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
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                    Text(payout.paymentMethod)
                        .font(.system(size: 10))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color(hex: "F0E8FE"))
                        .foregroundColor(Color(hex: "6B3FA0"))
                        .cornerRadius(.infinity)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                }
                // 第二行：付款日 + 年租
                HStack(spacing: 6) {
                    Text("\(payout.rentDueDay)号")
                        .font(.system(size: 12))
                        .foregroundColor(.themeText2)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color(hex: "FDF0F0"))
                        .cornerRadius(.infinity)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                    Text("年租\(Int(payout.annualRent))")
                        .font(.system(size: 12))
                        .foregroundColor(.themeText2)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color(hex: "FFF3E0"))
                        .cornerRadius(.infinity)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                }
                // 第三行：下次打租金额
                if let next = nextPayout {
                    HStack(spacing: 0) {
                        Text("下次\(next.month)月\(payout.rentDueDay)号应付：")
                            .font(.system(size: 10))
                            .foregroundColor(.white)
                        Text("\(Int(next.amount))")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                        Text("元")
                            .font(.system(size: 10))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.themeAccentDark)
                    .cornerRadius(.infinity)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                }
                // 第四行：备注
                if !payout.notes.isEmpty {
                    Text(payout.notes)
                        .font(.system(size: 11))
                        .foregroundColor(.themeText2)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 3)
                        .background(Color(hex: "F3E5F5"))
                        .cornerRadius(.infinity)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            Spacer()

            // 右侧：已付次数 + 已付金额 + 已付水电费
            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 0) {
                    Text("已付")
                        .font(.system(size: 10))
                        .foregroundColor(.white)
                    Text("\(paidCount)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                    Text("次租金")
                        .font(.system(size: 10))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.themeAccent)
                .cornerRadius(.infinity)

                HStack(spacing: 0) {
                    Text("已付")
                        .font(.system(size: 10))
                        .foregroundColor(.white)
                    Text("\(Int(paidAmount))")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                    Text("元")
                        .font(.system(size: 10))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color(hex: "6B3FA0"))
                .cornerRadius(.infinity)

                HStack(spacing: 0) {
                    Text("已付水电")
                        .font(.system(size: 10))
                        .foregroundColor(.white)
                    Text("\(Int(paidUtility))")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                    Text("元")
                        .font(.system(size: 10))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.themeAmber)
                .cornerRadius(.infinity)
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

    // 根据付款方式计算付款期数
    private var periodCount: Int {
        switch payout.paymentMethod {
        case "季付": return 4
        case "半年付": return 2
        case "年付": return 1
        default: return 12
        }
    }

    // 根据付款方式计算每期金额（默认，不考虑免租期）
    private var periodAmount: Double {
        periodCount > 0 ? payout.annualRent / Double(periodCount) : 0
    }

    // 根据免租期计算每期金额（第一期扣除免租期）
    private func calculatePeriodAmount(for index: Int) -> Double {
        let monthlyRent = payout.annualRent / 12.0
        let rentFreeDays = payout.rentFreeDays
        let periodMonths = 12 / periodCount

        if index == 0 && rentFreeDays > 0 {
            // 第一期扣除免租期（自然月按30天算）
            let totalDays = periodMonths * 30
            let freeDays = min(rentFreeDays, totalDays)
            let payableDays = totalDays - freeDays
            return (monthlyRent / 30.0) * Double(payableDays)
        }
        return monthlyRent * Double(periodMonths)
    }

    // 根据付款方式获取每期对应的月份（用于关联monthlyPayouts）
    private func periodMonth(for index: Int) -> Int {
        switch payout.paymentMethod {
        case "季付": return (index + 1) * 3
        case "半年付": return (index + 1) * 6
        case "年付": return 12
        default: return index + 1
        }
    }

    // 根据付款方式获取每期标签
    private func periodLabel(for index: Int) -> String {
        switch payout.paymentMethod {
        case "季付": return "第\(index + 1)季"
        case "半年付": return index == 0 ? "上半年" : "下半年"
        case "年付": return "全年"
        default: return months[index]
        }
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
                    LabeledContent("交租日", value: "每月\(payout.rentDueDay)号")
                    LabeledContent("免租期", value: payout.rentFreeDays > 0 ? "\(payout.rentFreeDays)天" : "无")
                    LabeledContent("起租期", value: dateFormatter.string(from: payout.leaseStartDate))
                    LabeledContent("到期日", value: dateFormatter.string(from: payout.leaseEndDate))
                    if !payout.leaseDuration.isEmpty { LabeledContent("租期", value: payout.leaseDuration) }
                    if !payout.notes.isEmpty { LabeledContent("备注", value: payout.notes) }
                }

                Section("打租计划（\(payout.paymentMethod)，共\(periodCount)期）") {
                    ForEach(0..<periodCount, id: \.self) { idx in
                        let month = periodMonth(for: idx)
                        let amount = calculatePeriodAmount(for: idx)
                        MonthPayoutRow(payout: payout, month: month, label: periodLabel(for: idx), defaultAmount: amount)
                    }
                }

                Section("水电结算（按月，金额可输入，打勾可取消）") {
                    ForEach(0..<12, id: \.self) { idx in
                        let month = idx + 1
                        PayoutUtilityRow(payout: payout, month: month, label: months[idx])
                    }
                }

                Section("水电底数") {
                    LabeledContent("水表底数", value: "\(payout.waterMeterBase)")
                    LabeledContent("电表底数", value: "\(payout.electricMeterBase)")
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
            Text(label)
                .foregroundColor(.themeText)
                .frame(width: 55, alignment: .leading)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
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

// MARK: - 包租按月水电费行（可输入金额+可取消打勾）
struct PayoutUtilityRow: View {
    let payout: PayoutRecord
    let month: Int
    let label: String
    @State private var waterText: String
    @State private var electricText: String
    @State private var isSettled: Bool

    init(payout: PayoutRecord, month: Int, label: String) {
        self.payout = payout
        self.month = month
        self.label = label
        let record = payout.monthlyUtilityRecords.first { $0.month == month }
        _waterText = State(initialValue: record?.waterAmount ?? 0 > 0 ? String(Int(record?.waterAmount ?? 0)) : "")
        _electricText = State(initialValue: record?.electricAmount ?? 0 > 0 ? String(Int(record?.electricAmount ?? 0)) : "")
        _isSettled = State(initialValue: record?.isSettled ?? false)
    }

    var body: some View {
        HStack(spacing: 8) {
            Text(label).foregroundColor(.themeText).frame(width: 35, alignment: .leading)
            Spacer()
            Text("水").foregroundColor(.themeText3).font(.system(size: 12))
            TextField("0", text: $waterText)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .foregroundColor(.themeText)
                .frame(width: 50)
                .onChange(of: waterText) { _, _ in updateRecord() }
            Text("电").foregroundColor(.themeText3).font(.system(size: 12))
            TextField("0", text: $electricText)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .foregroundColor(.themeText)
                .frame(width: 50)
                .onChange(of: electricText) { _, _ in updateRecord() }
            Button {
                isSettled.toggle()
                updateRecord()
            } label: {
                Image(systemName: isSettled ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSettled ? .themeAccent : .themeText3)
                    .font(.system(size: 22))
            }
            .buttonStyle(.plain)
        }
    }

    private func updateRecord() {
        let water = Double(waterText) ?? 0
        let electric = Double(electricText) ?? 0
        if let index = payout.monthlyUtilityRecords.firstIndex(where: { $0.month == month }) {
            payout.monthlyUtilityRecords[index].waterAmount = water
            payout.monthlyUtilityRecords[index].electricAmount = electric
            payout.monthlyUtilityRecords[index].isSettled = isSettled
        } else {
            let record = PayoutUtilityRecord(month: month, waterAmount: water, electricAmount: electric, isSettled: isSettled)
            payout.monthlyUtilityRecords.append(record)
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
    @State private var monthlyRentText: String
    @State private var depositText: String
    @State private var waterMeterText: String
    @State private var electricMeterText: String
    @State private var rentDueDay: Int
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
        _monthlyRentText = State(initialValue: payout.map { $0.annualRent > 0 ? String(Int($0.annualRent / 12)) : "" } ?? "")
        _depositText = State(initialValue: payout.map { $0.deposit > 0 ? String(Int($0.deposit)) : "" } ?? "")
        _waterMeterText = State(initialValue: payout.map { $0.waterMeterBase > 0 ? String($0.waterMeterBase) : "" } ?? "")
        _electricMeterText = State(initialValue: payout.map { $0.electricMeterBase > 0 ? String($0.electricMeterBase) : "" } ?? "")
        _rentDueDay = State(initialValue: payout?.rentDueDay ?? 1)
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
                        .onChange(of: annualRentText) { _, _ in
                            let annual = Double(annualRentText) ?? 0
                            if annual > 0 {
                                monthlyRentText = String(Int(annual / 12))
                            }
                        }
                    AmountField(label: "月租金", text: $monthlyRentText)
                        .onChange(of: monthlyRentText) { _, _ in
                            let monthly = Double(monthlyRentText) ?? 0
                            if monthly > 0 {
                                annualRentText = String(Int(monthly * 12))
                            }
                        }
                    AmountField(label: "押金", text: $depositText)
                    Picker("交租日", selection: $rentDueDay) { ForEach(1...31, id: \.self) { Text("\($0)号").tag($0) } }
                }
                Section("水电底数") {
                    TextField("水表底数", text: $waterMeterText)
                        .keyboardType(.numberPad)
                    TextField("电表底数", text: $electricMeterText)
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
                            p.electricMeterBase = Int(electricMeterText) ?? 0
                            p.rentDueDay = rentDueDay
                            p.paymentMethod = paymentMethod
                            p.notes = notes
                        } else {
                            let payout = PayoutRecord(
                                roomNumber: roomNumber, manager: manager, unitType: unitType,
                                leaseStartDate: leaseStartDate, leaseEndDate: leaseEndDate,
                                leaseDuration: leaseDuration, rentFreeDays: Int(rentFreeDaysText) ?? 0,
                                annualRent: Double(annualRentText) ?? 0,
                                deposit: Double(depositText) ?? 0,
                                waterMeterBase: Int(waterMeterText) ?? 0,
                                electricMeterBase: Int(electricMeterText) ?? 0,
                                rentDueDay: rentDueDay,
                                paymentMethod: paymentMethod, notes: notes)
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
