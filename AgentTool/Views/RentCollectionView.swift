import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct RentCollectionView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Property.roomNumber) private var properties: [Property]
    @State private var showingAddProperty = false
    @State private var editingProperty: Property?
    @State private var selectedProperty: Property?
    @State private var searchText = ""
    @State private var selectedDueDay: Int? = nil
    @State private var showUtility = false
    @State private var exportURL: ExportURL?
    @State private var showingRestore = false
    @State private var refreshID = UUID()

    // 只显示已登记的交租日期
    private var registeredDueDays: [Int] {
        Array(Set(properties.map { $0.rentDueDay })).sorted()
    }

    private var filteredProperties: [Property] {
        let currentMonth = Calendar.current.component(.month, from: Date())
        let currentDay = Calendar.current.component(.day, from: Date())
        return properties.filter { prop in
            let dayMatch = selectedDueDay == nil || prop.rentDueDay == selectedDueDay
            let searchMatch = searchText.isEmpty ||
                prop.roomNumber.localizedCaseInsensitiveContains(searchText) ||
                prop.landlord.localizedCaseInsensitiveContains(searchText) ||
                prop.unitType.localizedCaseInsensitiveContains(searchText) ||
                prop.propertyType.localizedCaseInsensitiveContains(searchText) ||
                prop.notes.localizedCaseInsensitiveContains(searchText)
            return dayMatch && searchMatch
        }.sorted { a, b in
            // 判断本月是否已收租
            let aPaid = a.monthlyRentRecords.contains { $0.month == currentMonth && $0.isPaid }
            let bPaid = b.monthlyRentRecords.contains { $0.month == currentMonth && $0.isPaid }
            // 未收租的优先
            if aPaid != bPaid { return !aPaid && bPaid }
            // 都未收租：拖租的优先，拖得越久越靠前
            if !aPaid && !bPaid {
                let aOverdue = a.rentDueDay < currentDay
                let bOverdue = b.rentDueDay < currentDay
                if aOverdue != bOverdue { return aOverdue && !bOverdue }
                if aOverdue && bOverdue {
                    // 都拖租：拖得越久越靠前
                    let aDays = currentDay - a.rentDueDay
                    let bDays = currentDay - b.rentDueDay
                    return aDays > bDays
                }
                // 都未拖租：离交租日近的排前面
                let aDays = a.rentDueDay - currentDay
                let bDays = b.rentDueDay - currentDay
                return aDays < bDays
            }
            // 都已收租：按房号排序
            return a.roomNumber < b.roomNumber
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
                        TextField("搜索房号、房东、户型…", text: $searchText)
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

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            FilterChip(title: "全部", isSelected: selectedDueDay == nil) {
                                selectedDueDay = nil
                            }
                            ForEach(registeredDueDays, id: \.self) { day in
                                FilterChip(title: "\(day)号", isSelected: selectedDueDay == day) {
                                    selectedDueDay = (selectedDueDay == day) ? nil : day
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
                .background(Color.themeBg)

                List {
                    ForEach(filteredProperties) { prop in
                        PropertyRentRow(property: prop)
                            .contentShape(Rectangle())
                            .onTapGesture { selectedProperty = prop }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    if let idx = filteredProperties.firstIndex(where: { $0.id == prop.id }) {
                                        modelContext.delete(filteredProperties[idx])
                                    }
                                } label: {
                                    Label("删除", systemImage: "trash")
                                }
                                Button {
                                    editingProperty = prop
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
                .id(refreshID)
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(Color.themeBg)
                .overlay {
                    if filteredProperties.isEmpty {
                        ContentUnavailableView("暂无房源", systemImage: "house", description: Text("点击右上角 + 添加房源"))
                    }
                }
            }
            .background(Color.themeBg)
            .navigationTitle("收租管理")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Menu {
                        Button {
                            exportToImage()
                        } label: {
                            Label("导出图片", systemImage: "photo")
                        }
                        Button {
                            exportToExcel()
                        } label: {
                            Label("导出Excel", systemImage: "tablecells")
                        }
                        Button {
                            exportTemplate()
                        } label: {
                            Label("导出Excel模板", systemImage: "doc.text")
                        }
                        Button {
                            showingRestore = true
                        } label: {
                            Label("恢复数据", systemImage: "square.and.arrow.down")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(.themeAccent)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 12) {
                        Button { showUtility = true } label: {
                            Image(systemName: "bolt.fill").foregroundColor(.themeAccent)
                        }
                        Button { showingAddProperty = true } label: {
                            Image(systemName: "plus.circle.fill").foregroundColor(.themeAccent)
                        }
                    }
                }
            }
            .sheet(isPresented: $showingAddProperty) { AddPropertyView() }
            .sheet(item: $editingProperty) { prop in AddPropertyView(property: prop) }
            .sheet(item: $selectedProperty, onDismiss: { refreshID = UUID() }) { prop in PropertyDetailView(property: prop) }
            .sheet(isPresented: $showUtility) { NavigationStack { UtilityView() } }
            .sheet(item: $exportURL) { url in
                ShareSheet(activityItems: [url.url])
            }
            .sheet(isPresented: $showingRestore) {
                RestoreBackupView(type: .properties) { success in
                    showingRestore = false
                }
            }
        }
    }

    private func deleteProperty(at offsets: IndexSet) {
        for index in offsets { modelContext.delete(filteredProperties[index]) }
    }

    // MARK: - 导出图片
    private func exportToImage() {
        let df = DateFormatter()
        df.locale = Locale(identifier: "zh_CN")
        df.dateFormat = "yyyy年M月d日 HH:mm"
        let dateStr = df.string(from: Date())
        let currentMonth = Calendar.current.component(.month, from: Date())
        let rows = filteredProperties.map { prop -> [String] in
            let paid = prop.monthlyRentRecords.contains { $0.month == currentMonth && $0.isPaid }
            return [prop.roomNumber, prop.landlord, prop.unitType,
                    "¥\(Int(prop.rent))", "\(prop.rentDueDay)号",
                    prop.propertyType, paid ? "已收" : "未收"]
        }
        let view = ExportTableView(
            title: "收租记录", dateStr: dateStr,
            headers: ["房号","房东","户型","月租","交租日","类型","本月状态"],
            rows: rows
        )
        let renderer = ImageRenderer(content: view.frame(width: 700))
        renderer.scale = 2.0
        if let image = renderer.uiImage {
            let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("收租记录-\(Int(Date().timeIntervalSince1970)).png")
            if let data = image.pngData() {
                try? data.write(to: fileURL)
                exportURL = ExportURL(url: fileURL)
            }
        }
    }

    // MARK: - 导出Excel(.xls)
    private func exportToExcel() {
        let headers = ["房号","房东","户型","月租金","交租日","房源类型","备注"]
        let rows = filteredProperties.map { [
            $0.roomNumber, $0.landlord, $0.unitType, "\(Int($0.rent))",
            "\($0.rentDueDay)", $0.propertyType, $0.notes
        ]}
        let html = makeExcelHTML(title: "收租记录", headers: headers, rows: rows)
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("收租记录-\(Int(Date().timeIntervalSince1970)).xls")
        try? html.write(to: fileURL, atomically: true, encoding: .utf8)
        exportURL = ExportURL(url: fileURL)
    }

    private func exportTemplate() {
        let headers = ["房号","房东","户型","月租金","交租日","房源类型","备注"]
        let rows = [["1-101","张三","单间上层","1000","1","管理","示例"]]
        let html = makeExcelHTML(title: "收租记录", headers: headers, rows: rows)
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("收租记录-模板.xls")
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

        for cols in rows {
            guard cols.count >= 5 else { continue }
            let prop = Property(
                roomNumber: cols[0], landlord: cols[1], unitType: cols[2],
                rent: Double(cols[3]) ?? 0, rentDueDay: Int(cols[4]) ?? 1,
                propertyType: cols.count > 5 ? cols[5] : "管理",
                notes: cols.count > 6 ? cols[6] : ""
            )
            modelContext.insert(prop)
        }
    }
}

struct PropertyRentRow: View {
    let property: Property
    private var currentMonth: Int { Calendar.current.component(.month, from: Date()) }

    private var paidMonthsCount: Int {
        property.monthlyRentRecords.filter { $0.isPaid }.count
    }

    private var totalUtility: Double {
        property.quarterlyUtilityRecords.reduce(0) { $0 + $1.electricAmount + $1.waterAmount }
    }

    private var leaseYears: String {
        guard !property.leaseStart.isEmpty, !property.leaseEnd.isEmpty else { return "" }
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy.M.d"
        guard let start = fmt.date(from: property.leaseStart),
              let end = fmt.date(from: property.leaseEnd) else { return "" }
        let months = Calendar.current.dateComponents([.month], from: start, to: end).month ?? 0
        if months >= 12 {
            let years = Double(months) / 12.0
            return years.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(years))年" : String(format: "%.1f年", years)
        }
        return "\(months)个月"
    }

    var body: some View {
        HStack(spacing: 12) {
            // 左侧字图标
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(property.typeBgColor)
                    .frame(width: 44, height: 44)
                Text(property.typeChar)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(property.typeColor)
            }

            VStack(alignment: .leading, spacing: 5) {
                // 第一行：房号 + 租金
                HStack(spacing: 6) {
                    Text(property.roomNumber)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.themeText)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color(hex: "F0F0F0"))
                        .cornerRadius(.infinity)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                    Text("租/\(Int(property.rent))")
                        .font(.system(size: 12))
                        .foregroundColor(.themeText2)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color(hex: "FFF3E0"))
                        .cornerRadius(.infinity)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                }
                // 第二行：交租日 + 房东 + 预存
                HStack(spacing: 6) {
                    Text("\(property.rentDueDay)号")
                        .font(.system(size: 12))
                        .foregroundColor(.themeText2)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color(hex: "FDF0F0"))
                        .cornerRadius(.infinity)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                    if !property.landlord.isEmpty {
                        Text(property.landlord)
                            .font(.system(size: 12))
                            .foregroundColor(.themeText2)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color(hex: "E8F0FE"))
                            .cornerRadius(.infinity)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                    if property.prepayment > 0 {
                        Text("预/\(Int(property.prepayment))")
                            .font(.system(size: 12))
                            .foregroundColor(.themeText2)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color(hex: "E8F5E9"))
                            .cornerRadius(.infinity)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                }
                // 第三行：租期
                HStack(spacing: 6) {
                    Text(property.leaseStart.isEmpty ? "未出租" : "\(property.leaseStart) 至 \(property.leaseEnd)")
                        .font(.system(size: 12))
                        .foregroundColor(property.leaseStart.isEmpty ? .themeAmber : .themeText3)
                    if !leaseYears.isEmpty {
                        Text(leaseYears)
                            .font(.system(size: 12))
                            .foregroundColor(.themeText3)
                    }
                }
            }
            Spacer()

            // 右侧：已收月数 + 累计水电 + 收租状态
            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 0) {
                    Text("已收")
                        .font(.system(size: 10.5))
                        .foregroundColor(.themeText2)
                    Text("\(paidMonthsCount)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.themeAccentDark)
                    Text("个月")
                        .font(.system(size: 10.5))
                        .foregroundColor(.themeText2)
                }
                HStack(spacing: 0) {
                    Text("累计收水电:")
                        .font(.system(size: 10))
                        .foregroundColor(.themeText2)
                    Text("\(Int(totalUtility))")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.themeAccentDark)
                    Text("元")
                        .font(.system(size: 10))
                        .foregroundColor(.themeText2)
                }
                let paid = property.monthlyRentRecords.contains { $0.month == currentMonth && $0.isPaid }
                HStack(spacing: 4) {
                    Image(systemName: paid ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(paid ? .themeAccent : .themeText3)
                        .font(.system(size: 16))
                    Text(paid ? "已收" : "待收")
                        .font(.system(size: 11))
                        .foregroundColor(paid ? .themeAccentDark : .themeAmber)
                }
            }
        }
        .padding(14)
        .background(Color.themePanel)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.themeBorder, lineWidth: 1))
    }
}

// MARK: - 房源详情（收租/水电）
struct PropertyDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let property: Property
    @State private var currentMonth = Calendar.current.component(.month, from: Date())
    @State private var shareImage: UIImage?
    @State private var showShareSheet = false

    private let months = ["1月","2月","3月","4月","5月","6月","7月","8月","9月","10月","11月","12月"]
    private let quarters = ["1季度","2季度","3季度","4季度"]

    private func generateShareImage() {
        let renderer = ImageRenderer(content: ShareDetailRenderView(property: property))
        renderer.scale = 3.0
        if let image = renderer.uiImage {
            shareImage = image
            showShareSheet = true
        } else {
            // 备用方案：用更低scale重试
            renderer.scale = 2.0
            if let image = renderer.uiImage {
                shareImage = image
                showShareSheet = true
            }
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("房源信息") {
                    LabeledContent("房号", value: property.roomNumber)
                    LabeledContent("房东", value: property.landlord)
                    LabeledContent("户型", value: property.unitType)
                    LabeledContent("房源类型", value: property.propertyType)
                    LabeledContent("租金", value: "¥\(Int(property.rent))/月")
                    LabeledContent("押金", value: "¥\(Int(property.deposit))")
                    LabeledContent("预存", value: "¥\(Int(property.prepayment))")
                    LabeledContent("租期", value: property.leaseStart.isEmpty ? "未出租" : "\(property.leaseStart) 至 \(property.leaseEnd)")
                    LabeledContent("交租日", value: "每月\(property.rentDueDay)号")
                    if !property.notes.isEmpty { LabeledContent("备注", value: property.notes) }
                }

                Section("月度收租（金额可修改，打勾可取消）") {
                    ForEach(0..<12, id: \.self) { idx in
                        let month = idx + 1
                        MonthRentRow(property: property, month: month, label: months[idx])
                    }
                }

                Section("水电结算（金额可输入，打勾可取消）") {
                    ForEach(0..<4, id: \.self) { idx in
                        let quarter = idx + 1
                        QuarterUtilityRow(property: property, quarter: quarter, label: quarters[idx])
                    }
                }

                Section("水电底数") {
                    LabeledContent("水表底数", value: "\(property.waterMeterBase)")
                    LabeledContent("电表底数", value: "\(property.electricMeterBase)")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.themeBg)
            .navigationTitle(property.roomNumber)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        generateShareImage()
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundColor(.themeAccent)
                    }
                }
                ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() }.foregroundColor(.themeAccent) }
            }
            .sheet(isPresented: $showShareSheet) {
                if let image = shareImage {
                    ActivityView(activityItems: [image])
                }
            }
        }
    }
}

// MARK: - 月度收租行（可编辑金额+可取消打勾）
struct MonthRentRow: View {
    let property: Property
    let month: Int
    let label: String
    @State private var amountText: String
    @State private var isPaid: Bool

    init(property: Property, month: Int, label: String) {
        self.property = property
        self.month = month
        self.label = label
        let record = property.monthlyRentRecords.first { $0.month == month }
        let amt = record?.amount ?? property.rent
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
                .onChange(of: amountText) { _, newValue in
                    updateRecord()
                }
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
        if let index = property.monthlyRentRecords.firstIndex(where: { $0.month == month }) {
            property.monthlyRentRecords[index].amount = amount
            property.monthlyRentRecords[index].isPaid = isPaid
            property.monthlyRentRecords[index].paidDate = isPaid ? Date() : nil
        } else {
            let record = RentMonthRecord(month: month, amount: amount, isPaid: isPaid)
            record.paidDate = isPaid ? Date() : nil
            property.monthlyRentRecords.append(record)
        }
    }
}

// MARK: - 季度水电行（可输入金额+可取消打勾）
struct QuarterUtilityRow: View {
    let property: Property
    let quarter: Int
    let label: String
    @State private var electricText: String
    @State private var waterText: String
    @State private var isSettled: Bool

    init(property: Property, quarter: Int, label: String) {
        self.property = property
        self.quarter = quarter
        self.label = label
        let record = property.quarterlyUtilityRecords.first { $0.quarter == quarter }
        _electricText = State(initialValue: (record?.electricAmount ?? 0) > 0 ? String(Int(record?.electricAmount ?? 0)) : "")
        _waterText = State(initialValue: (record?.waterAmount ?? 0) > 0 ? String(Int(record?.waterAmount ?? 0)) : "")
        _isSettled = State(initialValue: record?.isSettled ?? false)
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(label).foregroundColor(.themeText).font(.system(size: 14, weight: .medium))
                Spacer()
                Button {
                    isSettled.toggle()
                    updateRecord()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: isSettled ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(isSettled ? .themeAccent : .themeText3)
                        Text(isSettled ? "已结算" : "未结算")
                            .font(.system(size: 12))
                            .foregroundColor(isSettled ? .themeAccentDark : .themeText3)
                    }
                }
                .buttonStyle(.plain)
            }
            HStack {
                Text("电费").font(.system(size: 12)).foregroundColor(.themeText2)
                TextField("输入电费", text: $electricText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .foregroundColor(.themeText)
                    .onChange(of: electricText) { _, _ in updateRecord() }
                Text("元").font(.system(size: 12)).foregroundColor(.themeText3)
            }
            HStack {
                Text("水费").font(.system(size: 12)).foregroundColor(.themeText2)
                TextField("输入水费", text: $waterText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .foregroundColor(.themeText)
                    .onChange(of: waterText) { _, _ in updateRecord() }
                Text("元").font(.system(size: 12)).foregroundColor(.themeText3)
            }
        }
        .padding(.vertical, 4)
    }

    private func updateRecord() {
        let electric = Double(electricText) ?? 0
        let water = Double(waterText) ?? 0
        if let index = property.quarterlyUtilityRecords.firstIndex(where: { $0.quarter == quarter }) {
            property.quarterlyUtilityRecords[index].electricAmount = electric
            property.quarterlyUtilityRecords[index].waterAmount = water
            property.quarterlyUtilityRecords[index].isSettled = isSettled
        } else {
            property.quarterlyUtilityRecords.append(
                UtilityQuarterRecord(quarter: quarter, electricAmount: electric, waterAmount: water, isSettled: isSettled)
            )
        }
    }
}

// MARK: - 新增房源
struct AddPropertyView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    private let editingProperty: Property?

    @State private var roomNumber: String
    @State private var landlord: String
    @State private var unitType: String
    @State private var rentText: String
    @State private var depositText: String
    @State private var prepaymentText: String
    @State private var leaseStartDate: Date
    @State private var leaseEndDate: Date
    @State private var leaseDuration: String
    @State private var rentDueDay: Int
    @State private var waterMeterText: String
    @State private var electricMeterText: String
    @State private var propertyType: String
    @State private var notes: String

    private let unitTypes = ["单间上层","单间下层","独立厨房上层","独立厨房下层","复式","中空复式","平层","双钥匙一套","三房"]
    private let types = ["管理","包租","托管"]

    init(property: Property? = nil) {
        editingProperty = property
        let df = DateFormatter()
        df.dateFormat = "yyyy.M.d"
        _roomNumber = State(initialValue: property?.roomNumber ?? "")
        _landlord = State(initialValue: property?.landlord ?? "")
        _unitType = State(initialValue: property?.unitType ?? "")
        _rentText = State(initialValue: property.map { $0.rent > 0 ? String(Int($0.rent)) : "" } ?? "")
        _depositText = State(initialValue: property.map { $0.deposit > 0 ? String(Int($0.deposit)) : "" } ?? "")
        _prepaymentText = State(initialValue: property.map { $0.prepayment > 0 ? String(Int($0.prepayment)) : "" } ?? "")
        _leaseStartDate = State(initialValue: property.flatMap { df.date(from: $0.leaseStart) } ?? Date())
        _leaseEndDate = State(initialValue: property.flatMap { df.date(from: $0.leaseEnd) } ?? Date())
        _leaseDuration = State(initialValue: property?.leaseDuration ?? "")
        _rentDueDay = State(initialValue: property?.rentDueDay ?? 1)
        _waterMeterText = State(initialValue: property.map { $0.waterMeterBase > 0 ? String($0.waterMeterBase) : "" } ?? "")
        _electricMeterText = State(initialValue: property.map { $0.electricMeterBase > 0 ? String($0.electricMeterBase) : "" } ?? "")
        _propertyType = State(initialValue: property?.propertyType ?? "管理")
        _notes = State(initialValue: property?.notes ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("基本信息") {
                    TextField("房号", text: $roomNumber)
                    TextField("房东/管理", text: $landlord)
                    Picker("户型", selection: $unitType) { Text("请选择").tag(""); ForEach(unitTypes, id: \.self) { Text($0).tag($0) } }
                    Picker("房源类型", selection: $propertyType) { ForEach(types, id: \.self) { Text($0).tag($0) } }
                }
                Section("租赁信息") {
                    WheelDateField(label: "起租日", date: $leaseStartDate)
                    WheelDateField(label: "到期日", date: $leaseEndDate)
                    TextField("租期", text: $leaseDuration)
                    Picker("交租日", selection: $rentDueDay) {
                        ForEach(1...31, id: \.self) { day in Text("每月\(day)号").tag(day) }
                    }
                }
                Section("金额") {
                    AmountField(label: "月租金", text: $rentText)
                    AmountField(label: "押金", text: $depositText)
                    AmountField(label: "预存", text: $prepaymentText)
                }
                Section("水电底数（整数）") {
                    TextField("水表底数", text: $waterMeterText)
                        .keyboardType(.numberPad)
                    TextField("电表底数", text: $electricMeterText)
                        .keyboardType(.numberPad)
                }
                Section("备注") { TextField("备注", text: $notes, axis: .vertical) }
            }
            .scrollContentBackground(.hidden)
            .background(Color.themeBg)
            .navigationTitle(editingProperty == nil ? "新增收租" : "编辑收租")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        let df = DateFormatter()
                        df.dateFormat = "yyyy.M.d"
                        if let prop = editingProperty {
                            prop.roomNumber = roomNumber
                            prop.landlord = landlord
                            prop.unitType = unitType
                            prop.rent = Double(rentText) ?? 0
                            prop.deposit = Double(depositText) ?? 0
                            prop.prepayment = Double(prepaymentText) ?? 0
                            prop.leaseStart = df.string(from: leaseStartDate)
                            prop.leaseEnd = df.string(from: leaseEndDate)
                            prop.leaseDuration = leaseDuration
                            prop.rentDueDay = rentDueDay
                            prop.waterMeterBase = Int(waterMeterText) ?? 0
                            prop.electricMeterBase = Int(electricMeterText) ?? 0
                            prop.propertyType = propertyType
                            prop.notes = notes
                        } else {
                            let prop = Property(roomNumber: roomNumber, landlord: landlord, unitType: unitType,
                                rent: Double(rentText) ?? 0, deposit: Double(depositText) ?? 0,
                                prepayment: Double(prepaymentText) ?? 0, leaseStart: df.string(from: leaseStartDate),
                                leaseEnd: df.string(from: leaseEndDate), leaseDuration: leaseDuration, rentDueDay: rentDueDay,
                                waterMeterBase: Int(waterMeterText) ?? 0, electricMeterBase: Int(electricMeterText) ?? 0,
                                propertyType: propertyType, notes: notes)
                            modelContext.insert(prop)
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

// MARK: - 分享用渲染视图（剔除敏感信息）
struct ShareDetailRenderView: View {
    let property: Property

    private var paidMonthsCount: Int {
        property.monthlyRentRecords.filter { $0.isPaid }.count
    }

    private var totalUtility: Double {
        property.quarterlyUtilityRecords.reduce(0) { $0 + $1.electricAmount + $1.waterAmount }
    }

    private var shareTime: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd HH:mm"
        return fmt.string(from: Date())
    }

    var body: some View {
        VStack(spacing: 0) {
            // 顶部栏
            HStack {
                Text("系统记录，仅供参考")
                    .font(.system(size: 11))
                    .foregroundColor(.themeText3)
                Spacer()
                Text(shareTime)
                    .font(.system(size: 11))
                    .foregroundColor(.themeText3)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(hex: "F5F5F5"))

            // 房号标题
            Text(property.roomNumber)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.themeText)
                .padding(.top, 16)
                .padding(.bottom, 12)

            // 房源信息（剔除房东、房源类型、备注）
            VStack(spacing: 8) {
                shareRow(label: "户型", value: property.unitType)
                shareRow(label: "租金", value: "¥\(Int(property.rent))/月")
                shareRow(label: "押金", value: "¥\(Int(property.deposit))")
                if property.prepayment > 0 {
                    shareRow(label: "预存", value: "¥\(Int(property.prepayment))")
                }
                shareRow(label: "租期", value: property.leaseStart.isEmpty ? "未出租" : "\(property.leaseStart) 至 \(property.leaseEnd)")
                shareRow(label: "交租日", value: "每月\(property.rentDueDay)号")
            }
            .padding(.horizontal, 16)

            // 收租统计
            HStack(spacing: 20) {
                VStack(spacing: 4) {
                    Text("\(paidMonthsCount)")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.themeAccentDark)
                    Text("已收月数")
                        .font(.system(size: 11))
                        .foregroundColor(.themeText3)
                }
                VStack(spacing: 4) {
                    Text("¥\(Int(totalUtility))")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.themeAmber)
                    Text("累计水电")
                        .font(.system(size: 11))
                        .foregroundColor(.themeText3)
                }
            }
            .padding(.vertical, 16)

            // 月度收租记录
            VStack(alignment: .leading, spacing: 6) {
                Text("月度收租记录")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.themeText)
                    .padding(.bottom, 4)
                ForEach(0..<12, id: \.self) { idx in
                    let month = idx + 1
                    if let record = property.monthlyRentRecords.first(where: { $0.month == month }) {
                        HStack {
                            Text("\(month)月")
                                .font(.system(size: 11))
                                .foregroundColor(.themeText2)
                                .frame(width: 40, alignment: .leading)
                            Text("¥\(Int(record.amount))")
                                .font(.system(size: 11))
                                .foregroundColor(.themeText2)
                                .frame(width: 70, alignment: .leading)
                            Image(systemName: record.isPaid ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(record.isPaid ? .themeAccent : .themeText3)
                                .font(.system(size: 14))
                            Spacer()
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
        }
        .background(Color.white)
        .frame(width: 350)
    }

    private func shareRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.themeText3)
                .frame(width: 60, alignment: .leading)
            Text(value)
                .font(.system(size: 12))
                .foregroundColor(.themeText)
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - UIActivityViewController包装
struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
