import Foundation
import SwiftData

@MainActor
final class DataManager: ObservableObject {
    static let shared = DataManager()

    func monthlyStats(modelContext: ModelContext, month: Int, year: Int) -> (income: Double, expense: Double, net: Double) {
        let calendar = Calendar.current
        var totalIncome: Double = 0
        var totalExpense: Double = 0

        // 成交中介费收入
        let dealDescriptor = FetchDescriptor<DealRecord>()
        if let deals = try? modelContext.fetch(dealDescriptor) {
            for deal in deals {
                let comps = calendar.dateComponents([.month, .year], from: deal.date)
                if comps.month == month && comps.year == year {
                    totalIncome += deal.totalFee
                }
            }
        }

        // 杂项收入
        let incomeDescriptor = FetchDescriptor<MiscIncome>()
        if let incomes = try? modelContext.fetch(incomeDescriptor) {
            for inc in incomes {
                let comps = calendar.dateComponents([.month, .year], from: inc.date)
                if comps.month == month && comps.year == year {
                    totalIncome += inc.amount
                }
            }
        }

        // 杂项支出
        let expenseDescriptor = FetchDescriptor<MiscExpense>()
        if let expenses = try? modelContext.fetch(expenseDescriptor) {
            for exp in expenses {
                let comps = calendar.dateComponents([.month, .year], from: exp.date)
                if comps.month == month && comps.year == year {
                    totalExpense += exp.amount
                }
            }
        }

        return (totalIncome, totalExpense, totalIncome - totalExpense)
    }

    func dashboardStats(modelContext: ModelContext) -> DashboardStats {
        let calendar = Calendar.current
        let now = Date()
        let currentMonth = calendar.component(.month, from: now)
        let currentYear = calendar.component(.year, from: now)

        let propertyDescriptor = FetchDescriptor<Property>()
        let properties = (try? modelContext.fetch(propertyDescriptor)) ?? []

        let dealDescriptor = FetchDescriptor<DealRecord>()
        let deals = (try? modelContext.fetch(dealDescriptor)) ?? []

        let payoutDescriptor = FetchDescriptor<PayoutRecord>()
        let payouts = (try? modelContext.fetch(payoutDescriptor)) ?? []

        let profitDescriptor = FetchDescriptor<ProfitCalculation>()
        let profits = (try? modelContext.fetch(profitDescriptor)) ?? []

        // 在租房源数
        let activeProperties = properties.filter { !$0.leaseStart.isEmpty }

        // 本月应收租金
        var monthlyRentReceivable: Double = 0
        var monthlyRentCollected: Double = 0
        for prop in properties {
            for record in prop.monthlyRentRecords {
                if record.month == currentMonth {
                    monthlyRentReceivable += record.amount > 0 ? record.amount : prop.rent
                    if record.isPaid {
                        monthlyRentCollected += record.amount > 0 ? record.amount : prop.rent
                    }
                }
            }
            // 如果没有当月记录，按租金计入应收
            if !prop.monthlyRentRecords.contains(where: { $0.month == currentMonth }) {
                monthlyRentReceivable += prop.rent
            }
        }

        // 本月成交中介费
        var monthlyDealFee: Double = 0
        for deal in deals {
            let comps = calendar.dateComponents([.month, .year], from: deal.date)
            if comps.month == currentMonth && comps.year == currentYear {
                monthlyDealFee += deal.totalFee
            }
        }

        // 包租盈亏
        let totalNetProfit = profits.reduce(0) { $0 + $1.netProfit }

        // 即将到期（30天内）
        var expiringSoon: [Property] = []
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy.M.d"
        for prop in properties {
            if let endDate = dateFormatter.date(from: prop.leaseEnd) {
                let days = calendar.dateComponents([.day], from: now, to: endDate).day ?? 0
                if days >= 0 && days <= 30 {
                    expiringSoon.append(prop)
                }
            }
        }

        return DashboardStats(
            totalProperties: properties.count,
            activeProperties: activeProperties.count,
            managedProperties: properties.filter { $0.isManaged }.count,
            monthlyRentReceivable: monthlyRentReceivable,
            monthlyRentCollected: monthlyRentCollected,
            monthlyDealFee: monthlyDealFee,
            totalDeals: deals.count,
            packageProfit: totalNetProfit,
            expiringSoon: expiringSoon,
            currentMonth: currentMonth,
            currentYear: currentYear
        )
    }
}

struct DashboardStats {
    var totalProperties: Int
    var activeProperties: Int
    var managedProperties: Int
    var monthlyRentReceivable: Double
    var monthlyRentCollected: Double
    var monthlyDealFee: Double
    var totalDeals: Int
    var packageProfit: Double
    var expiringSoon: [Property]
    var currentMonth: Int
    var currentYear: Int
}
