import SwiftUI
import SwiftData

struct ProfitView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profits: [ProfitCalculation]
    @State private var showingAddProfit = false

    private var totalNetProfit: Double {
        profits.reduce(0) { $0 + $1.netProfit }
    }

    private var totalRentalIncome: Double {
        profits.reduce(0) { $0 + $1.rentalIncome }
    }

    private var totalCost: Double {
        profits.reduce(0) { $0 + $1.totalCost }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // 汇总卡片
                    HStack(spacing: 12) {
                        SummaryCard(title: "租金收入", value: "¥\(Int(totalRentalIncome))", color: .green)
                        SummaryCard(title: "总成本", value: "¥\(Int(totalCost))", color: .orange)
                        SummaryCard(title: "净利润", value: "¥\(Int(totalNetProfit))", color: totalNetProfit >= 0 ? .mint : .red)
                    }
                    .padding(.horizontal)

                    // 盈亏列表
                    LazyVStack(spacing: 12) {
                        ForEach(profits) { profit in
                            ProfitCard(profit: profit)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 16)
                }
                .padding(.top, 8)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("包租盈亏")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddProfit = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddProfit) {
                AddProfitView()
            }
            .overlay {
                if profits.isEmpty {
                    ContentUnavailableView("暂无盈亏记录", systemImage: "chart.pie", description: Text("点击右上角 + 添加包租盈亏计算"))
                }
            }
        }
    }
}

struct SummaryCard: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.headline)
                .foregroundColor(color)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}

struct ProfitCard: View {
    let profit: ProfitCalculation

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(profit.roomNumber)
                    .fontWeight(.semibold)
                Spacer()
                Text(profit.profitStatus)
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(profit.netProfit >= 0 ? Color.green.opacity(0.2) : Color.red.opacity(0.2))
                    .foregroundColor(profit.netProfit >= 0 ? .green : .red)
                    .cornerRadius(6)
            }

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("包租总额")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("¥\(Int(profit.totalPackageAmount))")
                        .font(.subheadline)
                }
                Spacer()
                VStack(alignment: .leading, spacing: 4) {
                    Text("日成本")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(String(format: "¥%.2f", profit.dailyCost))
                        .font(.subheadline)
                }
                Spacer()
                VStack(alignment: .leading, spacing: 4) {
                    Text("空置期")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("\(profit.vacancyDays)天")
                        .font(.subheadline)
                }
            }

            Divider()

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("租金收入")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("+¥\(Int(profit.rentalIncome))")
                        .font(.subheadline)
                        .foregroundColor(.green)
                }
                Spacer()
                VStack(alignment: .leading, spacing: 4) {
                    Text("总成本")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("-¥\(Int(profit.totalCost))")
                        .font(.subheadline)
                        .foregroundColor(.orange)
                }
                Spacer()
                VStack(alignment: .leading, spacing: 4) {
                    Text("净利润")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("¥\(Int(profit.netProfit))")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(profit.netProfit >= 0 ? .mint : .red)
                }
            }

            HStack {
                Text("剩余包租成本: ¥\(Int(profit.remainingPackageCost))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}

struct AddProfitView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var roomNumber = ""
    @State private var totalPackageAmount: Double = 0
    @State private var packageStart = Date()
    @State private var packageEnd = Date()
    @State private var vacancyDays: Int = 0
    @State private var tenantMonthlyRent: Double = 0
    @State private var rentStart = Date()
    @State private var rentEnd = Date()
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("基本信息") {
                    TextField("房号", text: $roomNumber)
                    HStack { Text("包租总金额"); TextField("0", value: $totalPackageAmount, format: .number).keyboardType(.decimalPad).multilineTextAlignment(.trailing) }
                }

                Section("包租周期") {
                    DatePicker("包租起", selection: $packageStart, displayedComponents: .date)
                    DatePicker("包租止", selection: $packageEnd, displayedComponents: .date)
                    HStack { Text("空置期(天)"); TextField("0", value: $vacancyDays, format: .number).keyboardType(.numberPad).multilineTextAlignment(.trailing) }
                }

                Section("出租信息") {
                    HStack { Text("租客月租金"); TextField("0", value: $tenantMonthlyRent, format: .number).keyboardType(.decimalPad).multilineTextAlignment(.trailing) }
                    DatePicker("出租起", selection: $rentStart, displayedComponents: .date)
                    DatePicker("出租止", selection: $rentEnd, displayedComponents: .date)
                }

                Section("备注") {
                    TextField("备注", text: $notes, axis: .vertical)
                }

                Section("预览") {
                    let temp = ProfitCalculation(
                        roomNumber: roomNumber, totalPackageAmount: totalPackageAmount,
                        packageStart: packageStart, packageEnd: packageEnd,
                        vacancyDays: vacancyDays, tenantMonthlyRent: tenantMonthlyRent,
                        rentStart: rentStart, rentEnd: rentEnd, notes: notes
                    )
                    LabeledContent("包租总天数", value: "\(temp.packageTotalDays)天")
                    LabeledContent("每日成本", value: String(format: "¥%.2f", temp.dailyCost))
                    LabeledContent("空置成本", value: "¥\(Int(temp.vacancyCost))")
                    LabeledContent("出租天数", value: "\(temp.rentedDays)天")
                    LabeledContent("租金收入", value: "¥\(Int(temp.rentalIncome))")
                    LabeledContent("净利润", value: "¥\(Int(temp.netProfit))")
                        .foregroundColor(temp.netProfit >= 0 ? .green : .red)
                }
            }
            .navigationTitle("新增盈亏计算")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        let profit = ProfitCalculation(
                            roomNumber: roomNumber, totalPackageAmount: totalPackageAmount,
                            packageStart: packageStart, packageEnd: packageEnd,
                            vacancyDays: vacancyDays, tenantMonthlyRent: tenantMonthlyRent,
                            rentStart: rentStart, rentEnd: rentEnd, notes: notes
                        )
                        modelContext.insert(profit)
                        dismiss()
                    }
                    .disabled(roomNumber.isEmpty || totalPackageAmount == 0)
                }
            }
        }
    }
}
