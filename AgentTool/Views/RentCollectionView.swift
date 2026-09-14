import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct RentCollectionView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Property.roomNumber) private var properties: [Property]
    @State private var showingAddProperty = false
    @State private var selectedProperty: Property?
    @State private var searchText = ""
    @State private var selectedDueDay: Int? = nil
    @State private var showUtility = false
    @State private var showFileImporter = false
    @State private var exportURL: ExportURL?

    // 只显示已登记的交租日期
    private var registeredDueDays: [Int] {
        Array(Set(properties.map { $0.rentDueDay })).sorted()
    }

    private var filteredProperties: [Property] {
        properties.filter { prop in
            let dayMatch = selectedDueDay == nil || prop.rentDueDay == selectedDueDay
            let searchMatch = searchText.isEmpty ||
                prop.roomNumber.localizedCaseInsensitiveContains(searchText) ||
                prop.landlord.localizedCaseInsensitiveContains(searchText) ||
                prop.unitType.localizedCaseInsensitiveContains(searchText) ||
                prop.propertyType.localizedCaseInsensitiveContains(searchText) ||
                prop.notes.localizedCaseInsensitiveContains(searchText)
            return dayMatch && searchMatch
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
                            .listRowBackground(Color.themeBg)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                            .contentShape(Rectangle())
                            .onTapGesture { selectedProperty = prop }
                    }
                    .onDelete(perform: deleteProperty)
                }
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
            .sheet(item: $selectedProperty) { prop in PropertyDetailView(property: prop) }
            .sheet(isPresented: $showUtility) { NavigationStack { UtilityView() } }
            .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.commaSeparatedText]) { result in
                if case .success(let url) = result {
                    importFromCSV(url: url)
                }
            }
            .sheet(item: $exportURL) { url in
                ShareSheet(activityItems: [url.url])
            }
        }
    }

    private func deleteProperty(at offsets: IndexSet) {
        for index in offsets { modelContext.delete(filteredProperties[index]) }
    }

    // MARK: - 导出PDF
    private func exportToPDF() {
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 595, height: 842))

        let pdfData = renderer.pdfData() { context in
            let cgContext = context.cgContext
            cgContext.setFillColor(UIColor.black.cgColor)

            let titleAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 18)]
            ("收租记录" as NSString).draw(at: CGPoint(x: 40, y: 40), withAttributes: titleAttrs)

            let dateAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 10), .foregroundColor: UIColor.gray]
            ("导出时间: \(DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .short))" as NSString).draw(at: CGPoint(x: 40, y: 65), withAttributes: dateAttrs)

            cgContext.setFillColor(UIColor(red: 0.08, green: 0.23, blue: 0.20, alpha: 1.0).cgColor)
            cgContext.fill(CGRect(x: 40, y: 90, width: 515, height: 25))

            let headerAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 10), .foregroundColor: UIColor.white]
            let colAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 9)]
            let headers = ["房号", "房东", "户型", "月租", "交租日", "类型", "本月状态"]
            let widths: [CGFloat] = [80, 70, 80, 70, 60, 70, 85]
            var x: CGFloat = 45
            for (i, h) in headers.enumerated() {
                (h as NSString).draw(at: CGPoint(x: x, y: 96), withAttributes: headerAttrs)
                x += widths[i]
            }

            let currentMonth = Calendar.current.component(.month, from: Date())
            var y: CGFloat = 120
            for prop in filteredProperties {
                if y > 800 { context.beginPage(); y = 40 }
                let paid = prop.monthlyRentRecords.contains { $0.month == currentMonth && $0.isPaid }
                let vals = [prop.roomNumber, prop.landlord, prop.unitType,
                            "¥\(Int(prop.rent))", "\(prop.rentDueDay)号",
                            prop.propertyType, paid ? "已收" : "未收"]
                x = 45
                for (i, v) in vals.enumerated() {
                    (v as NSString).draw(at: CGPoint(x: x, y: y), withAttributes: colAttrs)
                    x += widths[i]
                }
                y += 18
            }

            let totalAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 11)]
            ("共 \(filteredProperties.count) 套房源" as NSString).draw(at: CGPoint(x: 40, y: 810), withAttributes: totalAttrs)
        }

        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("收租记录-\(Int(Date().timeIntervalSince1970)).pdf")
        try? pdfData.write(to: fileURL)
        exportURL = ExportURL(url: fileURL)
    }

    private func exportTemplate() {
        let csv = "房号,房东,户型,月租金,交租日,房源类型,备注\n1-101,张三,单间上层,1000,1,普通收租,示例\n"
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("收租记录-模板.csv")
        try? csv.write(to: fileURL, atomically: true, encoding: .utf8)
        exportURL = ExportURL(url: fileURL)
    }

    private func importFromCSV(url: URL) {
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return }
        let lines = content.components(separatedBy: .newlines).dropFirst()
        for line in lines {
            let cols = line.components(separatedBy: ",")
            guard cols.count >= 5 else { continue }
            let prop = Property(
                roomNumber: cols[0], landlord: cols[1], unitType: cols[2],
                rent: Double(cols[3]) ?? 0, rentDueDay: Int(cols[4]) ?? 1,
                propertyType: cols.count > 5 ? cols[5] : "普通收租",
                notes: cols.count > 6 ? cols[6] : ""
            )
            modelContext.insert(prop)
        }
    }
}

struct PropertyRentRow: View {
    let property: Property
    private var currentMonth: Int { Calendar.current.component(.month, from: Date()) }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(property.isManaged ? Color(hex: "F0E8FE") : Color.themeAccentWeak)
                    .frame(width: 44, height: 44)
                Image(systemName: property.isManaged ? "briefcase.fill" : "house.fill")
                    .foregroundColor(property.isManaged ? Color(hex: "6B3FA0") : .themeAccentDark)
                    .font(.system(size: 18))
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(property.roomNumber)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.themeText)
                    Text(property.unitType)
                        .font(.system(size: 11))
                        .foregroundColor(.themeText3)
                    if property.isManaged {
                        Text(property.propertyType)
                            .font(.system(size: 10))
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color(hex: "F0E8FE"))
                            .foregroundColor(Color(hex: "6B3FA0"))
                            .cornerRadius(4)
                    }
                }
                HStack(spacing: 8) {
                    Text("房东: \(property.landlord)")
                        .font(.system(size: 11)).foregroundColor(.themeText2)
                    Text("¥\(Int(property.rent))/月")
                        .font(.system(size: 11)).foregroundColor(.themeText2)
                    Text("每月\(property.rentDueDay)号")
                        .font(.system(size: 11)).foregroundColor(.themeText2)
                }
                Text(property.leaseStart.isEmpty ? "未出租" : "\(property.leaseStart) 至 \(property.leaseEnd)")
                    .font(.system(size: 10))
                    .foregroundColor(property.leaseStart.isEmpty ? .themeAmber : .themeText3)
            }
            Spacer()

            let paid = property.monthlyRentRecords.contains { $0.month == currentMonth && $0.isPaid }
            VStack(alignment: .trailing, spacing: 4) {
                Image(systemName: paid ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(paid ? .themeAccent : .themeText3)
                    .font(.system(size: 20))
                Text(paid ? "已收" : "待收")
                    .font(.system(size: 11))
                    .foregroundColor(paid ? .themeAccentDark : .themeAmber)
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

    private let months = ["1月","2月","3月","4月","5月","6月","7月","8月","9月","10月","11月","12月"]
    private let quarters = ["1季度","2季度","3季度","4季度"]

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
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() }.foregroundColor(.themeAccent) } }
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
        _amountText = State(initialValue: amt > 0 ? String(amt) : "")
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
        _electricText = State(initialValue: (record?.electricAmount ?? 0) > 0 ? String(record?.electricAmount ?? 0) : "")
        _waterText = State(initialValue: (record?.waterAmount ?? 0) > 0 ? String(record?.waterAmount ?? 0) : "")
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

    @State private var roomNumber = ""
    @State private var landlord = ""
    @State private var unitType = ""
    @State private var rentText = ""
    @State private var depositText = ""
    @State private var prepaymentText = ""
    @State private var leaseStart = ""
    @State private var leaseEnd = ""
    @State private var leaseDuration = ""
    @State private var rentDueDay = 1
    @State private var waterMeterBase = 0
    @State private var electricMeterBase = 0
    @State private var propertyType = "普通"
    @State private var notes = ""

    private let unitTypes = ["单间上层","单间下层","独立厨房上层","独立厨房下层","复式","中空复式","平层","双钥匙一套","三房"]
    private let types = ["普通","包租","托管"]

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
                    TextField("起租日", text: $leaseStart)
                    TextField("到期日", text: $leaseEnd)
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
                    Stepper(value: $waterMeterBase, in: 0...999999) {
                        HStack { Text("水表底数"); Spacer(); Text("\(waterMeterBase)").foregroundColor(.themeText2) }
                    }
                    Stepper(value: $electricMeterBase, in: 0...999999) {
                        HStack { Text("电表底数"); Spacer(); Text("\(electricMeterBase)").foregroundColor(.themeText2) }
                    }
                }
                Section("备注") { TextField("备注", text: $notes, axis: .vertical) }
            }
            .scrollContentBackground(.hidden)
            .background(Color.themeBg)
            .navigationTitle("新增房源")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        let prop = Property(roomNumber: roomNumber, landlord: landlord, unitType: unitType,
                            rent: Double(rentText) ?? 0, deposit: Double(depositText) ?? 0,
                            prepayment: Double(prepaymentText) ?? 0, leaseStart: leaseStart,
                            leaseEnd: leaseEnd, leaseDuration: leaseDuration, rentDueDay: rentDueDay,
                            waterMeterBase: waterMeterBase, electricMeterBase: electricMeterBase,
                            propertyType: propertyType, notes: notes)
                        modelContext.insert(prop)
                        dismiss()
                    }
                    .disabled(roomNumber.isEmpty)
                    .foregroundColor(.themeAccent)
                }
            }
        }
    }
}
