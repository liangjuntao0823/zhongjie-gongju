import Foundation
import SwiftData

// 数据备份/导入导出管理
class DataBackupManager {
    static let shared = DataBackupManager()
    private let formatter = ISO8601DateFormatter()

    // 导出所有数据为JSON
    func exportAllData(modelContext: ModelContext) -> Data? {
        let deals = (try? modelContext.fetch(FetchDescriptor<DealRecord>())) ?? []
        let incomes = (try? modelContext.fetch(FetchDescriptor<MiscIncome>())) ?? []
        let expenses = (try? modelContext.fetch(FetchDescriptor<MiscExpense>())) ?? []
        let properties = (try? modelContext.fetch(FetchDescriptor<Property>())) ?? []
        let payouts = (try? modelContext.fetch(FetchDescriptor<PayoutRecord>())) ?? []

        var dict: [String: Any] = [:]

        // 成交
        dict["deals"] = deals.map { deal in
            [
                "date": formatter.string(from: deal.date),
                "roomNumber": deal.roomNumber,
                "landlord": deal.landlord,
                "unitType": deal.unitType,
                "leaseStart": formatter.string(from: deal.leaseStart),
                "leaseEnd": formatter.string(from: deal.leaseEnd),
                "leaseDuration": deal.leaseDuration,
                "rent": deal.rent,
                "deposit": deal.deposit,
                "prepayment": deal.prepayment,
                "rentDueDay": deal.rentDueDay as Any,
                "agentFeeLandlord": deal.agentFeeLandlord,
                "agentFeeTenant": deal.agentFeeTenant,
                "totalFee": deal.totalFee,
                "manager": deal.manager,
                "source": deal.source,
                "notes": deal.notes
            ]
        }

        // 杂项收入
        dict["incomes"] = incomes.map { inc in
            ["date": formatter.string(from: inc.date), "item": inc.item, "amount": inc.amount, "notes": inc.notes]
        }

        // 杂项支出
        dict["expenses"] = expenses.map { exp in
            ["date": formatter.string(from: exp.date), "item": exp.item, "amount": exp.amount, "notes": exp.notes]
        }

        // 房源
        dict["properties"] = properties.map { prop in
            [
                "roomNumber": prop.roomNumber,
                "landlord": prop.landlord,
                "unitType": prop.unitType,
                "rent": prop.rent,
                "deposit": prop.deposit,
                "prepayment": prop.prepayment,
                "leaseStart": prop.leaseStart,
                "leaseEnd": prop.leaseEnd,
                "leaseDuration": prop.leaseDuration,
                "rentDueDay": prop.rentDueDay,
                "waterMeterBase": prop.waterMeterBase,
                "electricMeterBase": prop.electricMeterBase,
                "propertyType": prop.propertyType,
                "notes": prop.notes,
                "monthlyRentRecords": prop.monthlyRentRecords.map { ["month": $0.month, "amount": $0.amount, "isPaid": $0.isPaid] },
                "quarterlyUtilityRecords": prop.quarterlyUtilityRecords.map { ["quarter": $0.quarter, "electricAmount": $0.electricAmount, "waterAmount": $0.waterAmount, "isSettled": $0.isSettled] }
            ]
        }

        // 包租
        dict["payouts"] = payouts.map { p in
            [
                "roomNumber": p.roomNumber,
                "manager": p.manager,
                "unitType": p.unitType,
                "annualRent": p.annualRent,
                "deposit": p.deposit,
                "leaseStartDate": formatter.string(from: p.leaseStartDate),
                "leaseEndDate": formatter.string(from: p.leaseEndDate),
                "leaseDuration": p.leaseDuration,
                "rentFreeDays": p.rentFreeDays,
                "waterMeterBase": p.waterMeterBase,
                "paymentMethod": p.paymentMethod,
                "notes": p.notes,
                "monthlyPayouts": p.monthlyPayouts.map { ["month": $0.month, "amount": $0.amount, "isPaid": $0.isPaid] }
            ]
        }

        return try? JSONSerialization.data(withJSONObject: dict, options: .prettyPrinted)
    }

    // 从JSON导入数据（清空后导入）
    func importAllData(from data: Data, modelContext: ModelContext) -> Bool {
        guard let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return false }

        // 清空现有数据
        try? modelContext.delete(model: DealRecord.self)
        try? modelContext.delete(model: MiscIncome.self)
        try? modelContext.delete(model: MiscExpense.self)
        try? modelContext.delete(model: Property.self)
        try? modelContext.delete(model: PayoutRecord.self)

        // 导入成交
        if let deals = dict["deals"] as? [[String: Any]] {
            for d in deals {
                let deal = DealRecord(
                    date: formatter.date(from: d["date"] as? String ?? "") ?? Date(),
                    roomNumber: d["roomNumber"] as? String ?? "",
                    landlord: d["landlord"] as? String ?? "",
                    unitType: d["unitType"] as? String ?? "",
                    leaseStart: formatter.date(from: d["leaseStart"] as? String ?? "") ?? Date(),
                    leaseEnd: formatter.date(from: d["leaseEnd"] as? String ?? "") ?? Date(),
                    leaseDuration: d["leaseDuration"] as? String ?? "",
                    rent: d["rent"] as? Double ?? 0,
                    deposit: d["deposit"] as? Double ?? 0,
                    prepayment: d["prepayment"] as? Double ?? 0,
                    rentDueDay: d["rentDueDay"] as? Int,
                    agentFeeLandlord: d["agentFeeLandlord"] as? Double ?? 0,
                    agentFeeTenant: d["agentFeeTenant"] as? Double ?? 0,
                    totalFee: d["totalFee"] as? Double ?? 0,
                    manager: d["manager"] as? String ?? "",
                    source: d["source"] as? String ?? "",
                    notes: d["notes"] as? String ?? ""
                )
                modelContext.insert(deal)
            }
        }

        // 导入杂项收入
        if let incomes = dict["incomes"] as? [[String: Any]] {
            for inc in incomes {
                let income = MiscIncome(
                    date: formatter.date(from: inc["date"] as? String ?? "") ?? Date(),
                    item: inc["item"] as? String ?? "",
                    amount: inc["amount"] as? Double ?? 0,
                    notes: inc["notes"] as? String ?? ""
                )
                modelContext.insert(income)
            }
        }

        // 导入杂项支出
        if let expenses = dict["expenses"] as? [[String: Any]] {
            for exp in expenses {
                let expense = MiscExpense(
                    date: formatter.date(from: exp["date"] as? String ?? "") ?? Date(),
                    item: exp["item"] as? String ?? "",
                    amount: exp["amount"] as? Double ?? 0,
                    notes: exp["notes"] as? String ?? ""
                )
                modelContext.insert(expense)
            }
        }

        // 导入房源
        if let properties = dict["properties"] as? [[String: Any]] {
            for p in properties {
                let prop = Property(
                    roomNumber: p["roomNumber"] as? String ?? "",
                    landlord: p["landlord"] as? String ?? "",
                    unitType: p["unitType"] as? String ?? "",
                    rent: p["rent"] as? Double ?? 0,
                    deposit: p["deposit"] as? Double ?? 0,
                    prepayment: p["prepayment"] as? Double ?? 0,
                    leaseStart: p["leaseStart"] as? String ?? "",
                    leaseEnd: p["leaseEnd"] as? String ?? "",
                    leaseDuration: p["leaseDuration"] as? String ?? "",
                    rentDueDay: p["rentDueDay"] as? Int ?? 1,
                    waterMeterBase: p["waterMeterBase"] as? Int ?? 0,
                    electricMeterBase: p["electricMeterBase"] as? Int ?? 0,
                    propertyType: p["propertyType"] as? String ?? "管理",
                    notes: p["notes"] as? String ?? ""
                )
                if let monthly = p["monthlyRentRecords"] as? [[String: Any]] {
                    for m in monthly {
                        let rec = RentMonthRecord(month: m["month"] as? Int ?? 1, amount: m["amount"] as? Double ?? 0, isPaid: m["isPaid"] as? Bool ?? false)
                        prop.monthlyRentRecords.append(rec)
                    }
                }
                if let quarterly = p["quarterlyUtilityRecords"] as? [[String: Any]] {
                    for q in quarterly {
                        let rec = UtilityQuarterRecord(quarter: q["quarter"] as? Int ?? 1, electricAmount: q["electricAmount"] as? Double ?? 0, waterAmount: q["waterAmount"] as? Double ?? 0, isSettled: q["isSettled"] as? Bool ?? false)
                        prop.quarterlyUtilityRecords.append(rec)
                    }
                }
                modelContext.insert(prop)
            }
        }

        // 导入包租
        if let payouts = dict["payouts"] as? [[String: Any]] {
            for p in payouts {
                let payout = PayoutRecord(
                    roomNumber: p["roomNumber"] as? String ?? "",
                    manager: p["manager"] as? String ?? "",
                    unitType: p["unitType"] as? String ?? "",
                    leaseStartDate: formatter.date(from: p["leaseStartDate"] as? String ?? "") ?? Date(),
                    leaseEndDate: formatter.date(from: p["leaseEndDate"] as? String ?? "") ?? Date(),
                    leaseDuration: p["leaseDuration"] as? String ?? "",
                    rentFreeDays: p["rentFreeDays"] as? Int ?? 0,
                    annualRent: p["annualRent"] as? Double ?? 0,
                    deposit: p["deposit"] as? Double ?? 0,
                    waterMeterBase: p["waterMeterBase"] as? Int ?? 0,
                    paymentMethod: p["paymentMethod"] as? String ?? "月付",
                    notes: p["notes"] as? String ?? ""
                )
                if let monthly = p["monthlyPayouts"] as? [[String: Any]] {
                    for m in monthly {
                        let rec = PayoutMonthRecord(month: m["month"] as? Int ?? 1, amount: m["amount"] as? Double ?? 0, isPaid: m["isPaid"] as? Bool ?? false)
                        payout.monthlyPayouts.append(rec)
                    }
                }
                modelContext.insert(payout)
            }
        }

        try? modelContext.save()
        return true
    }

    // 从bundle中的initialData.json导入初始数据
    func importInitialData(modelContext: ModelContext) -> Bool {
        guard let url = Bundle.main.url(forResource: "initialData", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            print("initialData.json not found in bundle")
            return false
        }
        return importAllData(from: data, modelContext: modelContext)
    }
}

// 自动备份设置
struct AutoBackupSettings: Codable {
    var enabled: Bool = false
    var frequency: String = "day" // day, week, month
    var hour: Int = 23
    var minute: Int = 0
    var lastBackupDate: Date?
}
