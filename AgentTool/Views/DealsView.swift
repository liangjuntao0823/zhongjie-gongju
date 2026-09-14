import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct DealsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DealRecord.date, order: .reverse) private var deals: [DealRecord]
    @Query(sort: \MiscIncome.date, order: .reverse) private var incomes: [MiscIncome]
    @Query(sort: \MiscExpense.date, order: .reverse) private var expenses: [MiscExpense]
    @State private var showingAddDeal = false
    @State private var selectedTab = 0
    @State private var searchText = ""
    @State private var selectedYear: Int? = nil
    @State private var selectedMonth: Int? = nil
    @State private var editingDeal: DealRecord?
    @State private var editingIncome: MiscIncome?
    @State private var editingExpense: MiscExpense?
    @State private var showImportExport = false
    @State private var showFileImporter = false
    @State private var exportURL: URL?

    private let availableYears = [2024, 2025, 2026, 2027, 2028]

    private var filteredDeals: [DealRecord] {
        deals.filter { deal in
            let cal = Calendar.current
            let yearMatch = selectedYear == nil || cal.component(.year, from: deal.date) == selectedYear
            let monthMatch = selectedMonth == nil || cal.component(.month, from: deal.date) == selectedMonth
            let searchMatch = searchText.isEmpty ||
                deal.roomNumber.localizedCaseInsensitiveContains(searchText) ||
                deal.landlord.localizedCaseInsensitiveContains(searchText) ||
                deal.unitType.localizedCaseInsensitiveContains(searchText) ||
                deal.manager.localizedCaseInsensitiveContains(searchText) ||
                deal.source.localizedCaseInsensitiveContains(searchText) ||
                deal.notes.localizedCaseInsensitiveContains(searchText)
            return yearMatch && monthMatch && searchMatch
        }
    }

    private var filteredIncomes: [MiscIncome] {
        incomes.filter { inc in
            let cal = Calendar.current
            let yearMatch = selectedYear == nil || cal.component(.year, from: inc.date) == selectedYear
            let monthMatch = selectedMonth == nil || cal.component(.month, from: inc.date) == selectedMonth
            let searchMatch = searchText.isEmpty ||
                inc.item.localizedCaseInsensitiveContains(searchText) ||
                inc.notes.localizedCaseInsensitiveContains(searchText)
            return yearMatch && monthMatch && searchMatch
        }
    }

    private var filteredExpenses: [MiscExpense] {
        expenses.filter { exp in
            let cal = Calendar.current
            let yearMatch = selectedYear == nil || cal.component(.year, from: exp.date) == selectedYear
            let monthMatch = selectedMonth == nil || cal.component(.month, from: exp.date) == selectedMonth
            let searchMatch = searchText.isEmpty ||
                exp.item.localizedCaseInsensitiveContains(searchText) ||
                exp.notes.localizedCaseInsensitiveContains(searchText)
            return yearMatch && monthMatch && searchMatch
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 搜索 + 筛选栏
                VStack(spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.themeText3)
                        TextField("搜索房号、房东、户型、备注…", text: $searchText)
                            .textFieldStyle(.plain)
                            .foregroundColor(.themeText)
                        if !searchText.isEmpty {
                            Button { searchText = "" } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.themeText3)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.themePanel)
                    .cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.themeBorder, lineWidth: 1))

                    HStack(spacing: 8) {
                        Picker("年份", selection: $selectedYear) {
                            Text("全部年").tag(nil as Int?)
                            ForEach(availableYears, id: \.self) { year in
                                Text("\(year)年").tag(year as Int?)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(.themeAccent)

                        Picker("月份", selection: $selectedMonth) {
                            Text("全部月").tag(nil as Int?)
                            ForEach(1...12, id: \.self) { m in
                                Text("\(m)月").tag(m as Int?)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(.themeAccent)

                        Spacer()

                        if selectedYear != nil || selectedMonth != nil {
                            Button {
                                selectedYear = nil
                                selectedMonth = nil
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.themeText3)
                            }
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
                .background(Color.themeBg)

                Picker("分类", selection: $selectedTab) {
                    Text("成交记录").tag(0)
                    Text("杂项收入").tag(1)
                    Text("杂项支出").tag(2)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.bottom, 8)
                .background(Color.themeBg)

                if selectedTab == 0 {
                    dealList
                } else if selectedTab == 1 {
                    incomeList
                } else {
                    expenseList
                }
            }
            .background(Color.themeBg)
            .navigationTitle("成交管理")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Menu {
                        Button {
                            exportToPDF()
                        } label: {
                            Label("导出PDF", systemImage: "square.and.arrow.up")
                        }
                        Button {
                            exportTemplate()
                        } label: {
                            Label("导出Excel模板", systemImage: "doc.text")
                        }
                        Button {
                            showFileImporter = true
                        } label: {
                            Label("导入数据", systemImage: "square.and.arrow.down")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(.themeAccent)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showingAddDeal = true } label: {
                        Image(systemName: "plus.circle.fill").foregroundColor(.themeAccent)
                    }
                }
            }
            .sheet(isPresented: $showingAddDeal) {
                if selectedTab == 0 {
                    AddDealView()
                } else if selectedTab == 1 {
                    AddMiscView(type: .income)
                } else {
                    AddMiscView(type: .expense)
                }
            }
            .sheet(item: $editingDeal) { deal in
                EditDealView(deal: deal)
            }
            .sheet(item: $editingIncome) { inc in
                EditMiscView(item: .income(inc))
            }
            .sheet(item: $editingExpense) { exp in
                EditMiscView(item: .expense(exp))
            }
            .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.commaSeparatedText]) { result in
                if case .success(let url) = result {
                    importFromCSV(url: url)
                }
            }
            .sheet(item: $exportURL) { url in
                ShareSheet(activityItems: [url])
            }
        }
    }

    // MARK: - 导出PDF
    private func exportToPDF() {
        let pdfData = NSMutableData()
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 595, height: 842), format: UIGraphicsPDFRendererFormat())

        let title = selectedTab == 0 ? "成交记录" : (selectedTab == 1 ? "杂项收入" : "杂项支出")
        let records = selectedTab == 0 ? filteredDeals.count : (selectedTab == 1 ? filteredIncomes.count : filteredExpenses.count)

        renderer.writePDF(to: pdfData) { context in
            let cgContext = context.cgContext
            cgContext.setFillColor(UIColor.black.cgColor)

            // 标题
            let titleFont = UIFont.boldSystemFont(ofSize: 18)
            let titleAttrs: [NSAttributedString.Key: Any] = [.font: titleFont]
            (title as NSString).draw(at: CGPoint(x: 40, y: 40), withAttributes: titleAttrs)

            // 日期
            let dateFont = UIFont.systemFont(ofSize: 10)
            let dateAttrs: [NSAttributedString.Key: Any] = [.font: dateFont, .foregroundColor: UIColor.gray]
            let dateStr = "导出时间: \(DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .short))"
            (dateStr as NSString).draw(at: CGPoint(x: 40, y: 65), withAttributes: dateAttrs)

            // 表头
            let headerFont = UIFont.boldSystemFont(ofSize: 10)
            let headerAttrs: [NSAttributedString.Key: Any] = [.font: headerFont, .foregroundColor: UIColor.white]
            cgContext.setFillColor(UIColor(red: 0.08, green: 0.23, blue: 0.20, alpha: 1.0).cgColor)
            cgContext.fill(CGRect(x: 40, y: 90, width: 515, height: 25))

            let colFont = UIFont.systemFont(ofSize: 9)
            let colAttrs: [NSAttributedString.Key: Any] = [.font: colFont]

            if selectedTab == 0 {
                let headers = ["日期", "房号", "房东", "户型", "租金", "中介费", "备注"]
                let widths: [CGFloat] = [70, 70, 60, 70, 60, 70, 115]
                var x: CGFloat = 45
                for (i, h) in headers.enumerated() {
                    (h as NSString).draw(at: CGPoint(x: x, y: 96), withAttributes: headerAttrs)
                    x += widths[i]
                }
                var y: CGFloat = 120
                for deal in filteredDeals {
                    if y > 800 {
                        context.beginPage()
                        y = 40
                    }
                    let vals = [
                        DateFormatter.localizedString(from: deal.date, dateStyle: .short, timeStyle: .none),
                        deal.roomNumber, deal.landlord, deal.unitType,
                        "¥\(Int(deal.rent))", "¥\(Int(deal.totalFee))", deal.notes
                    ]
                    x = 45
                    for (i, v) in vals.enumerated() {
                        (v as NSString).draw(at: CGPoint(x: x, y: y), withAttributes: colAttrs)
                        x += widths[i]
                    }
                    y += 18
                }
            } else {
                let headers = ["日期", "项目", "金额", "备注"]
                let widths: [CGFloat] = [100, 150, 100, 165]
                var x: CGFloat = 45
                for (i, h) in headers.enumerated() {
                    (h as NSString).draw(at: CGPoint(x: x, y: 96), withAttributes: headerAttrs)
                    x += widths[i]
                }
                var y: CGFloat = 120
                let items = selectedTab == 1 ? filteredIncomes.map { ($0.date, $0.item, $0.amount, $0.notes) } : filteredExpenses.map { ($0.date, $0.item, $0.amount, $0.notes) }
                for item in items {
                    if y > 800 {
                        context.beginPage()
                        y = 40
                    }
                    let vals = [
                        DateFormatter.localizedString(from: item.0, dateStyle: .short, timeStyle: .none),
                        item.1, "¥\(Int(item.2))", item.3
                    ]
                    x = 45
                    for (i, v) in vals.enumerated() {
                        (v as NSString).draw(at: CGPoint(x: x, y: y), withAttributes: colAttrs)
                        x += widths[i]
                    }
                    y += 18
                }
            }

            // 底部统计
            let totalFont = UIFont.boldSystemFont(ofSize: 11)
            let totalAttrs: [NSAttributedString.Key: Any] = [.font: totalFont]
            let totalStr = "共 \(records) 条记录"
            (totalStr as NSString).draw(at: CGPoint(x: 40, y: 810), withAttributes: totalAttrs)
        }

        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("\(title)-\(Int(Date().timeIntervalSince1970)).pdf")
        pdfData.write(to: fileURL, atomically: true)
        exportURL = ExportURL(url: fileURL)
    }

    // MARK: - 导出Excel模板(CSV)
    private func exportTemplate() {
        var csv = ""
        if selectedTab == 0 {
            csv = "成交日期,房号,房东,户型,起租期,到期日,租期,月租金,押金,预存,交租日,房东中介费,租客中介费,管理人,客源,备注\n"
            csv += "2026-01-15,1-101,张三,单间上层,2026-01-15,2027-01-14,一年,1000,1000,500,1,500,500,李四,58同城,示例数据\n"
        } else if selectedTab == 1 {
            csv = "日期,项目,金额,备注\n2026-01-15,保洁费,200,示例\n"
        } else {
            csv = "日期,项目,金额,备注\n2026-01-15,维修费,300,示例\n"
        }
        let tempDir = FileManager.default.temporaryDirectory
        let title = selectedTab == 0 ? "成交记录" : (selectedTab == 1 ? "杂项收入" : "杂项支出")
        let fileURL = tempDir.appendingPathComponent("\(title)-模板.csv")
        try? csv.write(to: fileURL, atomically: true, encoding: .utf8)
        exportURL = ExportURL(url: fileURL)
    }

    // MARK: - 导入CSV
    private func importFromCSV(url: URL) {
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return }
        let lines = content.components(separatedBy: .newlines).dropFirst()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        var count = 0
        for line in lines {
            let cols = line.components(separatedBy: ",")
            guard cols.count >= 3 else { continue }
            if selectedTab == 0 && cols.count >= 16 {
                let date = dateFormatter.date(from: cols[0]) ?? Date()
                let deal = DealRecord(
                    date: date, roomNumber: cols[1], landlord: cols[2],
                    unitType: cols[3], leaseStart: dateFormatter.date(from: cols[4]) ?? date,
                    leaseEnd: dateFormatter.date(from: cols[5]) ?? date,
                    leaseDuration: cols[6], rent: Double(cols[7]) ?? 0,
                    deposit: Double(cols[8]) ?? 0, prepayment: Double(cols[9]) ?? 0,
                    rentDueDay: Int(cols[10]) ?? 1,
                    agentFeeLandlord: Double(cols[11]) ?? 0,
                    agentFeeTenant: Double(cols[12]) ?? 0,
                    totalFee: (Double(cols[11]) ?? 0) + (Double(cols[12]) ?? 0),
                    manager: cols[13], source: cols[14], notes: cols[15]
                )
                modelContext.insert(deal)
                count += 1
            } else if selectedTab == 1 {
                let date = dateFormatter.date(from: cols[0]) ?? Date()
                modelContext.insert(MiscIncome(date: date, item: cols[1], amount: Double(cols[2]) ?? 0, notes: cols.count > 3 ? cols[3] : ""))
                count += 1
            } else if selectedTab == 2 {
                let date = dateFormatter.date(from: cols[0]) ?? Date()
                modelContext.insert(MiscExpense(date: date, item: cols[1], amount: Double(cols[2]) ?? 0, notes: cols.count > 3 ? cols[3] : ""))
                count += 1
            }
        }
    }

    private var dealList: some View {
        List {
            ForEach(filteredDeals) { deal in
                DealRow(deal: deal)
                    .listRowBackground(Color.themeBg)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    .contentShape(Rectangle())
                    .onTapGesture { editingDeal = deal }
            }
            .onDelete(perform: deleteDeal)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.themeBg)
        .overlay {
            if filteredDeals.isEmpty {
                ContentUnavailableView("暂无成交记录", systemImage: "doc.text", description: Text("点击右上角 + 添加成交记录"))
            }
        }
    }

    private var incomeList: some View {
        List {
            ForEach(filteredIncomes) { inc in
                MiscRow(title: inc.item, subtitle: inc.notes, amount: inc.amount, date: inc.date, isIncome: true)
                    .listRowBackground(Color.themeBg)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    .contentShape(Rectangle())
                    .onTapGesture { editingIncome = inc }
            }
            .onDelete(perform: deleteIncome)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.themeBg)
        .overlay {
            if filteredIncomes.isEmpty {
                ContentUnavailableView("暂无收入记录", systemImage: "arrow.down.circle", description: Text("点击右上角 + 添加收入"))
            }
        }
    }

    private var expenseList: some View {
        List {
            ForEach(filteredExpenses) { exp in
                MiscRow(title: exp.item, subtitle: exp.notes, amount: exp.amount, date: exp.date, isIncome: false)
                    .listRowBackground(Color.themeBg)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    .contentShape(Rectangle())
                    .onTapGesture { editingExpense = exp }
            }
            .onDelete(perform: deleteExpense)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.themeBg)
        .overlay {
            if filteredExpenses.isEmpty {
                ContentUnavailableView("暂无支出记录", systemImage: "arrow.up.circle", description: Text("点击右上角 + 添加支出"))
            }
        }
    }

    private func deleteDeal(at offsets: IndexSet) {
        for index in offsets { modelContext.delete(filteredDeals[index]) }
    }
    private func deleteIncome(at offsets: IndexSet) {
        for index in offsets { modelContext.delete(filteredIncomes[index]) }
    }
    private func deleteExpense(at offsets: IndexSet) {
        for index in offsets { modelContext.delete(filteredExpenses[index]) }
    }
}

// MARK: - 筛选标签
struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12.5, weight: isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? .white : .themeText2)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(isSelected ? Color.themeAccent : Color.themePanel)
                .cornerRadius(14)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(isSelected ? Color.clear : Color.themeBorder, lineWidth: 1)
                )
        }
    }
}

// MARK: - 行组件
struct DealRow: View {
    let deal: DealRecord

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.themeAccentWeak)
                    .frame(width: 44, height: 44)
                Image(systemName: "doc.text.fill")
                    .foregroundColor(.themeAccentDark)
                    .font(.system(size: 18))
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(deal.roomNumber)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.themeText)
                    Text(deal.unitType)
                        .font(.system(size: 11))
                        .foregroundColor(.themeText3)
                }
                HStack(spacing: 8) {
                    Text("房东: \(deal.landlord)")
                        .font(.system(size: 11)).foregroundColor(.themeText2)
                    Text("¥\(Int(deal.rent))/月")
                        .font(.system(size: 11)).foregroundColor(.themeText2)
                    Text("每月\(deal.rentDueDay)号交租")
                        .font(.system(size: 11)).foregroundColor(.themeText2)
                }
                if !deal.notes.isEmpty {
                    Text(deal.notes)
                        .font(.system(size: 10))
                        .foregroundColor(.themeAmber)
                        .lineLimit(1)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("+¥\(Int(deal.totalFee))")
                    .foregroundColor(.themeAccentDark)
                    .font(.system(size: 15, weight: .semibold))
                Text(deal.date, style: .date)
                    .font(.system(size: 11))
                    .foregroundColor(.themeText3)
            }
        }
        .padding(14)
        .background(Color.themePanel)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.themeBorder, lineWidth: 1))
    }
}

struct MiscRow: View {
    let title: String
    let subtitle: String
    let amount: Double
    let date: Date
    let isIncome: Bool

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(isIncome ? Color.themeAccentWeak : Color(hex: "FDF0F0"))
                    .frame(width: 44, height: 44)
                Image(systemName: isIncome ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                    .foregroundColor(isIncome ? .themeAccentDark : .themeRed)
                    .font(.system(size: 18))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.themeText)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(.themeText3)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(isIncome ? "+" : "-")¥\(Int(amount))")
                    .foregroundColor(isIncome ? .themeAccentDark : .themeRed)
                    .font(.system(size: 15, weight: .semibold))
                Text(date, style: .date)
                    .font(.system(size: 11))
                    .foregroundColor(.themeText3)
            }
        }
        .padding(14)
        .background(Color.themePanel)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.themeBorder, lineWidth: 1))
    }
}

// MARK: - 金额输入字段（不预留0）
struct AmountField: View {
    let label: String
    @Binding var text: String

    var body: some View {
        HStack {
            Text(label).foregroundColor(.themeText)
            Spacer()
            TextField("请输入", text: $text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .foregroundColor(.themeText)
                .frame(width: 120)
        }
    }
}

// MARK: - 新增成交
struct AddDealView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var date = Date()
    @State private var roomNumber = ""
    @State private var landlord = ""
    @State private var unitType = ""
    @State private var leaseStart = Date()
    @State private var leaseEnd = Date()
    @State private var leaseDuration = ""
    @State private var rentText = ""
    @State private var depositText = ""
    @State private var prepaymentText = ""
    @State private var rentDueDay = 1
    @State private var agentFeeLandlordText = ""
    @State private var agentFeeTenantText = ""
    @State private var manager = ""
    @State private var source = ""
    @State private var notes = ""

    private let unitTypes = ["单间上层", "单间下层", "独立厨房上层", "独立厨房下层", "复式", "中空复式", "平层", "双钥匙一套", "三房"]

    private var totalFee: Double {
        (Double(agentFeeLandlordText) ?? 0) + (Double(agentFeeTenantText) ?? 0)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("基本信息") {
                    DatePicker("成交日期", selection: $date, displayedComponents: .date)
                        .datePickerStyle(.compact)
                    TextField("房号", text: $roomNumber)
                    TextField("房东", text: $landlord)
                    Picker("户型", selection: $unitType) {
                        Text("请选择").tag("")
                        ForEach(unitTypes, id: \.self) { Text($0).tag($0) }
                    }
                    DatePicker("起租期", selection: $leaseStart, displayedComponents: .date)
                        .datePickerStyle(.compact)
                    DatePicker("到期日", selection: $leaseEnd, displayedComponents: .date)
                        .datePickerStyle(.compact)
                    TextField("租期（自由输入）", text: $leaseDuration)
                    Picker("交租日期", selection: $rentDueDay) {
                        ForEach(1...31, id: \.self) { day in
                            Text("每月\(day)号").tag(day)
                        }
                    }
                }
                Section("金额") {
                    AmountField(label: "月租金", text: $rentText)
                    AmountField(label: "押金", text: $depositText)
                    AmountField(label: "预存", text: $prepaymentText)
                }
                Section("中介费") {
                    AmountField(label: "房东中介费", text: $agentFeeLandlordText)
                    AmountField(label: "租客中介费", text: $agentFeeTenantText)
                    HStack { Text("合计"); Spacer(); Text("¥\(Int(totalFee))").foregroundColor(.themeAccentDark).fontWeight(.medium) }
                }
                Section("其他") {
                    TextField("管理人", text: $manager)
                    TextField("客源", text: $source)
                    TextField("备注", text: $notes, axis: .vertical)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.themeBg)
            .navigationTitle("新增成交")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        let deal = DealRecord(
                            date: date, roomNumber: roomNumber, landlord: landlord,
                            unitType: unitType, leaseStart: leaseStart, leaseEnd: leaseEnd,
                            leaseDuration: leaseDuration,
                            rent: Double(rentText) ?? 0, deposit: Double(depositText) ?? 0,
                            prepayment: Double(prepaymentText) ?? 0, rentDueDay: rentDueDay,
                            agentFeeLandlord: Double(agentFeeLandlordText) ?? 0,
                            agentFeeTenant: Double(agentFeeTenantText) ?? 0,
                            totalFee: totalFee, manager: manager, source: source, notes: notes)
                        modelContext.insert(deal)
                        dismiss()
                    }
                    .disabled(roomNumber.isEmpty)
                    .foregroundColor(.themeAccent)
                }
            }
        }
    }
}

// MARK: - 编辑成交
struct EditDealView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let deal: DealRecord

    @State private var date: Date
    @State private var roomNumber: String
    @State private var landlord: String
    @State private var unitType: String
    @State private var leaseStart: Date
    @State private var leaseEnd: Date
    @State private var leaseDuration: String
    @State private var rentText: String
    @State private var depositText: String
    @State private var prepaymentText: String
    @State private var rentDueDay: Int
    @State private var agentFeeLandlordText: String
    @State private var agentFeeTenantText: String
    @State private var manager: String
    @State private var source: String
    @State private var notes: String

    private let unitTypes = ["单间上层", "单间下层", "独立厨房上层", "独立厨房下层", "复式", "中空复式", "平层", "双钥匙一套", "三房"]

    init(deal: DealRecord) {
        self.deal = deal
        _date = State(initialValue: deal.date)
        _roomNumber = State(initialValue: deal.roomNumber)
        _landlord = State(initialValue: deal.landlord)
        _unitType = State(initialValue: deal.unitType)
        _leaseStart = State(initialValue: deal.leaseStart)
        _leaseEnd = State(initialValue: deal.leaseEnd)
        _leaseDuration = State(initialValue: deal.leaseDuration)
        _rentText = State(initialValue: deal.rent > 0 ? String(deal.rent) : "")
        _depositText = State(initialValue: deal.deposit > 0 ? String(deal.deposit) : "")
        _prepaymentText = State(initialValue: deal.prepayment > 0 ? String(deal.prepayment) : "")
        _rentDueDay = State(initialValue: deal.rentDueDay)
        _agentFeeLandlordText = State(initialValue: deal.agentFeeLandlord > 0 ? String(deal.agentFeeLandlord) : "")
        _agentFeeTenantText = State(initialValue: deal.agentFeeTenant > 0 ? String(deal.agentFeeTenant) : "")
        _manager = State(initialValue: deal.manager)
        _source = State(initialValue: deal.source)
        _notes = State(initialValue: deal.notes)
    }

    private var totalFee: Double {
        (Double(agentFeeLandlordText) ?? 0) + (Double(agentFeeTenantText) ?? 0)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("基本信息") {
                    DatePicker("成交日期", selection: $date, displayedComponents: .date)
                        .datePickerStyle(.compact)
                    TextField("房号", text: $roomNumber)
                    TextField("房东", text: $landlord)
                    Picker("户型", selection: $unitType) {
                        Text("请选择").tag("")
                        ForEach(unitTypes, id: \.self) { Text($0).tag($0) }
                    }
                    DatePicker("起租期", selection: $leaseStart, displayedComponents: .date)
                        .datePickerStyle(.compact)
                    DatePicker("到期日", selection: $leaseEnd, displayedComponents: .date)
                        .datePickerStyle(.compact)
                    TextField("租期（自由输入）", text: $leaseDuration)
                    Picker("交租日期", selection: $rentDueDay) {
                        ForEach(1...31, id: \.self) { day in
                            Text("每月\(day)号").tag(day)
                        }
                    }
                }
                Section("金额") {
                    AmountField(label: "月租金", text: $rentText)
                    AmountField(label: "押金", text: $depositText)
                    AmountField(label: "预存", text: $prepaymentText)
                }
                Section("中介费") {
                    AmountField(label: "房东中介费", text: $agentFeeLandlordText)
                    AmountField(label: "租客中介费", text: $agentFeeTenantText)
                    HStack { Text("合计"); Spacer(); Text("¥\(Int(totalFee))").foregroundColor(.themeAccentDark).fontWeight(.medium) }
                }
                Section("其他") {
                    TextField("管理人", text: $manager)
                    TextField("客源", text: $source)
                    TextField("备注", text: $notes, axis: .vertical)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.themeBg)
            .navigationTitle("编辑成交")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        deal.date = date
                        deal.roomNumber = roomNumber
                        deal.landlord = landlord
                        deal.unitType = unitType
                        deal.leaseStart = leaseStart
                        deal.leaseEnd = leaseEnd
                        deal.leaseDuration = leaseDuration
                        deal.rent = Double(rentText) ?? 0
                        deal.deposit = Double(depositText) ?? 0
                        deal.prepayment = Double(prepaymentText) ?? 0
                        deal.rentDueDay = rentDueDay
                        deal.agentFeeLandlord = Double(agentFeeLandlordText) ?? 0
                        deal.agentFeeTenant = Double(agentFeeTenantText) ?? 0
                        deal.totalFee = totalFee
                        deal.manager = manager
                        deal.source = source
                        deal.notes = notes
                        dismiss()
                    }
                    .disabled(roomNumber.isEmpty)
                    .foregroundColor(.themeAccent)
                }
            }
        }
    }
}

// MARK: - 新增杂项
struct AddMiscView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let type: MiscType

    @State private var date = Date()
    @State private var item = ""
    @State private var amountText = ""
    @State private var notes = ""

    enum MiscType { case income, expense }

    var body: some View {
        NavigationStack {
            Form {
                Section("信息") {
                    DatePicker("日期", selection: $date, displayedComponents: .date)
                        .datePickerStyle(.compact)
                    TextField("项目", text: $item)
                    AmountField(label: "金额", text: $amountText)
                    TextField("备注", text: $notes, axis: .vertical)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.themeBg)
            .navigationTitle(type == .income ? "新增收入" : "新增支出")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        let amount = Double(amountText) ?? 0
                        if type == .income {
                            modelContext.insert(MiscIncome(date: date, item: item, amount: amount, notes: notes))
                        } else {
                            modelContext.insert(MiscExpense(date: date, item: item, amount: amount, notes: notes))
                        }
                        dismiss()
                    }
                    .disabled(item.isEmpty || amountText.isEmpty)
                    .foregroundColor(.themeAccent)
                }
            }
        }
    }
}

// MARK: - 编辑杂项
struct EditMiscView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let item: MiscItem

    @State private var date: Date
    @State private var title: String
    @State private var amountText: String
    @State private var notes: String

    enum MiscItem {
        case income(MiscIncome)
        case expense(MiscExpense)
    }

    init(item: MiscItem) {
        self.item = item
        switch item {
        case .income(let inc):
            _date = State(initialValue: inc.date)
            _title = State(initialValue: inc.item)
            _amountText = State(initialValue: inc.amount > 0 ? String(inc.amount) : "")
            _notes = State(initialValue: inc.notes)
        case .expense(let exp):
            _date = State(initialValue: exp.date)
            _title = State(initialValue: exp.item)
            _amountText = State(initialValue: exp.amount > 0 ? String(exp.amount) : "")
            _notes = State(initialValue: exp.notes)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("信息") {
                    DatePicker("日期", selection: $date, displayedComponents: .date)
                        .datePickerStyle(.compact)
                    TextField("项目", text: $title)
                    AmountField(label: "金额", text: $amountText)
                    TextField("备注", text: $notes, axis: .vertical)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.themeBg)
            .navigationTitle("编辑记录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        let amount = Double(amountText) ?? 0
                        switch item {
                        case .income(let inc):
                            inc.date = date; inc.item = title; inc.amount = amount; inc.notes = notes
                        case .expense(let exp):
                            exp.date = date; exp.item = title; exp.amount = amount; exp.notes = notes
                        }
                        dismiss()
                    }
                    .disabled(title.isEmpty || amountText.isEmpty)
                    .foregroundColor(.themeAccent)
                }
            }
        }
    }
}

// MARK: - 导出URL包装
struct ExportURL: Identifiable {
    let id = UUID()
    let url: URL
}

// MARK: - 分享Sheet
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
