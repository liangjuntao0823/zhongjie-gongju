import Foundation
import SwiftData
import SwiftUI

@Model
final class Property {
    var id: UUID
    var roomNumber: String
    var landlord: String
    var unitType: String
    var rent: Double
    var deposit: Double
    var prepayment: Double
    var leaseStart: String
    var leaseEnd: String
    var leaseDuration: String
    var rentDueDay: Int // 1-31
    var waterMeterBase: Int
    var electricMeterBase: Int
    var propertyType: String // 管理, 包租, 托管
    var monthlyRentRecords: [RentMonthRecord]
    var quarterlyUtilityRecords: [UtilityQuarterRecord]
    var notes: String
    var createdAt: Date

    init(roomNumber: String = "", landlord: String = "", unitType: String = "",
         rent: Double = 0, deposit: Double = 0, prepayment: Double = 0,
         leaseStart: String = "", leaseEnd: String = "", leaseDuration: String = "",
         rentDueDay: Int = 1, waterMeterBase: Int = 0, electricMeterBase: Int = 0,
         propertyType: String = "管理", notes: String = "") {
        self.id = UUID()
        self.roomNumber = roomNumber
        self.landlord = landlord
        self.unitType = unitType
        self.rent = rent
        self.deposit = deposit
        self.prepayment = prepayment
        self.leaseStart = leaseStart
        self.leaseEnd = leaseEnd
        self.leaseDuration = leaseDuration
        self.rentDueDay = rentDueDay
        self.waterMeterBase = waterMeterBase
        self.electricMeterBase = electricMeterBase
        self.propertyType = propertyType
        self.monthlyRentRecords = []
        self.quarterlyUtilityRecords = []
        self.notes = notes
        self.createdAt = Date()
    }

    var building: String {
        roomNumber.hasPrefix("2-") ? "2座" : "1座"
    }

    var isManaged: Bool {
        propertyType == "包租" || propertyType == "托管"
    }

    // 统一显示名称（旧数据"普通"映射为"管理"）
    var typeDisplayName: String {
        propertyType == "普通" ? "管理" : propertyType
    }

    // 类型对应的单字
    var typeChar: String {
        switch typeDisplayName {
        case "包租": return "包"
        case "托管": return "托"
        default: return "管"
        }
    }

    // 类型对应的颜色
    var typeColor: Color {
        switch typeDisplayName {
        case "包租": return Color(hex: "7B61FF")
        case "托管": return Color(hex: "E09A2F")
        default: return Color(hex: "0FA48B")
        }
    }

    // 类型对应的浅色背景
    var typeBgColor: Color {
        switch typeDisplayName {
        case "包租": return Color(hex: "F0EDFF")
        case "托管": return Color(hex: "FBF1DE")
        default: return Color(hex: "E2F4EF")
        }
    }
}

@Model
final class RentMonthRecord {
    var id: UUID
    var month: Int // 1-12
    var amount: Double
    var isPaid: Bool
    var paidDate: Date?

    init(month: Int, amount: Double = 0, isPaid: Bool = false) {
        self.id = UUID()
        self.month = month
        self.amount = amount
        self.isPaid = isPaid
        self.paidDate = nil
    }
}

@Model
final class UtilityQuarterRecord {
    var id: UUID
    var quarter: Int // 1-4
    var electricAmount: Double
    var waterAmount: Double
    var isSettled: Bool

    init(quarter: Int, electricAmount: Double = 0, waterAmount: Double = 0, isSettled: Bool = false) {
        self.id = UUID()
        self.quarter = quarter
        self.electricAmount = electricAmount
        self.waterAmount = waterAmount
        self.isSettled = isSettled
    }

    var total: Double { electricAmount + waterAmount }
}
