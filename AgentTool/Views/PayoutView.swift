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
                if payout.rentFreeDays > 0 {
                    Text("免租期: \(payout.rentFreeDays)天")
                        .font(.system(size: 10)).foregroundColor(.themeAmber)
                }
                if !payout.notes.isEmpty {
                    Text(payout.notes).font(.system(size: 10)).foregroundColor(.themeText3).lineLimit(1)
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

    @State private var roomNumber = ""
    @State private var manager = ""
    @State private var unitType = ""
    @State private var leaseStartDate = Date()
    @State private var leaseEndDate = Date()
    @State private var leaseDuration = ""
    @State private var rentFreeDays = 0
    @State private var annualRentText = ""
    @State private var depositText = ""
    @State private var waterMeterBase = 0
    @State private var paymentMethod = "月付"
    @State private var notes = ""

    private let unitTypes = ["单间上层","单间下层","独立厨房上层","独立厨房下层","复式","中空复式","平层","双钥匙一套","三房"]
    private let methods = ["月付","季付"]

    var body: some View {
        NavigationStack {
            Form {
                Section("基本信息") {
                    TextField("房号", text: $roomNumber)
                    TextField("管理人", text: $manager)
                    Picker("户型", selection: $unitType) { Text("请选择").tag(""); ForEach(unitTypes, id: \.self) { Text($0).tag($0) } }
                }
                Section("租赁信息") {
                    DatePicker("起租期", selection: $leaseStartDate, displayedComponents: .date)
                        .datePickerStyle(.compact)
                    DatePicker("到期日", selection: $leaseEndDate, displayedComponents: .date)
                        .datePickerStyle(.compact)
                    TextField("租期（自由输入）", text: $leaseDuration)
                    Stepper(value: $rentFreeDays, in: 0...365) {
                        HStack { Text("免租期"); Spacer(); Text("\(rentFreeDays)天").foregroundColor(.themeText2) }
                    }
                    Picker("付款方式", selection: $paymentMethod) { ForEach(methods, id: \.self) { Text($0).tag($0) } }
                }
                Section("金额") {
                    AmountField(label: "年租金", text: $annualRentText)
                    AmountField(label: "押金", text: $depositText)
                    Stepper(value: $waterMeterBase, in: 0...999999) {
                        HStack { Text("水表底数"); Spacer(); Text("\(waterMeterBase)").foregroundColor(.themeText2) }
                    }
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
                        let payout = PayoutRecord(
                            roomNumber: roomNumber, manager: manager, unitType: unitType,
                            leaseStartDate: leaseStartDate, leaseEndDate: leaseEndDate,
                            leaseDuration: leaseDuration, rentFreeDays: rentFreeDays,
                            annualRent: Double(annualRentText) ?? 0,
                            deposit: Double(depositText) ?? 0,
                            waterMeterBase: waterMeterBase, paymentMethod: paymentMethod, notes: notes)
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
