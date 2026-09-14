import SwiftUI
import SwiftData

struct RentCollectionView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Property.roomNumber) private var properties: [Property]
    @State private var selectedTab = 0
    @State private var showingAddProperty = false
    @State private var selectedProperty: Property?

    private var filteredProperties: [Property] {
        selectedTab == 0 ? properties.filter { $0.propertyType == "普通" } : properties.filter { $0.isManaged }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("类型", selection: $selectedTab) {
                    Text("普通收租").tag(0)
                    Text("包租/托管").tag(1)
                }
                .pickerStyle(.segmented)
                .padding()
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
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showingAddProperty = true } label: {
                        Image(systemName: "plus.circle.fill").foregroundColor(.themeAccent)
                    }
                }
            }
            .sheet(isPresented: $showingAddProperty) {
                AddPropertyView(defaultType: selectedTab == 0 ? "普通" : "包租")
            }
            .sheet(item: $selectedProperty) { prop in
                PropertyDetailView(property: prop)
            }
        }
    }

    private func deleteProperty(at offsets: IndexSet) {
        for index in offsets { modelContext.delete(filteredProperties[index]) }
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
                    Text(property.rentDueDay)
                        .font(.system(size: 11)).foregroundColor(.themeText2)
                }
                Text(property.leaseStart.isEmpty ? "未出租" : property.leaseStart)
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
                    LabeledContent("租金", value: "¥\(Int(property.rent))/月")
                    LabeledContent("押金", value: "¥\(Int(property.deposit))")
                    LabeledContent("预存", value: "¥\(Int(property.prepayment))")
                    LabeledContent("租期", value: property.leaseStart.isEmpty ? "未出租" : "\(property.leaseStart) 至 \(property.leaseEnd)")
                    LabeledContent("交租日", value: property.rentDueDay)
                    if !property.notes.isEmpty { LabeledContent("备注", value: property.notes) }
                }
                Section("月度收租") {
                    ForEach(0..<12, id: \.self) { idx in
                        let month = idx + 1
                        let record = property.monthlyRentRecords.first { $0.month == month }
                        HStack {
                            Text(months[idx]).foregroundColor(.themeText)
                            Spacer()
                            Text("¥\(Int(record?.amount ?? property.rent))").foregroundColor(.themeText2)
                            Image(systemName: record?.isPaid ?? false ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(record?.isPaid ?? false ? .themeAccent : .themeText3)
                                .onTapGesture { toggleRent(month: month) }
                        }
                    }
                }
                Section("水电结算（季度）") {
                    ForEach(0..<4, id: \.self) { idx in
                        let quarter = idx + 1
                        let record = property.quarterlyUtilityRecords.first { $0.quarter == quarter }
                        HStack {
                            Text(quarters[idx]).foregroundColor(.themeText)
                            Spacer()
                            if let record = record {
                                Text("电¥\(Int(record.electricAmount)) 水¥\(Int(record.waterAmount))")
                                    .font(.system(size: 12)).foregroundColor(.themeText3)
                            }
                            Image(systemName: record?.isSettled ?? false ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(record?.isSettled ?? false ? .themeAccent : .themeText3)
                                .onTapGesture { toggleUtility(quarter: quarter) }
                        }
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

    private func toggleRent(month: Int) {
        if let index = property.monthlyRentRecords.firstIndex(where: { $0.month == month }) {
            property.monthlyRentRecords[index].isPaid.toggle()
            if property.monthlyRentRecords[index].isPaid { property.monthlyRentRecords[index].paidDate = Date() }
        } else {
            let record = RentMonthRecord(month: month, amount: property.rent, isPaid: true)
            record.paidDate = Date()
            property.monthlyRentRecords.append(record)
        }
    }

    private func toggleUtility(quarter: Int) {
        if let index = property.quarterlyUtilityRecords.firstIndex(where: { $0.quarter == quarter }) {
            property.quarterlyUtilityRecords[index].isSettled.toggle()
        } else {
            property.quarterlyUtilityRecords.append(UtilityQuarterRecord(quarter: quarter, isSettled: true))
        }
    }
}

struct AddPropertyView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let defaultType: String

    @State private var roomNumber = ""
    @State private var landlord = ""
    @State private var unitType = ""
    @State private var rent: Double = 0
    @State private var deposit: Double = 0
    @State private var prepayment: Double = 0
    @State private var leaseStart = ""
    @State private var leaseEnd = ""
    @State private var leaseDuration = "1年"
    @State private var rentDueDay = "1号"
    @State private var waterMeterBase: Double = 0
    @State private var electricMeterBase: Double = 0
    @State private var propertyType = "普通"
    @State private var notes = ""

    private let unitTypes = ["单间上层","单间下层","独立厨房上层","独立厨房下层","复式","中空复式","平层","双钥匙一套"]
    private let durations = ["1月","2月","3月","半年","8月","1年","2年","月租"]
    private let dueDays = ["1号","10号","15号","20号","21号","23号","25号","26号"]
    private let types = ["普通","包租","托管"]

    var body: some View {
        NavigationStack {
            Form {
                Section("基本信息") {
                    TextField("房号", text: $roomNumber)
                    TextField("房东/管理", text: $landlord)
                    Picker("户型", selection: $unitType) { Text("未选择").tag(""); ForEach(unitTypes, id: \.self) { Text($0).tag($0) } }
                    Picker("房源类型", selection: $propertyType) { ForEach(types, id: \.self) { Text($0).tag($0) } }
                }
                Section("租赁信息") {
                    TextField("起租日", text: $leaseStart)
                    TextField("到期日", text: $leaseEnd)
                    Picker("租期", selection: $leaseDuration) { ForEach(durations, id: \.self) { Text($0).tag($0) } }
                    Picker("交租日", selection: $rentDueDay) { ForEach(dueDays, id: \.self) { Text($0).tag($0) } }
                }
                Section("金额") {
                    HStack { Text("月租金"); TextField("0", value: $rent, format: .number).keyboardType(.decimalPad).multilineTextAlignment(.trailing) }
                    HStack { Text("押金"); TextField("0", value: $deposit, format: .number).keyboardType(.decimalPad).multilineTextAlignment(.trailing) }
                    HStack { Text("预存"); TextField("0", value: $prepayment, format: .number).keyboardType(.decimalPad).multilineTextAlignment(.trailing) }
                }
                Section("水电底数") {
                    HStack { Text("水表底数"); TextField("0", value: $waterMeterBase, format: .number).keyboardType(.decimalPad).multilineTextAlignment(.trailing) }
                    HStack { Text("电表底数"); TextField("0", value: $electricMeterBase, format: .number).keyboardType(.decimalPad).multilineTextAlignment(.trailing) }
                }
                Section("备注") { TextField("备注", text: $notes, axis: .vertical) }
            }
            .scrollContentBackground(.hidden)
            .background(Color.themeBg)
            .navigationTitle("新增房源")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { propertyType = defaultType }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        let prop = Property(roomNumber: roomNumber, landlord: landlord, unitType: unitType,
                            rent: rent, deposit: deposit, prepayment: prepayment, leaseStart: leaseStart,
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
