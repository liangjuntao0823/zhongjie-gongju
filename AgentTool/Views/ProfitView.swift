import SwiftUI
import SwiftData

struct ProfitView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profits: [ProfitCalculation]
    @State private var showingAddProfit = false

    private var totalNetProfit: Double { profits.reduce(0) { $0 + $1.netProfit } }
    private var totalRentalIncome: Double { profits.reduce(0) { $0 + $1.rentalIncome } }
    private var totalCost: Double { profits.reduce(0) { $0 + $1.totalCost } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    // 汇总卡片
                    HStack(spacing: 10) {
                        SummaryCard(title: "租金收入", value: "¥\(Int(totalRentalIncome))", color: .themeAccentDark)
                        SummaryCard(title: "总成本", value: "¥\(Int(totalCost))", color: .themeAmber)
                        SummaryCard(title: "净利润", value: "¥\(Int(totalNetProfit))", color: totalNetProfit >= 0 ? .themeAccentDark : .themeRed)
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)

                    // 盈亏列表
                    LazyVStack(spacing: 12) {
                        ForEach(profits) { profit in
                            ProfitCard(profit: profit)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 16)
                }
            }
            .background(Color.themeBg)
            .navigationTitle("包租盈亏")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showingAddProfit = true } label: {
                        Image(systemName: "plus.circle.fill").foregroundColor(.themeAccent)
                    }
                }
            }
            .sheet(isPresented: $showingAddProfit) { AddProfitView() }
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
            Text(title).font(.system(size: 11)).foregroundColor(.themeText2)
            Text(value).font(.system(size: 16, weight: .bold)).foregroundColor(color).minimumScaleFactor(0.5).lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color.themePanel)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.themeBorder, lineWidth: 1))
    }
}

struct ProfitCard: View {
    let profit: ProfitCalculation

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 8) {
                    GlowDot(color: profit.netProfit >= 0 ? .themeAccent : .themeRed)
                    Text(profit.roomNumber)
                        .font(.system(size: 15, weight: .semibold)).foregroundColor(.themeText)
                }
                Spacer()
                StatusTag(text: profit.profitStatus, style: profit.netProfit >= 0 ? .renting : .unpaid)
            }

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("包租总额").font(.system(size: 11)).foregroundColor(.themeText3)
                    Text("¥\(Int(profit.totalPackageAmount))").font(.system(size: 13)).foregroundColor(.themeText)
                }
                Spacer()
                VStack(alignment: .leading, spacing: 4) {
                    Text("日成本").font(.system(size: 11)).foregroundColor(.themeText3)
                    Text(String(format: "¥%.2f", profit.dailyCost)).font(.system(size: 13)).foregroundColor(.themeText)
                }
                Spacer()
                VStack(alignment: .leading, spacing: 4) {
                    Text("空置期").font(.system(size: 11)).foregroundColor(.themeText3)
                    Text("\(profit.vacancyDays)天").font(.system(size: 13)).foregroundColor(.themeText)
                }
            }

            Divider().background(Color.themeBorder)

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("租金收入").font(.system(size: 11)).foregroundColor(.themeText3)
                    Text("+¥\(Int(profit.rentalIncome))").font(.system(size: 13)).foregroundColor(.themeAccentDark)
                }
                Spacer()
                VStack(alignment: .leading, spacing: 4) {
                    Text("总成本").font(.system(size: 11)).foregroundColor(.themeText3)
                    Text("-¥\(Int(profit.totalCost))").font(.system(size: 13)).foregroundColor(.themeAmber)
                }
                Spacer()
                VStack(alignment: .leading, spacing: 4) {
                    Text("净利润").font(.system(size: 11)).foregroundColor(.themeText3)
                    Text("¥\(Int(profit.netProfit))").font(.system(size: 14, weight: .bold))
                        .foregroundColor(profit.netProfit >= 0 ? .themeAccentDark : .themeRed)
                }
            }

            HStack {
                Text("剩余包租成本: ¥\(Int(profit.remainingPackageCost))")
                    .font(.system(size: 11)).foregroundColor(.themeText3)
                Spacer()
            }
        }
        .padding(16)
        .background(Color.themePanel)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.themeBorder, lineWidth: 1))
    }
}

struct AddProfitView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var roomNumber = ""
    @State private var totalPackageAmountText = ""
    @State private var packageStart = Date()
    @State private var packageEnd = Date()
    @State private var vacancyDaysText = ""
    @State private var tenantMonthlyRentText = ""
    @State private var rentStart = Date()
    @State private var rentEnd = Date()
    @State private var notes = ""

    private var totalPackageAmount: Double { Double(totalPackageAmountText) ?? 0 }
    private var vacancyDays: Int { Int(vacancyDaysText) ?? 0 }
    private var tenantMonthlyRent: Double { Double(tenantMonthlyRentText) ?? 0 }

    var body: some View {
        NavigationStack {
            Form {
                Section("基本信息") {
                    TextField("房号", text: $roomNumber)
                    AmountField(label: "包租总金额", text: $totalPackageAmountText)
                }
                Section("包租周期") {
                    DatePicker("包租起", selection: $packageStart, displayedComponents: .date)
                    DatePicker("包租止", selection: $packageEnd, displayedComponents: .date)
                    HStack { Text("空置期(天)").foregroundColor(.themeText); Spacer(); TextField("请输入", text: $vacancyDaysText).keyboardType(.numberPad).multilineTextAlignment(.trailing).foregroundColor(.themeText).frame(width: 120) }
                }
                Section("出租信息") {
                    AmountField(label: "租客月租金", text: $tenantMonthlyRentText)
                    DatePicker("出租起", selection: $rentStart, displayedComponents: .date)
                    DatePicker("出租止", selection: $rentEnd, displayedComponents: .date)
                }
                Section("备注") { TextField("备注", text: $notes, axis: .vertical) }
                Section("预览") {
                    let temp = ProfitCalculation(roomNumber: roomNumber, totalPackageAmount: totalPackageAmount,
                        packageStart: packageStart, packageEnd: packageEnd, vacancyDays: vacancyDays,
                        tenantMonthlyRent: tenantMonthlyRent, rentStart: rentStart, rentEnd: rentEnd, notes: notes)
                    LabeledContent("包租总天数", value: "\(temp.packageTotalDays)天")
                    LabeledContent("每日成本", value: String(format: "¥%.2f", temp.dailyCost))
                    LabeledContent("空置成本", value: "¥\(Int(temp.vacancyCost))")
                    LabeledContent("出租天数", value: "\(temp.rentedDays)天")
                    LabeledContent("租金收入", value: "¥\(Int(temp.rentalIncome))")
                    LabeledContent("净利润", value: "¥\(Int(temp.netProfit))")
                        .foregroundColor(temp.netProfit >= 0 ? .themeAccentDark : .themeRed)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.themeBg)
            .navigationTitle("新增盈亏计算")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        let profit = ProfitCalculation(roomNumber: roomNumber, totalPackageAmount: totalPackageAmount,
                            packageStart: packageStart, packageEnd: packageEnd, vacancyDays: vacancyDays,
                            tenantMonthlyRent: tenantMonthlyRent, rentStart: rentStart, rentEnd: rentEnd, notes: notes)
                        modelContext.insert(profit)
                        dismiss()
                    }
                    .disabled(roomNumber.isEmpty || totalPackageAmountText.isEmpty)
                    .foregroundColor(.themeAccent)
                }
            }
        }
    }
}
