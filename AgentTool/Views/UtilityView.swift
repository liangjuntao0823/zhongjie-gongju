import SwiftUI

struct UtilityView: View {
    @State private var electricPriceText = "0.8"
    @State private var waterPriceText = "5.5"
    @State private var electricTotalText = ""
    @State private var electricSubText = ""
    @State private var electricBaseText = ""
    @State private var waterTotalText = ""
    @State private var waterSubText = ""
    @State private var waterBaseText = ""
    @State private var prepaymentText = ""
    @State private var roomNumber = ""

    private var electricPrice: Double { Double(electricPriceText) ?? 0.8 }
    private var waterPrice: Double { Double(waterPriceText) ?? 5.5 }
    private var electricTotal: Double { Double(electricTotalText) ?? 0 }
    private var electricSub: Double { Double(electricSubText) ?? 0 }
    private var electricBase: Double { Double(electricBaseText) ?? 0 }
    private var waterTotal: Double { Double(waterTotalText) ?? 0 }
    private var waterSub: Double { Double(waterSubText) ?? 0 }
    private var waterBase: Double { Double(waterBaseText) ?? 0 }
    private var prepayment: Double { Double(prepaymentText) ?? 0 }

    private var electricUsage: Double { max(0, electricSub - electricBase) }
    private var waterUsage: Double { max(0, waterSub - waterBase) }
    private var electricCost: Double { electricUsage * electricPrice }
    private var waterCost: Double { waterUsage * waterPrice }
    private var totalCost: Double { electricCost + waterCost }
    private var balance: Double { prepayment - totalCost }

    var body: some View {
        NavigationStack {
            Form {
                Section("房源信息") {
                    TextField("房号", text: $roomNumber)
                }
                Section("单价设置") {
                    HStack { Text("电费单价").foregroundColor(.themeText); Spacer(); TextField("0.8", text: $electricPriceText).keyboardType(.decimalPad).multilineTextAlignment(.trailing).foregroundColor(.themeText).frame(width: 80); Text("元/度").foregroundColor(.themeText3) }
                    HStack { Text("水费单价").foregroundColor(.themeText); Spacer(); TextField("5.5", text: $waterPriceText).keyboardType(.decimalPad).multilineTextAlignment(.trailing).foregroundColor(.themeText).frame(width: 80); Text("元/吨").foregroundColor(.themeText3) }
                }
                Section("电费计算") {
                    HStack { Text("总表读数").foregroundColor(.themeText); Spacer(); TextField("请输入", text: $electricTotalText).keyboardType(.decimalPad).multilineTextAlignment(.trailing).foregroundColor(.themeText).frame(width: 120) }
                    HStack { Text("分表读数").foregroundColor(.themeText); Spacer(); TextField("请输入", text: $electricSubText).keyboardType(.decimalPad).multilineTextAlignment(.trailing).foregroundColor(.themeText).frame(width: 120) }
                    HStack { Text("底数").foregroundColor(.themeText); Spacer(); TextField("请输入", text: $electricBaseText).keyboardType(.decimalPad).multilineTextAlignment(.trailing).foregroundColor(.themeText).frame(width: 120) }
                    HStack { Text("用电量"); Spacer(); Text("\(Int(electricUsage)) 度").foregroundColor(.themeText2) }
                    HStack { Text("电费金额"); Spacer(); Text("¥\(String(format: "%.2f", electricCost))").foregroundColor(.themeAmber).fontWeight(.medium) }
                }
                Section("水费计算") {
                    HStack { Text("总表读数").foregroundColor(.themeText); Spacer(); TextField("请输入", text: $waterTotalText).keyboardType(.decimalPad).multilineTextAlignment(.trailing).foregroundColor(.themeText).frame(width: 120) }
                    HStack { Text("分表读数").foregroundColor(.themeText); Spacer(); TextField("请输入", text: $waterSubText).keyboardType(.decimalPad).multilineTextAlignment(.trailing).foregroundColor(.themeText).frame(width: 120) }
                    HStack { Text("底数").foregroundColor(.themeText); Spacer(); TextField("请输入", text: $waterBaseText).keyboardType(.decimalPad).multilineTextAlignment(.trailing).foregroundColor(.themeText).frame(width: 120) }
                    HStack { Text("用水量"); Spacer(); Text("\(Int(waterUsage)) 吨").foregroundColor(.themeText2) }
                    HStack { Text("水费金额"); Spacer(); Text("¥\(String(format: "%.2f", waterCost))").foregroundColor(.themeBlue).fontWeight(.medium) }
                }
                Section("预存结算") {
                    HStack { Text("预存总额").foregroundColor(.themeText); Spacer(); TextField("请输入", text: $prepaymentText).keyboardType(.decimalPad).multilineTextAlignment(.trailing).foregroundColor(.themeText).frame(width: 120) }
                    HStack { Text("水电合计"); Spacer(); Text("¥\(String(format: "%.2f", totalCost))").foregroundColor(.themeRed).fontWeight(.medium) }
                    HStack { Text("结余"); Spacer(); Text(balance >= 0 ? "¥\(String(format: "%.2f", balance))" : "-¥\(String(format: "%.2f", abs(balance)))").foregroundColor(balance >= 0 ? .themeAccentDark : .themeRed).fontWeight(.semibold) }
                }
                Section("结算单") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(roomNumber.isEmpty ? "房源结算单" : "\(roomNumber) 结算单")
                            .font(.system(size: 15, weight: .bold)).foregroundColor(.themeText)
                        Divider().background(Color.themeBorder)
                        HStack { Text("电费:").foregroundColor(.themeText2); Spacer(); Text("\(Int(electricUsage))度 × ¥\(electricPrice) = ¥\(String(format: "%.2f", electricCost))").foregroundColor(.themeText) }
                        HStack { Text("水费:").foregroundColor(.themeText2); Spacer(); Text("\(Int(waterUsage))吨 × ¥\(waterPrice) = ¥\(String(format: "%.2f", waterCost))").foregroundColor(.themeText) }
                        Divider().background(Color.themeBorder)
                        HStack { Text("合计:").fontWeight(.medium).foregroundColor(.themeText); Spacer(); Text("¥\(String(format: "%.2f", totalCost))").fontWeight(.bold).foregroundColor(.themeText) }
                        if prepayment > 0 {
                            HStack { Text("预存:").foregroundColor(.themeText2); Spacer(); Text("¥\(String(format: "%.2f", prepayment))").foregroundColor(.themeText) }
                            HStack { Text(balance >= 0 ? "应退:" : "应补:").fontWeight(.medium).foregroundColor(.themeText); Spacer(); Text("¥\(String(format: "%.2f", abs(balance)))").foregroundColor(balance >= 0 ? .themeAccentDark : .themeRed).fontWeight(.bold) }
                        }
                    }
                    .padding(.vertical, 8)
                }
                Section {
                    Button(role: .destructive) {
                        electricTotalText = ""; electricSubText = ""; electricBaseText = ""
                        waterTotalText = ""; waterSubText = ""; waterBaseText = ""
                        prepaymentText = ""; roomNumber = ""
                    } label: { HStack { Spacer(); Text("清空重置"); Spacer() } }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.themeBg)
            .navigationTitle("水电结算")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
