import Foundation
import SwiftData

// 数据备份/导入导出管理
class DataBackupManager {
    static let shared = DataBackupManager()
    private let isoFormatter = ISO8601DateFormatter()
    private let dateFormatters: [DateFormatter] = {
        let formats = ["yyyy-MM-dd", "yyyy.MM.dd", "yyyy/MM/dd", "yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd'T'HH:mm:ssXXXXX", "yyyy.M.d", "yyyy年M月d日"]
        return formats.map { fmt in
            let df = DateFormatter()
            df.dateFormat = fmt
            df.locale = Locale(identifier: "zh_CN")
            df.timeZone = TimeZone(identifier: "Asia/Shanghai")
            return df
        }
    }()

    private func parseDate(_ str: String?) -> Date {
        guard let s = str, !s.isEmpty else { return Date() }
        if let d = isoFormatter.date(from: s) { return d }
        for df in dateFormatters {
            if let d = df.date(from: s) { return d }
        }
        return Date()
    }

    private func dbl(_ v: Any?) -> Double {
        if let n = v as? Double { return n }
        if let n = v as? Int { return Double(n) }
        if let s = v as? String, let n = Double(s) { return n }
        return 0
    }

    private func intVal(_ v: Any?) -> Int {
        if let n = v as? Int { return n }
        if let n = v as? Double { return Int(n) }
        if let s = v as? String, let n = Int(s) { return n }
        return 0
    }

    private func strVal(_ v: Any?) -> String {
        if let s = v as? String { return s }
        if let n = v as? NSNumber { return n.stringValue }
        return ""
    }

    // 导出所有数据为JSON
    func exportAllData(modelContext: ModelContext) -> Data? {
        let deals = (try? modelContext.fetch(FetchDescriptor<DealRecord>())) ?? []
        let incomes = (try? modelContext.fetch(FetchDescriptor<MiscIncome>())) ?? []
        let expenses = (try? modelContext.fetch(FetchDescriptor<MiscExpense>())) ?? []
        let properties = (try? modelContext.fetch(FetchDescriptor<Property>())) ?? []
        let payouts = (try? modelContext.fetch(FetchDescriptor<PayoutRecord>())) ?? []

        var dict: [String: Any] = [:]

        dict["deals"] = deals.map { deal in
            [
                "date": isoFormatter.string(from: deal.date),
                "roomNumber": deal.roomNumber,
                "landlord": deal.landlord,
                "unitType": deal.unitType,
                "leaseStart": isoFormatter.string(from: deal.leaseStart),
                "leaseEnd": isoFormatter.string(from: deal.leaseEnd),
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

        dict["incomes"] = incomes.map { inc in
            ["date": isoFormatter.string(from: inc.date), "item": inc.item, "amount": inc.amount, "notes": inc.notes]
        }

        dict["expenses"] = expenses.map { exp in
            ["date": isoFormatter.string(from: exp.date), "item": exp.item, "amount": exp.amount, "notes": exp.notes]
        }

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

        dict["payouts"] = payouts.map { p in
            [
                "roomNumber": p.roomNumber,
                "manager": p.manager,
                "unitType": p.unitType,
                "annualRent": p.annualRent,
                "deposit": p.deposit,
                "leaseStartDate": isoFormatter.string(from: p.leaseStartDate),
                "leaseEndDate": isoFormatter.string(from: p.leaseEndDate),
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

    // 分批导入数据，避免主线程阻塞导致闪退
    func importAllData(from data: Data, modelContext: ModelContext, completion: @escaping (Bool) -> Void) {
        guard let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            completion(false)
            return
        }

        let dealsData = (dict["deals"] as? [[String: Any]]) ?? []
        let incomesData = (dict["incomes"] as? [[String: Any]]) ?? []
        let expensesData = (dict["expenses"] as? [[String: Any]]) ?? []
        let propertiesData = (dict["properties"] as? [[String: Any]]) ?? []
        let payoutsData = (dict["payouts"] as? [[String: Any]]) ?? []

        // 第一步：清空数据
        func clearAndImport() {
            if let deals = try? modelContext.fetch(FetchDescriptor<DealRecord>()) {
                for item in deals { modelContext.delete(item) }
            }
            if let incomes = try? modelContext.fetch(FetchDescriptor<MiscIncome>()) {
                for item in incomes { modelContext.delete(item) }
            }
            if let expenses = try? modelContext.fetch(FetchDescriptor<MiscExpense>()) {
                for item in expenses { modelContext.delete(item) }
            }
            if let properties = try? modelContext.fetch(FetchDescriptor<Property>()) {
                for item in properties { modelContext.delete(item) }
            }
            if let payouts = try? modelContext.fetch(FetchDescriptor<PayoutRecord>()) {
                for item in payouts { modelContext.delete(item) }
            }
            try? modelContext.save()

            // 分批导入
            var allItems: [() -> Void] = []

            for d in dealsData {
                allItems.append {
                    let deal = DealRecord(
                        date: self.parseDate(d["date"] as? String),
                        roomNumber: self.strVal(d["roomNumber"]),
                        landlord: self.strVal(d["landlord"]),
                        unitType: self.strVal(d["unitType"]),
                        leaseStart: self.parseDate(d["leaseStart"] as? String),
                        leaseEnd: self.parseDate(d["leaseEnd"] as? String),
                        leaseDuration: self.strVal(d["leaseDuration"]),
                        rent: self.dbl(d["rent"]),
                        deposit: self.dbl(d["deposit"]),
                        prepayment: self.dbl(d["prepayment"]),
                        rentDueDay: d["rentDueDay"] as? Int,
                        agentFeeLandlord: self.dbl(d["agentFeeLandlord"]),
                        agentFeeTenant: self.dbl(d["agentFeeTenant"]),
                        totalFee: self.dbl(d["totalFee"]),
                        manager: self.strVal(d["manager"]),
                        source: self.strVal(d["source"]),
                        notes: self.strVal(d["notes"])
                    )
                    modelContext.insert(deal)
                }
            }

            for inc in incomesData {
                allItems.append {
                    let income = MiscIncome(
                        date: self.parseDate(inc["date"] as? String),
                        item: self.strVal(inc["item"]),
                        amount: self.dbl(inc["amount"]),
                        notes: self.strVal(inc["notes"])
                    )
                    modelContext.insert(income)
                }
            }

            for exp in expensesData {
                allItems.append {
                    let expense = MiscExpense(
                        date: self.parseDate(exp["date"] as? String),
                        item: self.strVal(exp["item"]),
                        amount: self.dbl(exp["amount"]),
                        notes: self.strVal(exp["notes"])
                    )
                    modelContext.insert(expense)
                }
            }

            for p in propertiesData {
                allItems.append {
                    let prop = Property(
                        roomNumber: self.strVal(p["roomNumber"]),
                        landlord: self.strVal(p["landlord"]),
                        unitType: self.strVal(p["unitType"]),
                        rent: self.dbl(p["rent"]),
                        deposit: self.dbl(p["deposit"]),
                        prepayment: self.dbl(p["prepayment"]),
                        leaseStart: self.strVal(p["leaseStart"]),
                        leaseEnd: self.strVal(p["leaseEnd"]),
                        leaseDuration: self.strVal(p["leaseDuration"]),
                        rentDueDay: self.intVal(p["rentDueDay"]),
                        waterMeterBase: self.intVal(p["waterMeterBase"]),
                        electricMeterBase: self.intVal(p["electricMeterBase"]),
                        propertyType: self.strVal(p["propertyType"]),
                        notes: self.strVal(p["notes"])
                    )
                    modelContext.insert(prop)
                    if let monthly = p["monthlyRentRecords"] as? [[String: Any]] {
                        for m in monthly {
                            let rec = RentMonthRecord(month: self.intVal(m["month"]), amount: self.dbl(m["amount"]), isPaid: m["isPaid"] as? Bool ?? false)
                            modelContext.insert(rec)
                            prop.monthlyRentRecords.append(rec)
                        }
                    }
                    if let quarterly = p["quarterlyUtilityRecords"] as? [[String: Any]] {
                        for q in quarterly {
                            let rec = UtilityQuarterRecord(quarter: self.intVal(q["quarter"]), electricAmount: self.dbl(q["electricAmount"]), waterAmount: self.dbl(q["waterAmount"]), isSettled: q["isSettled"] as? Bool ?? false)
                            modelContext.insert(rec)
                            prop.quarterlyUtilityRecords.append(rec)
                        }
                    }
                }
            }

            for p in payoutsData {
                allItems.append {
                    let payout = PayoutRecord(
                        roomNumber: self.strVal(p["roomNumber"]),
                        manager: self.strVal(p["manager"]),
                        unitType: self.strVal(p["unitType"]),
                        leaseStartDate: self.parseDate(p["leaseStartDate"] as? String),
                        leaseEndDate: self.parseDate(p["leaseEndDate"] as? String),
                        leaseDuration: self.strVal(p["leaseDuration"]),
                        rentFreeDays: self.intVal(p["rentFreeDays"]),
                        annualRent: self.dbl(p["annualRent"]),
                        deposit: self.dbl(p["deposit"]),
                        waterMeterBase: self.intVal(p["waterMeterBase"]),
                        paymentMethod: self.strVal(p["paymentMethod"]),
                        notes: self.strVal(p["notes"])
                    )
                    modelContext.insert(payout)
                    if let monthly = p["monthlyPayouts"] as? [[String: Any]] {
                        for m in monthly {
                            let rec = PayoutMonthRecord(month: self.intVal(m["month"]), amount: self.dbl(m["amount"]), isPaid: m["isPaid"] as? Bool ?? false)
                            modelContext.insert(rec)
                            payout.monthlyPayouts.append(rec)
                        }
                    }
                }
            }

            // 分批执行，每批2条
            let batchSize = 2
            var index = 0
            func processBatch() {
                let end = min(index + batchSize, allItems.count)
                for i in index..<end {
                    allItems[i]()
                }
                try? modelContext.save()
                index = end
                if index < allItems.count {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
                        processBatch()
                    }
                } else {
                    completion(true)
                }
            }
            processBatch()
        }

        clearAndImport()
    }

    // 从bundle中的initialData.json导入初始数据
    func importInitialData(modelContext: ModelContext, completion: @escaping (Bool) -> Void) {
        guard let url = Bundle.main.url(forResource: "initialData", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            print("initialData.json not found in bundle")
            completion(false)
            return
        }
        importAllData(from: data, modelContext: modelContext, completion: completion)
    }

    // MARK: - 分板块导出
    enum BackupType: String {
        case deals = "成交备份"
        case properties = "收租备份"
        case payouts = "包租备份"
        case total = "总备份"
    }

    func exportDeals(modelContext: ModelContext) -> Data? {
        let deals = (try? modelContext.fetch(FetchDescriptor<DealRecord>())) ?? []
        let incomes = (try? modelContext.fetch(FetchDescriptor<MiscIncome>())) ?? []
        let expenses = (try? modelContext.fetch(FetchDescriptor<MiscExpense>())) ?? []
        var dict: [String: Any] = [:]
        dict["deals"] = deals.map { deal in
            ["date": isoFormatter.string(from: deal.date), "roomNumber": deal.roomNumber, "landlord": deal.landlord, "unitType": deal.unitType, "leaseStart": isoFormatter.string(from: deal.leaseStart), "leaseEnd": isoFormatter.string(from: deal.leaseEnd), "leaseDuration": deal.leaseDuration, "rent": deal.rent, "deposit": deal.deposit, "prepayment": deal.prepayment, "rentDueDay": deal.rentDueDay as Any, "agentFeeLandlord": deal.agentFeeLandlord, "agentFeeTenant": deal.agentFeeTenant, "totalFee": deal.totalFee, "manager": deal.manager, "source": deal.source, "notes": deal.notes]
        }
        dict["incomes"] = incomes.map { ["date": isoFormatter.string(from: $0.date), "item": $0.item, "amount": $0.amount, "notes": $0.notes] }
        dict["expenses"] = expenses.map { ["date": isoFormatter.string(from: $0.date), "item": $0.item, "amount": $0.amount, "notes": $0.notes] }
        dict["properties"] = []
        dict["payouts"] = []
        return try? JSONSerialization.data(withJSONObject: dict, options: .prettyPrinted)
    }

    func exportProperties(modelContext: ModelContext) -> Data? {
        let properties = (try? modelContext.fetch(FetchDescriptor<Property>())) ?? []
        var dict: [String: Any] = [:]
        dict["deals"] = []
        dict["incomes"] = []
        dict["expenses"] = []
        dict["properties"] = properties.map { prop in
            ["roomNumber": prop.roomNumber, "landlord": prop.landlord, "unitType": prop.unitType, "rent": prop.rent, "deposit": prop.deposit, "prepayment": prop.prepayment, "leaseStart": prop.leaseStart, "leaseEnd": prop.leaseEnd, "leaseDuration": prop.leaseDuration, "rentDueDay": prop.rentDueDay, "waterMeterBase": prop.waterMeterBase, "electricMeterBase": prop.electricMeterBase, "propertyType": prop.propertyType, "notes": prop.notes, "monthlyRentRecords": prop.monthlyRentRecords.map { ["month": $0.month, "amount": $0.amount, "isPaid": $0.isPaid] }, "quarterlyUtilityRecords": prop.quarterlyUtilityRecords.map { ["quarter": $0.quarter, "electricAmount": $0.electricAmount, "waterAmount": $0.waterAmount, "isSettled": $0.isSettled] }]
        }
        dict["payouts"] = []
        return try? JSONSerialization.data(withJSONObject: dict, options: .prettyPrinted)
    }

    func exportPayouts(modelContext: ModelContext) -> Data? {
        let payouts = (try? modelContext.fetch(FetchDescriptor<PayoutRecord>())) ?? []
        var dict: [String: Any] = [:]
        dict["deals"] = []
        dict["incomes"] = []
        dict["expenses"] = []
        dict["properties"] = []
        dict["payouts"] = payouts.map { p in
            ["roomNumber": p.roomNumber, "manager": p.manager, "unitType": p.unitType, "leaseStartDate": isoFormatter.string(from: p.leaseStartDate), "leaseEndDate": isoFormatter.string(from: p.leaseEndDate), "leaseDuration": p.leaseDuration, "rentFreeDays": p.rentFreeDays, "annualRent": p.annualRent, "deposit": p.deposit, "waterMeterBase": p.waterMeterBase, "paymentMethod": p.paymentMethod, "notes": p.notes, "monthlyPayouts": p.monthlyPayouts.map { ["month": $0.month, "amount": $0.amount, "isPaid": $0.isPaid] }]
        }
        return try? JSONSerialization.data(withJSONObject: dict, options: .prettyPrinted)
    }

    // MARK: - 分板块清空
    func clearDeals(modelContext: ModelContext) {
        if let items = try? modelContext.fetch(FetchDescriptor<DealRecord>()) {
            for item in items { modelContext.delete(item) }
        }
        if let items = try? modelContext.fetch(FetchDescriptor<MiscIncome>()) {
            for item in items { modelContext.delete(item) }
        }
        if let items = try? modelContext.fetch(FetchDescriptor<MiscExpense>()) {
            for item in items { modelContext.delete(item) }
        }
        try? modelContext.save()
    }

    func clearProperties(modelContext: ModelContext) {
        if let items = try? modelContext.fetch(FetchDescriptor<Property>()) {
            for item in items { modelContext.delete(item) }
        }
        if let items = try? modelContext.fetch(FetchDescriptor<RentMonthRecord>()) {
            for item in items { modelContext.delete(item) }
        }
        if let items = try? modelContext.fetch(FetchDescriptor<UtilityQuarterRecord>()) {
            for item in items { modelContext.delete(item) }
        }
        try? modelContext.save()
    }

    func clearPayouts(modelContext: ModelContext) {
        if let items = try? modelContext.fetch(FetchDescriptor<PayoutRecord>()) {
            for item in items { modelContext.delete(item) }
        }
        if let items = try? modelContext.fetch(FetchDescriptor<PayoutMonthRecord>()) {
            for item in items { modelContext.delete(item) }
        }
        try? modelContext.save()
    }

    func clearAll(modelContext: ModelContext) {
        clearDeals(modelContext: modelContext)
        clearProperties(modelContext: modelContext)
        clearPayouts(modelContext: modelContext)
    }

    // MARK: - 备份文件管理
    func backupFolderURL(for type: BackupType) -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent(type.rawValue, isDirectory: true)
    }

    func listBackups(in type: BackupType) -> [URL] {
        let folder = backupFolderURL(for: type)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
        return files.filter { $0.pathExtension == "json" }.sorted { $0.lastPathComponent > $1.lastPathComponent }
    }

    func saveBackup(_ data: Data, type: BackupType, name: String? = nil) -> URL? {
        let folder = backupFolderURL(for: type)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let fileName = name ?? "\(type.rawValue)-\(timestampString()).json"
        let url = folder.appendingPathComponent(fileName)
        do {
            try data.write(to: url)
            return url
        } catch {
            print("保存备份失败: \(error)")
            return nil
        }
    }

    func deleteBackup(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    private func timestampString() -> String {
        let df = DateFormatter()
        df.dateFormat = "yyyyMMdd-HHmm"
        return df.string(from: Date())
    }
}

// 自动备份设置
struct AutoBackupSettings: Codable {
    var enabled: Bool = false
    var frequency: String = "day"
    var hour: Int = 23
    var minute: Int = 0
    var lastBackupDate: Date?
}
