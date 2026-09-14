import SwiftUI
import SwiftData

struct PayoutView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PayoutRecord.roomNumber) private var payouts: [PayoutRecord]
    @State private var showingAddPayout = false
    @State private var selectedPayout: PayoutRecord?

    var body: some View {
        NavigationStack {
            List {
                ForEach(payouts) { payout in
                    PayoutRow(payout: payout)
                        .listRowBackground(Color.themeBg)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                        .contentShape(Rectangle())
                        .onTapGesture { selectedPayout = payout }
                }
                .onDelete(perform: deletePayout)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color.themeBg)
            .overlay {
                if payouts.isEmpty {
                    ContentUnavailableView("暂无打租记录", systemImage: "arrow.up.circle", description: Text("点击右上角 + 添加包租打租记录"))
                }
            }
            .navigationTitle("包租打租")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showingAddPayout = true } label: {
                        Image(systemName: "plus.circle.fill").foregroundColor(.themeAccent)
                    }
                }
            }
            .sheet(isPresented: $showingAddPayout) { AddPayoutView() }
            .sheet(item: $selectedPayout) { payout in PayoutDetailView(payout: payout) }
        }
    }

    private func deletePayout(at offsets: IndexSet) {
        for index in offsets { modelContext.delete(payouts[index]) }
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
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(payout.roomNumber)
                        .font(.system(size: 14, weight: .semibold)).foregroundColor(.themeText)
                    Text(payout.unitType)
                        .font(.system(size: 11)).foregroundColor(.themeText3)
                    Text(payout.paymentMethod)
                        .font(.system(size: 10)).padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color(hex: "F0E8FE")).foregroundColor(Color(hex: "6B3FA0")).cornerRadius(4)
                }
                HStack(spacing: 8) {
                    Text("管理: \(payout.manager)").font(.system(size: 11)).foregroundColor(.themeText2)
                    Text("年租金: ¥\(Int(payout.annualRent))").font(.system(size: 11)).foregroundColor(.themeText2)
                }
                if !payout.notes.isEmpty {
                    Text(payout.notes).font(.system(size: 10)).foregroundColor(.themeAmber).lineLimit(1)
                }
            }
            Spacer()
            let paidCount = payout.monthlyPayouts.filter { $0.isPaid }.count
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(paidCount)/12月").font(.system(size: 12)).foregroundColor(.themeText2)
                Text("已打¥\(Int(payout.monthlyPayouts.filter { $0.isPaid }.reduce(0) { $0 + $1.amount }))")
                    .font(.system(size: 11)).foregroundColor(Color(hex: "6B3FA0"))
            }
        }
        .padding(14)
        .background(Color.themePanel)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.themeBorder, lineWidth: 1))
    }
}

struct PayoutDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let payout: PayoutRecord
    private let months = ["1月","2月","3月","4月","5月","6月","7月","8月","9月","10月","11月","12月"]

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
                    LabeledContent("租期", value: payout.leasePeriod.isEmpty ? "未填写" : payout.leasePeriod)
                    if !payout.notes.isEmpty { LabeledContent("备注", value: payout.notes) }
                }
                Section("月度打租") {
                    ForEach(0..<12, id: \.self) { idx in
                        let month = idx + 1
                        let record = payout.monthlyPayouts.first { $0.month == month }
                        HStack {
                            Text(months[idx]).foregroundColor(.themeText)
                            Spacer()
                            Text("¥\(Int(record?.amount ?? (payout.annualRent / 12)))").foregroundColor(.themeText2)
                            Image(systemName: record?.isPaid ?? false ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(record?.isPaid ?? false ? .themeAccent : .themeText3)
                                .onTapGesture { togglePayout(month: month) }
                        }
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

    private func togglePayout(month: Int) {
        if let index = payout.monthlyPayouts.firstIndex(where: { $0.month == month }) {
            payout.monthlyPayouts[index].isPaid.toggle()
            if payout.monthlyPayouts[index].isPaid { payout.monthlyPayouts[index].paidDate = Date() }
        } else {
            let record = PayoutMonthRecord(month: month, amount: payout.annualRent / 12, isPaid: true)
            record.paidDate = Date()
            payout.monthlyPayouts.append(record)
        }
    }
}

struct AddPayoutView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var roomNumber = ""
    @State private var manager = ""
    @State private var unitType = ""
    @State private var leasePeriod = ""
    @State private var leaseDuration = "1年"
    @State private var annualRent: Double = 0
    @State private var deposit: Double = 0
    @State private var waterMeterBase: Double = 0
    @State private var paymentMethod = "月付"
    @State private var notes = ""

    private let unitTypes = ["单间上层","单间下层","独立厨房上层","独立厨房下层","复式","中空复式","平层","双钥匙一套"]
    private let methods = ["月付","季付"]

    var body: some View {
        NavigationStack {
            Form {
                Section("基本信息") {
                    TextField("房号", text: $roomNumber)
                    TextField("管理人", text: $manager)
                    Picker("户型", selection: $unitType) { Text("未选择").tag(""); ForEach(unitTypes, id: \.self) { Text($0).tag($0) } }
                    TextField("起止租期", text: $leasePeriod)
                }
                Section("金额") {
                    HStack { Text("年租金"); TextField("0", value: $annualRent, format: .number).keyboardType(.decimalPad).multilineTextAlignment(.trailing) }
                    HStack { Text("押金"); TextField("0", value: $deposit, format: .number).keyboardType(.decimalPad).multilineTextAlignment(.trailing) }
                    HStack { Text("水表底数"); TextField("0", value: $waterMeterBase, format: .number).keyboardType(.decimalPad).multilineTextAlignment(.trailing) }
                    Picker("付款方式", selection: $paymentMethod) { ForEach(methods, id: \.self) { Text($0).tag($0) } }
                }
                Section("备注") { TextField("备注", text: $notes, axis: .vertical) }
            }
            .scrollContentBackground(.hidden)
            .background(Color.themeBg)
            .navigationTitle("新增打租记录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        let payout = PayoutRecord(roomNumber: roomNumber, manager: manager, unitType: unitType,
                            leasePeriod: leasePeriod, leaseDuration: leaseDuration, annualRent: annualRent,
                            deposit: deposit, waterMeterBase: waterMeterBase, paymentMethod: paymentMethod, notes: notes)
                        modelContext.insert(payout)
                        dismiss()
                    }
                    .disabled(roomNumber.isEmpty)
                    .foregroundColor(.themeAccent)
                }
            }
        }
    }
}
