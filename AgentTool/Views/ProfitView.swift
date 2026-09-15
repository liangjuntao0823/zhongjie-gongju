import SwiftUI
import SwiftData

struct MonthlySummary: Identifiable {
    let id = UUID()
    let year: Int
    let month: Int
    let dealCount: Int
    let agentFee: Double
    let miscIncome: Double
    let miscExpense: Double
    var netIncome: Double { agentFee + miscIncome - miscExpense }
}

struct ProfitView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var deals: [DealRecord]
    @Query private var incomes: [MiscIncome]
    @Query private var expenses: [MiscExpense]

    @State private var selectedYear: Int? = Calendar.current.component(.year, from: Date())
    @State private var selectedMonth: Int? = nil

    private var calendar: Calendar { Calendar.current }

    private var monthlySummaries: [MonthlySummary] {
        let targetYear = selectedYear ?? calendar.component(.year, from: Date())
        let targetMonth = selectedMonth
        var summaries: [MonthlySummary] = []
        let monthsToShow: [Int]
        if let m = targetMonth {
            monthsToShow = [m]
        } else {
            monthsToShow = Array(1...12)
        }
        for month in monthsToShow {
            let monthDeals = deals.filter {
                let m = calendar.component(.month, from: $0.date)
                let y = calendar.component(.year, from: $0.date)
                return m == month && y == targetYear
            }
            let monthIncomes = incomes.filter {
                let m = calendar.component(.month, from: $0.date)
                let y = calendar.component(.year, from: $0.date)
                return m == month && y == targetYear
            }
            let monthExpenses = expenses.filter {
                let m = calendar.component(.month, from: $0.date)
                let y = calendar.component(.year, from: $0.date)
                return m == month && y == targetYear
            }
            let agentFee = monthDeals.reduce(0) { $0 + $1.totalFee }
            let miscIncome = monthIncomes.reduce(0) { $0 + $1.amount }
            let miscExpense = monthExpenses.reduce(0) { $0 + $1.amount }
            if monthDeals.count > 0 || monthIncomes.count > 0 || monthExpenses.count > 0 {
                summaries.append(MonthlySummary(
                    year: targetYear,
                    month: month,
                    dealCount: monthDeals.count,
                    agentFee: agentFee,
                    miscIncome: miscIncome,
                    miscExpense: miscExpense
                ))
            }
        }
        return summaries.sorted(by: { $0.month > $1.month })
    }

    private var yearTotal: MonthlySummary {
        let targetYear = selectedYear ?? calendar.component(.year, from: Date())
        let allDeals = deals.filter { calendar.component(.year, from: $0.date) == targetYear }
        let allIncomes = incomes.filter { calendar.component(.year, from: $0.date) == targetYear }
        let allExpenses = expenses.filter { calendar.component(.year, from: $0.date) == targetYear }
        return MonthlySummary(
            year: targetYear,
            month: 0,
            dealCount: allDeals.count,
            agentFee: allDeals.reduce(0) { $0 + $1.totalFee },
            miscIncome: allIncomes.reduce(0) { $0 + $1.amount },
            miscExpense: allExpenses.reduce(0) { $0 + $1.amount }
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    // 筛选栏
                    HStack {
                        WheelYearMonthPicker(year: $selectedYear, month: $selectedMonth)
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)

                    // 年度汇总卡片 - 新布局：左边2x2，右边净收入跨两行
                    HStack(spacing: 10) {
                        VStack(spacing: 10) {
                            HStack(spacing: 10) {
                                SummaryCard(title: "成交", value: "\(yearTotal.dealCount)单", color: Color(hex: "F59E0B"))
                                SummaryCard(title: "中介费", value: "¥\(Int(yearTotal.agentFee))", color: Color(hex: "F59E0B"))
                            }
                            HStack(spacing: 10) {
                                SummaryCard(title: "杂项收入", value: "¥\(Int(yearTotal.miscIncome))", color: .themeRed)
                                SummaryCard(title: "杂项支出", value: "¥\(Int(yearTotal.miscExpense))", color: .themeAccentDark)
                            }
                        }
                        SummaryCard(title: "净总收入", value: "¥\(Int(yearTotal.netIncome))", color: .themeRed)
                            .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal)

                    // 月度汇总列表
                    LazyVStack(spacing: 10) {
                        ForEach(monthlySummaries) { summary in
                            MonthlySummaryRow(summary: summary, isCurrent: summary.month == (selectedMonth ?? calendar.component(.month, from: Date())))
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 16)
                }
            }
            .background(Color.themeBg)
            .navigationTitle("汇总")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct MonthlySummaryRow: View {
    let summary: MonthlySummary
    let isCurrent: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(summary.year)年\(summary.month)月")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.themeText)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(Color(hex: "E8F0FE"))
                    .cornerRadius(.infinity)
                if isCurrent {
                    Text("本月")
                        .font(.system(size: 10))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.themeAccent)
                        .cornerRadius(.infinity)
                }
                Spacer()
                Text("净收入 ¥\(Int(summary.netIncome))")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.themeRed)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color(hex: "FDECEC"))
                    .cornerRadius(.infinity)
            }

            HStack(spacing: 0) {
                SummaryItem(label: "成交", value: "\(summary.dealCount)单")
                Spacer()
                SummaryItem(label: "中介费", value: "¥\(Int(summary.agentFee))")
                Spacer()
                SummaryItem(label: "杂收入", value: "¥\(Int(summary.miscIncome))")
                Spacer()
                SummaryItem(label: "支出", value: "¥\(Int(summary.miscExpense))")
            }
        }
        .padding(14)
        .background(Color.themePanel)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(isCurrent ? Color.themeAccent.opacity(0.5) : Color.themeBorder, lineWidth: isCurrent ? 1.5 : 1))
    }
}

struct SummaryItem: View {
    let label: String
    let value: String

    private var itemColor: Color {
        switch label {
        case "成交", "中介费": return Color(hex: "F59E0B")
        case "杂收入": return .themeRed
        case "支出": return .themeAccentDark
        default: return .themeText
        }
    }

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(itemColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(itemColor.opacity(0.1))
                .cornerRadius(.infinity)
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.themeText3)
        }
    }
}

struct SummaryCard: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.themeText2)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color(hex: "F0F0F0"))
                .cornerRadius(.infinity)
            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(color)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(color.opacity(0.1))
                .cornerRadius(.infinity)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color.themePanel)
        .cornerRadius(12)
    }
}
