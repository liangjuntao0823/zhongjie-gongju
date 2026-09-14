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
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddDeal = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.themeAccent)
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
                    .listRowBackground(Color.themeBg)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
            }
            .onDelete(perform: deleteDeal)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.themeBg)
        .overlay {
            if deals.isEmpty {
                ContentUnavailableView("暂无成交记录", systemImage: "doc.text", description: Text("点击右上角 + 添加成交记录"))
            }
        }
    }

    private var incomeList: some View {
        List {
            ForEach(incomes) { inc in
                MiscRow(title: inc.item, subtitle: inc.notes, amount: inc.amount, date: inc.date, isIncome: true)
                    .listRowBackground(Color.themeBg)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
            }
            .onDelete(perform: deleteIncome)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.themeBg)
    }

    private var expenseList: some View {
        List {
            ForEach(expenses) { exp in
                MiscRow(title: exp.item, subtitle: exp.notes, amount: exp.amount, date: exp.date, isIncome: false)
                    .listRowBackground(Color.themeBg)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
            }
            .onDelete(perform: deleteExpense)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.themeBg)
    }

    private func deleteDeal(at offsets: IndexSet) {
        for index in offsets { modelContext.delete(deals[index]) }
    }
    private func deleteIncome(at offsets: IndexSet) {
        for index in offsets { modelContext.delete(incomes[index]) }
    }
    private func deleteExpense(at offsets: IndexSet) {
        for index in offsets { modelContext.delete(expenses[index]) }
    }
}

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
                HStack {
                    Text(deal.roomNumber)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.themeText)
                    Text(deal.unitType)
                        .font(.system(size: 11))
                        .foregroundColor(.themeText3)
                }
                HStack(spacing: 8) {
                    Text("房东: \(deal.landlord)")
                        .font(.system(size: 11))
                        .foregroundColor(.themeText2)
                    Text("¥\(Int(deal.rent))/月")
                        .font(.system(size: 11))
                        .foregroundColor(.themeText2)
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
                    TextField("起止租期", text: $leasePeriod)
                    Picker("租期", selection: $leaseDuration) {
                        ForEach(durations, id: \.self) { Text($0).tag($0) }
                    }
                    Picker("交租日期", selection: $rentDueDay) {
                        ForEach(dueDays, id: \.self) { Text($0).tag($0) }
                    }
                }
                Section("金额") {
                    HStack { Text("月租金"); TextField("0", value: $rent, format: .number).keyboardType(.decimalPad).multilineTextAlignment(.trailing) }
                    HStack { Text("押金"); TextField("0", value: $deposit, format: .number).keyboardType(.decimalPad).multilineTextAlignment(.trailing) }
                    HStack { Text("预存"); TextField("0", value: $prepayment, format: .number).keyboardType(.decimalPad).multilineTextAlignment(.trailing) }
                }
                Section("中介费") {
                    HStack { Text("房东中介费"); TextField("0", value: $agentFeeLandlord, format: .number).keyboardType(.decimalPad).multilineTextAlignment(.trailing) }
                    HStack { Text("租客中介费"); TextField("0", value: $agentFeeTenant, format: .number).keyboardType(.decimalPad).multilineTextAlignment(.trailing) }
                    HStack { Text("合计"); Spacer(); Text("¥\(Int(agentFeeLandlord + agentFeeTenant))").foregroundColor(.themeAccentDark).fontWeight(.medium) }
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
                        let deal = DealRecord(date: date, roomNumber: roomNumber, landlord: landlord, unitType: unitType,
                            leasePeriod: leasePeriod, leaseDuration: leaseDuration, rent: rent, deposit: deposit,
                            prepayment: prepayment, rentDueDay: rentDueDay, agentFeeLandlord: agentFeeLandlord,
                            agentFeeTenant: agentFeeTenant, totalFee: agentFeeLandlord + agentFeeTenant,
                            manager: manager, source: source, notes: notes)
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

struct AddMiscView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let type: MiscType

    @State private var date = Date()
    @State private var item = ""
    @State private var amount: Double = 0
    @State private var notes = ""

    enum MiscType { case income, expense }

    var body: some View {
        NavigationStack {
            Form {
                Section("信息") {
                    DatePicker("日期", selection: $date, displayedComponents: .date)
                    TextField("项目", text: $item)
                    HStack { Text("金额"); TextField("0", value: $amount, format: .number).keyboardType(.decimalPad).multilineTextAlignment(.trailing) }
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
                        if type == .income {
                            modelContext.insert(MiscIncome(date: date, item: item, amount: amount, notes: notes))
                        } else {
                            modelContext.insert(MiscExpense(date: date, item: item, amount: amount, notes: notes))
                        }
                        dismiss()
                    }
                    .disabled(item.isEmpty || amount == 0)
                    .foregroundColor(.themeAccent)
                }
            }
        }
    }
}
