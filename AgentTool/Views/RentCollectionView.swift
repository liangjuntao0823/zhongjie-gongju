import SwiftUI
import SwiftData

struct RentCollectionView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Property.roomNumber) private var properties: [Property]
    @State private var selectedTab = 0 // 0=普通收租, 1=包租托管
    @State private var showingAddProperty = false
    @State private var selectedProperty: Property?

    private var filteredProperties: [Property] {
        if selectedTab == 0 {
            return properties.filter { $0.propertyType == "普通" }
        } else {
            return properties.filter { $0.isManaged }
        }
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

                List {
                    ForEach(filteredProperties) { prop in
                        PropertyRentRow(property: prop)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedProperty = prop
                            }
                    }
                    .onDelete(perform: deleteProperty)
                }
                .listStyle(.plain)
                .overlay {
                    if filteredProperties.isEmpty {
                        ContentUnavailableView("暂无房源", systemImage: "house", description: Text("点击右上角 + 添加房源"))
                    }
                }
            }
            .navigationTitle("收租管理")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddProperty = true
                    } label: {
                        Image(systemName: "plus")
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
        for index in offsets {
            modelContext.delete(filteredProperties[index])
        }
    }
}

struct PropertyRentRow: View {
    let property: Property
    @State private var currentMonthPaid = false

    private var currentMonth: Int {
        Calendar.current.component(.month, from: Date())
    }

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(property.isManaged ? Color.purple.opacity(0.1) : Color.blue.opacity(0.1))
                .frame(width: 44, height: 44)
                .overlay {
                    Image(systemName: property.isManaged ? "briefcase.fill" : "house.fill")
                        .foregroundColor(property.isManaged ? .purple : .blue)
                }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(property.roomNumber)
                        .fontWeight(.semibold)
                    Text(property.unitType)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if property.isManaged {
                        Text(property.propertyType)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.purple.opacity(0.2))
                            .cornerRadius(4)
                    }
                }
                HStack(spacing: 8) {
                    Text("房东: \(property.landlord)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("¥\(Int(property.rent))/月")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(property.rentDueDay)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Text(property.leaseStart.isEmpty ? "未出租" : property.leaseStart)
                    .font(.caption2)
                    .foregroundColor(property.leaseStart.isEmpty ? .orange : .secondary)
            }
            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                // 本月收租状态
                let paid = property.monthlyRentRecords.contains { $0.month == currentMonth && $0.isPaid }
                Image(systemName: paid ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(paid ? .green : .gray)
                Text(paid ? "已收" : "待收")
                    .font(.caption2)
                    .foregroundColor(paid ? .green : .orange)
            }
        }
        .padding(.vertical, 4)
    }
}

struct PropertyDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let property: Property
    @State private var currentMonth = Calendar.current.component(.month, from: Date())

    private let months = ["1月", "2月", "3月", "4月", "5月", "6月", "7月", "8月", "9月", "10月", "11月", "12月"]
    private let quarters = ["1季度", "2季度", "3季度", "4季度"]

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
                    if !property.notes.isEmpty {
                        LabeledContent("备注", value: property.notes)
                    }
                }

                Section("月度收租") {
                    ForEach(0..<12, id: \.self) { idx in
                        let month = idx + 1
                        let record = property.monthlyRentRecords.first { $0.month == month }
                        HStack {
                            Text(months[idx])
                            Spacer()
                            Text("¥\(Int(record?.amount ?? property.rent))")
                                .foregroundColor(.secondary)
                            Image(systemName: record?.isPaid ?? false ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(record?.isPaid ?? false ? .green : .gray)
                                .onTapGesture {
                                    toggleRent(month: month)
                                }
                        }
                    }
                }

                Section("水电结算（季度）") {
                    ForEach(0..<4, id: \.self) { idx in
                        let quarter = idx + 1
                        let record = property.quarterlyUtilityRecords.first { $0.quarter == quarter }
                        HStack {
                            Text(quarters[idx])
                            Spacer()
                            if let record = record {
                                Text("电¥\(Int(record.electricAmount)) 水¥\(Int(record.waterAmount))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Image(systemName: record?.isSettled ?? false ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(record?.isSettled ?? false ? .green : .gray)
                                .onTapGesture {
                                    toggleUtility(quarter: quarter)
                                }
                        }
                    }
                }

                Section("水电底数") {
                    LabeledContent("水表底数", value: "\(property.waterMeterBase)")
                    LabeledContent("电表底数", value: "\(property.electricMeterBase)")
                }
            }
            .navigationTitle(property.roomNumber)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }

    private func toggleRent(month: Int) {
        if let index = property.monthlyRentRecords.firstIndex(where: { $0.month == month }) {
            property.monthlyRentRecords[index].isPaid.toggle()
            if property.monthlyRentRecords[index].isPaid {
                property.monthlyRentRecords[index].paidDate = Date()
            }
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

    private let unitTypes = ["单间上层", "单间下层", "独立厨房上层", "独立厨房下层", "复式", "中空复式", "平层", "双钥匙一套"]
    private let durations = ["1月", "2月", "3月", "半年", "8月", "1年", "2年", "月租"]
    private let dueDays = ["1号", "10号", "15号", "20号", "21号", "23号", "25号", "26号"]
    private let types = ["普通", "包租", "托管"]

    var body: some View {
        NavigationStack {
            Form {
                Section("基本信息") {
                    TextField("房号 (如 1-2254下 或 2-1418下)", text: $roomNumber)
                    TextField("房东/管理", text: $landlord)
                    Picker("户型", selection: $unitType) {
                        Text("未选择").tag("")
                        ForEach(unitTypes, id: \.self) { Text($0).tag($0) }
                    }
                    Picker("房源类型", selection: $propertyType) {
                        ForEach(types, id: \.self) { Text($0).tag($0) }
                    }
                }

                Section("租赁信息") {
                    TextField("起租日 (如 2026.1.1)", text: $leaseStart)
                    TextField("到期日 (如 2027.1.1)", text: $leaseEnd)
                    Picker("租期", selection: $leaseDuration) {
                        ForEach(durations, id: \.self) { Text($0).tag($0) }
                    }
                    Picker("交租日", selection: $rentDueDay) {
                        ForEach(dueDays, id: \.self) { Text($0).tag($0) }
                    }
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

                Section("备注") {
                    TextField("备注", text: $notes, axis: .vertical)
                }
            }
            .navigationTitle("新增房源")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { propertyType = defaultType }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        let prop = Property(
                            roomNumber: roomNumber, landlord: landlord, unitType: unitType,
                            rent: rent, deposit: deposit, prepayment: prepayment,
                            leaseStart: leaseStart, leaseEnd: leaseEnd, leaseDuration: leaseDuration,
                            rentDueDay: rentDueDay, waterMeterBase: waterMeterBase,
                            electricMeterBase: electricMeterBase, propertyType: propertyType, notes: notes
                        )
                        modelContext.insert(prop)
                        dismiss()
                    }
                    .disabled(roomNumber.isEmpty)
                }
            }
        }
    }
}
