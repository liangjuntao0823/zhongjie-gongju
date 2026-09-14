import SwiftUI
import SwiftData

struct DealsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DealRecord.date, order: .reverse) private var deals: [DealRecord]
    @Query private var incomes: [MiscIncome]
    @Query private var expenses: [MiscExpense]
    @State private var showingAddDeal = false
    @State private var selectedTab = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("分类", selection: $selectedTab) {
                    Text("成交记录").tag(0)
                    Text("杂项收入").tag(1)
                    Text("杂项支出").tag(2)
                }
                .pickerStyle(.segmented)
                .padding()

                if selectedTab == 0 {
                    dealList
                } else if selectedTab == 1 {
                    incomeList
                } else {
                    expenseList
                }
            }
            .navigationTitle("成交管理")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddDeal = true
                    } label: {
                        Image(systemName: "plus")
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
        }
    }

    private var dealList: some View {
        List {
            ForEach(deals) { deal in
                DealRow(deal: deal)
            }
            .onDelete(perform: deleteDeal)
        }
        .listStyle(.plain)
        .overlay {
            if deals.isEmpty {
                ContentUnavailableView("暂无成交记录", systemImage: "doc.text", description: Text("点击右上角 + 添加成交记录"))
            }
        }
    }

    private var incomeList: some View {
        List {
            ForEach(incomes) { inc in
                HStack {
                    VStack(alignment: .leading) {
                        Text(inc.item)
                            .fontWeight(.medium)
                        Text(inc.notes)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text("+¥\(Int(inc.amount))")
                            .foregroundColor(.green)
                            .fontWeight(.medium)
                        Text(inc.date, style: .date)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .onDelete(perform: deleteIncome)
        }
        .listStyle(.plain)
    }

    private var expenseList: some View {
        List {
            ForEach(expenses) { exp in
                HStack {
                    VStack(alignment: .leading) {
                        Text(exp.item)
                            .fontWeight(.medium)
                        Text(exp.notes)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text("-¥\(Int(exp.amount))")
                            .foregroundColor(.red)
                            .fontWeight(.medium)
                        Text(exp.date, style: .date)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .onDelete(perform: deleteExpense)
        }
        .listStyle(.plain)
    }

    private func deleteDeal(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(deals[index])
        }
    }

    private func deleteIncome(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(incomes[index])
        }
    }

    private func deleteExpense(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(expenses[index])
        }
    }
}

struct DealRow: View {
    let deal: DealRecord

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.blue.opacity(0.1))
                .frame(width: 44, height: 44)
                .overlay {
                    Image(systemName: "doc.text.fill")
                        .foregroundColor(.blue)
                }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(deal.roomNumber)
                        .fontWeight(.semibold)
                    Text(deal.unitType)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                HStack(spacing: 8) {
                    Text("房东: \(deal.landlord)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("租金: ¥\(Int(deal.rent))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                if !deal.notes.isEmpty {
                    Text(deal.notes)
                        .font(.caption2)
                        .foregroundColor(.orange)
                        .lineLimit(1)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("+¥\(Int(deal.totalFee))")
                    .foregroundColor(.green)
                    .fontWeight(.semibold)
                Text(deal.date, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct AddDealView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var date = Date()
    @State private var roomNumber = ""
    @State private var landlord = ""
    @State private var unitType = ""
    @State private var leasePeriod = ""
    @State private var leaseDuration = "1年"
    @State private var rent: Double = 0
    @State private var deposit: Double = 0
    @State private var prepayment: Double = 0
    @State private var rentDueDay = "1号"
    @State private var agentFeeLandlord: Double = 0
    @State private var agentFeeTenant: Double = 0
    @State private var manager = ""
    @State private var source = ""
    @State private var notes = ""

    private let unitTypes = ["单间上层", "单间下层", "独立厨房上层", "独立厨房下层", "复式", "中空复式", "平层", "双钥匙一套"]
    private let durations = ["1月", "2月", "3月", "半年", "8月", "1年", "2年", "月租"]
    private let dueDays = ["1号", "10号", "15号", "20号", "21号", "23号", "25号", "26号"]

    var body: some View {
        NavigationStack {
            Form {
                Section("基本信息") {
                    DatePicker("成交日期", selection: $date, displayedComponents: .date)
                    TextField("房号", text: $roomNumber)
                    TextField("房东", text: $landlord)
                    Picker("户型", selection: $unitType) {
                        Text("未选择").tag("")
                        ForEach(unitTypes, id: \.self) { Text($0).tag($0) }
                    }
                    TextField("起止租期 (如 2026.1.1-2027.1.1)", text: $leasePeriod)
                    Picker("租期", selection: $leaseDuration) {
                        ForEach(durations, id: \.self) { Text($0).tag($0) }
                    }
                    Picker("交租日期", selection: $rentDueDay) {
                        ForEach(dueDays, id: \.self) { Text($0).tag($0) }
                    }
                }

                Section("金额") {
                    HStack {
                        Text("月租金")
                        TextField("0", value: $rent, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("押金")
                        TextField("0", value: $deposit, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("预存")
                        TextField("0", value: $prepayment, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                }

                Section("中介费") {
                    HStack {
                        Text("房东中介费")
                        TextField("0", value: $agentFeeLandlord, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("租客中介费")
                        TextField("0", value: $agentFeeTenant, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("合计")
                        Spacer()
                        Text("¥\(Int(agentFeeLandlord + agentFeeTenant))")
                            .foregroundColor(.green)
                            .fontWeight(.medium)
                    }
                }

                Section("其他") {
                    TextField("管理人", text: $manager)
                    TextField("客源", text: $source)
                    TextField("备注", text: $notes, axis: .vertical)
                }
            }
            .navigationTitle("新增成交")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        let deal = DealRecord(
                            date: date, roomNumber: roomNumber, landlord: landlord,
                            unitType: unitType, leasePeriod: leasePeriod, leaseDuration: leaseDuration,
                            rent: rent, deposit: deposit, prepayment: prepayment,
                            rentDueDay: rentDueDay, agentFeeLandlord: agentFeeLandlord,
                            agentFeeTenant: agentFeeTenant, totalFee: agentFeeLandlord + agentFeeTenant,
                            manager: manager, source: source, notes: notes
                        )
                        modelContext.insert(deal)
                        dismiss()
                    }
                    .disabled(roomNumber.isEmpty)
                }
            }
        }
    }
}

struct AddMiscView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let type: MiscType

    @State private var date = Date()
    @State private var item = ""
    @State private var amount: Double = 0
    @State private var notes = ""

    enum MiscType {
        case income, expense
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("信息") {
                    DatePicker("日期", selection: $date, displayedComponents: .date)
                    TextField("项目", text: $item)
                    HStack {
                        Text("金额")
                        TextField("0", value: $amount, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    TextField("备注", text: $notes, axis: .vertical)
                }
            }
            .navigationTitle(type == .income ? "新增收入" : "新增支出")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        if type == .income {
                            modelContext.insert(MiscIncome(date: date, item: item, amount: amount, notes: notes))
                        } else {
                            modelContext.insert(MiscExpense(date: date, item: item, amount: amount, notes: notes))
                        }
                        dismiss()
                    }
                    .disabled(item.isEmpty || amount == 0)
                }
            }
        }
    }
}
