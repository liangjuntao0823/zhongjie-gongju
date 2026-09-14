import Foundation
import SwiftData

@Model
final class DealRecord {
    var id: UUID
    var date: Date
    var roomNumber: String
    var landlord: String
    var unitType: String
    var leasePeriod: String
    var leaseDuration: String
    var rent: Double
    var deposit: Double
    var prepayment: Double
    var rentDueDay: String
    var agentFeeLandlord: Double
    var agentFeeTenant: Double
    var totalFee: Double
    var manager: String
    var source: String
    var notes: String

    init(date: Date = Date(), roomNumber: String = "", landlord: String = "",
         unitType: String = "", leasePeriod: String = "", leaseDuration: String = "",
         rent: Double = 0, deposit: Double = 0, prepayment: Double = 0,
         rentDueDay: String = "1号", agentFeeLandlord: Double = 0,
         agentFeeTenant: Double = 0, totalFee: Double = 0, manager: String = "",
         source: String = "", notes: String = "") {
        self.id = UUID()
        self.date = date
        self.roomNumber = roomNumber
        self.landlord = landlord
        self.unitType = unitType
        self.leasePeriod = leasePeriod
        self.leaseDuration = leaseDuration
        self.rent = rent
        self.deposit = deposit
        self.prepayment = prepayment
        self.rentDueDay = rentDueDay
        self.agentFeeLandlord = agentFeeLandlord
        self.agentFeeTenant = agentFeeTenant
        self.totalFee = totalFee
        self.manager = manager
        self.source = source
        self.notes = notes
    }
}

@Model
final class MiscIncome {
    var id: UUID
    var date: Date
    var item: String
    var amount: Double
    var notes: String

    init(date: Date = Date(), item: String = "", amount: Double = 0, notes: String = "") {
        self.id = UUID()
        self.date = date
        self.item = item
        self.amount = amount
        self.notes = notes
    }
}

@Model
final class MiscExpense {
    var id: UUID
    var date: Date
    var item: String
    var amount: Double
    var notes: String

    init(date: Date = Date(), item: String = "", amount: Double = 0, notes: String = "") {
        self.id = UUID()
        self.date = date
        self.item = item
        self.amount = amount
        self.notes = notes
    }
}
