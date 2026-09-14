import SwiftUI

struct UtilityView: View {
    @State private var electricPrice: Double = 0.8
    @State private var waterPrice: Double = 5.5
    @State private var electricTotal: Double = 0
    @State private var electricSub: Double = 0
    @State private var electricBase: Double = 0
    @State private var waterTotal: Double = 0
    @State private var waterSub: Double = 0
    @State private var waterBase: Double = 0
    @State private var prepayment: Double = 0
    @State private var roomNumber = ""

    private var electricUsage: Double {
        max(0, electricSub - electricBase)
    }

    private var waterUsage: Double {
        max(0, waterSub - waterBase)
    }

    private var electricCost: Double {
        electricUsage * electricPrice
    }

    private var waterCost: Double {
        waterUsage * waterPrice
    }

    private var totalCost: Double {
        electricCost + waterCost
    }

    private var balance: Double {
        prepayment - totalCost
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("房源信息") {
                    TextField("房号", text: $roomNumber)
                }

                Section("单价设置") {
                    HStack {
                        Text("电费单价")
                        TextField("0.8", value: $electricPrice, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                        Text("元/度")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("水费单价")
                        TextField("5.5", value: $waterPrice, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                        Text("元/吨")
                            .foregroundColor(.secondary)
                    }
                }

                Section("电费计算") {
                    HStack {
                        Text("总表读数")
                        TextField("0", value: $electricTotal, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("分表读数")
                        TextField("0", value: $electricSub, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("底数")
                        TextField("0", value: $electricBase, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("用电量")
                        Spacer()
                        Text("\(Int(electricUsage)) 度")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("电费金额")
                        Spacer()
                        Text("¥\(String(format: "%.2f", electricCost))")
                            .foregroundColor(.orange)
                            .fontWeight(.medium)
                    }
                }

                Section("水费计算") {
                    HStack {
                        Text("总表读数")
                        TextField("0", value: $waterTotal, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("分表读数")
                        TextField("0", value: $waterSub, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("底数")
                        TextField("0", value: $waterBase, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("用水量")
                        Spacer()
                        Text("\(Int(waterUsage)) 吨")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("水费金额")
                        Spacer()
                        Text("¥\(String(format: "%.2f", waterCost))")
                            .foregroundColor(.blue)
                            .fontWeight(.medium)
                    }
                }

                Section("预存结算") {
                    HStack {
                        Text("预存总额")
                        TextField("0", value: $prepayment, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("水电合计")
                        Spacer()
                        Text("¥\(String(format: "%.2f", totalCost))")
                            .foregroundColor(.red)
                            .fontWeight(.medium)
                    }
                    HStack {
                        Text("结余")
                        Spacer()
                        Text(balance >= 0 ? "¥\(String(format: "%.2f", balance))" : "-¥\(String(format: "%.2f", abs(balance)))")
                            .foregroundColor(balance >= 0 ? .green : .red)
                            .fontWeight(.semibold)
                    }
                }

                Section("结算单") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(roomNumber.isEmpty ? "房源结算单" : "\(roomNumber) 结算单")
                            .font(.headline)
                        Divider()
                        HStack { Text("电费:"); Spacer(); Text("\(Int(electricUsage))度 × ¥\(electricPrice) = ¥\(String(format: "%.2f", electricCost))") }
                        HStack { Text("水费:"); Spacer(); Text("\(Int(waterUsage))吨 × ¥\(waterPrice) = ¥\(String(format: "%.2f", waterCost))") }
                        Divider()
                        HStack { Text("合计:"); Spacer(); Text("¥\(String(format: "%.2f", totalCost))").fontWeight(.bold) }
                        if prepayment > 0 {
                            HStack { Text("预存:"); Spacer(); Text("¥\(String(format: "%.2f", prepayment))") }
                            HStack { Text(balance >= 0 ? "应退:" : "应补:"); Spacer(); Text("¥\(String(format: "%.2f", abs(balance)))").foregroundColor(balance >= 0 ? .green : .red).fontWeight(.bold) }
                        }
                    }
                    .padding(.vertical, 8)
                }

                Section {
                    Button(role: .destructive) {
                        electricTotal = 0; electricSub = 0; electricBase = 0
                        waterTotal = 0; waterSub = 0; waterBase = 0
                        prepayment = 0; roomNumber = ""
                    } label: {
                        HStack {
                            Spacer()
                            Text("清空重置")
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("水电结算")
        }
    }
}
