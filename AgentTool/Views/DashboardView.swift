import SwiftUI
import SwiftData

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var tabRouter: TabRouter
    @State private var stats: DashboardStats?
    @State private var currentTime = Date()
    @State private var showUtility = false
    @State private var showAddDeal = false
    @State private var showAddRent = false
    @State private var showAddPayout = false
    @State private var showAddIncome = false
    @State private var showAddExpense = false

    private let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    private var daysRemainingInMonth: Int {
        let calendar = Calendar.current
        let now = Date()
        let range = calendar.range(of: .day, in: .month, for: now)!
        let currentDay = calendar.component(.day, from: now)
        return range.count - currentDay
    }

    private var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: currentTime)
    }

    private var dateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年M月d日 EEEE"
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: currentTime)
    }

    // 未收租提醒：交租日前3天内且未收租的房源
    private var upcomingRentReminders: [RentReminder] {
        let calendar = Calendar.current
        let now = Date()
        let currentMonth = calendar.component(.month, from: now)
        let currentDay = calendar.component(.day, from: now)
        let currentYear = calendar.component(.year, from: now)

        var reminders: [RentReminder] = []
        let descriptor = FetchDescriptor<Property>()
        guard let properties = try? modelContext.fetch(descriptor) else { return [] }

        for prop in properties {
            // 当月是否已收租
            let paid = prop.monthlyRentRecords.contains { $0.month == currentMonth && $0.isPaid }
            if paid { continue }

            let dueDay = prop.rentDueDay
            // 计算距离交租日的天数
            var daysUntilDue = dueDay - currentDay
            if daysUntilDue < 0 {
                // 已过交租日，也算提醒（逾期）
                daysUntilDue = 0
            }

            if daysUntilDue <= 3 {
                // 计算水电结算状态
                let needUtilitySettlement = needsUtilitySettlement(for: prop, currentMonth: currentMonth, currentYear: currentYear)
                let utilitySettled = isUtilitySettled(for: prop, currentMonth: currentMonth, currentYear: currentYear)

                reminders.append(RentReminder(
                    roomNumber: prop.roomNumber,
                    landlord: prop.landlord,
                    amount: prop.rent,
                    dueDay: dueDay,
                    daysUntilDue: daysUntilDue,
                    needUtility: needUtilitySettlement,
                    utilitySettled: utilitySettled
                ))
            }
        }
        return reminders.sorted { $0.daysUntilDue < $1.daysUntilDue }
    }

    // 判断当前月份是否需要结算水电（每季度一次，根据首次交租月）
    private func needsUtilitySettlement(for prop: Property, currentMonth: Int, currentYear: Int) -> Bool {
        // 找到首次交租月份
        var startMonth = currentMonth
        if let firstRecord = prop.monthlyRentRecords.sorted(by: { $0.month < $1.month }).first {
            startMonth = firstRecord.month
        }
        // 计算月份差
        let monthsDiff = (currentYear - 2025) * 12 + (currentMonth - startMonth)
        return monthsDiff >= 3 && monthsDiff % 3 == 0
    }

    // 判断水电是否已结算
    private func isUtilitySettled(for prop: Property, currentMonth: Int, currentYear: Int) -> Bool {
        if !needsUtilitySettlement(for: prop, currentMonth: currentMonth, currentYear: currentYear) {
            return true // 不需要结算则视为已完成
        }
        // 找到对应的季度记录
        var startMonth = currentMonth
        if let firstRecord = prop.monthlyRentRecords.sorted(by: { $0.month < $1.month }).first {
            startMonth = firstRecord.month
        }
        let monthsDiff = (currentYear - 2025) * 12 + (currentMonth - startMonth)
        let quarterIndex = (monthsDiff / 3 - 1) % 4 + 1
        return prop.quarterlyUtilityRecords.contains { $0.quarter == quarterIndex && $0.isSettled }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // 顶部标题
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("工作台")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.themeText)
                        Text("经营概览")
                            .font(.system(size: 12.5))
                            .foregroundColor(.themeText2)
                    }
                    Spacer()
                    Button {
                        tabRouter.selectedTab = 2
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color.themeRed.opacity(0.1))
                                .frame(width: 38, height: 38)
                            Image(systemName: "bell.fill")
                                .foregroundColor(.themeRed)
                                .font(.system(size: 16))
                            if !upcomingRentReminders.isEmpty {
                                Text("\(upcomingRentReminders.count)")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(width: 16, height: 16)
                                    .background(Circle().fill(Color.themeRed))
                                    .offset(x: 10, y: -10)
                            }
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)

                // 时间卡片
                VStack(spacing: 6) {
                    Text(timeString)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                        .fontDesign(.rounded)
                    Text(dateString)
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.9))
                    Text("本月还剩\(daysRemainingInMonth)天，加油！")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                        .padding(.top, 2)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    LinearGradient(gradient: Gradient(colors: [Color.themeAccent, Color.themeAccentDark]),
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .cornerRadius(14)
                .padding(.horizontal)

                // 快捷操作
                VStack(alignment: .leading, spacing: 12) {
                    SectionTitle(title: "快捷操作")
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                        QuickActionItem(icon: "plus.circle.fill", label: "新增成交", color: .themeAccent) {
                            showAddDeal = true
                        }
                        QuickActionItem(icon: "creditcard.fill", label: "登记收租", color: .themeBlue) {
                            showAddRent = true
                        }
                        QuickActionItem(icon: "arrow.up.circle.fill", label: "包租打租", color: Color(hex: "6B3FA0")) {
                            showAddPayout = true
                        }
                        QuickActionItem(icon: "dollarsign.circle.fill", label: "新增收入", color: Color(hex: "2E8B57")) {
                            showAddIncome = true
                        }
                        QuickActionItem(icon: "dollarsign.circle.fill", label: "新增支出", color: Color(hex: "CD5C5C")) {
                            showAddExpense = true
                        }
                        QuickActionItem(icon: "bolt.fill", label: "水电结算", color: .themeAmber) {
                            showUtility = true
                        }
                    }
                }
                .padding(16)
                .background(Color.themePanel)
                .cornerRadius(14)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.themeBorder, lineWidth: 1))
                .padding(.horizontal)

                // KPI 看板
                VStack(spacing: 0) {
                    // 第一行：在管房间、即将到期
                    HStack(spacing: 10) {
                        KpiCard(
                            label: "在管房间",
                            value: "\(stats?.activeProperties ?? 0)",
                            unit: "套",
                            foot: "在管\(stats?.activeProperties ?? 0)套 · 托管/包租\(stats?.managedProperties ?? 0)套",
                            style: .normal
                        )
                        KpiCard(
                            label: "即将到期",
                            value: "\(stats?.expiringSoon.count ?? 0)",
                            unit: "套",
                            foot: "30天内到期",
                            style: (stats?.expiringSoon.count ?? 0) > 0 ? .alert : .normal
                        )
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)

                    // 分界虚线
                    HStack {
                        Rectangle()
                            .fill(Color.themeBorder)
                            .frame(height: 1)
                            .overlay(
                                Rectangle()
                                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                                    .foregroundColor(Color.themeBorder)
                            )
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                    // 第二行：本月中介费、杂项收入、杂项支出、本月收入
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        KpiCard(
                            label: "本月中介费",
                            value: "\(Int(stats?.monthlyDealFee ?? 0))",
                            unit: "元",
                            foot: "累计\(stats?.totalDeals ?? 0)单",
                            style: .normal
                        )
                        KpiCard(
                            label: "杂项收入",
                            value: "\(Int(stats?.monthlyMiscIncome ?? 0))",
                            unit: "元",
                            foot: "本月",
                            style: .normal
                        )
                        KpiCard(
                            label: "杂项支出",
                            value: "\(Int(stats?.monthlyMiscExpense ?? 0))",
                            unit: "元",
                            foot: "本月",
                            style: .normal
                        )
                        KpiCard(
                            label: "本月收入",
                            value: "\(Int(stats?.monthlyNetIncome ?? 0))",
                            unit: "元",
                            foot: "中介费+收入-支出",
                            style: (stats?.monthlyNetIncome ?? 0) >= 0 ? .normal : .alert
                        )
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }
                .background(Color.themePanel)
                .cornerRadius(14)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.themeBorder, lineWidth: 1))
                .padding(.horizontal)

                // 收租进度
                VStack(alignment: .leading, spacing: 10) {
                    SectionTitle(title: "收租进度", subtitle: "本月")
                    let progress = (stats?.monthlyRentReceivable ?? 0) > 0 ? (stats?.monthlyRentCollected ?? 0) / (stats?.monthlyRentReceivable ?? 1) : 0
                    ProgressView(value: progress)
                        .tint(Color.themeAccent)
                        .scaleEffect(x: 1, y: 1.5)
                    HStack {
                        Label("已收 ¥\(Int(stats?.monthlyRentCollected ?? 0))", systemImage: "checkmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.themeAccentDark)
                        Spacer()
                        Label("未收 ¥\(Int((stats?.monthlyRentReceivable ?? 0) - (stats?.monthlyRentCollected ?? 0)))", systemImage: "clock.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.themeAmber)
                    }
                }
                .padding(16)
                .background(Color.themePanel)
                .cornerRadius(14)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.themeBorder, lineWidth: 1))
                .padding(.horizontal)

                // 未收租提醒
                if !upcomingRentReminders.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        SectionTitle(title: "未收租提醒", subtitle: "\(upcomingRentReminders.count)套")
                        ForEach(upcomingRentReminders, id: \.roomNumber) { reminder in
                            HStack(spacing: 10) {
                                VStack(alignment: .center, spacing: 2) {
                                    Text("\(reminder.dueDay)")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundColor(reminder.daysUntilDue == 0 ? .themeRed : .themeAmber)
                                    Text("号交租")
                                        .font(.system(size: 10))
                                        .foregroundColor(.themeText3)
                                }
                                .frame(width: 44)
                                .padding(.vertical, 6)
                                .background(reminder.daysUntilDue == 0 ? Color(hex: "FDF0F0") : Color(hex: "FBF1DE"))
                                .cornerRadius(8)

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(reminder.roomNumber)
                                        .font(.system(size: 13.5, weight: .semibold))
                                        .foregroundColor(.themeText)
                                    Text("房东: \(reminder.landlord)")
                                        .font(.system(size: 11))
                                        .foregroundColor(.themeText2)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 3) {
                                    Text("¥\(Int(reminder.amount))")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(.themeText)
                                    if reminder.needUtility {
                                        HStack(spacing: 3) {
                                            Text("水电")
                                                .font(.system(size: 10))
                                                .foregroundColor(.themeText3)
                                            Text(reminder.utilitySettled ? "✅" : "❌")
                                                .font(.system(size: 12))
                                        }
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                            if reminder.roomNumber != upcomingRentReminders.last?.roomNumber {
                                Divider().background(Color.themeBorder)
                            }
                        }
                    }
                    .padding(16)
                    .background(Color.themePanel)
                    .cornerRadius(14)
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.themeBorder, lineWidth: 1))
                    .padding(.horizontal)
                }

                // 即将到期
                if let expiring = stats?.expiringSoon, !expiring.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        SectionTitle(title: "即将到期", subtitle: "\(expiring.count)套")
                        ForEach(expiring.prefix(3), id: \.id) { prop in
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color.themeAccentWeak)
                                        .frame(width: 36, height: 36)
                                    Text(String(prop.roomNumber.prefix(2)))
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.themeAccentDark)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(prop.roomNumber)
                                        .font(.system(size: 13.5, weight: .semibold))
                                        .foregroundColor(.themeText)
                                    Text("\(prop.unitType) · 房东\(prop.landlord)")
                                        .font(.system(size: 12))
                                        .foregroundColor(.themeText3)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(prop.leaseEnd)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.themeAmber)
                                    StatusTag(text: "待续约", style: .warn)
                                }
                            }
                            .padding(.vertical, 4)
                            if prop.id != expiring.prefix(3).last?.id {
                                Divider().background(Color.themeBorder)
                            }
                        }
                    }
                    .padding(16)
                    .background(Color.themePanel)
                    .cornerRadius(14)
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.themeBorder, lineWidth: 1))
                    .padding(.horizontal)
                }

                Spacer().frame(height: 16)
            }
        }
        .background(Color.themeBg)
        .onAppear {
            stats = DataManager.shared.dashboardStats(modelContext: modelContext)
        }
        .onReceive(timer) { _ in
            currentTime = Date()
        }
        .sheet(isPresented: $showUtility) {
            NavigationStack { UtilityView() }
        }
        .sheet(isPresented: $showAddDeal) {
            NavigationStack { AddDealView() }
        }
        .sheet(isPresented: $showAddRent) {
            NavigationStack { AddPropertyView() }
        }
        .sheet(isPresented: $showAddPayout) {
            NavigationStack { AddPayoutView() }
        }
        .sheet(isPresented: $showAddIncome) {
            NavigationStack { AddMiscView(type: .income) }
        }
        .sheet(isPresented: $showAddExpense) {
            NavigationStack { AddMiscView(type: .expense) }
        }
        .navigationTitle("工作台")
        .navigationBarHidden(true)
    }
}

// MARK: - 未收租提醒模型
struct RentReminder {
    let roomNumber: String
    let landlord: String
    let amount: Double
    let dueDay: Int
    let daysUntilDue: Int
    let needUtility: Bool
    let utilitySettled: Bool
}

// MARK: - KPI 卡片
struct KpiCard: View {
    let label: String
    let value: String
    let unit: String
    let foot: String
    var style: KpiStyle = .normal

    enum KpiStyle {
        case normal, accent, alert
    }

    private var dotColor: Color {
        switch style {
        case .accent: return .white
        case .alert: return .themeRed
        case .normal: return .themeAccent
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Circle()
                    .fill(dotColor)
                    .frame(width: 7, height: 7)
                    .shadow(color: dotColor.opacity(0.6), radius: 4)
                Text(label)
                    .font(.system(size: 11))
                    .foregroundColor(style == .accent ? .white.opacity(0.9) : .themeText2)
            }
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(style == .accent ? .white : (style == .alert ? .themeRed : .themeText))
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                Text(unit)
                    .font(.system(size: 11))
                    .foregroundColor(style == .accent ? .white.opacity(0.7) : .themeText3)
            }
            Text(foot)
                .font(.system(size: 11))
                .foregroundColor(style == .accent ? .white.opacity(0.7) : .themeText3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            Group {
                if style == .accent {
                    LinearGradient(gradient: Gradient(colors: [Color.themeAccent, Color.themeAccentDark]),
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                } else if style == .alert {
                    Color(hex: "FDF5F5")
                } else {
                    Color.themePanel
                }
            }
        )
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(style == .normal ? Color.themeBorder : (style == .alert ? Color(hex: "F4D9D9") : Color.clear), lineWidth: 1)
        )
    }
}

struct QuickActionItem: View {
    let icon: String
    let label: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 26))
                    .foregroundColor(color)
                Text(label)
                    .font(.system(size: 11))
                    .foregroundColor(.themeText)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }
}
